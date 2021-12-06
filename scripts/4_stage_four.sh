#!/usr/bin/env bash

function 1_copy_binary_package_and_create_dir {
    # 1. 解压 k8s 二进制文件
    # 2. 将 kubernetes 二进制文件、etcd 二进制文件、cfssl 工具包拷贝到所有的 master 节点
    # 3. 将 Kubernetes 二进制文件拷贝到所有的 worker 节点
    # 4. k8s 所有节点创建所需目录
    MSG2 "1. Copy Binary Package and Create Dir"

    # 1. 解压二进制文件
    mkdir -p ${K8S_DEPLOY_LOG_PATH}/bin
    tar -xvf bin/helm/helm.tar.xz                               -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/etcd/etcd.tar.xz                               -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/etcd/etcdctl.tar.xz                            -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/cfssl/cfssl.tar.xz                             -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/cfssl/cfssl-json.tar.xz                        -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/cfssl/cfssl-certinfo.tar.xz                    -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/${K8S_VERSION}/kube-apiserver.tar.xz           -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/${K8S_VERSION}/kube-controller-manager.tar.xz  -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/${K8S_VERSION}/kube-scheduler.tar.xz           -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/${K8S_VERSION}/kube-proxy.tar.xz               -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/${K8S_VERSION}/kubelet.tar.xz                  -C ${K8S_DEPLOY_LOG_PATH}/bin/
    tar -xvf bin/${K8S_VERSION}/kubectl.tar.xz                  -C ${K8S_DEPLOY_LOG_PATH}/bin/

    # 2. 将 k8s 二进制文件拷贝到所有 master 节点
    for NODE in "${MASTER[@]}"; do
        for PKG in \
            ${K8S_DEPLOY_LOG_PATH}/bin/helm \
            ${K8S_DEPLOY_LOG_PATH}/bin/etcd \
            ${K8S_DEPLOY_LOG_PATH}/bin/etcdctl \
            ${K8S_DEPLOY_LOG_PATH}/bin/cfssl \
            ${K8S_DEPLOY_LOG_PATH}/bin/cfssl-json \
            ${K8S_DEPLOY_LOG_PATH}/bin/cfssl-certinfo \
            ${K8S_DEPLOY_LOG_PATH}/bin/kube-apiserver \
            ${K8S_DEPLOY_LOG_PATH}/bin/kube-controller-manager \
            ${K8S_DEPLOY_LOG_PATH}/bin/kube-scheduler \
            ${K8S_DEPLOY_LOG_PATH}/bin/kube-proxy \
            ${K8S_DEPLOY_LOG_PATH}/bin/kubelet \
            ${K8S_DEPLOY_LOG_PATH}/bin/kubectl; do
            scp ${PKG} ${NODE}:/usr/local/bin/
        done
    done

    # 3. 将 k8s 二进制文件拷贝到所有 worker 节点
    for NODE in "${WORKER[@]}"; do
        for PKG in \
            ${K8S_DEPLOY_LOG_PATH}/bin/kube-proxy \
            ${K8S_DEPLOY_LOG_PATH}/bin/kubelet \
            ${K8S_DEPLOY_LOG_PATH}/bin/kubectl; do
            scp ${PKG} ${NODE}:/usr/local/bin/
        done
    done

    # 4. k8s 所有节点创建所需目录
    for NODE in "${ALL_NODE[@]}"; do
        for DIR_PATH in \
            ${K8S_PATH} \
            ${KUBE_CERT_PATH} \
            ${ETCD_CERT_PATH} \
            "/etc/kubernetes/manifests" \
            "/etc/systemd/system/kubelet.service.d" \
            "/var/lib/kubelet" \
            "/var/lib/kube-proxy" \
            "/var/log/kubernetes"; do
            ssh ${NODE} "mkdir -p ${DIR_PATH}"
        done
    done
}



function 2_install_keepalived_and_haproxy {
    #  master 节点安装 keepalived, haproxy
    MSG2 "2. Installed Keepalived and Haproxy for Master Node"

    for NODE in "${MASTER[@]}"; do
        ssh ${NODE} "ls /usr/sbin/keepalived" &> /dev/null
        if [[ $? -ne 0 ]]; then ssh ${NODE} "${INSTALL_MANAGER} install -y keepalived"; fi
        ssh ${NODE} "ls /usr/sbin/haproxy" &> /dev/null
        if [[ $? -ne 0 ]]; then ssh ${NODE} "${INSTALL_MANAGER} install -y haproxy"; fi
    done
}



