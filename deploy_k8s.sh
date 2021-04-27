#!/usr/bin/env bash

# 描述: 一共分为 5 个阶段
#   Stage Prepare: 准备阶段，用来配置 ssh 免密码登录
#   Stage 1: Linux 系统准备
#   Stage 2: 为部署 Kubernetes 做好环境准备
#   Stage 3: 安装 Docker
#   Stage 4: 部署 Kubernetes Cluster

# 注意事项：
#   - 支持的系统: CentOS 7, Ubuntu 18, Ubuntu 20, Debian9, Debian 10
#   - 运行此命令的必须是 master 节点，任何一台 master 节点都行
#   - Stage Prepare、Stage 1、Stage 2、Stage 3 可以重复运行；Stage 4 不可以重复允许
#     所以可以在 Stage Prepare、Stage 1 2 3 中断重复运行
#   - 只需要提前配置好静态IP地址，只需等待一键安装(不需要提前配置好主机名，不需要提前配置好 SSH 免密码登录)
#   - 必须要有网络

# to-do-list
#   - 扩展节点问题？ certSANs
#   - 获取远程服务器的网卡接口名字
#   - hosts 文件 设置 127.0.0.1
#   - hold docker-ce
#   - 写一下需要修改的地方
#   - scp 的问题

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }

MASTER_HOST=(master1
             master2
             master3)
WORKER_HOST=(worker1
             worker2
             worker3)
#MASTER_IP=(10.230.11.11
           #10.230.11.12
           #10.230.11.13)
#WORKER_IP=(10.230.11.21
           #10.230.11.22
           #10.230.11.23)
#CONTROL_PLANE_ENDPOINT="10.230.11.10:8443"
MASTER_IP=(10.230.12.11
           10.230.12.12
           10.230.12.13)
WORKER_IP=(10.230.12.21
           10.230.12.22
           10.230.12.23)
CONTROL_PLANE_ENDPOINT="10.230.12.10:8443"
MASTER=(${MASTER_HOST[@]})
WORKER=(${WORKER_HOST[@]})
ALL_NODE=(${MASTER[@]} ${WORKER[@]})

SRV_NETWORK_CIDR="172.18.0.0/16"
POD_NETWORK_CIDR="192.168.0.0/16"
SRV_NETWORK_IP="172.18.0.1"
SRV_NETWORK_DNS_IP="172.18.0.10"

ROOT_PASS="toor"                                        # Change your own root passwd here
OS=""
INSTALL_MANAGER=""

K8S_PATH="/etc/kubernetes"
KUBE_CERT_PATH="/etc/kubernetes/pki"
ETCD_CERT_PATH="/etc/etcd/ssl"
PKG_PATH="bin"

INSTALL_DASHBOARD=""
INSTALL_KUBOARD=1
INSTALL_INGRESS=1



