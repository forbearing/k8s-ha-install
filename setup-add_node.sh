#!/usr/bin/env bash
EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }

OLD_WORKER_IP=(
    10.240.4.21
    10.240.4.22
    10.240.4.23
)
K8S_ROOT_PASS="doe)aMmj,sk|"
NEW_WORKER_HOSTNAME=(
    u18-worker4
)
NEW_WORKER_IP=(
    10.240.4.24
)

#while getopts "i:s:h" opt; do
    #case "${opt}" in
        #"i")
            #NEW_WORKER_IP=${OPTARG} ;;
        #"s")
            #NEW_WORKER_HOSTNAME=${OPTARG} ;;
        #"h")
            #MSG1 "$(basename $0) [-e environment_file] [-i new_worker_ip] [-s new_worker_hostname]" && exit $EXIT_SUCCESS ;;
    #esac
#done

# 当前运行的 master 节点对 新的 worker 节点的 ssh 免密登录
function 1_ {
    MSG1 "1. ssh auth"
    for NODE in "${NEW_WORKER_IP[@]}"; do
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts 2> /dev/null
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${NODE}"
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${NODE}"
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${NODE}"
    done
}


# 设置新节点的主机名
function 2_ {
    MSG1 "2. set hostname"
    for (( i=0; i<${#NEW_WORKER_IP[@]}; i++ )); do
        ssh ${NEW_WORKER_IP[$i]} hostnamectl set-hostname ${NEW_WORKER_HOSTNAME[$i]}
    done
}


#  复制二进制文件 kubelet kube-proxy
function 3_ {
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

    for NODE in "${NEW_WORKER_IP[@]}"; do
        ssh ${NODE} "bash -s" < "${_1_prepare_for_server}"
        ssh ${NODE} "bash -s" < "${_2_prepare_for_k8s}"
        ssh ${NODE} "bash -s" < "${_3_install_docker}"
    done
}


function 4_ {
    MSG1 "4. copy binary file"
    tar -xvf bin/kubelet.tgz -C bin/
    tar -xvf bin/kube-proxy.tgz -C bin/
    tar -xvf bin/kubectl.tgz -C bin/
    for NODE in "${NEW_WORKER_IP[@]}"; do
        scp bin/kubelet root@${NODE}:/usr/local/bin/
        scp bin/kube-proxy root@${NODE}:/usr/local/bin/
        scp bin/kubectl root@${NODE}:/usr/local/bin/
    done

}


# 从第一个 worker 节点上把相关的 k8s 证书文件、etcd 证书文件、
# kubelet 和 kube-proxy 自启动文件、kublet 和 kube-proxy 的配置文件拷贝到新的 worker 节点上
function 5_ {
    for NODE in "${NEW_WORKER_IP[@]}"; do
        MSG1 "5. copy certs and config file"

        local ADD_NODE_PATH="/tmp/add_node"
        rm -rf ${ADD_NODE_PATH}
        mkdir ${ADD_NODE_PATH}

        scp -r root@${OLD_WORKER_IP[0]}:/etc/kubernetes/ ${ADD_NODE_PATH}
        scp -r root@${OLD_WORKER_IP[0]}:/etc/etcd/ ${ADD_NODE_PATH}
        scp -r root@${OLD_WORKER_IP[0]}:/etc/systemd/system/kubelet.service.d/ ${ADD_NODE_PATH}
        scp root@${OLD_WORKER_IP[0]}:/lib/systemd/system/kubelet.service ${ADD_NODE_PATH}
        scp root@${OLD_WORKER_IP[0]}:/lib/systemd/system/kube-proxy.service ${ADD_NODE_PATH}

        scp -r ${ADD_NODE_PATH}/kubernetes root@${NODE}:/etc/
        scp -r ${ADD_NODE_PATH}/etcd root@${NODE}:/etc/
        scp -r ${ADD_NODE_PATH}/kubelet.service.d root@${NODE}:/etc/systemd/system/
        scp ${ADD_NODE_PATH}/kubelet.service root@${NODE}:/lib/systemd/system/
        scp ${ADD_NODE_PATH}/kube-proxy.service root@${NODE}:/lib/systemd/system/

        ssh root@${NODE} "systemctl daemon-reload"

        #mkdir
        ssh root@${NODE} "mkdir -p /etc/cni/bin /var/lib/kubelet /var/log/kubernetes"

    done
}

function 6_ {
    MSG1 "6. Enbled kubelet kube-proxy service"

    for NODE in "${NEW_WORKER_IP[@]}"; do
        ssh ${NODE} "systemctl enable --now docker"
        ssh ${NODE} "systemctl enable kubelet"
        ssh ${NODE} "systemctl restart kubelet"
        ssh ${NODE} "systemctl enable kube-proxy"
        ssh ${NODE} "systemctl restart kube-proxy"
    done
}

1_
2_
3_
4_
5_
6_