function 3_setup_haproxy {
    MSG2 "3. Setup haproxy"

    local OLD_IFS
    local CONTROL_PLANE_ENDPOINT_PORT
    OLD_IFS=${IFS}
    IFS=":"
    temp_arr=(${CONTROL_PLANE_ENDPOINT})
    IFS=${OLD_IFS}
    CONTROL_PLANE_ENDPOINT_PORT=${temp_arr[1]}

    # 为 master 节点生成 haproxy.cfg 配置文件
    mkdir -p ${K8S_DEPLOY_LOG_PATH}/conf/haproxy
    local HAPROXY_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/conf/haproxy"
    local count=0
    cp conf/haproxy/haproxy.cfg                         ${HAPROXY_CONF_PATH}/haproxy.cfg
    sed -i "s/#PORT#/${CONTROL_PLANE_ENDPOINT_PORT}/"   ${HAPROXY_CONF_PATH}/haproxy.cfg
    for HOST in "${!MASTER[@]}"; do
        local IP=${MASTER[$HOST]}
        sed -i "s/#MASTER_HOSTNAME_$count#/${HOST}/"    ${HAPROXY_CONF_PATH}/haproxy.cfg
        sed -i "s/#MASTER_IP_$count#/${IP}/"            ${HAPROXY_CONF_PATH}/haproxy.cfg
        (( count++ ))
    done

    # 将生成好的配置文件 haproxy.cfg 复制到所有 master 节点
    #for (( i=0; i<${#MASTER[@]}; i++ )); do
    for NODE in "${MASTER[@]}"; do
        scp ${HAPROXY_CONF_PATH}/haproxy.cfg ${NODE}:/etc/haproxy/haproxy.cfg
        ssh ${NODE} "systemctl enable haproxy"
        ssh ${NODE} "systemctl restart haproxy"
    done
}



function 4_setup_keepalived {
    MSG2 "4. Setup Keepalived"

    local OLD_IFS
    local CONTROL_PLANE_ENDPOINT_IP
    local STATE
    local INTERFACE
    local ROUTE_ID
    local PRIORITY
    local VIRTUAL_IP
    OLD_IFS=${IFS}
    IFS=":"
    temp_arr=(${CONTROL_PLANE_ENDPOINT})
    IFS=${OLD_IFS}
    CONTROL_PLANE_ENDPOINT_IP=${temp_arr[0]}
    INTERFACE=$(ip route show | grep default | awk '{print $5}' | sed -n '1,1p')
    ROUTE_ID=$(echo $RANDOM % 100 + 1 | bc)         # random virtual_route_id for keepalived
    VIRTUAL_IP=${CONTROL_PLANE_ENDPOINT_IP}

    # 为 master 节点生成 keepalived 配置文件
    mkdir -p ${K8S_DEPLOY_LOG_PATH}/conf/keepalived
    local KEEPALIVED_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/conf/keepalived"
    local count=0
    for HOST in "${!MASTER[@]}"; do
        local IP=${MASTER[$HOST]}
        if [[ $count -eq 0 ]]; then
            STATE="MASTER"
            PRIORITY=101
        else
            STATE="BACKUP"
            PRIORITY=100; fi
        cp conf/keepalived/keepalived.conf              ${KEEPALIVED_CONF_PATH}/keepalived.conf_${HOST}
        sed -i "s/#STATE#/${STATE}/"                    ${KEEPALIVED_CONF_PATH}/keepalived.conf_${HOST}
        sed -i "s/#INTERFACE#/${INTERFACE}/"            ${KEEPALIVED_CONF_PATH}/keepalived.conf_${HOST}
        sed -i "s/#ROUTE_ID#/${ROUTE_ID}/"              ${KEEPALIVED_CONF_PATH}/keepalived.conf_${HOST}
        sed -i "s/#PRIORITY#/${PRIORITY}/"              ${KEEPALIVED_CONF_PATH}/keepalived.conf_${HOST}
        sed -i "s/#MASTER_IP#/${IP}/"                   ${KEEPALIVED_CONF_PATH}/keepalived.conf_${HOST}
        sed -i "s/#VIRTUAL_IPADDRESS#/${VIRTUAL_IP}/"   ${KEEPALIVED_CONF_PATH}/keepalived.conf_${HOST}
        (( count++ ))
    done

    # 将生成好的配置文件keepalived.cfg 复制到 master 节点
    for HOST in "${!MASTER[@]}"; do
        scp ${KEEPALIVED_CONF_PATH}/keepalived.conf_${HOST} ${HOST}:/etc/keepalived/keepalived.conf
        scp conf/keepalived/check_apiserver.sh ${HOST}:/etc/keepalived/check_apiserver.sh
        ssh ${HOST} "chmod 755 /etc/keepalived/check_apiserver.sh"
        ssh ${HOST} "systemctl enable keepalived"
        ssh ${HOST} "systemctl restart haproxy"
        ssh ${HOST} "systemctl restart keepalived"; done
}



