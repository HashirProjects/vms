# Setup Guide

- download ubuntu server, I am using ubuntu-24.04.4-live-server-amd64

- use qemu to create a disk:

qemu-img create -f qcow2 ubuntu-disk-master.qcow2 20G

- setup the master image using just the defaults for all options, configure ssh so we can actually get into it and obv remember all the passwords and keys you set.

- run setup.sh (and read it too, it explains the network topology we are setting up)

vm1 - control plane
vm2 - worker
vm3 - worker
vm4 - docker 

- ssh into vm4 and install docker via:

sudo sed -i 's|http://|https://|g' /etc/apt/sources.list.d/ubuntu.sources
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io

sudo systemctl enable --now docker

sudo usermod -aG docker $USER
newgrp docker

docker run hello-world

- scp app and dockerfile to a directory in vm4

- docker build and docker run in vm4:

docker build -t flask . && docker run -p 5000:5000 flask

- create registry:

docker run -d -p 5000:5000 --restart=always --name registry registry:2

- since this is http, we need to edit /etc/docker/daemon.json:

sudo -i
cat > /etc/docker/daemon.json << EOF
{
  "insecure-registries": ["192.168.100.13:5000"]
}
EOF
systemctl restart docker

- if that works, push it to the registry:

docker build -t 192.168.100.13:5000/flask:latest .
docker push 192.168.100.13:5000/flask:latest

- on vm1 (control plane):

curl -sfL https://get.k3s.io | sh -

- get the token for the worker nodes:

sudo cat /var/lib/rancher/k3s/server/node-token

- on vm2 and vm3 (workers), replacing the token, node_name and IP:

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.100.10:6443 K3S_TOKEN=<TOKEN_HERE> K3S_NODE_NAME=vm2 sh -

- tell k3s about the insecure registry, on vm2, and vm3:

sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  "192.168.100.13:5000":
    endpoint:
      - "http://192.168.100.13:5000"
EOF
sudo systemctl restart k3s-agent

- and on vm1:

sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  "192.168.100.13:5000":
    endpoint:
      - "http://192.168.100.13:5000"
EOF
sudo systemctl restart k3s

- verify everything is up, on vm1:

sudo kubectl get nodes