function 0_check_root_and_os() {
    # 检测是否为 root 用户，否则推出脚本
    # 检测是否为支持的 Linux 版本，否则退出脚本
    [[ $(id -u) != "0" ]] && ERR "not root !" && exit $EXIT_FAILURE
    [[ "$(uname)" != "Linux" ]] && ERR "not support !" && exit $EXIT_FAILURE
    source /etc/os-release
    OS=${ID}
    if [[ "$ID" == "centos" || "$ID" == "rhel" ]]; then
        INSTALL_MANAGER="yum"
    elif [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        INSTALL_MANAGER="apt-get"
    else
        ERR "not support !"
        EXIT $EXIT_FAILURE
    fi
}



function stage_prepare {
    # 生成 /etc/hosts 文件
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        sed -r -i "/(.*)${MASTER_HOST[$i]}(.*)/d" /etc/hosts
        echo "${MASTER_IP[$i]} ${MASTER_HOST[$i]}" >> /etc/hosts
    done
    for (( i=0; i<${#WORKER[@]}; i++ )); do
        sed -r -i "/(.*)${WORKER_HOST[$i]}(.*)/d" /etc/hosts
        echo "${WORKER_IP[$i]} ${WORKER_HOST[$i]}" >> /etc/hosts
    done


    # 安装 sshpass ssh-keyscan
    # 生成 ssh 密钥对
    command -v sshpass &> /dev/null
    if [ $? != 0 ]; then ${INSTALL_MANAGER} install -y sshpass; fi
    command -v ssh-keyscan &> /dev/null
    if [ $? != 0 ]; then ${INSTALL_MANAGER} install -y ssh-keyscan; fi
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
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts 2> /dev/null
    done
    for NODE in "${ALL_NODE[@]}"; do
        sshpass -p "${ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${NODE}"
        sshpass -p "${ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${NODE}"
        sshpass -p "${ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${NODE}"
        #sshpass -p "${ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_xmss.pub root@"${NODE}"
    done


    # 设置 hostname
    # 将 /etc/hosts 文件复制到所有节点
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        ssh ${MASTER[$i]} "hostnamectl set-hostname ${MASTER_HOST[$i]}"
        scp /etc/hosts ${MASTER[$i]}:/etc/hosts
    done
    for (( i=0; i<${#WORKER[@]}; i++ )); do
        ssh ${WORKER[$i]} "hostnamectl set-hostname ${WORKER_HOST[$i]}"
        scp /etc/hosts ${WORKER[$i]}:/etc/hosts
    done


    # yum 源目录 yum.repos.d 复制到所有的节点上
    for NODE in "${ALL_NODE[@]}"; do
        scp -r yum.repos.d ${NODE}:/tmp/
    done
}



function stage_one {
    # Stage 1: 系统准备
    #   1. 导入所需 yum 源
    #   2. 安装必要软件
    #   3. 升级系统
    #   4. 关闭防火墙、SELinux
    #   5. 设置时区、NTP 时间同步
    #   6. 设置 sshd
    #   7. ulimits 参数调整
    local stage_one_script_path=""
    case "${OS}" in
        "centos")
            stage_one_script_path="centos/1_prepare_for_server.sh" ;;
        "rhel")
            stage_one_script_path="centos/1_prepare_for_server.sh" ;;
        "debian")
            stage_one_script_path="debian/1_prepare_for_server.sh" ;;
        "ubuntu" )
            stage_one_script_path="ubuntu/1_prepare_for_server.sh" ;;
        *)
            ERR "not support" && exit $EXIT_FAILURE ;;
    esac
    for NODE in "${ALL_NODE[@]}"; do
        ssh ${NODE} "bash -s" < "${stage_one_script_path}"
    done
}



function stage_two {
    # Stage 2: k8s 准备
    #   1. 安装 k8s 所需软件
    #   2. 关闭 swap 分区
    #   4. 升级 Kernel
    #   4. 加载 K8S 所需内核模块
    #   5. 调整内核参数
    local stage_two_script_path=""
    case "${OS}" in
        "centos")
            stage_two_script_path="centos/2_prepare_for_k8s.sh" ;;
        "rhel")
            stage_two_script_path="centos/2_prepare_for_k8s.sh" ;;
        "debian")
            stage_two_script_path="debian/2_prepare_for_k8s.sh" ;;
        "ubuntu" )
            stage_two_script_path="ubuntu/2_prepare_for_k8s.sh" ;;
        *)
            ERR "not support" && exit $EXIT_FAILURE ;;
    esac
    for NODE in "${ALL_NODE[@]}"; do
        ssh ${NODE} "bash -s" < "${stage_two_script_path}"
    done
}



function stage_three {
    # Stage 3: 安装 Docker
    #   1. 安装 docker 所需软件
    #   1. 安装 docker-ce
    #   2. 调整 docker-ce 启动参数
    local stage_three_script_path=""
    case "${OS}" in
        "centos")
            stage_three_script_path="centos/3_install_docker.sh" ;;
        "rhel")
            stage_three_script_path="centos/3_install_docker.sh" ;;
        "debian")
            stage_three_script_path="debian/3_install_docker.sh" ;;
        "ubuntu" )
            stage_three_script_path="ubuntu/3_install_docker.sh" ;;
        *)
            ERR "not support" && exit $EXIT_FAILURE ;;
    esac
    for NODE in "${ALL_NODE[@]}"; do
        ssh ${NODE} "bash -s" < "${stage_three_script_path}"
    done
}