function 5_generate_etcd_certs {
    MSG2 "5. Generate certs for etcd"

    # 如果 kubernetees 在部署成功，就不重新生成 etcd 证书
    if kubectl get node; then return; fi
    [[ ! -d ${K8S_PATH} ]] && rm -rf "${K8S_PATH}"; mkdir -p "${K8S_PATH}"
    [[ ! -d ${ETCD_CERT_PATH} ]] && rm -rf "${ETCD_CERT_PATH}"; mkdir -p "${ETCD_CERT_PATH}"


    # 在 EXTRA_MASTER_HOST 和 EXTRA_MASTER_IP 中多预留一些 hostname 和 IP 地址
    local HOSTNAME
    for NODE in "${!MASTER[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"; done
    for NODE in "${!EXTRA_MASTER[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"; done
    for NODE in "${MASTER[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"; done
    for NODE in "${EXTRA_MASTER[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"; done
    HOSTNAME=${HOSTNAME},"127.0.0.1"
    HOSTNAME=${HOSTNAME/,}
    MSG2 "etcd hostname string: ${HOSTNAME}"


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
}



function 6_generate_kubernetes_certs() {
    # 1、分别为 apiserver、front-proxy、controller-manager、scheduler、kubernetes-admin 创建证书
    # 2、分别为 controller-manager、scheduler、kubernetes-admin 创建 kubeconfig 文件
    # 3、将 kubernetes 相关的所有证书和 kubeconfig 文件拷贝到所有的 master 节点上
    # 4、创建 ServiceAccount Key
    MSG2 "6. Generate certs for Kubernetes"

    # 如果 kubernetees 在正常运行，就不重新生成 kubernetes 证书
    if kubectl get node; then return; fi
    [[ ! -d ${K8S_PATH} ]] && rm -rf "${K8S_PATH}"; mkdir -p "${K8S_PATH}"
    [[ ! -d ${KUBE_CERT_PATH} ]] && rm -rf "${KUBE_CERT_PATH}"; mkdir -p "${KUBE_CERT_PATH}"

    # 获取 control plane endpoint ip 地址
    local OLD_IFS
    local CONTROL_PLANE_ENDPOINT_IP
    OLD_IFS=${IFS}
    IFS=":"
    temp_arr=(${CONTROL_PLANE_ENDPOINT})
    IFS=${OLD_IFS}
    CONTROL_PLANE_ENDPOINT_IP=${temp_arr[0]}

    # 在这里设置，可以为 master 节点和 worker 节点多预留几个主机名和IP地址，方便集群扩展
    local HOSTNAME
    for NODE in "${!MASTER[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"; done
    for NODE in "${!EXTRA_MASTER[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"; done
    for NODE in "${MASTER[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"; done
    for NODE in "${EXTRA_MASTER[@]}"; do
        HOSTNAME="${HOSTNAME}","${NODE}"; done
    HOSTNAME="${HOSTNAME}","${CONTROL_PLANE_ENDPOINT_IP}"
    HOSTNAME="${HOSTNAME}","${SRV_NETWORK_IP}"
    HOSTNAME="${HOSTNAME}","127.0.0.1"
    HOSTNAME="${HOSTNAME}","kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local"
    HOSTNAME=${HOSTNAME/,}
    MSG2 "kubernetes hostname string: ${HOSTNAME}"


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
    # 生成 controller-manager 的 kubeconfig 文件
    #   kube-controller-manager 使用 kubeconfig 文件访问 apiserver，该文件提供了 apiserver
    #   地址、嵌入式 CA 证书和 kube-controller-manager 证书等信息
    #
    # kubectl config 参数解释
    #   kubectl config set-cluster        设置一个集群项（设置集群参数）
    #       --certificate-authority       验证 kube-apiserver 证书的根证书
    #       --embed-cert=true             将 CA 证书和客户端证书其纳入到生成的 kubeconfig 文件中
    #           否则，写入的是证书文件路径，后续拷贝 kubeconfig 到其它机器时，还需要单独拷贝整数，不方便
    #       --server                      指定 kube-apiserver 的地址.
    #   kubectl config set-credentials    设置一个用户项（设置客户端认证参数）
    #       --client-certificate          生成的客户端证书
    #       --client-key                  生成的客户端证书的私钥
    #   kubectl config set-context        设置一个环境项（设置上下文参数）
    #   kubectl config use-context        使用某个环境当做默认环境（设置默认上下文）
    cfssl gencert \
        -ca="${KUBE_CERT_PATH}"/ca.pem \
        -ca-key="${KUBE_CERT_PATH}"/ca-key.pem \
        -config=pki/ca-config.json \
        -profile=kubernetes \
        pki/manager-csr.json \
        | cfssl-json -bare "${KUBE_CERT_PATH}"/controller-manager
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
    # 生成 scheduler 的 kubeconfig 文件
    #   kube-scheduler 使用 kubeconfig 文件访问 apiserver，该文件提供了 apiserver 地址、
    #   嵌入式的 CA 证书和 kube-scheduler 证书
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
    # 为 kubectl 客户端工具(k8s 管理员) 生成 kubeconfig 文件
    #   kubectl 使用 kubeconfig 文件访问 apiserver，该文件包含了 kube-apiserver 的地址
    #   和认证信息（CA 证书和客户端证书）
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


    # 生成 bootstrap-kubelet.kubeconfig 文件
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
}



