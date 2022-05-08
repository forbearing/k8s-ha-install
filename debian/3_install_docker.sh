#!/usr/bin/env bash

1_install_docker() {
    echo "1. [`hostname`] Install docker"

    _apt_wait && apt-get remove -y docker docker-engine docker.io containerd runc
    _apt_wait && apt-get update -y
    _apt_wait && apt-get install -y --allow-downgrades docker-ce docker-ce-cli containerd.io
    systemctl enable --now docker containerd
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


3_configure_containerd() {
    echo "3. [`hostname`] Configure containerd"

    echo "KUBE_VERSION:     $KUBE_VERSION"
    if [[ $KUBE_VERSION == "v1.20" || \
          $KUBE_VERSION == "v1.21" || \
          $KUBE_VERSION == "v1.22" || \
          $KUBE_VERSION == "v1.23" ]]; then
        echo "no need to setup containerd"
        return
    fi

    local containerd_conf_dir="/etc/containerd"
    local containerd_conf_path=${containerd_conf_dir}/config.toml

    # create containerd directory if not exist
    if [ ! -d $containerd_conf_dir ]; then
        rm -rf $containerd_conf_dir
        echo "mkdir $containerd_conf_dir"
        mkdir -p $containerd_conf_dir
    fi
    # backup containerd config if already exist.
    if [ -f $containerd_conf_path ]; then
        echo "backup $containerd_conf_path"
        yes | cp $containerd_conf_path $containerd_conf_path.$(date +%Y%m%d%H%M%S)
    fi

    # generate containerd default config
    containerd config default > $containerd_conf_path
    # replace "SystemdCgroup"
    sed -i "/SystemdCgroup =/d" $containerd_conf_path
    sed -i '/containerd.runtimes.runc.options/a\ \ \ \ \ \ \ \ \ \ \ \ SystemdCgroup = true' $containerd_conf_path
    if [[ $TIMEZONE == "Asia/Shanghai" || $TIMEZONE == "Asia/Chongqing" ]]; then
        # replace google_container
        sed -r -i "s%(.*)sandbox_image = (.*)/pause:(.*)%\1sandbox_image = \"registry.cn-hangzhou.aliyuncs.com/google_containers/pause:\3%" $containerd_conf_path
        sed -r -i "s%(.*)sandbox_image(.*)pause:(.*)%\1sandbox_image\2pause:3.7\"%g" $containerd_conf_path
    fi

    # reload contaienrd daemon
    systemctl daemon-reload
    systemctl restart containerd

    # setting runtime endpoint in the crictl config file
    local crictl_conf_path="/etc/crictl.yaml"
    #sed -i '/^runtime-endpoint:/d'                                    $crictl_conf_path
    #sed -i '/^image-endpoint:/d'                                      $crictl_conf_path
    #sed -i '/^timeout:/d'                                             $crictl_conf_path
    #sed -i '/^debug:/d'                                               $crictl_conf_path
    echo "runtime-endpoint: unix:///run/containerd/containerd.sock" > $crictl_conf_path
    echo "image-endpoint: unix:///run/containerd/containerd.sock" >>  $crictl_conf_path
    echo "timeout: 10" >>                                             $crictl_conf_path
    echo "debug: false" >>                                            $crictl_conf_path
}

audit_for_docker() {
    # echo "4. [`hostname`] Audit for Docker"
    # audit_file=(
    #     "-w /var/lib/docker -p wa"
    #     "-w /etc/docker -p wa"
    #     "-w /lib/systemd/system/docker.service -p wa"
    #     "-w /lib/systemd/system/docker.socket -p wa"
    #     "-w /etc/default/docker -p wa"
    #     "-w /etc/docker/daemon.json -p wa"
    #     "-w /usr/bin/docker -p wa"
    #     "-w /usr/bin/containerd -p wa"
    #     "-w /usr/bin/containerd-shim -p wa"
    #     "-w /usr/bin/containerd-shim-runc-v1 -p wa"
    #     "-w /usr/bin/containerd-shim-runc-v2 -p wa"
    #     "-w /usr/bin/runc -p wa"
    #     "-w /run/containerd -p wa"
    #     "-w /etc/containerd/config.toml -p wa"
    #     )
    # printf "%s\n" "${audit_file[@]}" > /etc/audit/rules.d/docker.rules
    :
}


main() {
    1_install_docker
    2_configure_docker
    3_configure_containerd
}
