#!/usr/bin/env bash

source /etc/os-release
function stage_prepare {
    # 生成 /etc/hosts 文件
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        sed -r -i "/(.*)${MASTER_HOST[$i]}(.*)/d" /etc/hosts
        echo "${MASTER_IP[$i]} ${MASTER_HOST[$i]}" >> /etc/hosts; done
    for (( i=0; i<${#WORKER[@]}; i++ )); do
        sed -r -i "/(.*)${WORKER_HOST[$i]}(.*)/d" /etc/hosts
        echo "${WORKER_IP[$i]} ${WORKER_HOST[$i]}" >> /etc/hosts; done


    # 安装 sshpass ssh-keyscan
    # 生成 ssh 密钥对
    if ! command -v sshpass; then ${INSTALL_MANAGER} install -y sshpass; fi
    [ ! -d "${K8S_PATH}" ] && rm -rf "${K8S_PATH}"; mkdir -p "${K8S_PATH}"
    [ ! -d "${KUBE_CERT_PATH}" ] && rm -rf "${KUBE_CERT_PATH}"; mkdir -p "${KUBE_CERT_PATH}"
    [ ! -d "${ETCD_CERT_PATH}" ] && rm -rf "${ETCD_CERT_PATH}"; mkdir -p "${ETCD_CERT_PATH}"
    if [[ ! -d "/root/.ssh" ]]; then rm -rf /root/.ssh; mkdir /root/.ssh; chmod 0700 /root/.ssh; fi
    if [[ ! -s "/root/.ssh/id_rsa" ]]; then ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa; fi 
    if [[ ! -s "/root/.ssh/id_ecdsa" ]]; then ssh-keygen -t ecdsa -N '' -f /root/.ssh/id_ecdsa; fi
    if [[ ! -s "/root/.ssh/id_ed25519" ]]; then ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519; fi
    #if [[ ! -s "/root/.ssh/id_xmss" ]]; then ssh-keyscan -t xmss -N '' -f /root/.ssh/id_xmss; fi


    # 收集 master 节点和 worker 节点的主机指纹
    # 将本机的 SSH 公钥拷贝到所有的 K8S 节点上
    for NODE in "${ALL_NODE[@]}"; do 
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts 2> /dev/null; done
    for NODE in "${ALL_NODE[@]}"; do
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${NODE}"
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${NODE}"
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${NODE}"; done
        #sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_xmss.pub root@"${NODE}"


    # 设置 hostname
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        ssh ${MASTER[$i]} "hostnamectl set-hostname ${MASTER_HOST[$i]}"
        scp /etc/hosts ${MASTER[$i]}:/etc/hosts; done
    # 将 /etc/hosts 文件复制到所有节点
    for (( i=0; i<${#WORKER[@]}; i++ )); do
        ssh ${WORKER[$i]} "hostnamectl set-hostname ${WORKER_HOST[$i]}"
        scp /etc/hosts ${WORKER[$i]}:/etc/hosts; done


    # yum 源目录 yum.repos.d 复制到所有的节点上
    source /etc/os-release
    if [[ "${ID}" == "centos" || "${ID}" == "rhel" ]]; then
        for NODE in "${ALL_NODE[@]}"; do
            scp -r centos/yum.repos.d ${NODE}:/tmp/; done; fi
}