function 7_copy_etcd_and_k8s_certs {
    MSG2 "7. Copy etcd and k8s certs and config file"


    # 将 etcd 证书拷贝到所有的 master 节点上
    for NODE in "${MASTER[@]}"; do
        ssh ${NODE} "mkdir -p ${ETCD_CERT_PATH}"
        for FILE in etcd-ca-key.pem etcd-ca.pem etcd-key.pem etcd.pem; do
            scp ${ETCD_CERT_PATH}/${FILE} ${NODE}:${ETCD_CERT_PATH}/${FILE}
        done
    done


    # 将生成的 kubernetes 各个组件的证书和 kubeconfig 文件分别拷贝到 master 节点
    for NODE in "${MASTER[@]}"; do
        ssh ${NODE} "mkdir -p ${KUBE_CERT_PATH}"
        for FILE in \
            ca.pem ca-key.pem \
            front-proxy-ca.pem front-proxy-ca-key.pem \
            admin.pem admin-key.pem \
            sa.key sa.pub \
            apiserver.pem apiserver-key.pem \
            controller-manager.pem controller-manager-key.pem \
            scheduler.pem scheduler-key.pem \
            front-proxy-client.pem front-proxy-client-key.pem ; do
            scp ${KUBE_CERT_PATH}/${FILE} ${NODE}:${KUBE_CERT_PATH}/${FILE}
        done
        for FILE in \
            controller-manager.kubeconfig \
            scheduler.kubeconfig \
            bootstrap-kubelet.kubeconfig \
            admin.kubeconfig; do
            scp ${K8S_PATH}/${FILE} ${NODE}:${K8S_PATH}/${FILE} 
        done
    done

    # 将 所需证书和配置文件拷贝到 worker 节点
    for NODE in "${WORKER[@]}"; do
        ssh ${NODE} "mkdir -p ${KUBE_CERT_PATH}"
        for FILE in ca.pem front-proxy-ca.pem; do
            scp ${KUBE_CERT_PATH}/${FILE} ${NODE}:${KUBE_CERT_PATH}/${FILE}
        done
        scp ${K8S_PATH}/bootstrap-kubelet.kubeconfig ${NODE}:${K8S_PATH}/bootstrap-kubelet.kubeconfig
    done
}



function 8_setup_etcd() {
    # 1、通过 etcd.config.yaml 模版文件，分别为3个 etcd 节点生成 etcd.config.yaml 配置文件
    #   （3个 master 节点分别对应3个 etcd 节点）
    # 2、将配置文件 etcd.config.yaml 和 etcd.service 配置文件拷贝到所有的 etcd 节点上
    #   （etcd.config.yaml 为 etcd 的配置文件
    #     etcd.service 为 etcd 的自启动文件）
    # 3、所有 etcd 节点设置 etcd 服务自启动
    MSG2 "8. Setup etcd"

    # 在所有 master 节点上 创建所需目录
    # 链接 /etc/etcd/ssl 目录到 /etc/kubernetes/pki/etcd/
    for NODE in "${MASTER[@]}"; do
        ssh ${NODE} "mkdir ${KUBE_CERT_PATH}/etcd/"
        ssh ${NODE} "ln -sf ${ETCD_CERT_PATH}/* ${KUBE_CERT_PATH}/etcd/"; done


    # 将生成的 etcd 组件相关配置文件保存到指定位置
    mkdir -p ${K8S_DEPLOY_LOG_PATH}/conf/etcd
    local ETCD_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/conf/etcd"

    local INITIAL_CLUSTER
    for HOST in "${!MASTER[@]}"; do
        local IP=${MASTER[$HOST]}
        INITIAL_CLUSTER="${INITIAL_CLUSTER}","${HOST}=https://${IP}:2380"; done
    INITIAL_CLUSTER=${INITIAL_CLUSTER/,}
    MSG2 "INITIAL_CLUSTER: ${INITIAL_CLUSTER}"


    # 生成配置文件
    #   /lib/systemd/system/etcd.service
    #   /etc/etcd/etcd.config.yaml
    # 将配置文件 etcd.config.yaml 和 etcd 服务自启动文件 etcd.service 复制到远程服务器上
    for HOST in "${!MASTER[@]}"; do
        local IP=${MASTER[$HOST]}
        cp conf/etcd/etcd.service                       ${ETCD_CONF_PATH}/etcd.service
        cp conf/etcd/etcd.config.yaml                   ${ETCD_CONF_PATH}/etcd.config.yaml_${HOST}
        sed -i "s/#MASTER_HOSTNAME#/${HOST}/"           ${ETCD_CONF_PATH}/etcd.config.yaml_${HOST}
        sed -i "s/#MASTER_IP#/${IP}/"                   ${ETCD_CONF_PATH}/etcd.config.yaml_${HOST}
        sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%"  ${ETCD_CONF_PATH}/etcd.config.yaml_${HOST}
        sed -i -r "s%initial-cluster:(.*)%initial-cluster: '${INITIAL_CLUSTER}'%"  ${ETCD_CONF_PATH}/etcd.config.yaml_${HOST}
        scp ${ETCD_CONF_PATH}/etcd.service              ${HOST}:/lib/systemd/system/etcd.service
        scp ${ETCD_CONF_PATH}/etcd.config.yaml_${HOST} ${HOST}:/etc/etcd/etcd.config.yaml
        ssh ${HOST} "systemctl daemon-reload
                     systemctl enable etcd
                     systemctl restart etcd" &
    done
}