# 1、将 kubernetes 二进制软件包、etcd 二进制软件包、cfssl 工具包拷贝到所有的 master 节点上
# 2、将 Kubernetes 二进制软件包拷贝到所有的 worker 节点上
function 1_copy_binary_package_and_create_dir {
    MSG2 "1. Copy Binary Package and Create Dir"

    # 将二进制软件包拷贝到 k8s 节点上
    tar -xvf bin/kube-apiserver.tgz -C bin/
    tar -xvf bin/kube-controller-manager.tgz -C bin/
    tar -xvf bin/kube-scheduler.tgz -C bin/
    tar -xvf bin/kubelet.tgz -C bin/
    tar -xvf bin/kube-proxy.tgz -C bin/
    tar -xvf bin/kubectl.tgz -C bin/
    # 将二进制软件包拷贝到 master 节点
    for NODE in "${MASTER[@]}"; do
        for PKG in etcd etcdctl \
            kube-apiserver kube-controller-manager kube-scheduler \
            kube-proxy kubelet kubectl \
            cfssl cfssl-json cfssl-certinfo \
            helm
        do
            scp ${PKG_PATH}/${PKG} ${NODE}:/usr/local/bin/${PKG}
        done
    done
    # 将二进制软件包拷贝到 worker 节点
    for NODE in "${WORKER[@]}"; do
        for PKG in kube-proxy kubelet kubectl; do
            scp ${PKG_PATH}/${PKG} ${NODE}:/usr/local/bin/${PKG}
        done
    done


    # k8s 所有节点创建所需目录
    for NODE in "${ALL_NODE[@]}"; do
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



# 检测 master 节点是否安装了 keepalived, haproxy
function 2_install_keepalived_and_haproxy {
    MSG2 "2. Installed Keepalived and Haproxy for Master Node"
    for NODE in "${MASTER[@]}"; do
        ssh ${NODE} "ls /usr/sbin/keepalived" &> /dev/null
        if [[ "$?" != 0 ]]; then
            ssh ${NODE} "${INSTALL_MANAGER} install -y keepalived"
        fi
        ssh ${NODE} "ls /usr/sbin/haproxy" &> /dev/null
        if [[ "$?" != 0 ]]; then
            ssh ${NODE} "${INSTALL_MANAGER} install -y haproxy"
        fi
    done
}



# 1、生成 etcd 证书
# 2、将 etcd 证书拷贝到其他节点上
function 3_generate_etcd_certs {
    MSG2 "3. Generate certs for etcd"

    # 如果配置过 etcd 就不要在重新生成 etcd 证书
    # 重复生成 K8S 组件证书没事，但是如果重新生成 etcd 证书会有问题，需要额外设置
    for NODE in "${MASTER[@]}"; do
        ssh ${NODE} "systemctl status etcd" &> /dev/null
        if [ $? == "0" ]; then
            MSG2 "etcd is installed, skip"
            return $EXIT_SUCCESS
        fi
    done


    # 在这里设置，可以为 etcd 多预留几个 hostname 或者 ip 地址，方便 etcd 扩容
    local HOSTNAME=""
    for NODE in "${MASTER_HOST[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"
    done
    for NODE in "${MASTER_IP[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"
    done
    HOSTNAME=${HOSTNAME}",127.0.0.1"
    HOSTNAME=${HOSTNAME/,}


    # 生成 etcd ca 证书
    # 通过 etcd ca 证书来生成 etcd 客户端证书
    cfssl gencert -initca pki/etcd-ca-csr.json | cfssl-json -bare "${ETCD_CERT_PATH}"/etcd-ca
    cfssl gencert \
        -ca="${ETCD_CERT_PATH}"/etcd-ca.pem \
        -ca-key="${ETCD_CERT_PATH}"/etcd-ca-key.pem \
        -config=pki/ca-config.json \
        -hostname="${HOSTNAME}" \
        -profile=kubernetes \
        pki/etcd-csr.json \
        | cfssl-json -bare "${ETCD_CERT_PATH}"/etcd


    # 将 etcd 证书拷贝到所有的 master 节点上
    for NODE in "${MASTER[@]}"; do
        ssh ${NODE} "mkdir -p ${ETCD_CERT_PATH}"
        for FILE in etcd-ca-key.pem etcd-ca.pem etcd-key.pem etcd.pem; do
            scp ${ETCD_CERT_PATH}/${FILE} ${NODE}:${ETCD_CERT_PATH}/${FILE}
        done
    done
    # 将 etcd 证书拷贝到所有的 worker 节点上
    for NODE in "${WORKER[@]}"; do
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
    MSG2 "4. Generate certs for Kubernetes"

    # 获取 control plane endpoint ip 地址
    local OLD_IFS=""
    local CONTROL_PLANE_ENDPOINT_IP=""
    OLD_IFS=${IFS}
    IFS=":"
    temp_arr=(${CONTROL_PLANE_ENDPOINT})
    IFS=${OLD_IFS}
    CONTROL_PLANE_ENDPOINT_IP=${temp_arr[0]}


    # 在这里设置，可以为 master 节点和 worker 节点多预留几个主机名和IP地址，方便集群扩展
    local HOSTNAME=""
    for NODE in "${MASTER_HOST[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"
    done
    for NODE in "${MASTER_IP[@]}"; do
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
    cfssl gencert \
        -ca="${KUBE_CERT_PATH}"/ca.pem \
        -ca-key="${KUBE_CERT_PATH}"/ca-key.pem \
        -config=pki/ca-config.json \
        -hostname="${HOSTNAME}" \
        -profile=kubernetes \
        pki/apiserver-csr.json \
        | cfssl-json -bare "${KUBE_CERT_PATH}"/apiserver


    # 生成 apiserver 的聚合证书
    cfssl gencert \
        -ca="${KUBE_CERT_PATH}"/front-proxy-ca.pem \
        -ca-key="${KUBE_CERT_PATH}"/front-proxy-ca-key.pem \
        -config=pki/ca-config.json \
        -profile=kubernetes \
        pki/front-proxy-client-csr.json \
        | cfssl-json -bare "${KUBE_CERT_PATH}"/front-proxy-client


    # 生成 controller-manager 证书
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
    openssl genrsa -out "${KUBE_CERT_PATH}"/sa.key 2048
    openssl rsa -in "${KUBE_CERT_PATH}"/sa.key -pubout -out "${KUBE_CERT_PATH}"/sa.pub


    # 将生成的 kubernetes 各个组件的证书和配置文件分别拷贝到 master 节点
    for NODE in "${MASTER[@]}"; do
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
    # 将 所需证书和配置文件拷贝到 worker 节点
    for NODE in "${WORKER[@]}"; do
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
    MSG2 "5. Setup etcd"
    # 如果 etcd 在运行就不设置 etcd
    for NODE in "${MASTER[@]}"; do
        ssh ${NODE} "systemctl status etcd" &> /dev/null
        if [ $? == "0" ]; then
            MSG2 "etcd is installed, skip"
            return $EXIT_SUCCESS
        fi
    done


    for NODE in "${MASTER[@]}"; do
        ssh $NODE "mkdir ${KUBE_CERT_PATH}/etcd/"
        ssh $NODE "ln -sf ${ETCD_CERT_PATH}/* ${KUBE_CERT_PATH}/etcd/"
    done


    # 生成配置文件
    #   /lib/systemd/system/etcd.service
    #   /etc/etcd/etcd.config.yaml
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
        scp conf/etcd.service ${MASTER[$i]}:/lib/systemd/system/etcd.service
        ssh ${MASTER[$i]} "systemctl daemon-reload"
        ssh ${MASTER[$i]} "systemctl enable etcd"
        ssh ${MASTER[$i]} "systemctl restart etcd" &
    done
}



function 6_setup_keepalived {
    MSG2 "6. Setup Keepalived"

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
    INTERFACE=$(ip route show | grep default | awk '{print $5}')
    VIRTUAL_IPADDRESS=${CONTROL_PLANE_ENDPOINT_IP}


    # 为 master 节点生成 keepalived 配置文件
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
    

    # 将生成好的配置文件keepalived.cfg 复制到 master 节点
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        #rsync -avzH /tmp/keepalived.conf-$i ${MASTER[$i]}:/etc/keepalived/keepalived.conf
        scp /tmp/keepalived.conf-$i ${MASTER[$i]}:/etc/keepalived/keepalived.conf
        scp conf/check_apiserver.sh ${MASTER[$i]}:/etc/keepalived/check_apiserver.sh
        ssh ${MASTER[$i]} "systemctl enable keepalived"
        ssh ${MASTER[$i]} "systemctl restart keepalived"
    done
}



function 7_setup_haproxy() {
    MSG2 "7. Setup haproxy"

    local OLD_IFS=""
    local CONTROL_PLANE_ENDPOINT_PORT=""
    OLD_IFS=${IFS}
    IFS=":"
    temp_arr=(${CONTROL_PLANE_ENDPOINT})
    IFS=${OLD_IFS}
    CONTROL_PLANE_ENDPOINT_PORT=${temp_arr[1]}


    # 为 master 节点生成 haproxy.cfg 配置文件
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        cp conf/haproxy.cfg /tmp/haproxy.cfg-$i
        sed -i "s/#PORT#/${CONTROL_PLANE_ENDPOINT_PORT}/" /tmp/haproxy.cfg-$i
        for (( j=0; j<${#MASTER[@]}; j++ )); do
            sed -i "s/#MASTER_HOSTNAME_$j#/${MASTER_HOST[$j]}/" /tmp/haproxy.cfg-$i
            sed -i "s/#MASTER_IP_$j#/${MASTER_IP[$j]}/" /tmp/haproxy.cfg-$i
        done
    done


    # 将生成好的配置文件 haproxy.cfg 复制到所有 master 节点
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/haproxy.cfg-$i ${MASTER[$i]}:/etc/haproxy/haproxy.cfg
        #rsync -avzH /tmp/haproxy.cfg-$i ${MASTER[$i]}:/etc/haproxy/haproxy.cfg
        ssh ${MASTER[$i]} "systemctl enable haproxy"
        ssh ${MASTER[$i]} "systemctl restart haproxy"
    done
}



function 8_setup_apiserver() {
    MSG2 "8. Setup kube-apiserver"

    # 为 master 节点生成 kube-apiserver.service 文件
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


    # 将生成好的配置文件 kube-apiserver.service 复制到所有 master 节点
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/kube-apiserver.service-$i ${MASTER[$i]}:/lib/systemd/system/kube-apiserver.service
        ssh ${MASTER[$i]} "systemctl daemon-reload"
        ssh ${MASTER[$i]} "systemctl enable kube-apiserver"
        ssh ${MASTER[$i]} "systemctl restart kube-apiserver"
    done
}



function 9_setup_controller_manager {
    MSG2 "9. Setup kube-controller-manager"

    # 为 master 节点生成 kube-controller-manager.service 文件
    cp conf/kube-controller-manager.service /tmp/kube-controller-manager.service
    sed -i "s%#K8S_PATH#%${K8S_PATH}%" /tmp/kube-controller-manager.service
    sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%" /tmp/kube-controller-manager.service
    sed -i "s%#POD_NETWORK_CIDR#%${POD_NETWORK_CIDR}%" /tmp/kube-controller-manager.service


    # 将生成的配置文件 kube-controller-manager.service 复制到所有 master 节点
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/kube-controller-manager.service ${MASTER[$i]}:/lib/systemd/system/kube-controller-manager.service
        ssh ${MASTER[$i]} "systemctl daemon-reload"
        ssh ${MASTER[$i]} "systemctl enable kube-controller-manager"
        ssh ${MASTER[$i]} "systemctl restart kube-controller-manager"
    done
}



function 10_setup_scheduler {
    MSG2 "10. Setup kube-scheduler"

    # 为 master 节点生成 kube-scheduler.service 文件
    cp conf/kube-scheduler.service /tmp/kube-scheduler.service
    sed -i "s%#K8S_PATH#%${K8S_PATH}%" /tmp/kube-scheduler.service


    # 将生成的配置文件 kube-scheduler.service 复制到所有 master 节点
    for (( i=0; i<${#MASTER[@]}; i++ )); do
        scp /tmp/kube-scheduler.service ${MASTER[$i]}:/lib/systemd/system/kube-scheduler.service
        ssh ${MASTER[$i]} "systemctl daemon-reload"
        ssh ${MASTER[$i]} "systemctl enable kube-scheduler"
        ssh ${MASTER[$i]} "systemctl restart kube-scheduler"
    done
}



function 11_setup_k8s_admin {
    MSG2 "11. Setup K8S admin"

    [ ! -d /root/.kube ] && rm -rf /root/.kube && mkdir /root/.kube
    cp ${K8S_PATH}/admin.kubeconfig /root/.kube/config


    # 应用 bootstrap/bootstrap.secret.yaml
    while true; do
        kubectl get cs &> /dev/null
        if [ $? == "0" ]; then
            kubectl apply -f bootstrap/bootstrap.secret.yaml
            break
        fi
    done
}



function 12_setup_kubelet {
    MSG2 "12. Setup kubelet"

    # 需要三个文件，两个需要生成
    #   /lib/systemd/system/kubelet.service
    #   /etc/systemd/system/kubelet.service.d/10-kubelet.conf
    #   /etc/kubernetes/kubelet-conf.yaml
    # kubelet-conf.yaml 的配置注意事项
    #   如果 k8s node 是 Ubuntu 的系统，需要将 kubelet-conf.yaml 的 resolvConf 
    #   选项改成 resolvConf: /run/systemd/resolve/resolv.conf 
    #   参考: https://github.com/coredns/coredns/issues/2790
    cp conf/10-kubelet.conf /tmp/10-kubelet.conf
    cp conf/kubelet-conf.yaml /tmp/kubelet-conf.yaml
    sed -i "s%#K8S_PATH#%${K8S_PATH}%g" /tmp/10-kubelet.conf
    sed -i "s%#K8S_PATH#%${K8S_PATH}%" /tmp/kubelet-conf.yaml
    sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%" /tmp/kubelet-conf.yaml
    sed -i "s%#SRV_NETWORK_DNS_IP#%${SRV_NETWORK_DNS_IP}%" /tmp/kubelet-conf.yaml
    case "${OS}" in
        "centos" )
            sed -i "s%#resolvConf#%/etc/resolv.conf%g" /tmp/kubelet-conf.yaml;;
          "rhel" )
            sed -i "s%#resolvConf#%/etc/resolv.conf%g" /tmp/kubelet-conf.yaml ;;
          "debian" )
            sed -i "s%#resolvConf#%/etc/resolv.conf%g" /tmp/kubelet-conf.yaml ;;
          "ubuntu" )
            sed -i "s%#resolvConf#%/run/systemd/resolve/resolv.conf%g" /tmp/kubelet-conf.yaml ;;
    esac


    # 将生成的配置文件发送到 k8s 所有节点上
    for NODE in "${ALL_NODE[@]}"; do
        scp conf/kubelet.service ${NODE}:/lib/systemd/system/kubelet.service
        scp /tmp/10-kubelet.conf ${NODE}:/etc/systemd/system/kubelet.service.d/10-kubelet.conf
        scp /tmp/kubelet-conf.yaml ${NODE}:${K8S_PATH}/kubelet-conf.yaml
        ssh ${NODE} "systemctl daemon-reload"
        ssh ${NODE} "systemctl enable kubelet"
        ssh ${NODE} "systemctl restart kubelet"
    done
}



function 13_setup_kube_proxy {
    MSG2 "13. Setup kube-proxy"

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


    # 将生成的配置文件 kube-proxy.kubeconfig kube-proxy.service kube-proxy.conf 复制到所有的节点上
    for NODE in "${ALL_NODE[@]}"; do
        scp ${K8S_PATH}/kube-proxy.kubeconfig ${NODE}:${K8S_PATH}/kube-proxy.kubeconfig
        scp /tmp/kube-proxy.service ${NODE}:/lib/systemd/system/kube-proxy.service
        scp /tmp/kube-proxy.conf ${NODE}:${K8S_PATH}/kube-proxy.conf
        ssh ${NODE} "systemctl daemon-reload"
        ssh ${NODE} "systemctl enable kube-proxy"
        ssh ${NODE} "systemctl restart kube-proxy"
    done
}



function 14_deploy_calico {
    MSG2 "14. Deploy calico"

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
    MSG2 "15. Deploy coredns"

    cp CoreDNS/coredns.yaml /tmp/coredns.yaml
    sed -i "s%192.168.0.10%${SRV_NETWORK_DNS_IP}%g" /tmp/coredns.yaml
    kubectl apply -f /tmp/coredns.yaml
}



function 16_deploy_metrics_server {
    MSG2 "16. Deploy metrics server"

    kubectl apply -f  metrics-server-0.4.x/metrics-server-0.4.1.yaml
}



function deploy_dashboard {
    MSG1 "Deploy kubernetes dashboard"
    kubectl apply -f dashboard/dashboard.yaml
    kubectl apply -f dashboard/dashboard-user.yaml
}
function deploy_kuboard {
    MSG1 "Deploy Kuboard"
    kubectl apply -f kuboard/kuboard.yaml
}
function deploy_ingress {
    MSG1 "Deploy Ingress-nginx"
    kubectl create namespace ingress-nginx
    for (( i=0; i<3; i++ )); do
        kubectl label node ${WORKER[$i]} ingress="true" --overwrite
    done
    helm install ingress-nginx helm/ingress-nginx/ -n ingress-nginx
}



0_check_root_and_os

MSG1 "=============== Prepare: Setup SSH Public Key Authentication =================="
stage_prepare

MSG1 "=================== Stage 1: Prepare for Linux Server ========================="
stage_one

MSG1 "====================== Stage 2: Prepare for Kubernetes ========================"
stage_two

MSG1 "========================= Stage 3: Install Docker ============================="
stage_three

MSG1 "============ Stage 4: Deployment Kubernetes Cluster from Binary ==============="
1_copy_binary_package_and_create_dir
2_install_keepalived_and_haproxy
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
[ ${INSTALL_KUBOARD} ] && deploy_kuboard
[ ${INSTALL_INGRESS} ] && deploy_ingress
