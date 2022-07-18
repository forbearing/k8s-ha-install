#!/usr/bin/env bash

#apt-get update
#apt-get install -y vim

ROOT_PASS="toor"

setup_ssh() {
    SSH_CONF_PATH="/etc/ssh/sshd_config"
    sed -i "/^UseDNS/d" $SSH_CONF_PATH
    sed -i "/^GSSAPIAuthentication/d" $SSH_CONF_PATH
    sed -i "/^PermitRootLogin/d" $SSH_CONF_PATH
    sed -i "/^PermitEmptyPasswords/d" $SSH_CONF_PATH

    echo "UseDNS no" >> $SSH_CONF_PATH
    echo "GSSAPIAuthentication no" >> $SSH_CONF_PATH
    echo "PermitRootLogin yes" >> $SSH_CONF_PATH
    echo "PasswordAuthentication yes" >> $SSH_CONF_PATH
}

setup_pass() {
    echo -e "$ROOT_PASS\n$ROOT_PASS" | passwd -q root
}

install_pkg() {
    apt-get update
    apt-get install -y nfs-common
}

deploy_k8s() {
    [[ ! -d $SYNCED_FOLDER/k8s-ha-install  ]] && return
    [[ "$HOSTNAME" != "vg-d11-k8s-master1"  ]] && return

    [[ $(id -u) -eq 0 ]] && sudo -i
    [[ $(id -u) -eq 0 ]] && echo "Not Root!" && return 1

    SYNCED_FOLDER="/vagrant_data"
    KUBE_NODE_LIST=(vg-d11-k8s-master1 vg-d11-k8s-master1 vg-d11-k8s-master3 vg-d11-k8s-worker1 vg-d11-k8s-worker2 vg-d11-k8s-worker3)

    while true; do
        echo "[$HOSTNAME] is waiting others k8s node ready..."
        for node in "${KUBE_NODE_LIST[@]}"; do
            if ! ping -W 1 -c 1 "$node"; then
                continue
            fi
        done
        break
    done
    cd $SYNCED_FOLDER/k8s-ha-install
    ./setup.sh -e env/k8s-vg-d11.env

}

setup_ssh
setup_pass
#deploy_k8s
#install_pkg