function 9_setup_apiserver() {
    MSG2 "9. Setup kube-apiserver"

    # 将生成的 kube-apiserver 组件相关配置文件保存到指定位置
    mkdir -p ${K8S_DEPLOY_LOG_PATH}/conf/kube-apiserver
    local APISERVER_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/conf/kube-apiserver"

    # 为 master 节点生成 kube-apiserver.service 文件
    local ETCD_SERVERS
    for HOST in "${!MASTER[@]}"; do
        local IP=${MASTER[$HOST]}
        ETCD_SERVERS="${ETCD_SERVERS}","https://${IP}:2379"
    done
    ETCD_SERVERS=${ETCD_SERVERS/,}
    ETCD_SERVERS=${ETCD_SERVERS}" \\"
    echo "ETCD_SERVERS: ${ETCD_SERVERS[*]}"
    for HOST in "${!MASTER[@]}"; do
        local IP=${MASTER[$HOST]}
        cp conf/${K8S_VERSION}/kube-apiserver.service       ${APISERVER_CONF_PATH}/kube-apiserver.service_${HOST}
        sed -i "s/#MASTER_IP#/${IP}/"                       ${APISERVER_CONF_PATH}/kube-apiserver.service_${HOST}
        sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%"      ${APISERVER_CONF_PATH}/kube-apiserver.service_${HOST}
        sed -i "s%#ETCD_CERT_PATH#%${ETCD_CERT_PATH}%"      ${APISERVER_CONF_PATH}/kube-apiserver.service_${HOST}
        sed -i "s%#SRV_NETWORK_CIDR#%${SRV_NETWORK_CIDR}%"  ${APISERVER_CONF_PATH}/kube-apiserver.service_${HOST}
        sed -i "s%#POD_NETWORK_CIDR#%${POD_NETWORK_CIDR}%"  ${APISERVER_CONF_PATH}/kube-apiserver.service_${HOST}
        sed -r -i "s%(.*)--etcd-servers(.*)%\1--etcd-servers=${ETCD_SERVERS}\\%" ${APISERVER_CONF_PATH}/kube-apiserver.service_${HOST}
        scp ${APISERVER_CONF_PATH}/kube-apiserver.service_${HOST} ${HOST}:/lib/systemd/system/kube-apiserver.service
        # 将生成好的配置文件 kube-apiserver.service 复制到所有 master 节点
        ssh ${HOST} "systemctl daemon-reload
                     systemctl enable kube-apiserver
                     systemctl restart kube-apiserver"
    done
}



function 10_setup_controller_manager {
    MSG2 "10. Setup kube-controller-manager"

    # 将生成的 kube-controller-manager 组件相关配置文件保存到指定位置
    mkdir -p ${K8S_DEPLOY_LOG_PATH}/conf/kube-controller-manager
    local CONTROLLER_MANAGER_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/conf/kube-controller-manager"

    # 为 master 节点生成 kube-controller-manager.service 文件
    cp conf/${K8S_VERSION}/kube-controller-manager.service  ${CONTROLLER_MANAGER_CONF_PATH}/kube-controller-manager.service
    sed -i "s%#K8S_PATH#%${K8S_PATH}%"                      ${CONTROLLER_MANAGER_CONF_PATH}/kube-controller-manager.service
    sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%"          ${CONTROLLER_MANAGER_CONF_PATH}/kube-controller-manager.service
    sed -i "s%#SRV_NETWORK_CIDR#%${SRV_NETWORK_CIDR}%"      ${CONTROLLER_MANAGER_CONF_PATH}/kube-controller-manager.service
    sed -i "s%#POD_NETWORK_CIDR#%${POD_NETWORK_CIDR}%"      ${CONTROLLER_MANAGER_CONF_PATH}/kube-controller-manager.service


    # 将生成的配置文件 kube-controller-manager.service 复制到所有 master 节点
    #for (( i=0; i<${#MASTER[@]}; i++ )); do
    for NODE in "${MASTER[@]}"; do
        scp ${CONTROLLER_MANAGER_CONF_PATH}/kube-controller-manager.service \
            ${NODE}:/lib/systemd/system/kube-controller-manager.service
        ssh ${NODE} "systemctl daemon-reload"
        ssh ${NODE} "systemctl enable kube-controller-manager"
        ssh ${NODE} "systemctl restart kube-controller-manager"
    done
}



