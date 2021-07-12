#!/usr/bin/env bash

# to-do-list
# ubuntu20 和 ubuntu18 的 VERSION_STRING 不一样，需要设置

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
    while true; do
        #if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
        if curl -fsSL http://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
            break; fi
        sleep 1
    done
    echo \
      "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sed -i s%download.docker.com%mirrors.ustc.edu.cn/docker-ce% /etc/apt/sources.list.d/docker.list                 # mirror.ustc.edu.cn for docker-ce
    apt-get update -y
    local VERSION_STRING=""
    local RELEASE=""
    RELEASE=$(cat /etc/os-release | grep VERSION= | awk -F'.' '{print $1}' | awk -F \" '{print $2}')
    if [[ ${RELEASE} -eq 18 ]]; then
        VERSION_STRING="5:19.03.15~3-0~ubuntu-bionic"
    elif [[ ${RELEASE} -eq 20 ]]; then
        VERSION_STRING="5:19.03.15~3-0~ubuntu-focal"; fi
    apt-get install -y --allow-downgrades docker-ce=${VERSION_STRING} docker-ce-cli=${VERSION_STRING} containerd.io
    apt-mark hold docker-ce docker-ce-cli
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


function 3_configure_containerd {
    MSG2 "3. Configure containerd"
    sed -i "s/^KillMode=process/KillMode=mixed/g" /lib/systemd/system/containerd.service
    systemctl daemon-reload
}

function 4_audit_for_docker {
    MSG2 "4. Audit for Docker"
    audit_file=(
        "-w /var/lib/docker -p wa"
        "-w /etc/docker -p wa"
        "-w /lib/systemd/system/docker.service -p wa"
        "-w /lib/systemd/system/docker.socket -p wa"
        "-w /etc/default/docker -p wa"
        "-w /etc/docker/daemon.json -p wa"
        "-w /usr/bin/docker -p wa"
        "-w /usr/bin/containerd -p wa"
        "-w /usr/bin/containerd-shim -p wa"
        "-w /usr/bin/containerd-shim-runc-v1 -p wa"
        "-w /usr/bin/containerd-shim-runc-v2 -p wa"
        "-w /usr/bin/runc -p wa"
        "-w /run/containerd -p wa"
        "-w /etc/containerd/config.toml -p wa"
        )
    printf "%s\n" "${audit_file[@]}" > /etc/audit/rules.d/docker.rules
}


MSG1 "*** `hostname` *** Install Docker"
1_install_docker
2_configure_docker
#3_configure_containerd
4_audit_for_docker
