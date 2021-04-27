#!/usr/bin/env bash

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }


function 1_install_docker {
    MSG2 "1. Install docker"

    apt-get remove -y docker docker-engine docker.io containerd runc
    apt-get update -y
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
      "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io
    local VERSION_STRING=""
    VERSION_STRING="5:19.03.15~3-0~ubuntu-bionic"
    apt-get install -y docker-ce=${VERSION_STRING} docker-ce-cli=${VERSION_STRING} containerd.io
    apt-mark hold docker-ce
    systemctl enable --now docker
}


function 2_configure_docker {
    MSG2 "2. Configure docker"

cat > /etc/docker/daemon.json <<-EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": ["https://f4kfbhwb.mirror.aliyuncs.com"],
  "insecure-registries": ["http://registry.qxis-dev.com"],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "log-driver": "json-file",
  "live-restore": true,
  "log-opts": {
    "max-size": "300m",
    "max-file": "2"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
      "overlay2.override_kernel_check=true"
  ]
}
EOF
    systemctl daemon-reload
    systemctl restart docker
}


MSG1 "*** `hostname` *** Install Docker"
1_install_docker
2_configure_docker