function 11_setup_scheduler {
    MSG2 "11. Setup kube-scheduler"

    # 将生成的 kube-scheduler 组件相关配置文件保存到指定位置
    mkdir -p ${K8S_DEPLOY_LOG_PATH}/conf/kube-scheduler
    local SCHEDULER_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/conf/kube-scheduler"

    # 为 master 节点生成 kube-scheduler.service 文件
    cp conf/${K8S_VERSION}/kube-scheduler.service   ${SCHEDULER_CONF_PATH}/kube-scheduler.service
    sed -i "s%#K8S_PATH#%${K8S_PATH}%"              ${SCHEDULER_CONF_PATH}/kube-scheduler.service


    # 将生成的配置文件 kube-scheduler.service 复制到所有 master 节点
    for NODE in "${MASTER[@]}"; do
        scp ${SCHEDULER_CONF_PATH}/kube-scheduler.service \
            ${NODE}:/lib/systemd/system/kube-scheduler.service
        ssh ${NODE} "systemctl daemon-reload"
        ssh ${NODE} "systemctl enable kube-scheduler"
        ssh ${NODE} "systemctl restart kube-scheduler"
    done
}



function 12_setup_k8s_admin {
    MSG2 "12. Setup K8S admin"

    [ ! -d /root/.kube ] && rm -rf /root/.kube; mkdir /root/.kube
    cp ${K8S_PATH}/admin.kubeconfig /root/.kube/config

    # 应用 bootstrap/bootstrap.secret.yaml
    while true; do
        if kubectl get cs; then
            kubectl apply -f conf/bootstrap/bootstrap.secret.yaml
            break; fi
        sleep 1; done
}



function 13_setup_kubelet {
    MSG2 "13. Setup kubelet"

    # 将生成的 kubelet 组件相关配置文件保存到指定位置
    mkdir -p ${K8S_DEPLOY_LOG_PATH}/conf/kubelet
    local KUBELET_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/conf/kubelet"

    # 生成 kubelet 组件相关的配置文件
    #   /lib/systemd/system/kubelet.service
    #   /etc/systemd/system/kubelet.service.d/10-kubelet.conf
    #   /etc/kubernetes/kubelet-conf.yaml
    # kubelet-conf.yaml 的配置注意事项
    #   如果 k8s node 是 Ubuntu 的系统，需要将 kubelet-conf.yaml 的 resolvConf 
    #   选项改成 resolvConf: /run/systemd/resolve/resolv.conf 
    #   参考: https://github.com/coredns/coredns/issues/2790
    cp conf/${K8S_VERSION}/kubelet.service                  ${KUBELET_CONF_PATH}/kubelet.service
    cp conf/${K8S_VERSION}/10-kubelet.conf                  ${KUBELET_CONF_PATH}/10-kubelet.conf
    cp conf/${K8S_VERSION}/kubelet-conf.yaml                ${KUBELET_CONF_PATH}/kubelet-conf.yaml
    sed -i "s%#K8S_PATH#%${K8S_PATH}%g"                     ${KUBELET_CONF_PATH}/10-kubelet.conf
    sed -i "s%#K8S_PATH#%${K8S_PATH}%"                      ${KUBELET_CONF_PATH}/kubelet-conf.yaml
    sed -i "s%#KUBE_CERT_PATH#%${KUBE_CERT_PATH}%"          ${KUBELET_CONF_PATH}/kubelet-conf.yaml
    sed -i "s%#SRV_NETWORK_DNS_IP#%${SRV_NETWORK_DNS_IP}%"  ${KUBELET_CONF_PATH}/kubelet-conf.yaml
    local resolvConf
    source /etc/os-release
    case ${ID} in
        "centos"|"rhel" )
            resolvConf="/etc/resolv.conf"
            sed -i "s%#resolvConf#%${resolvConf}%g" ${KUBELET_CONF_PATH}/kubelet-conf.yaml ;;
          "debian" )
            resolvConf="/etc/resolv.conf"
            sed -i "s%#resolvConf#%${resolvConf}%g" ${KUBELET_CONF_PATH}/kubelet-conf.yaml ;;
          "ubuntu" )
            resolvConf="/run/systemd/resolve/resolv.conf"
            sed -i "s%#resolvConf#%${resolvConf}%g" ${KUBELET_CONF_PATH}/kubelet-conf.yaml ;;
    esac

    # 将生成的配置文件发送到 k8s 所有节点上
    for NODE in "${ALL_NODE[@]}"; do
        scp ${KUBELET_CONF_PATH}/kubelet.service    ${NODE}:/lib/systemd/system/kubelet.service
        scp ${KUBELET_CONF_PATH}/10-kubelet.conf    ${NODE}:/etc/systemd/system/kubelet.service.d/10-kubelet.conf
        scp ${KUBELET_CONF_PATH}/kubelet-conf.yaml  ${NODE}:${K8S_PATH}/kubelet-conf.yaml
        ssh ${NODE} "systemctl daemon-reload"
        ssh ${NODE} "systemctl enable kubelet"
        ssh ${NODE} "systemctl restart kubelet"
    done
}



