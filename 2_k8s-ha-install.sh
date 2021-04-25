#!/usr/bin/env bash
# 注意事项：
#   1. etcd 证书不能重复生成，其他的 k8s 组件，比如 kube-apiserver, kube-controller-mananger 等等可以重复生成

# to-do-list
#   1、扩展节点问题？ certSANs
#   2、local 变量设置 HOSTNAME
#   3、取消一些变量
#   4、获取远程服务器的网卡接口名字

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
WARN(){ echo -e "\033[33m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\033[32m\033[01m$1\033[0m"; }
MSG2(){ echo -e "\033[34m\033[01m$1\033[0m"; }

MASTER_HOST=(master1
             master2
             master3)
MASTER_IP=(10.230.11.11
           10.230.11.12
           10.230.11.13)
WORKER_HOST=(worker1
             worker2
             worker3)
WORKER_IP=(10.230.11.21
           10.230.11.22
           10.230.11.23)
MASTER=(${MASTER_HOST[@]})
WORKER=(${WORKER_HOST[@]})
ALL_NODE=(${MASTER[@]} ${WORKER[@]})

SRV_NETWORK_CIDR="172.18.0.0/16"
POD_NETWORK_CIDR="192.168.0.0/16"
SRV_NETWORK_IP="172.18.0.1"
SRV_NETWORK_DNS_IP="172.18.0.10"
CONTROL_PLANE_ENDPOINT="10.230.11.10:8443"

MASTER_ROOT_PASS="toor"             # Change your own root passwd here
K8S_PATH="/etc/kubernetes"
KUBE_CERT_PATH="/etc/kubernetes/pki"
ETCD_CERT_PATH="/etc/etcd/ssl"
PKG_PATH="bin"

INSTALL_DASHBOARD="0"



