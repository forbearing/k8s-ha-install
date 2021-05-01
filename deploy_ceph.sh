#!/usr/bin/env bash


EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }


CEPH_NODE_HOST=(node1
                node2
                node3)
CEPH_NODE_IP=(10.250.20.11
              10.250.20.12
              10.250.20.13)
CEPH_NODE=(${CEPH_NODE_HOST[@]})
CEPH_CLUSTER_NETWORK_CIDR="10.250.0.0/16"
CEPH_PUBLIC_NETWORK_CIDR="10.250.0.0/16"

CEPH_NODE_ROOT_PASS="toor"
INSTALL_MANAGER="yum"



function 0_check_root_and_os() {
    [ `id -u` != "0" ] && ERR "not root !" && exit $EXIT_FAILURE
    [ `uname` != "Linux" ] && ERR "not support !" && exit $EXIT_FAILURE

    timeout 2 ping -c 1 -i 1 8.8.8.8
    if [ $? != 0 ]; then ERR "no network"; exit $EXIT_FAILURE; fi
}



function 1_ssh_public_key_auth {
    # 生成 /etc/hosts 文件
    for (( i=0; i<${#CEPH_NODE[@]}; i++ )); do
        sed -r -i "/(.*)${CEPH_NODE_HOST[$i]}(.*)/d" /etc/hosts
        echo "${CEPH_NODE_IP[$i]} ${CEPH_NODE_HOST[$i]}" >> /etc/hosts
    done


    # 生成 ssh key
    command -v sshpass &> /dev/null
    if [ $? != 0 ]; then ${INSTALL_MANAGER} install -y sshpass; fi
    command -v ssh-keyscan &> /dev/null
    if [ $? != 0 ]; then ${INSTALL_MANAGER} install -y ssh-keyscan; fi
    if [[ ! -d "/root/.ssh" ]]; then rm -rf /root/.ssh; mkdir /root/.ssh; chmod 0700 /root/.ssh; fi
    if [[ ! -s "/root/.ssh/id_rsa" ]]; then ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa; fi 
    if [[ ! -s "/root/.ssh/id_ecdsa" ]]; then ssh-keygen -t ecdsa -N '' -f /root/.ssh/id_ecdsa; fi
    if [[ ! -s "/root/.ssh/id_ed25519" ]]; then ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519; fi
    #if [[ ! -s "/root/.ssh/id_xmss" ]]; then ssh-keyscan -t xmss -N '' -f /root/.ssh/id_xmss; fi


    # 设置 ssh 公钥登录
    for NODE in "${CEPH_NODE[@]}"; do 
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts 2> /dev/null
    done
    for NODE in "${CEPH_NODE[@]}"; do
        sshpass -p "${CEPH_NODE_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${NODE}"
        sshpass -p "${CEPH_NODE_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${NODE}"
        sshpass -p "${CEPH_NODE_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${NODE}"
        #sshpass -p "${CEPH_NODE_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_xmss.pub root@"${NODE}"
    done


    # 设置 hostname
    # 复制 /etc/hosts 文件到远程服务器
    for (( i=0; i<${#CEPH_NODE[@]}; i++ )); do
        ssh ${CEPH_NODE[$i]} "hostnamectl set-hostname ${CEPH_NODE[$i]}"
        scp /etc/hosts ${CEPH_NODE[$i]}:/etc/hosts
    done
}



function 3_prepare_for_ceph {
    # 生成 ceph 源
    cat > /etc/yum.repos.d/ceph.repo <<-EOF
[ceph-x86_64]
name=Ceph-x86_64
baseurl=https://mirrors.tuna.tsinghua.edu.cn/ceph/rpm-nautilus/el7/x86_64/
enabled=1
gpgcheck=0

[ceph-noarch]
name=Ceph noarch
baseurl=https://mirrors.tuna.tsinghua.edu.cn/ceph/rpm-nautilus/el7/noarch/
enabled=1
gpgcheck=0

[ceph-source]
name=ceph-source
baseurl=https://mirrors.tuna.tsinghua.edu.cn/ceph/rpm-nautilus/el7/SRPMS/
enabled=1
gpgcheck=0
EOF
    # 导入 ceph 源
    for NODE in "${CEPH_NODE[@]}"; do
        scp /etc/yum.repos.d/ceph.repo ${NODE}:/etc/yum.repos.d/ceph.repo
        yum makecache
    done
    # 安装 ceph 相关软件包
    for NODE in "${CEPH_NODE[@]}"; do
        ssh ${NODE} "rpm -qi epel-release" &> /dev/null
        [ $? -ne 0 ] && ssh ${NODE} "yum install -y epel-release"
        ssh ${NODE} "rpm -qi ceph-deploy python2-pip deltarpm" &> /dev/null
        [ $? -ne 0 ] && ssh ${NODE} "yum install -y ceph-deploy python2-pip deltarpm"
    done


    # 关闭防火墙
    # 关闭 SELinux
    sed -i "/^SELINUX=/d" /etc/selinux/config
    echo "SELINUX=disabled" >> /etc/selinux/config
    for NODE in "${CEPH_NODE[@]}"; do
        ssh ${NODE} "systemctl disable --now firewalld"
        ssh ${NODE} "setenforce 0"
        scp /etc/selinux/config ${NODE}:/etc/selinux/config
    done
}



function 4_install_ceph {
    mkdir /root/ceph-deploy && cd /root/ceph-deploy

    # step 1: deploy a new ceph cluster
    MSG2 "deploy a new ceph cluster"
    ceph-deploy new --cluster-network="${CEPH_CLUSTER_NETWORK_CIDR}" --public-network="${CEPH_PUBLIC_NETWORK_CIDR}" ${CEPH_NODE[0]}

    # step 2: install new package in remote host
    MSG2 "Install new package in remote host"
    for NODE in ${CEPH_NODE[@]}; do
        ssh ${NODE} "yum install -y ceph-mon ceph-mgr ceph-osd ceph-mds ceph-radosgw ceph"
    done

    # step 3: create ceph-mon
    MSG2 "create ceph-mon"
    ceph-deploy mon create-initial

    # step 4: Push configuration and client.admin key to a remoth configuration and client.admin key to a remoteu
    MSG2 "push config and key"
    for NODE in ${CEPH_NODE[@]}; do
        ceph-deploy admin ${NODE}
    done

    # step 5: create ceph-mgr
    MSG2 "create ceph-mgr"
    ceph-deploy mgr create ${CEPH_NODE[0]}

    # step 6: create ceph-osd
    MSG2 "create ceph-osd"
    for NODE in ${CEPH_NODE[@]}; do
        ceph-deploy osd create ${NODE} --data /dev/sdb
    done

    ## setp 7: add more ceph-mon
    MSG2 "add more ceph-mon"
    ceph-deploy mon add ${CEPH_NODE[1]}
    ceph-deploy mon add ${CEPH_NODE[2]}

    # step 8: add more ceph-mgr
    MSG2 "add more ceph-mgr"
    ceph-deploy mgr create ${CEPH_NODE[1]} ${CEPH_NODE[2]}
}



0_check_root_and_os
1_ssh_public_key_auth
3_prepare_for_ceph
4_install_ceph
