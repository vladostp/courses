#!/bin/bash
set -e

DOCKER_VERSION=5:24.0.7-1~ubuntu.22.04~jammy

echo "Initilization started..."

echo "Configuring apt..."
cat > /etc/apt/apt.conf.d/proxy <<EOL
Acquire::http::Proxy "http://proxy.univ-lyon1.fr:3128/";
Acquire::https::Proxy "http://proxy.univ-lyon1.fr:3128/";
EOL

chmod 644 '/etc/apt/apt.conf.d/proxy'

echo "Adding proxy env vars..."
cat > /etc/environment <<EOL
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
http_proxy=http://proxy.univ-lyon1.fr:3128
ftp_proxy=http://proxy.univ-lyon1.fr:3128
https_proxy=http://proxy.univ-lyon1.fr:3128
all_proxy=http://proxy.univ-lyon1.fr:3128
HTTP_PROXY=http://proxy.univ-lyon1.fr:3128
FTP_PROXY=http://proxy.univ-lyon1.fr:3128
HTTPS_PROXY=http://proxy.univ-lyon1.fr:3128
ALL_PROXY=http://proxy.univ-lyon1.fr:3128
no_proxy=univ-lyon1.fr,127.0.0.1,localhost,192.168.0.0/16
NO_PROXY=univ-lyon1.fr,127.0.0.1,localhost,192.168.0.0/16
EOL
https_proxy=http://proxy.univ-lyon1.fr:3128 
http_proxy=http://proxy.univ-lyon1.fr:3128 
export https_proxy
export http_proxy

echo "Installing docker..."
apt-get update
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove $pkg; done
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce=$DOCKER_VERSION docker-ce-cli=$DOCKER_VERSION containerd.io docker-buildx-plugin docker-compose-plugin

echo "Configuring docker daemon..."

cat > /etc/docker/daemon.json <<EOL
{
    "bip": "10.247.0.1/25",
    "dns": ["10.10.10.10","10.10.10.11"],
    "default-address-pools":[
        {"base":"10.247.0.0/16","size":25}
    ],
    "registry-mirrors": ["https://docker-mirror.univ-lyon1.fr"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "10"
    }
}
EOL
groupadd -f docker
usermod -aG docker ubuntu

echo "Initilization success rebooting..."
sudo reboot 0
