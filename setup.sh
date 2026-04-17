#!/bin/bash
set -e

BRIDGE=br0
BRIDGE_IP=192.168.100.1/24
SUBNET=192.168.100.0/24
GATEWAY_IP=192.168.100.1
WAN_IF=wlo1

MASTER_IMAGE=ubuntu-disk-master.img
NUM_VMS=4

declare -A VM_CONFIG=(
  ["vm1"]="52:54:00:12:34:01,192.168.100.10"
  ["vm2"]="52:54:00:12:34:02,192.168.100.11"
  ["vm3"]="52:54:00:12:34:03,192.168.100.12"
  ["vm4"]="52:54:00:12:34:04,192.168.100.13"
)

ip link show $BRIDGE &>/dev/null || ip link add $BRIDGE type bridge
ip addr add $BRIDGE_IP dev $BRIDGE 2>/dev/null || true
ip link set $BRIDGE up

sysctl -w net.ipv4.ip_forward=1 >/dev/null

iptables -C FORWARD -i $BRIDGE -o $WAN_IF -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i $BRIDGE -o $WAN_IF -j ACCEPT

iptables -C FORWARD -i $WAN_IF -o $BRIDGE -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i $WAN_IF -o $BRIDGE -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -t nat -C POSTROUTING -s $SUBNET -o $WAN_IF -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s $SUBNET -o $WAN_IF -j MASQUERADE

apt-get install -y dnsmasq

cat > /etc/dnsmasq.conf <<EOF
interface=$BRIDGE
bind-interfaces
dhcp-range=192.168.100.50,192.168.100.200,255.255.255.0,12h
dhcp-option=3,$GATEWAY_IP
dhcp-option=6,1.1.1.1,8.8.8.8
EOF

for VM in "${!VM_CONFIG[@]}"; do
  echo "dhcp-host=${VM_CONFIG[$VM]}" >> /etc/dnsmasq.conf
done

systemctl restart dnsmasq

for i in $(seq 1 $NUM_VMS); do
  TAP="tap$((i-1))"
  VM="vm$i"
  OVERLAY="${VM}-overlay.qcow2"
  IFS=',' read -r MAC IP <<< "${VM_CONFIG[$VM]}"

  ip tuntap add $TAP mode tap 2>/dev/null || true
  ip link set $TAP master $BRIDGE
  ip link set $TAP up

  [ -f $OVERLAY ] || qemu-img create -f qcow2 -b $MASTER_IMAGE -F qcow2 $OVERLAY

  qemu-system-x86_64 \
    -m 2048 \
    -smp 2 \
    -hda $OVERLAY \
    -netdev tap,id=net0,ifname=$TAP,script=no,downscript=no \
    -device virtio-net-pci,netdev=net0,mac=$MAC \
    -nographic \
    -enable-kvm &
done