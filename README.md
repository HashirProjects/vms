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

- scp app and dockerfile to a directory in vm 4

- docker build and docker run:

docker build -t flask . && docker run -p 5000:5000 flask


