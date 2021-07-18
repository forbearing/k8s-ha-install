#!/usr/bin/env bash
#url :https://github.com/chadoe/docker-cleanup-volumes/blob/master/docker-cleanup-volumes.sh

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }

DEL_WORKER=""


while getopts "H:h" opt; do
    case "${opt}" in
        "H" )
            DEL_WORKER=${OPTARG} ;;
        "h")
            MSG1 "Usage: $(basename $0) -H [del_worker]" && exit $EXIT_SUCCESS ;;
        *)
            ERR "Usage: $(basename $0) -H [del_worker]" && exit $EXIT_FAILURE
    esac
done
[ -z ${DEL_WORKER} ] && ERR "Usage: $(basename $0) -H [del_worker]" && exit $EXIT_FAILURE


function 1_drain_and_delete_k8s_node {
    MSG1 "1. drain and delete k8s node"
    kubectl drain ${DEL_WORKER} --force --ignore-daemonsets --delete-emptydir-data --delete-local-data
    kubectl delete node ${DEL_WORKER}
}


function 2_delete_k8s_service_and_file {
    MSG1 "2. delete k8s service and file"
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
        /etc/cni
        /opt/cni/
        /var/lib/etcd/
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
        /usr/local/bin/etcd
        /usr/local/bin/etcdctl
        /usr/local/bin/cfssl
        /usr/local/bin/cfssl-json
        /usr/local/bin/cfssl-certinfo)

    # stop k8s service
    for SERVICE in "${K8S_SERVICE_LIST[@]}"; do
        ssh root@${DEL_WORKER} "systemctl disable --now ${SERVICE}"
    done

    # delete k8s file
    for FILE in "${K8S_FILE_LIST[@]}"; do
        ssh root@${DEL_WORKER} "rm -rf ${FILE}"
    done
}


function 3_remove_docker_and_file {
    MSG1 "3. remove docker-ce containerd"

    DOCKER_CONTAINERD_FILE_LIST=(
        /etc/docker/
        /run/docker/
        /var/run/docker.sock
        /var/run/dockershim.sock
        /var/lib/docker/
        /etc/containerd/
        /var/lib/containerd/
        /run/containerd/)

    # remove docker-ce containerd
    scp root@${DEL_WORKER}:/etc/os-release /tmp/
    source /tmp/os-release
    rm -rf /tmp/os-release
    case $ID in
        "ubuntu")
            ssh root@${DEL_WORKER} "systemctl disable --now containerd docker"
            ssh root@${DEL_WORKER} "apt-mark unhold docker-ce docker-ce-cli"
            ssh root@${DEL_WORKER} "apt-get purge -y docker-ce docker-ce-cli containerd.io; apt-get autoremove -y"
            ssh root@${DEL_WORKER} "groupdel docker"
            for FILE in "${DOCKER_CONTAINERD_FILE_LIST[@]}"; do
                ssh root@${DEL_WORKER} "rm -rf ${FILE}"
            done
            ssh root@${DEL_WORKER} reboot
            ;;
        "centos"|"rhel")
            ssh root@${DEL_WORKER} "systemctl disable --now containerd docker"
            ssh root@${DEL_WORKER} "yum remove -y docker-ce docker-ce-cli containerd.io"
            ssh root@${DEL_WORKER} "groupdel docker"
            for FILE in "${DOCKER_CONTAINERD_FILE_LIST[@]}"; do
                ssh root@${DEL_WORKER} "rm -rf ${FILE}"
            done
            ;;
    esac
}


1_drain_and_delete_k8s_node
2_delete_k8s_service_and_file
3_remove_docker_and_file
