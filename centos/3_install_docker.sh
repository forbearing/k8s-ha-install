#!/usr/bin/env bash

1_install_docker() {
    echo "1. [`hostname`] Install docker"

    yum remove -y docker docker-client docker-client-latest docker-common \
        docker-latest docker-latest-logrotate docker-logrotate docker-engine
    yum install -y docker-ce docker-ce-cli containerd.io
    systemctl enable --now docker
}


2_configure_docker() {
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


main() {
    1_install_docker
    2_configure_docker
}