# 检测1：是否为 root、不是 root 退出脚本
# 检测2：是否是支持的 Linux 版本，否则退出脚本
# 检测3：是否已经安装了必须软件
function 0_prepare() {
    [[ $(id -u) != "0" ]] && ERR "not root !" && exit $EXIT_FAILURE
    [[ "$(uname)" != "Linux" ]] && ERR "not support !" && exit $EXIT_FAILURE
    source /etc/os-release
    if [[ "$ID" == "centos" || "$ID" == "rhel" ]]; then
        INSTALL="yum"
    elif [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID" == "Ubuntu" ]]; then
        INSTALL="apt-get"
    else
        ERR "not support !"
        EXIT $EXIT_FAILURE
    fi


    command -v sshpass &> /dev/null
    if [ $? != 0 ]; then $INSTALL install -y sshpass; fi
    command -v ssh-keyscan &> /dev/null
    if [ $? != 0 ]; then $INSTALL install -y ssh-keyscan; fi
    [ ! -d "${K8S_PATH}" ] && rm -rf "${K8S_PATH}"; mkdir -p "${K8S_PATH}"
    [ ! -d "${KUBE_CERT_PATH}" ] && rm -rf "${KUBE_CERT_PATH}"; mkdir -p "${KUBE_CERT_PATH}"
    [ ! -d "${ETCD_CERT_PATH}" ] && rm -rf "${ETCD_CERT_PATH}"; mkdir -p "${ETCD_CERT_PATH}"
}



# 1、创建 ssh 密钥对
# 2、收集 master 节点和 worker 节点的主机指纹
# 3、将本机的私钥拷贝到所有的 master 节点上和 worker 节点上
function 1_copy_ssh_key() {
    MSG1 "1. Setup SSH Public Key Authentication"

    # 1、创建 ssh 密钥对
    MSG1 "Generate SSH Key"
    if [[ ! -d "/root/.ssh" ]]; then rm -rf /root/.ssh; mkdir /root/.ssh; chmod 0700 /root/.ssh; fi
    if [[ ! -s "/root/.ssh/id_rsa" ]]; then ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa; fi
    if [[ ! -s "/root/.ssh/id_ecdsa" ]]; then ssh-keygen -t ecdsa -N '' -f /root/.ssh/id_ecdsa; fi
    if [[ ! -s "/root/.ssh/id_ed25519" ]]; then ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519; fi
    #if [[ ! -s "/root/.ssh/id_xmss" ]]; then ssh-keyscan -t xmss -N '' -f /root/.ssh/id_xmss; fi


    # 2、收集 master 节点和 worker 节点的主机指纹
    MSG1 "Copy ssh public key to remote host"
    for NODE in ${ALL_NODE[@]}; do 
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts 2> /dev/null
    done


    # 3、将本机的私钥拷贝到所有的 master 节点上和 worker 节点上
    for NODE in ${ALL_NODE[@]}; do
        MSG2 "Copy to ${NODE}"
        sshpass -p "${MASTER_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${NODE}"
        sshpass -p "${MASTER_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${NODE}"
        sshpass -p "${MASTER_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${NODE}"
        #sshpass -p "${MASTER_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_xmss.pub root@"${NODE}"
    done
}



# 1、将 kubernetes 二进制软件包、etcd 二进制软件包、cfssl 工具包拷贝到所有的 master 节点上
# 2、将 Kubernetes 二进制软件包拷贝到所有的 worker 节点上
# 3、检测 master 节点是否安装了 keepalived, haproxy
function 2_copy_binary_package {
    MSG1 "2. Copy Binary Package and Create Dir"

    tar -xvf bin/kube-apiserver.tgz -C bin/
    tar -xvf bin/kube-controller-manager.tgz -C bin/
    tar -xvf bin/kube-scheduler.tgz -C bin/
    tar -xvf bin/kubelet.tgz -C bin/
    tar -xvf bin/kube-proxy.tgz -C bin/
    tar -xvf bin/kubectl.tgz -C bin/
    MSG2 " Copy Binary Package to Master"
    for NODE in ${MASTER[@]}; do
        for PKG in etcd etcdctl kube-apiserver kube-controller-manager kube-scheduler kube-proxy kubelet kubectl cfssl cfssl-json cfssl-certinfo; do
            scp ${PKG_PATH}/${PKG} ${NODE}:/usr/local/bin/${PKG}
        done
    done


    MSG2 "Copy Binary Package to Worker"
    for NODE in ${WORKER[@]}; do
        for PKG in kube-proxy kubelet kubectl; do
            scp ${PKG_PATH}/${PKG} ${NODE}:/usr/local/bin/${PKG}
        done
    done


    MSG2 "Installed Keepalived and Haproxy for Master Node"
    for NODE in ${MASTER[@]}; do
        ssh ${NODE} "rpm -qi keepalived" &> /dev/null
        if [ $? != 0 ]; then ssh ${NODE} "yum install -y keepalived"; fi
        ssh ${NODE} "rpm -qi haproxy" &> /dev/null
        if [ $? != 0 ]; then ssh ${NODE} "yum install -y haproxy"; fi
    done


    MSG2 "Create dir for Kubernetes and etcd"
    for NODE in ${ALL_NODE[@]}; do
        for DIR_PATH in \
            ${K8S_PATH} \
            ${KUBE_CERT_PATH} \
            ${ETCD_CERT_PATH} \
            "/etc/kubernetes/manifests" \
            "/etc/systemd/system/kubelet.service.d" \
            "/etc/cni/bin" \
            "/var/lib/kubelet" \
            "/var/log/kubernetes" \
            "/tmp/k8s-install-log"
        do
            ssh ${NODE} "mkdir -p ${DIR_PATH}"
        done
    done
}



# 1、生成 etcd CA 证书、etcd 证书和私钥
# 2、将 etcd CA 证书、etcd 证书和私钥拷贝到 etcd 节点上（三个 master 节点分别对应三个 etcd 节点）
function 3_generate_etcd_certs {
    MSG1 "3. Generate etcd certs"

    # 如果配置过 etcd 就不要在重新生成 etcd 证书
    # 重复生成 K8S 组件证书没事，但是如果重新生成 etcd 证书会有问题，需要额外设置
    for NODE in ${MASTER[@]}; do
        ssh ${NODE} "systemctl status etcd" &> /dev/null
        if [ $? == "0" ]; then
            WARN "etcd is installed, skip"
            return $EXIT_SUCCESS
        fi
    done


    # 在此可以为 etcd 多预留几个 hostname 或者 ip 地址，方便 etcd 扩容
    local HOSTNAME=""
    for NODE in ${MASTER_HOST[@]}; do
        HOSTNAME="${HOSTNAME}","${NODE}"
    done
    for NODE in ${MASTER_IP[@]}; do
        HOSTNAME="${HOSTNAME}","${NODE}"
    done
    HOSTNAME=${HOSTNAME}",127.0.0.1"
    HOSTNAME=${HOSTNAME/,}


    # 生成 etcd ca 证书
    # 通过 etcd ca 证书来生成 etcd 客户端证书
    MSG2 "Generate certs and key for etcd"
    cfssl gencert -initca pki/etcd-ca-csr.json | cfssl-json -bare "${ETCD_CERT_PATH}"/etcd-ca
    cfssl gencert \
        -ca="${ETCD_CERT_PATH}"/etcd-ca.pem \
        -ca-key="${ETCD_CERT_PATH}"/etcd-ca-key.pem \
        -config=pki/ca-config.json \
        -hostname="${HOSTNAME}" \
        -profile=kubernetes \
        pki/etcd-csr.json \
        | cfssl-json -bare "${ETCD_CERT_PATH}"/etcd


    MSG2 "Copy etcd certs and key to Master Node"
    for NODE in ${MASTER[@]}; do
        ssh ${NODE} "mkdir -p ${ETCD_CERT_PATH}"
        for FILE in etcd-ca-key.pem etcd-ca.pem etcd-key.pem etcd.pem; do
            scp ${ETCD_CERT_PATH}/${FILE} ${NODE}:${ETCD_CERT_PATH}/${FILE}
        done
    done
    MSG2 "Copy etcd certs and key to Worker Node"
    for NODE in ${WORKER[@]}; do
        ssh ${NODE} mkdir -p ${ETCD_CERT_PATH}
        for FILE in etcd-ca.pem etcd.pem etcd-key.pem; do
            scp ${ETCD_CERT_PATH}/${FILE} ${NODE}:${ETCD_CERT_PATH}/${FILE}
        done
    done
}



# 1、分别为 apiserver、front-proxy、controller-manager、scheduler、kubernetes-admin 创建证书
# 2、分别为 controller-manager、scheduler、kubernetes-admin 创建 kubeconfig 文件
# 3、将 kubernetes 相关的所有证书和 kubeconfig 文件拷贝到所有的 master 节点上
# 4、创建 ServiceAccount Key
function 4_generate_kubernetes_certs() {
    MSG1 "4. Generate certs for Kubernetes"

    # 获取 control plane endpoint ip 地址
    local OLD_IFS=""
    local CONTROL_PLANE_ENDPOINT_IP=""
    OLD_IFS=${IFS}
    IFS=":"
    temp_arr=(${CONTROL_PLANE_ENDPOINT})
    IFS=${OLD_IFS}
    CONTROL_PLANE_ENDPOINT_IP=${temp_arr[0]}


    # 可以为 master 节点和 worker 节点多预留几个主机名和IP地址，方便集群扩展
    local HOSTNAME=""
    for NODE in ${MASTER_HOST[@]}; do
        HOSTNAME="${HOSTNAME}","${NODE}"
    done
    for NODE in ${MASTER_IP[@]}; do
        HOSTNAME="${HOSTNAME}","${NODE}"
    done
    HOSTNAME=${HOSTNAME}",127.0.0.1"
    HOSTNAME=${HOSTNAME}",${SRV_NETWORK_IP}"
    HOSTNAME=${HOSTNAME}",${CONTROL_PLANE_ENDPOINT_IP}"
    HOSTNAME=${HOSTNAME}",kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local"
    HOSTNAME=${HOSTNAME/,}


    # 生成两个 CA 证书
    # ca.pem, ca-key.pem 专用于 apiserver, controller-manager, scheduler, kubernetes admin 生成客户端证书
    # front-proxy-ca.pem front-proxy-ca-key 用于生成 apiserver 聚合证书
    cfssl gencert -initca pki/ca-csr.json | cfssl-json -bare "${KUBE_CERT_PATH}"/ca
    cfssl gencert -initca pki/front-proxy-ca-csr.json | cfssl-json -bare "${KUBE_CERT_PATH}"/front-proxy-ca


    # 生成 apiserver 证书
    MSG2 "apiserver"
    cfssl gencert \
        -ca="${KUBE_CERT_PATH}"/ca.pem \
        -ca-key="${KUBE_CERT_PATH}"/ca-key.pem \
        -config=pki/ca-config.json \
        -hostname="${HOSTNAME}" \
        -profile=kubernetes \
        pki/apiserver-csr.json \
        | cfssl-json -bare "${KUBE_CERT_PATH}"/apiserver


    # 生成 apiserver 的聚合证书
    MSG2 "front-proxy"
    cfssl gencert \
        -ca="${KUBE_CERT_PATH}"/front-proxy-ca.pem \
        -ca-key="${KUBE_CERT_PATH}"/front-proxy-ca-key.pem \
        -config=pki/ca-config.json \
        -profile=kubernetes \
        pki/front-proxy-client-csr.json \
        | cfssl-json -bare "${KUBE_CERT_PATH}"/front-proxy-client


    # 生成 controller-manager 证书
    MSG2 "controller-manager"
    cfssl gencert \
        -ca="${KUBE_CERT_PATH}"/ca.pem \
        -ca-key="${KUBE_CERT_PATH}"/ca-key.pem \
        -config=pki/ca-config.json \
        -profile=kubernetes \
        pki/manager-csr.json \
        | cfssl-json -bare "${KUBE_CERT_PATH}"/controller-manager
    # kubectl config set-cluster        设置一个集群项
    # kubectl config set-credentials    设置一个用户项
    # kubectl config set-context        设置一个环境项（一个上下文）
    # kubectl config use-context        使用某个环境当做默认环境
    kubectl config set-cluster kubernetes \
        --certificate-authority="${KUBE_CERT_PATH}"/ca.pem \
        --embed-certs=true \
        --server=https://${CONTROL_PLANE_ENDPOINT} \
        --kubeconfig="${K8S_PATH}"/controller-manager.kubeconfig
    kubectl config set-credentials system:kube-controller-manager \
        --client-certificate=${KUBE_CERT_PATH}/controller-manager.pem \
        --client-key=${KUBE_CERT_PATH}/controller-manager-key.pem \
        --embed-certs=true \
        --kubeconfig="${K8S_PATH}"/controller-manager.kubeconfig
    kubectl config set-context system:kube-controller-manager@kubernetes \
        --cluster=kubernetes \
        --user=system:kube-controller-manager \
        --kubeconfig="${K8S_PATH}"/controller-manager.kubeconfig
    kubectl config use-context system:kube-controller-manager@kubernetes \
        --kubeconfig="${K8S_PATH}"/controller-manager.kubeconfig


    # 生成 scheduler 证书
    MSG2 "scheduler"
    cfssl gencert \
        -ca="${KUBE_CERT_PATH}"/ca.pem \
        -ca-key="${KUBE_CERT_PATH}"/ca-key.pem \
        -config=pki/ca-config.json \
        -profile=kubernetes \
        pki/scheduler-csr.json \
        | cfssl-json -bare "${KUBE_CERT_PATH}"/scheduler
    kubectl config set-cluster kubernetes \
        --certificate-authority="${KUBE_CERT_PATH}"/ca.pem \
        --embed-certs=true \
        --server=https://${CONTROL_PLANE_ENDPOINT} \
        --kubeconfig="${K8S_PATH}"/scheduler.kubeconfig
    kubectl config set-credentials system:kube-scheduler \
        --client-certificate="${KUBE_CERT_PATH}"/scheduler.pem \
        --client-key="${KUBE_CERT_PATH}"/scheduler-key.pem \
        --embed-certs=true \
        --kubeconfig="${K8S_PATH}"/scheduler.kubeconfig
    kubectl config set-context system:kube-scheduler@kubernetes \
        --cluster=kubernetes \
        --user=system:kube-scheduler \
        --kubeconfig="${K8S_PATH}"/scheduler.kubeconfig
    kubectl config use-context system:kube-scheduler@kubernetes \
        --kubeconfig="${K8S_PATH}"/scheduler.kubeconfig



    # 生成 kubernetes admin 证书，给 kubernetes 管理员使用
    MSG2 "Kubernetes adminstrator"
    cfssl gencert \
        -ca="${KUBE_CERT_PATH}"/ca.pem \
        -ca-key="${KUBE_CERT_PATH}"/ca-key.pem \
        -config=pki/ca-config.json \
        -profile=kubernetes \
        pki/admin-csr.json \
        | cfssl-json -bare "${KUBE_CERT_PATH}"/admin
    kubectl config set-cluster kubernetes \
        --certificate-authority="${KUBE_CERT_PATH}"/ca.pem \
        --embed-certs=true \
        --server=https://${CONTROL_PLANE_ENDPOINT} \
        --kubeconfig="${K8S_PATH}"/admin.kubeconfig
    kubectl config set-credentials kubernetes-admin \
        --client-certificate="${KUBE_CERT_PATH}"/admin.pem \
        --client-key="${KUBE_CERT_PATH}"/admin-key.pem \
        --embed-certs=true \
        --kubeconfig="${K8S_PATH}"/admin.kubeconfig
    kubectl config set-context kubernetes-admin@kubernetes \
        --cluster=kubernetes \
        --user=kubernetes-admin \
        --kubeconfig="${K8S_PATH}"/admin.kubeconfig
    kubectl config use-context kubernetes-admin@kubernetes \
        --kubeconfig=/etc/kubernetes/admin.kubeconfig


    # 1.TLS Bootstrap 用于自动给 kubelet 颁发证书，生成 /etc/kubelet.kubeconfig 文件
    # 2.node 节点启动，如果没有 /etc/kubelet.kubeconfig 文件，则会用 /etc/bootstrap-kubelet.kubeconfig
    #   申请一个 /etc/kubelet.kubeconfig 文件，然后才启动 kubelet 进程
    #   最后 kubelet 用 /etc/kubelet.kubeconfig 文件和 kube-apiserver 进行通信
    # token-id 和 token-secret 在 bootstrap/bootstrap.secret.yaml 中
    MSG2 "TLS Bootstrapping"
    kubectl config set-cluster kubernetes \
        --certificate-authority=${KUBE_CERT_PATH}/ca.pem \
        --embed-certs=true \
        --server=https://${CONTROL_PLANE_ENDPOINT} \
        --kubeconfig=${K8S_PATH}/bootstrap-kubelet.kubeconfig
    kubectl config set-credentials tls-bootstrap-token-user \
        --token=c8ad9c.2e4d610cf3e7426e \
        --kubeconfig=${K8S_PATH}/bootstrap-kubelet.kubeconfig
    kubectl config set-context tls-bootstrap-token-user@kubernetes \
        --cluster=kubernetes \
        --user=tls-bootstrap-token-user \
        --kubeconfig=${K8S_PATH}/bootstrap-kubelet.kubeconfig
    kubectl config use-context tls-bootstrap-token-user@kubernetes \
        --kubeconfig=${K8S_PATH}/bootstrap-kubelet.kubeconfig


    # 创建一个 serviceAccount，默认会有一个 secret 绑定了这个 serviceAccount，
    # 这个 secret 会产生一个 token，token 的生成就是用这个证书生成的。
    MSG2 "ServiceAccount Key"
    openssl genrsa -out "${KUBE_CERT_PATH}"/sa.key 2048
    openssl rsa -in "${KUBE_CERT_PATH}"/sa.key -pubout -out "${KUBE_CERT_PATH}"/sa.pub


    # 将生成的 kubernetes 各个组件的证书和配置文件分别发送到 master 节点上和 worker 节点上。
    MSG2 "Copy Kubernetes certs to Master Node"
    for NODE in ${MASTER[@]}; do
        ssh ${NODE} "mkdir -p ${KUBE_CERT_PATH}"
        for FILE in $(ls ${KUBE_CERT_PATH} | grep -v etcd); do
            scp ${KUBE_CERT_PATH}/${FILE} ${NODE}:${KUBE_CERT_PATH}/${FILE}
        done
        for FILE in \
            controller-manager.kubeconfig \
            scheduler.kubeconfig \
            admin.kubeconfig \
            bootstrap-kubelet.kubeconfig
        do
            scp ${K8S_PATH}/${FILE} ${NODE}:${K8S_PATH}/${FILE}
        done
    done
    MSG2 "Copy Kubernetes certs to Worker Node"
    for NODE in ${WORKER[@]}; do
        ssh ${NODE} "mkdir -p ${KUBE_CERT_PATH}"
        for FILE in ca.pem ca-key.pem front-proxy-ca.pem; do
            scp ${KUBE_CERT_PATH}/${FILE} ${NODE}:${KUBE_CERT_PATH}/${FILE}
        done
        scp ${K8S_PATH}/bootstrap-kubelet.kubeconfig ${NODE}:${K8S_PATH}/bootstrap-kubelet.kubeconfig
    done
}



# 1、通过 etcd.config.yaml 模版文件，分别为3个 etcd 节点生成 etcd.config.yaml 配置文件
#   （3个 master 节点分别对应3个 etcd 节点）
# 2、将配置文件 etcd.config.yaml 和 etcd.service 配置文件拷贝到所有的 etcd 节点上
#   （etcd.config.yaml 为 etcd 的配置文件
#     etcd.service 为 etcd 的自启动文件）
# 3、所有 etcd 节点设置 etcd 服务自启动
function 5_setup_etcd() {
    MSG1 "5. Setup etcd"

    # 如果 etcd 在运行就不设置 etcd
    for NODE in ${MASTER[@]}; do
        ssh ${NODE} "systemctl status etcd" &> /dev/null
        if [ $? == "0" ]; then
            WARN "etcd is installed, skip"
            return $EXIT_SUCCESS
        fi
    done


    for NODE in ${MASTER[@]}; do
        ssh $NODE "mkdir ${KUBE_CERT_PATH}/etcd/"
        ssh $NODE "ln -sf ${ETCD_CERT_PATH}/* ${KUBE_CERT_PATH}/etcd/"
    done


    # 分别为3个 etcd 节点生成 etcd.config.yaml 文件
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        cp conf/etcd.config.yaml /tmp/etcd.config.yaml-$i
        sed -i "s/#MASTER_HOSTNAME#/${MASTER_HOST[$i]}/" /tmp/etcd.config.yaml-$i
        sed -i "s/#MASTER_IP#/${MASTER_IP[$i]}/" /tmp/etcd.config.yaml-$i
        sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%" /tmp/etcd.config.yaml-$i
        for (( j=0; j<${#MASTER[@]}; j++ )); do
            sed -i "s/#MASTER_HOSTNAME_$j#/${MASTER_HOST[$j]}/" /tmp/etcd.config.yaml-$i
            sed -i "s/#MASTER_IP_$j#/${MASTER_IP[$j]}/" /tmp/etcd.config.yaml-$i
        done
    done


    # 将配置文件 etcd.config.yaml 和 etcd 服务自启动文件 etcd.service 复制到远程服务器上
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/etcd.config.yaml-$i ${MASTER[$i]}:/etc/etcd/etcd.config.yaml
        scp conf/etcd.service ${MASTER[$i]}:/usr/lib/systemd/system/etcd.service
        ssh ${MASTER[$i]} "systemctl daemon-reload"
        ssh ${MASTER[$i]} "systemctl enable etcd"
        ssh ${MASTER[$i]} "systemctl restart etcd" &
    done
}



function 6_setup_keepalived {
    MSG1 "6. Setup Keepalived"

    local OLD_IFS=""
    local CONTROL_PLANE_ENDPOINT_IP=""
    local STATE=""
    local INTERFACE=""
    local PRIORITY=""
    local VIRTUAL_IPADDRESS=""
    OLD_IFS=${IFS}
    IFS=":"
    temp_arr=(${CONTROL_PLANE_ENDPOINT})
    IFS=${OLD_IFS}
    CONTROL_PLANE_ENDPOINT_IP=${temp_arr[0]}
    INTERFACE=$(ip route show | grep default | awk '{print $NF}')
    VIRTUAL_IPADDRESS=${CONTROL_PLANE_ENDPOINT_IP}


    # 分别为三个 master 节点生成 keepalived 配置文件
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        if [[ $i == "0" ]]; then
            STATE="MASTER"
            PRIORITY=100
        else
            STATE="BACKUP"
            PRIORITY=101
        fi
        cp conf/keepalived.conf /tmp/keepalived.conf-$i
        sed -i "s/#STATE#/${STATE}/" /tmp/keepalived.conf-$i
        sed -i "s/#INTERFACE#/${INTERFACE}/" /tmp/keepalived.conf-$i
        sed -i "s/#PRIORITY#/${PRIORITY}/" /tmp/keepalived.conf-$i
        sed -i "s/#MASTER_IP#/${MASTER_IP[$i]}/" /tmp/keepalived.conf-$i
        sed -i "s/#VIRTUAL_IPADDRESS#/${VIRTUAL_IPADDRESS}/" /tmp/keepalived.conf-$i
    done
    

    # 将生成好的配置文件keepalived.cfg 复制到远程服务器上
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/keepalived.conf-$i ${MASTER[$i]}:/etc/keepalived/keepalived.conf
        scp conf/check_apiserver.sh ${MASTER[$i]}:/etc/keepalived/check_apiserver.sh
        ssh ${MASTER[$i]} "systemctl enable keepalived"
        ssh ${MASTER[$i]} "systemctl restart keepalived"
    done
}



function 7_setup_haproxy() {
    MSG1 "7. Setup haproxy"

    local OLD_IFS=""
    local CONTROL_PLANE_ENDPOINT_PORT=""
    OLD_IFS=${IFS}
    IFS=":"
    temp_arr=(${CONTROL_PLANE_ENDPOINT})
    IFS=${OLD_IFS}
    CONTROL_PLANE_ENDPOINT_PORT=${temp_arr[1]}


    # 分别为3个 master 节点生成 haproxy.cfg 配置文件
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        cp conf/haproxy.cfg /tmp/haproxy.cfg-$i
        sed -i "s/#PORT#/${CONTROL_PLANE_ENDPOINT_PORT}/" /tmp/haproxy.cfg-$i
        for (( j=0; j<${#MASTER[@]}; j++ )); do
            sed -i "s/#MASTER_HOSTNAME_$j#/${MASTER_HOST[$j]}/" /tmp/haproxy.cfg-$i
            sed -i "s/#MASTER_IP_$j#/${MASTER_IP[$j]}/" /tmp/haproxy.cfg-$i
        done
    done


    # 将生成好的配置文件 haproxy.cfg 复制到远程服务器上
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/haproxy.cfg-$i ${MASTER[$i]}:/etc/haproxy/haproxy.cfg
        ssh ${MASTER[$i]} "systemctl enable haproxy"
        ssh ${MASTER[$i]} "systemctl restart haproxy"
    done
}



function 8_setup_apiserver() {
    MSG1 "8. Setup kube-apiserver"

    # 分别为三个 master 节点生成 kube-apiserver.service 文件
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        cp conf/kube-apiserver.service /tmp/kube-apiserver.service-$i
        sed -i "s%#SRV_NETWORK_CIDR#%${SRV_NETWORK_CIDR}%" /tmp/kube-apiserver.service-$i
        sed -i "s/#MASTER_IP#/${MASTER_IP[$i]}/" /tmp/kube-apiserver.service-$i
        sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%" /tmp/kube-apiserver.service-$i
        sed -i "s%#ETCD_CERT_PATH#%${ETCD_CERT_PATH}%" /tmp/kube-apiserver.service-$i
        for (( j=0; j<${#MASTER[@]}; j++ )); do
            sed -i "s/#MASTER_IP_$j#/${MASTER_IP[$j]}/" /tmp/kube-apiserver.service-$i
        done
    done


    # 将生成好的配置文件 kube-apiserver.service 复制到远程服务器
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/kube-apiserver.service-$i ${MASTER[$i]}:/lib/systemd/system/kube-apiserver.service
        ssh ${MASTER[$i]} "systemctl daemon-reload"
        ssh ${MASTER[$i]} "systemctl enable kube-apiserver"
        ssh ${MASTER[$i]} "systemctl restart kube-apiserver"
    done
}



function 9_setup_controller_manager {
    MSG1 "9. Setup kube-controller-manager"

    # 为 master 节点生成 kube-controller-manager.service 文件
    cp conf/kube-controller-manager.service /tmp/kube-controller-manager.service
    sed -i "s%#K8S_PATH#%${K8S_PATH}%" /tmp/kube-controller-manager.service
    sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%" /tmp/kube-controller-manager.service
    sed -i "s%#POD_NETWORK_CIDR#%${POD_NETWORK_CIDR}%" /tmp/kube-controller-manager.service


    # 将生成的 kube-controller-manager.service 配置文件复制到远程服务器
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/kube-controller-manager.service ${MASTER[$i]}:/lib/systemd/system/kube-controller-manager.service
        ssh ${MASTER[$i]} "systemctl daemon-reload"
        ssh ${MASTER[$i]} "systemctl enable kube-controller-manager"
        ssh ${MASTER[$i]} "systemctl restart kube-controller-manager"
    done
}



function 10_setup_scheduler {
    MSG1 "10. Setup kube-scheduler"

    # 为 master 节点生成 kube-scheduler.service 文件
    cp conf/kube-scheduler.service /tmp/kube-scheduler.service
    sed -i "s%#K8S_PATH#%${K8S_PATH}%" /tmp/kube-scheduler.service


    # 将生成的 kube-scheduler.service 配置文件到远程服务器
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/kube-scheduler.service ${MASTER[$i]}:/lib/systemd/system/kube-scheduler.service
        ssh ${MASTER[$i]} "systemctl daemon-reload"
        ssh ${MASTER[$i]} "systemctl enable kube-scheduler"
        ssh ${MASTER[$i]} "systemctl restart kube-scheduler"
    done
}



function 11_setup_k8s_admin {
    MSG1 "11. Setup K8S admin"

    [ ! -d /root/.kube ] && rm -rf /root/.kube && mkdir /root/.kube
    cp ${K8S_PATH}/admin.kubeconfig /root/.kube/config
    while true; do
        kubectl get cs &> /dev/null
        if [ $? == "0" ]; then
            kubectl apply -f bootstrap/bootstrap.secret.yaml
            break
        fi
    done
}



function 12_setup_kubelet {
    MSG1 "12. Setup kubelet"

    # 需要三个文件，两个需要生成
    #   /lib/systemd/system/kubelet.service
    #   /etc/systemd/system/kubelet.service.d/10-kubelet.conf
    #   /etc/kubernetes/kubelet-conf.yaml
    cp conf/10-kubelet.conf /tmp/10-kubelet.conf
    cp conf/kubelet-conf.yaml /tmp/kubelet-conf.yaml
    sed -i "s%#K8S_PATH#%${K8S_PATH}%g" /tmp/10-kubelet.conf
    sed -i "s%#K8S_PATH#%${K8S_PATH}%" /tmp/kubelet-conf.yaml
    sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%" /tmp/kubelet-conf.yaml
    sed -i "s%#SRV_NETWORK_DNS_IP#%${SRV_NETWORK_DNS_IP}%" /tmp/kubelet-conf.yaml


    # 将配置文件发送到 k8s 所有节点上
    for NODE in ${ALL_NODE[@]}; do
        scp conf/kubelet.service ${NODE}:/lib/systemd/system/kubelet.service
        scp /tmp/10-kubelet.conf ${NODE}:/etc/systemd/system/kubelet.service.d/10-kubelet.conf
        scp /tmp/kubelet-conf.yaml ${NODE}:${K8S_PATH}/kubelet-conf.yaml
        ssh ${NODE} "systemctl daemon-reload"
        ssh ${NODE} "systemctl enable kubelet"
        ssh ${NODE} "systemctl restart kubelet"
    done
}



function 13_setup_kube_proxy {
    MSG1 "13. Setup kube-proxy"

    # 为 kube-proxy 创建 serviceaccount: kube-proxy
    # 为 kube-proxy 创建 clusterrolebinding system:kube-proxy
    kubectl -n kube-system create serviceaccount kube-proxy
    kubectl create clusterrolebinding system:kube-proxy \
        --clusterrole system:node-proxier \
        --serviceaccount kube-system:kube-proxy


    # 1.生成 kube-proxy.kubeconfig 配置文件
    # 2.kube-proxy.kubeconfig 配置文件不能放在 4_generate_kubernetes_certs 函数中执行，
    #   因为 生成 kube-proxy.kubeconfig 集群部署好后，才能生成，4_generate_kubernetes_certs  阶段
    #   还没有部署好 K8S 集群，11_setup_k8s_admin 阶段 
    local SECRET=$(kubectl -n kube-system get sa/kube-proxy --output=jsonpath='{.secrets[0].name}')
    local JWT_TOKEN=$(kubectl -n kube-system get secret/$SECRET --output=jsonpath='{.data.token}' | base64 -d)
    kubectl config set-cluster kubernetes \
        --certificate-authority="${KUBE_CERT_PATH}"/ca.pem \
        --embed-certs=true \
        --server=https://${CONTROL_PLANE_ENDPOINT} \
        --kubeconfig=${K8S_PATH}/kube-proxy.kubeconfig
    kubectl config set-credentials kubernetes \
        --token=${JWT_TOKEN} \
        --kubeconfig=${K8S_PATH}/kube-proxy.kubeconfig
    kubectl config set-context kubernetes \
        --cluster=kubernetes \
        --user=kubernetes \
        --kubeconfig=${K8S_PATH}/kube-proxy.kubeconfig
    kubectl config use-context kubernetes \
        --kubeconfig=${K8S_PATH}/kube-proxy.kubeconfig


    # 生成两个配置文件
    #   /lib/systemd/system/kube-proxy.service
    #   /etc/kubernetes/kube-proxy.conf
    cp conf/kube-proxy.service /tmp/kube-proxy.service
    cp conf/kube-proxy.conf /tmp/kube-proxy.conf
    sed -i "s%#K8S_PATH#%${K8S_PATH}%" /tmp/kube-proxy.service
    sed -i "s%#K8S_PATH#%${K8S_PATH}%" /tmp/kube-proxy.conf
    sed -i "s%#POD_NETWORK_CIDR#%${POD_NETWORK_CIDR}%" /tmp/kube-proxy.conf


    # 将生成的 kube-proxy.kubeconfig kube-proxy.service kube-proxy.conf 复制到所有的节点上
    for NODE in ${ALL_NODE[@]}; do
        scp ${K8S_PATH}/kube-proxy.kubeconfig ${NODE}:${K8S_PATH}/kube-proxy.kubeconfig
        scp /tmp/kube-proxy.service ${NODE}:/lib/systemd/system/kube-proxy.service
        scp /tmp/kube-proxy.conf ${NODE}:${K8S_PATH}/kube-proxy.conf
        ssh ${NODE} "systemctl daemon-reload"
        ssh ${NODE} "systemctl enable kube-proxy"
        ssh ${NODE} "systemctl restart kube-proxy"
    done
}



function 14_deploy_calico {
    MSG1 "14. Deploy calico"

    local ETCD_ENDPOINTS=""
    local ETCD_CA=""
    local ETCD_CERT=""
    local ETCD_KEY=""
    for (( i=0; i<${#MASTER_IP[@]}; i++ )); do
        ETCD_ENDPOINTS="${ETCD_ENDPOINTS},https://${MASTER_IP[$i]}:2379"
    done
    ETCD_ENDPOINTS=${ETCD_ENDPOINTS/,}
    ETCD_CA=$(cat ${KUBE_CERT_PATH}/etcd/etcd-ca.pem | base64 | tr -d '\n')
    ETCD_CERT=$(cat ${KUBE_CERT_PATH}/etcd/etcd.pem | base64 | tr -d '\n')
    ETCD_KEY=$(cat ${KUBE_CERT_PATH}/etcd/etcd-key.pem | base64 | tr -d '\n')


    #cp calico_3.15/calico-etcd.yaml /tmp/calico-etcd.yaml
    cp calico_3.18/calico-etcd.yaml /tmp/calico-etcd.yaml
    #curl https://docs.projectcalico.org/manifests/calico-etcd.yaml -o /tmp/calico-etcd.yaml
    sed -r -i "s%(.*)http://<ETCD_IP>:<ETCD_PORT>(.*)%\1${ETCD_ENDPOINTS}\2%" /tmp/calico-etcd.yaml
    sed -i "s%# etcd-key: null%etcd-key: ${ETCD_KEY}%g" /tmp/calico-etcd.yaml
    sed -i "s%# etcd-cert: null%etcd-cert: ${ETCD_CERT}%g" /tmp/calico-etcd.yaml
    sed -i "s%# etcd-ca: null%etcd-ca: ${ETCD_CA}%g" /tmp/calico-etcd.yaml
    sed -r -i "s%etcd_ca: \"\"(.*)%etcd_ca: \"/calico-secrets/etcd-ca\"%g" /tmp/calico-etcd.yaml
    sed -r -i "s%etcd_cert: \"\"(.*)%etcd_cert: \"/calico-secrets/etcd-cert\"%g" /tmp/calico-etcd.yaml
    sed -r -i "s%etcd_key: \"\"(.*)%etcd_key: \"/calico-secrets/etcd-key\"%g" /tmp/calico-etcd.yaml
    sed -i "s%# - name: CALICO_IPV4POOL_CIDR%- name: CALICO_IPV4POOL_CIDR%g" /tmp/calico-etcd.yaml
    sed -i "s%#   value: \"192.168.0.0/16\"%  value: \"${POD_NETWORK_CIDR}\"%g" /tmp/calico-etcd.yaml
    sed -i "s%defaultMode: 0400%defaultMode: 0440%g" /tmp/calico-etcd.yaml
    kubectl apply -f /tmp/calico-etcd.yaml
}



function 15_deploy_coredns {
    MSG1 "15. Deploy coredns"

    cp CoreDNS/coredns.yaml /tmp/coredns.yaml
    sed -i "s%192.168.0.10%${SRV_NETWORK_DNS_IP}%g" /tmp/coredns.yaml
    kubectl apply -f /tmp/coredns.yaml
}



function 16_deploy_metrics_server {
    MSG1 "16. Deploy metrics server"

    kubectl apply -f  metrics-server-0.4.x/comp.yaml
}



function deploy_dashboard {
    MSG1 "Deploy kubernetes dashboard"

    kubectl apply -f dashboard/dashboard.yaml
    kubectl apply -f dashboard/dashboard-user.yaml
}


0_prepare
1_copy_ssh_key
2_copy_binary_package
3_generate_etcd_certs
4_generate_kubernetes_certs
5_setup_etcd
6_setup_keepalived
7_setup_haproxy
8_setup_apiserver
9_setup_controller_manager
10_setup_scheduler
11_setup_k8s_admin
12_setup_kubelet
13_setup_kube_proxy
14_deploy_calico
15_deploy_coredns
16_deploy_metrics_server

[ ${INSTALL_DASHBOARD} ] && deploy_dashboard
