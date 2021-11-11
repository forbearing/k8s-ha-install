#!/usr/bin/env bash

function 1_install_docker {
    echo "1. [`hostname`] Install docker"

    # Disable IPv6
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1

    yum remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
    if [[ ${TIMEZONE} == "Asia/Shanghai" || ${TIMEZONE} == "Asia/Chongqing" ]]; then
        echo y | cp /tmp/yum.repos.d/docker-ce.repo-aliyun /etc/yum.repos.d/docker.repo
    else
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo; fi
    #===== BEGIN install specific version docker
    #yum install -y docker-ce-19.03.15-3.el7
    # END

    #===== BEGIN intall latest docker
    yum install -y docker-ce docker-ce-cli containerd.io
    # END
    systemctl enable --now docker
}


function 2_configure_docker {
    echo "2. [`hostname`] Configure docker"
    while true; do
        if ls -d /etc/docker; then
            break
        else
            sleep 3
        fi
    done

cat > /etc/docker/daemon.json <<-EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
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


function main {
    1_install_docker
    2_configure_docker
}
