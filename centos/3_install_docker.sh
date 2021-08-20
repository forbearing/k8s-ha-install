#!/usr/bin/env bash

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }


function 1_install_docker {
    MSG2 "1. [`hostname`] Install docker"

    yum remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
    if [[ ${TIMEZONE} == "Asia/Shanghai" || ${TIMEZONE} == "Asia/Chongqing" ]]; then
        echo y | cp /etc/yum.repos.d/docker.repo /etc/yum.repos.d/docker.repo.$(date +%Y%m%d%H%M)
        echo y | cp /tmp/yum.repos.d/yum.repos.d/docker-ce.repo-aliyun /etc/yum.repos.d/docker.repo
    else
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo; fi
    yum install -y docker-ce-19.03.15-3.el7
    systemctl enable --now docker
}


function 2_configure_docker {
    MSG2 "2. [`hostname`] Configure docker"

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
    "max-file": "5"
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
