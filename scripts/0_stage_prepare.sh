#!/usr/bin/env bash

function stage_prepare {
    MSG1 "=============  Stage Prepare: Setup SSH Public Key Authentication ============="

    # 将 k8s 节点的主机名与 IP 对应关系写入 /etc/hosts 文件
    for HOST in "${!MASTER[@]}"; do
        local IP=${MASTER[$HOST]}
        sed -r -i "/(.*)${IP}(.*)${HOST}(.*)/d" /etc/hosts
        echo "${IP} ${HOST}" >> /etc/hosts; done
    for HOST in "${!WORKER[@]}"; do
        local IP=${WORKER[$HOST]}
        sed -r -i "/(.*)${IP}(.*)${HOST}(.*)/d" /etc/hosts
        echo "${IP} ${HOST}" >> /etc/hosts; done


    # 安装 sshpass ssh-keyscan multitail
    source /etc/os-release
    case ${ID} in 
    debian | ubuntu)
        _apt_wait && apt-get install -y sshpass multitail ;;
    rocky | centos)
        yum install -y epel-release
        yum install -y sshpass multitail ;;
    *)
        ERR "Not Support Linux ${ID}!"
        exit $EXIT_FAILURE
    esac
    # 生成 ssh 密钥对
    [[ ! -d ${K8S_PATH} ]] && rm -rf "${K8S_PATH}"; mkdir -p "${K8S_PATH}"
    [[ ! -d ${KUBE_CERT_PATH} ]] && rm -rf "${KUBE_CERT_PATH}"; mkdir -p "${KUBE_CERT_PATH}"
    [[ ! -d ${ETCD_CERT_PATH} ]] && rm -rf "${ETCD_CERT_PATH}"; mkdir -p "${ETCD_CERT_PATH}"
    if [[ ! -d "/root/.ssh" ]]; then rm -rf /root/.ssh; mkdir /root/.ssh; chmod 0700 /root/.ssh; fi
    if [[ ! -s "/root/.ssh/id_rsa" ]]; then ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa; fi 
    if [[ ! -s "/root/.ssh/id_ecdsa" ]]; then ssh-keygen -t ecdsa -N '' -f /root/.ssh/id_ecdsa; fi
    if [[ ! -s "/root/.ssh/id_ed25519" ]]; then ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519; fi
    #if [[ ! -s "/root/.ssh/id_xmss" ]]; then ssh-keygen -t xmss -N '' -f /root/.ssh/id_xmss; fi


    # 收集 master 节点和 worker 节点的主机指纹
    # 在当前 master 节点上配置好 ssh 公钥认证
    for NODE in "${ALL_NODE[@]}"; do 
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts; done
    for NODE in "${MASTER[@]}"; do
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts; done
    for NODE in "${WORKER[@]}"; do
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts; done
    for NODE in "${ALL_NODE[@]}"; do
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${NODE}" > /dev/null
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${NODE}" > /dev/null
        sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${NODE}" > /dev/null ; done
        #sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_xmss.pub root@"${NODE}"


    # 设置 hostname
    # 将 /etc/hosts 文件复制到所有节点
    for NODE in "${ALL_NODE[@]}"; do
        ssh ${NODE} "hostnamectl set-hostname ${NODE}"
        scp /etc/hosts ${NODE}:/etc/hosts
    done


    # 所有节点设置默认 shell 为 bash
    for NODE in "${ALL_NODE[@]}"; do
        chsh -s "$(which bash)"
    done


    # 如果操作系统为 RHEL/CentOS/Rocky，则将 yum.repos.d 复制到所有的 k8s 节点的 /tmp 目录下
    source /etc/os-release
    case ${ID} in
    rhel | centos)
        for NODE in "${ALL_NODE[@]}"; do
            scp -q -r centos/yum.repos.d ${NODE}:/tmp/; done ;;
    rocky)
        for NODE in "${ALL_NODE[@]}"; do
            scp -q -r rocky/yum.repos.d ${NODE}:/tmp/; done ;;
    esac
}
