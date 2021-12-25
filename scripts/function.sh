#!/usr/bin/env bash

function usage {
    echo -e "Options: "
    echo -e "    -e      environment file"
    echo -e "    -a      delete k8s node"
    echo -e "    -d      delete k8s node"
    echo -e "    -h      help info\n"
    echo -e "Example: "
    echo -e "    ./setup.sh                     使用默认的 k8s.env 变量文件部署 k8s 集群"
    echo -e "    ./setup.sh -a                  使用默认的 k8s.env 变量文件添加 k8s worker 节点"
    echo -e "    ./setup.sh -e k8s-t20.env      使用自定义的 k8s-t20.env 变量文件部署 k8s 集群"
    echo -e "    ./setup.sh -e k8s-t20.env -a   使用自定义的 k8s-t20.env 变量文件添加 k8s worker 节点"
    echo -e "    ./setup.sh -d worker4          删除 k8s worker 节点"
}


function usage2 {

env_des="-e          指定变量文件(非必选), 如果不指定, 默认从当前路径下的 k8s.env 文件中读取变量. (需要参数)\n"
add_des="-a          添加 k8s worker 节点, 要添加的 k8s worker 节点列表是从环境变量中读取的. (不需要参数)\n"
del_des="-d          删除 k8s worker 节点, 需要提供你想删除的 worker 节点的名字, 这个 worker 节点\n
                    名字可以从 kubectl get node 中查找到. ( 需要参数)"
    printf "%s" ${del_des}
}

function print_environment {
    MSG1 "=================================== Environment ==================================="
    MSG2 "master node"
    for HOST in "${!MASTER[@]}"; do
        local IP=${MASTER[$HOST]}
        printf "%-20s%s\n" ${HOST} ${IP}; done

    MSG2 "worker node"
    for HOST in "${!WORKER[@]}"; do
        local IP=${WORKER[$HOST]}
        printf "%-20s%s\n" ${HOST} ${IP}; done

    MSG2 "all k8s node"
    for HOST in "${ALL_NODE[@]}"; do
        echo ${HOST}; done

    MSG2 "extra master node"
    for HOST in "${!EXTRA_MASTER[@]}"; do
        local IP=${EXTRA_MASTER[$HOST]}
        printf "%-20s%s\n" ${HOST} ${IP}; done

    MSG2 "add worker node"
    for HOST in "${!ADD_WORKER[@]}"; do
        local IP=${ADD_WORKER[$HOST]}
        printf "%-20s%s\n" ${HOST} ${IP}; done

    MSG2 "others environment"
    echo "CONTROL_PLANE_ENDPOINT:   ${CONTROL_PLANE_ENDPOINT}"
    echo "SRV_NETWORK_CIDR:         ${SRV_NETWORK_CIDR[*]}"
    echo "SRV_NETWORK_IP:           ${SRV_NETWORK_IP}"
    echo "SRV_NETWORK_DNS_IP:       ${SRV_NETWORK_DNS_IP[*]}"
    echo "POD_NETWORK_CIDR:         ${POD_NETWORK_CIDR[*]}"
    echo "K8S_PATH                  ${K8S_PATH}"
    echo "K8S_VERSION:              ${K8S_VERSION}"
    echo "K8S_PROXY_MODE:           ${K8S_PROXY_MODE}"
    echo "KUBE_CERT_PATH:           ${KUBE_CERT_PATH}"
    echo "ETCD_CERT_PATH:           ${ETCD_CERT_PATH}"
    echo "K8S_DEPLOY_LOG_PATH:      ${K8S_DEPLOY_LOG_PATH}"
    MSG1 "=================================== Environment ==================================="
}

function check_root_and_os() {
    # 检测是否为支持的 Linux 版本，否则退出脚本
    # 检测是否为 root 用户，否则推出脚本
    [[ "$(uname)" != "Linux" ]] && ERR "Not Support OS !" && exit $EXIT_FAILURE
    [[ $(id -u) -ne 0 ]] && ERR "Not ROOT !" && exit $EXIT_FAILURE
    source /etc/os-release
    if [[ "$ID" == "centos" || "$ID" == "rhel"  || "rocky" ]]; then
        INSTALL_MANAGER="yum"
    elif [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        INSTALL_MANAGER="apt-get"
    else
        ERR "Not Support Linux !"
        EXIT $EXIT_FAILURE
    fi
    # 检查网络是否可用，否则退出脚本
    if ! timeout 2 ping -c 2 -i 1 114.114.114.114 &> /dev/null; then ERR "no network" && exit $EXIT_FAILURE; fi
}

# refer: https://gist.github.com/tedivm/e11ebfdc25dc1d7935a3d5640a1f1c90
function _apt_wait() {
    while true; do
        if lsof /var/lib/dpkg/lock &> /dev/null; then
            sleep 1
            continue; fi
        if lsof /var/lib/dpkg/lock-frontend &> /dev/null; then
            sleep 1
            continue; fi
        if lsof /var/lib/apt/lists/lock &> /dev/null; then
            sleep 1
            continue; fi
        if lsof /var/lib/apt/daily_lock &> /dev/null; then
            sleep 1
            continue; fi
        if lsof /var/log/unattended-upgrades/unattended-upgrades.log &> /dev/null; then
            sleep 1
            continue; fi
        #echo "lock released"
        break
    done
}

# refer: https://gist.github.com/tedivm/e11ebfdc25dc1d7935a3d5640a1f1c90
function _apt_wait2() {
    while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
        sleep 1
    done
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
        sleep 1
    done
    while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do
        sleep 1
    done
    if [ -f /var/log/unattended-upgrades/unattended-upgrades.log ]; then
        while sudo fuser /var/log/unattended-upgrades/unattended-upgrades.log >/dev/null 2>&1 ; do
            sleep 1
        done
    fi
}
