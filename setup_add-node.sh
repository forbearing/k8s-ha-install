#!/usr/bin/env bash

EXIT_SUCCESS=0
EXIT_FAILURE=1

ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }


environment_file=""
while getopts "e:h" opt; do
    case "${opt}" in
        e) environment_file="${OPTARG}" ;;
        h) MSG1 "$(basename $0) -e environment_file" && exit $EXIT_SUCCESS ;;
        *) ERR "$(basename $0) -e environment_file" && exit $EXIT_FAILURE
    esac
done
[ -z $environment_file ] && ERR "$(basename $0) -e environment_file" && exit $EXIT_FAILURE
source "$environment_file"

MSG1 "=================================== Environment ==================================="
echo "MASTER_HOST:              ${MASTER_HOST[*]}"
echo "WORKER_HOST:              ${WORKER_HOST[*]}"
echo "MASTER_IP:                ${MASTER_IP[*]}"
echo "WORKER_IP:                ${WORKER_IP[*]}"
echo "ADD_WORKER_HOST:          ${ADD_WORKER_HOST[*]}"
echo "ADD_WORKER_IP:            ${ADD_WORKER_IP[*]}"
MSG1 "=================================== Environment ==================================="


function 0_prepare {
    # 检测是否为 root 用户，否则退出脚本
    # 检测是否为支持的 Linux 版本，否则退出脚本
    [[ $(id -u) -ne 0 ]] && ERR "not root !" && exit $EXIT_FAILURE
    [[ "$(uname)" != "Linux" ]] && ERR "not support !" && exit $EXIT_FAILURE
    source /etc/os-release
    K8S_NODE_OS=${ID}
    if [[ "$ID" == "centos" || "$ID" == "rhel" ]]; then
        INSTALL_MANAGER="yum"
    elif [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        INSTALL_MANAGER="apt-get"
    else
        ERR "not support !"
        EXIT $EXIT_FAILURE; fi

    # 检查网络是否可用，否则退出脚本
    # 检查新增节点是否可达，否则退出脚本
    if ! timeout 2 ping -c 1 -i 1 8.8.8.8; then ERR "no network" && exit $EXIT_FAILURE; fi
    for NODE in "${ADD_WORKER_IP[@]}"; do
        if ! timeout 2 ping -c 1 -i 1 ${NODE}; then
            ERR "worker node ${NODE} can't access"
            exit $EXIT_FAILURE; fi; done
}


# 当前运行的 master 节点对新的 worker 节点的 ssh 免密登录
function 1_ssh_auth {
    MSG1 "1. ssh auth"

    # 生成新的 hosts 文件
    for (( i=0; i<${#ADD_WORKER_IP[@]}; i++ )); do
        sed -r -i "/(.*)${ADD_WORKER_IP[$i]}(.*)${ADD_WORKER_HOST[$i]}(.*)/d" /etc/hosts
        echo "${ADD_WORKER_IP[$i]} ${ADD_WORKER_HOST[$i]}" >> /etc/hosts; done

    # ssh 免密钥登录
    for NODE in "${ADD_WORKER_HOST[@]}"; do
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts 2> /dev/null; done
    for NODE in "${ADD_WORKER_IP[@]}"; do
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts 2> /dev/null; done
    for NODE in "${ADD_WORKER_HOST[@]}"; do
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${NODE}"
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${NODE}"
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${NODE}"; done
}


# 设置新节点的主机名
function 2_copy_hosts_file {
    MSG1 "2. set hostname"

    # 设置 worker 节点的主机名
    for (( i=0; i<${#ADD_WORKER_IP[@]}; i++ )); do
        ssh ${ADD_WORKER_IP[$i]} "hostnamectl set-hostname ${ADD_WORKER_HOST[$i]}"; done

    # 将新的 hosts 文件复制到所有 master 节点上
    for NODE in "${MASTER[@]}"; do
        scp /etc/hosts "${NODE}":/etc/hosts; done

    # 将新的 hosts 文件复制到所有的 worker 节点上
    for NODE in "${WORKER[@]}"; do
        scp /etc/hosts "${NODE}":/etc/hosts; done
    for NODE in "${ADD_WORKER_IP}"; do
        scp /etc/hosts "${NODE}":/etc/hosts; done
}


#  复制二进制文件 kubelet kube-proxy
function 3_run_script {
    MSG1 "3. run script"

    local _1_prepare_for_server=""
    local _2_prepare_for_k8s=""
    local _3_install_docker=""
    source /etc/os-release
    case "$ID" in
        "centos" | "rhel")
            _1_prepare_for_server="centos/1_prepare_for_server.sh"
            _2_prepare_for_k8s="centos/2_prepare_for_k8s.sh"
            _3_install_docker="centos/3_install_docker.sh" ;;
        "ubuntu")
            _1_prepare_for_server="ubuntu/1_prepare_for_server.sh"
            _2_prepare_for_k8s="ubuntu/2_prepare_for_k8s.sh" 
            _3_install_docker="ubuntu/3_install_docker.sh" ;;
        "debian" )
            _1_prepare_for_server="debian/1_prepare_for_server"
            _2_prepare_for_k8s="debian/2_prepare_for_k8s.sh"
            _3_install_docker="debian/3_install_docker" ;;
    esac

    for NODE in "${ADD_WORKER_IP[@]}"; do
        ssh ${NODE} "bash -s" < "${_1_prepare_for_server}"
        ssh ${NODE} "bash -s" < "${_2_prepare_for_k8s}"
        ssh ${NODE} "bash -s" < "${_3_install_docker}"
    done
}


function 4_copy_binary_file {
    MSG1 "4. copy binary file"
    tar -xvf bin/kubelet.tgz -C bin/
    tar -xvf bin/kube-proxy.tgz -C bin/
    tar -xvf bin/kubectl.tgz -C bin/
    for NODE in "${ADD_WORKER_IP[@]}"; do
        scp bin/kubelet root@${NODE}:/usr/local/bin/
        scp bin/kube-proxy root@${NODE}:/usr/local/bin/
        scp bin/kubectl root@${NODE}:/usr/local/bin/
    done

}


# 从第一个 worker 节点上把相关的 k8s 证书文件、etcd 证书文件、
# kubelet 和 kube-proxy 自启动文件、kublet 和 kube-proxy 的配置文件拷贝到新的 worker 节点上
function 5_copy_certs_and_config_file {
    for NODE in "${ADD_WORKER_IP[@]}"; do
        MSG1 "5. copy certs and config file"

        local ADD_NODE_PATH="/tmp/add_node"
        rm -rf ${ADD_NODE_PATH}
        mkdir ${ADD_NODE_PATH}

        scp -r root@${WORKER_IP[0]}:/etc/kubernetes/ ${ADD_NODE_PATH}
        scp -r root@${WORKER_IP[0]}:/etc/etcd/ ${ADD_NODE_PATH}
        scp -r root@${WORKER_IP[0]}:/etc/systemd/system/kubelet.service.d/ ${ADD_NODE_PATH}
        scp root@${WORKER_IP[0]}:/lib/systemd/system/kubelet.service ${ADD_NODE_PATH}
        scp root@${WORKER_IP[0]}:/lib/systemd/system/kube-proxy.service ${ADD_NODE_PATH}

        scp -r ${ADD_NODE_PATH}/kubernetes root@${NODE}:/etc/
        scp -r ${ADD_NODE_PATH}/etcd root@${NODE}:/etc/
        scp -r ${ADD_NODE_PATH}/kubelet.service.d root@${NODE}:/etc/systemd/system/
        scp ${ADD_NODE_PATH}/kubelet.service root@${NODE}:/lib/systemd/system/
        scp ${ADD_NODE_PATH}/kube-proxy.service root@${NODE}:/lib/systemd/system/

        # mkdir
        ssh root@${NODE} "mkdir -p /etc/cni/bin /var/lib/kubelet /var/log/kubernetes"
    done
}

function 6_enable_kube_service {
    MSG1 "6. Enbled kubelet kube-proxy service"

    for NODE in "${ADD_WORKER_IP[@]}"; do
        ssh root@${NODE} "systemctl daemon-reload"
        ssh root@${NODE} "systemctl enable --now docker"
        ssh root@${NODE} "systemctl enable kubelet"
        ssh root@${NODE} "systemctl restart kubelet"
        ssh root@${NODE} "systemctl enable kube-proxy"
        ssh root@${NODE} "systemctl restart kube-proxy" 
    done
}

0_prepare
1_ssh_auth
2_copy_hosts_file
3_run_script
4_copy_binary_file
5_copy_certs_and_config_file
6_enable_kube_service