function 14_setup_kube_proxy {
    MSG2 "14. Setup kube-proxy"

    # 为 kube-proxy 创建 serviceaccount: kube-proxy
    # 为 kube-proxy 创建 clusterrolebinding: system:kube-proxy, 绑定到 system:node-proxier
    kubectl -n kube-system create serviceaccount kube-proxy
    kubectl create clusterrolebinding system:kube-proxy \
        --clusterrole system:node-proxier \
        --serviceaccount kube-system:kube-proxy

    # 生成 kube-proxy.kubeconfig 配置文件
    local SECRET
    local JWT_TOKEN
    SECRET=$(kubectl -n kube-system get sa/kube-proxy --output=jsonpath='{.secrets[0].name}')
    JWT_TOKEN=$(kubectl -n kube-system get secret/$SECRET --output=jsonpath='{.data.token}' | base64 -d)
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

    # 将生成的 kube-proxy 组件相关配置文件保存到指定位置
    mkdir -p ${K8S_DEPLOY_LOG_PATH}/conf/kube-proxy
    local KUBE_PROXY_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/conf/kube-proxy"
    # 生成 kube-proxy 组件相关配置文件
    #   /lib/systemd/system/kube-proxy.service
    #   /etc/kubernetes/kube-proxy.yaml
    cp conf/${K8S_VERSION}/kube-proxy.service           ${KUBE_PROXY_CONF_PATH}/kube-proxy.service
    cp conf/${K8S_VERSION}/kube-proxy.yaml              ${KUBE_PROXY_CONF_PATH}/kube-proxy.yaml
    sed -i "s%#K8S_PATH#%${K8S_PATH}%"                  ${KUBE_PROXY_CONF_PATH}/kube-proxy.service
    sed -i "s%#K8S_PATH#%${K8S_PATH}%"                  ${KUBE_PROXY_CONF_PATH}/kube-proxy.yaml
    sed -i "s%#POD_NETWORK_CIDR#%${POD_NETWORK_CIDR}%"  ${KUBE_PROXY_CONF_PATH}/kube-proxy.yaml

    # 设置 kube-proxy mode, 默认设置为 ipvs
    case ${K8S_PROXY_MODE} in
        "ipvs")
            sed -i "s%#K8S_PROXY_MODE#%${K8S_PROXY_MODE}%"  ${KUBE_PROXY_CONF_PATH}/kube-proxy.yaml ;;
        "iptables")
            K8S_PROXY_MODE=""
            sed -i "s%#K8S_PROXY_MODE#%${K8S_PROXY_MODE}%"  ${KUBE_PROXY_CONF_PATH}/kube-proxy.yaml ;;
        *)
            K8S_PROXY_MODE="ipvs"
            sed -i "s%#K8S_PROXY_MODE#%${K8S_PROXY_MODE}%"  ${KUBE_PROXY_CONF_PATH}/kube-proxy.yaml ;;
    esac

    # 将生成的配置文件 kube-proxy.kubeconfig kube-proxy.yaml kube-proxy.service复制到所有的节点上
    for NODE in "${ALL_NODE[@]}"; do
        scp ${KUBE_PROXY_CONF_PATH}/kube-proxy.service  ${NODE}:/lib/systemd/system/kube-proxy.service
        scp ${KUBE_PROXY_CONF_PATH}/kube-proxy.yaml     ${NODE}:${K8S_PATH}/kube-proxy.yaml
        scp ${K8S_PATH}/kube-proxy.kubeconfig           ${NODE}:${K8S_PATH}/kube-proxy.kubeconfig
        ssh ${NODE} "systemctl daemon-reload"
        ssh ${NODE} "systemctl enable kube-proxy"
        ssh ${NODE} "systemctl restart kube-proxy"
    done
}



