#!/usr/bin/env bash

#url :https://github.com/chadoe/docker-cleanup-volumes/blob/master/docker-cleanup-volumes.sh

# 直接在服务器执行此脚本来清理 k8s 和 docker
# k8s master 和 k8s worker 节点都支持
# 此脚本需要执行两遍，第一遍执行之后需要重启再执行第二遍

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }

function 1_delete_k8s_and_file {
    MSG1 "1. delete k8s and file"
    # k8s service list
    local K8S_SERVICE_LIST=(
        kube-apiserver
        kube-controller-manager
        kube-scheduler
        kube-proxy
        kubelet)
    # k8s file list
    local K8S_FILE_LIST=(
        /root/.kube/
        /etc/kubernetes/
        /etc/systemd/system/kubelet.service.d/
        /etc/etcd/
        /etc/cni/
        /opt/cni/
        /var/lib/kubelet/
        /var/lib/kube-proxy/
        /var/lib/etcd/
        /var/lib/calico/
        /lib/systemd/system/kube-apiserver.service
        /lib/systemd/system/kube-controller-manager.service
        /lib/systemd/system/kube-scheduler.service
        /lib/systemd/system/kube-proxy.service
        /lib/systemd/system/kubelet.service
        /lib/systemd/system/etcd.service
        /usr/local/bin/kube-apiserver
        /usr/local/bin/kube-controller-manager
        /usr/local/bin/kube-scheduler
        /usr/local/bin/kube-proxy
        /usr/local/bin/kubelet
        /usr/local/bin/kubectl
        /usr/local/bin/helm
        /usr/local/bin/etcd
        /usr/local/bin/etcdctl
        /usr/local/bin/cfssl
        /usr/local/bin/cfssl-json
        /usr/local/bin/cfssl-certinfo
        /var/log/kubernetes/
        /var/log/calico/
        /var/log/containers/
        /var/log/pods/)

    # stop k8s service
    MSG2 "disabled k8s service"
    for SERVICE in "${K8S_SERVICE_LIST[@]}"; do
        systemctl disable --now "${SERVICE}"
    done

    # delete k8s files
    MSG2 "delete k8s files"
    for FILE in "${K8S_FILE_LIST[@]}"; do
        rm -rf "${FILE}"
    done
}


function 2_delete_docker_and_file {
    MSG1 "2. delete docker-ce containerd"

    DOCKER_CONTAINERD_FILE_LIST=(
        /var/lib/docker/
        /etc/docker/
        /run/docker/
        /run/docker.sock
        /var/lib/containerd/
        /etc/containerd/
        /run/containerd/
        /var/lib/dockershim/
        /run/dockershim.sock)

    # remove docker-ce containerd
    source /etc/os-release
    case $ID in
    "ubuntu")
        systemctl disable --now containerd docker;
        apt-mark unhold docker-ce docker-ce-cli;
        apt-get purge -y docker-ce docker-ce-cli containerd.io; 
        apt-get autoremove -y;
        groupdel docker
        for FILE in "${DOCKER_CONTAINERD_FILE_LIST[@]}"; do
            rm -rf "${FILE}"
        done
        #ssh root@${DEL_WORKER} reboot
        return
        ;;
    "centos"|"rhel")
        systemctl disable --now containerd docker
        yum remove -y docker-ce docker-ce-cli containerd.io
        groupdel docker
        for FILE in "${DOCKER_CONTAINERD_FILE_LIST[@]}"; do
            rm -rf "${FILE}"
        done
        #ssh root@${DEL_WORKER} reboot
        return
        ;;
    esac
}

function 3_delete_etcd_and_file {
    MSG1 "3. delete etcd"
    rm -rf /var/lib/etcd
    rm -rf /etc/systemd/system/etcd.service
    rm -rf /usr/local/bin/etcd
    rm -rf /usr/local/bin/etcdctl
}


function del_k8s_node {
    1_delete_k8s_and_file
    2_delete_docker_and_file
    3_delete_etcd_and_file
}


del_k8s_node
