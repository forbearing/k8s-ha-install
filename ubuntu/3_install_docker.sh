#!/usr/bin/env bash

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }


function 1_install_necessary_package_for_docker {
    MSG2 "1. Install package for docker"
    yum install -y docker-ce-19.03.15-3.el7
    systemctl enable --now docker
}

function 2_install_docker {
    MSG2 "2. Install docker"
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

MSG1 "*** `hostname` *** ### Install Docker"
1_install_necessary_package_for_docker
2_install_docker