function 15_deploy_calico {
    MSG2 "15. Deploy calico"

    local ETCD_ENDPOINTS
    local ETCD_CA
    local ETCD_CERT
    local ETCD_KEY
    #for (( i=0; i<${#MASTER_IP[@]}; i++ )); do
    for HOST in "${!MASTER[@]}"; do
        local IP="${MASTER[$HOST]}"
        ETCD_ENDPOINTS="${ETCD_ENDPOINTS},https://${IP}:2379"; done
    ETCD_ENDPOINTS=${ETCD_ENDPOINTS/,}
    ETCD_CA=$(cat ${KUBE_CERT_PATH}/etcd/etcd-ca.pem | base64 | tr -d '\n')
    ETCD_CERT=$(cat ${KUBE_CERT_PATH}/etcd/etcd.pem | base64 | tr -d '\n')
    ETCD_KEY=$(cat ${KUBE_CERT_PATH}/etcd/etcd-key.pem | base64 | tr -d '\n')


    #curl https://docs.projectcalico.org/manifests/calico-etcd.yaml -o calico-etcd.yaml                 # latest version
    #curl https://docs.projectcalico.org/archive/v3.20/manifests/calico-etcd.yaml -o calico-etcd.yaml   # v3.20
    mkdir -p "${K8S_DEPLOY_LOG_PATH}/addons/calico"
    local CALICO_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/addons/calico"
    cp addons/calico/calico-3.20/calico-etcd-v3.20.3.yaml                        ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i -r "s%(.*)http://<ETCD_IP>:<ETCD_PORT>(.*)%\1${ETCD_ENDPOINTS}\2%"    ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i "s%# etcd-key: null%etcd-key: ${ETCD_KEY}%g"                          ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i "s%# etcd-cert: null%etcd-cert: ${ETCD_CERT}%g"                       ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i "s%# etcd-ca: null%etcd-ca: ${ETCD_CA}%g"                             ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i -r "s%etcd_ca: \"\"(.*)%etcd_ca: \"/calico-secrets/etcd-ca\"%g"       ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i -r "s%etcd_cert: \"\"(.*)%etcd_cert: \"/calico-secrets/etcd-cert\"%g" ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i -r "s%etcd_key: \"\"(.*)%etcd_key: \"/calico-secrets/etcd-key\"%g"    ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i "s%# - name: CALICO_IPV4POOL_CIDR%- name: CALICO_IPV4POOL_CIDR%g"     ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i "s%#   value: \"192.168.0.0/16\"%  value: \"${POD_NETWORK_CIDR}\"%g"  ${CALICO_CONF_PATH}/calico-etcd.yaml
    sed -i "s%defaultMode: 0400%defaultMode: 0440%g"                             ${CALICO_CONF_PATH}/calico-etcd.yaml
    kubectl apply -f ${CALICO_CONF_PATH}/calico-etcd.yaml
}



function 16_deploy_coredns {
    MSG2 "16. Deploy coredns"

    mkdir -p ${K8S_DEPLOY_LOG_PATH}/addons/coredns
    local COREDNS_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/addons/coredns"
    cp addons/coredns/${K8S_VERSION}/coredns.yaml           ${COREDNS_CONF_PATH}/coredns.yaml
    sed -i "s%#SRV_NETWORK_DNS_IP#%${SRV_NETWORK_DNS_IP}%g" ${COREDNS_CONF_PATH}/coredns.yaml
    kubectl apply -f ${COREDNS_CONF_PATH}/coredns.yaml
}



function 17_deploy_metrics_server {
    MSG2 "17. Deploy metrics server"

    mkdir -p ${K8S_DEPLOY_LOG_PATH}/addons/metrics-server
    local METRICS_CONF_PATH="${K8S_DEPLOY_LOG_PATH}/addons/metrics-server"
    # cp addons/metrics-server/metrics-server-0.4.x/metrics-server-0.4.3.yaml ${METRICS_CONF_PATH}
    # kubectl apply -f ${METRICS_CONF_PATH}/metrics-server-0.4.3.yaml
    cp addons/metrics-server/metrics-server-0.5.x/metrics-server-0.5.2.yaml ${METRICS_CONF_PATH}
    kubectl apply -f ${METRICS_CONF_PATH}/metrics-server-0.5.2.yaml
}



function 18_label_and_taint_master_node {
    # 为 master 节点打上标签
    # 为 master 节点打上污点
    # master 节点的 taint 默认是 NoSchedule，为了充分利用 master 资源可以设置成 PreferNoSchedule
    MSG2 "18. Label and Taint master node"
    sleep 5
    while true; do
        if kubectl get node | grep Ready; then
            for HOST in "${!MASTER[@]}"; do
                kubectl label nodes ${HOST} node-role.kubernetes.io/master= --overwrite  
                kubectl label nodes ${HOST} node-role.kubernetes.io/control-plane= --overwrite
                kubectl taint nodes ${HOST} node-role.kubernetes.io/master:NoSchedule --overwrite; done
                #kubectl taint nodes ${HOST} node-role.kubernetes.io/master:PreferNoSchedule --overwrite
            break
        else
            sleep 1; 
        fi
    done
}


function stage_four {
    MSG1 "============ Stage 4: Deployment Kubernetes Cluster from Binary ===============";
    1_copy_binary_package_and_create_dir
    2_install_keepalived_and_haproxy
    3_setup_haproxy
    4_setup_keepalived
    5_generate_etcd_certs
    6_generate_kubernetes_certs
    7_copy_etcd_and_k8s_certs
    8_setup_etcd
    9_setup_apiserver
    10_setup_controller_manager
    11_setup_scheduler
    12_setup_k8s_admin
    13_setup_kubelet
    14_setup_kube_proxy
    15_deploy_calico
    16_deploy_coredns
    17_deploy_metrics_server
    18_label_and_taint_master_node
}
