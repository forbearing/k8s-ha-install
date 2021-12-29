#!/usr/bin/env bash

function 1_install_docker {
    echo "1. [`hostname`] Install docker"

    _apt_wait && apt-get remove -y docker docker-engine docker.io containerd runc
    _apt_wait && apt-get update -y
    _apt_wait && apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

    local docker_url
    if [[ ${TIMEZONE} == "Asia/Shanghai" || ${TIMEZONE} == "Asia/Chongqing" ]]; then
        #docker_url="https://mirrors.ustc.edu.cn/docker-ce"
        #docker_url="https://mirrors.aliyun.com/docker-ce"
        docker_url="https://mirrors.163.com/docker-ce"
    else
        docker_url="https://download.docker.com"; fi

    while true; do
        if curl -fsSL ${docker_url}/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
            break; fi
        sleep 1
    done
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] ${docker_url}/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    _apt_wait && apt-get update -y
    ##===== BEGIN: install specific version docker
    #local docker_version="5:19.03.15~3-0~ubuntu-$(lsb_release -sc)"
    #apt-mark unhold docker-ce docker-ce-cli
    #apt-get install -y --allow-downgrades docker-ce=${docker_version} docker-ce-cli=${docker_version} containerd.io
    #apt-mark hold docker-ce docker-ce-cli
    ## END
    #===== BEGIN install latest docker
    _apt_wait && apt-get install -y --allow-downgrades docker-ce docker-ce-cli containerd.io
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

cat > /etc/docker/daemon.json <<-\EOF
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


function configure_containerd {
    echo "3. [`hostname`] Configure containerd"
    sed -i "s/^KillMode=process/KillMode=mixed/g" /lib/systemd/system/containerd.service
    systemctl daemon-reload
}

function 3_audit_for_docker {
    echo "4. [`hostname`] Audit for Docker"
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


function main {
    1_install_docker
    2_configure_docker
    3_audit_for_docker
}
