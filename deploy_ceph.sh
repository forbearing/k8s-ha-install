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
    MSG1 "check root and os"
    [ `id -u` != "0" ] && ERR "not root !" && exit $EXIT_FAILURE
    [ `uname` != "Linux" ] && ERR "not support !" && exit $EXIT_FAILURE

    timeout 2 ping -c 1 -i 1 8.8.8.8
    if [ $? != 0 ]; then ERR "no network"; exit $EXIT_FAILURE; fi
}



function 1_ssh_public_key_auth {
    MSG1 "1. ssh public key authentication"
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



function 2_prepare_for_ceph {
    MSG1 "2. prepare for ceph"

    # 生成 ceph 源
    cat <<- \EOF > /etc/yum.repos.d/ceph.repo 
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
sed -i 's/^[[:space:]]*//' /etc/yum.repos.d/ceph.repo

    cat <<- \EOF > /etc/yum.repos.d/elrepo.repo
    [elrepo]
    name=ELRepo.org Community Enterprise Linux Repository - el7
    baseurl=http://mirror.rackspace.com/elrepo/elrepo/el7/$basearch/
    #mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo.el7
    enabled=1
    gpgcheck=0
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
    protect=0

    [elrepo-kernel]
    name=ELRepo.org Community Enterprise Linux Kernel Repository - el7
    baseurl=http://mirror.rackspace.com/elrepo/kernel/el7/$basearch/
    #mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo-kernel.el7
    enabled=1
    gpgcheck=0
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
    protect=0
EOF
sed -i 's/^[[:space:]]*//' /etc/yum.repos.d/elrepo.repo

    cat <<- \EOF > /tmp/set_default_kernel.sh
    #!/usr/bin/env bash
    grub2-set-default "$(cat /boot/grub2/grub.cfg  | grep '^menuentry' | sed -n '1,1p' | awk -F "'" '{print $2}')"
EOF
sed -i 's/^[[:space:]]*//' /tmp/set_default_kernel.sh


    # 关闭 SELinux
    # 设置防火墙
    MSG2 "2.1 Disable SELinux and setup firewall"
    sed -i "/^SELINUX=/d" /etc/selinux/config
    echo "SELINUX=disabled" >> /etc/selinux/config
    for NODE in "${CEPH_NODE[@]}"; do
        scp /etc/selinux/config ${NODE}:/etc/selinux/config
        ssh ${NODE} "setenforce 0"
        ssh ${NODE} "systemctl enable --now firewalld"
        ssh ${NODE} "firewall-cmd --add-service=ceph"
        ssh ${NODE} "firewall-cmd --add-service=ceph-mon"
        ssh ${NODE} "firewall-cmd --add-service=ceph --permanent"
        ssh ${NODE} "firewall-cmd --add-service=ceph-mon --permanent"
        ssh ${NODE} "firewall-cmd --reload"
    done


    # 复制 yum 源到远程目录
    MSG2 "2.2 import yum repo"
    for NODE in "${CEPH_NODE[@]}"; do
        scp /etc/yum.repos.d/ceph.repo ${NODE}:/etc/yum.repos.d/ceph.repo
        scp /etc/yum.repos.d/elrepo.repo ${NODE}:/etc/yum.repos.d/elrepo.repo
        yum makecache
    done

    # 安装 ceph 相关软件包
    MSG2 "2.3 install package for ceph"
    for NODE in "${CEPH_NODE[@]}"; do
        ssh ${NODE} "rpm -qi epel-release" &> /dev/null
        [ $? -ne 0 ] && ssh ${NODE} "yum install -y epel-release"
        ssh ${NODE} "rpm -qi ceph-deploy python2-pip deltarpm" &> /dev/null
        [ $? -ne 0 ] && ssh ${NODE} "yum install -y ceph-deploy python2-pip deltarpm"
    done

    # 升级系统
    MSG2 "2.4 upgrade system"
    for NODE in "${CEPH_NODE[@]}"; do
        ssh ${NODE} "yum update -y"
    done


    # 时区、时间同步配置
    MSG2 "2.5 Setup timezone and ntp"
    echo "server 0.asia.pool.ntp.org iburst" > /etc/ntpd.conf
    echo "server 1.asia.pool.ntp.org iburst" >> /etc/ntpd.conf
    echo "server 2.asia.pool.ntp.org iburst" >> /etc/ntpd.conf
    echo "server 3.asia.pool.ntp.org iburst" >> /etc/ntpd.conf
    for NODE in "${CEPH_NODE[@]}"; do
        ssh ${NODE} "timedatectl set-timezone 'Asia/Shanghai'"
        ssh ${NODE} "timedatectl set-ntp 0"
        ssh ${NODE} "systemctl disable --now systemd-timedated.service"
        ssh ${NODE} "systemctl disable --now chrony" &> /dev/null
        ssh ${NODE} "rpm -qi ntpdate ntp" &> /dev/null
        if [ $? -ne 0 ]; then ssh ${NODE} "yum install -y ntpdate ntp"; fi
        scp /etc/ntpd.conf ${NODE}:/etc/ntpd.conf
        ssh ${NODE} "systemctl enable ntpd.service"
        ssh ${NODE} "systemctl restart ntpd.service"
    done
}



function 3_optimize_for_ceph {
    MSG1 "3. optimize for ceph"

    # 升级内核并设置默认内核
    MSG2 "3.1 Upgrade Kernel"
    for NODE in "${CEPH_NODE[@]}"; do
        ssh ${NODE} "yum install -y kernel-lt"
        ssh ${NODE} "bash -s" < "/tmp/set_default_kernel.sh"
    done


    # 设置 ulimit，调整最大打开文件数、最大进程数、内存最大锁定值
    MSG2 "3.2 Setup Ulimit file"
    local ULIMITS_CONF_PATH="/etc/security/limits.conf"

    sed -i -r "/^\*(.*)soft(.*)nofile(.*)/d" ${ULIMITS_CONF_PATH}
    sed -i -r "/^\*(.*)hard(.*)nofile(.*)/d" ${ULIMITS_CONF_PATH}
    sed -i -r "/^\*(.*)soft(.*)nproc(.*)/d" ${ULIMITS_CONF_PATH}
    sed -i -r "/^\*(.*)hard(.*)nproc(.*)/d" ${ULIMITS_CONF_PATH}
    sed -i -r "/^\*(.*)soft(.*)memlock(.*)/d" ${ULIMITS_CONF_PATH}
    sed -i -r "/^\*(.*)hard(.*)memlock(.*)/d" ${ULIMITS_CONF_PATH}

    echo "* soft nofile 655360" >> ${ULIMITS_CONF_PATH}
    echo "* hard nofile 131072" >> ${ULIMITS_CONF_PATH}
    echo "* soft nproc 655360" >> ${ULIMITS_CONF_PATH}
    echo "* hard nproc 655360" >> ${ULIMITS_CONF_PATH}
    echo "* soft memlock unlimited" >> ${ULIMITS_CONF_PATH}
    echo "* hard memlock unlimited" >> ${ULIMITS_CONF_PATH}
    for NODE in "${CEPH_NODE[@]}"; do
        scp ${ULIMITS_CONF_PATH} ${NODE}:${ULIMITS_CONF_PATH}
    done


    # 调整内核参数
    MSG2 "3.3 Setup kernel parameter"
    ceph_sysctl=(
        "net.ipv4.ip_forward = 0"
        "fs.inotify.max_user_instances = 81920"
        "fs.inotify.max_user_watches = 1048576"
        "fs.file-max = 52706963"
        "fs.nr_open = 52706963"
    )
    printf '%s\n' "${ceph_sysctl}" > /etc/sysctl.d/98-ceph.conf
    for NODE in "${CEPH_NODE[@]}"; do
        scp /etc/sysctl.d/98-ceph.conf ${NODE}:/etc/sysctl.d/98-ceph.conf
        sysctl --system
    done
}



function 4_install_ceph {
    MSG1 "4. install ceph"
    mkdir /root/ceph-deploy && cd /root/ceph-deploy

    # step 1: deploy a new ceph cluster
    MSG2 "4.1 Deploy a new ceph cluster"
    ceph-deploy new --cluster-network="${CEPH_CLUSTER_NETWORK_CIDR}" --public-network="${CEPH_PUBLIC_NETWORK_CIDR}" ${CEPH_NODE[0]}

    # step 2: install new package in remote host
    MSG2 "4.2 Install ceph package in remote host"
    for NODE in "${CEPH_NODE[@]}"; do
        ssh ${NODE} "yum install -y ceph-mon ceph-mgr ceph-osd ceph-mds ceph-radosgw ceph"
    done

    # step 3: create ceph-mon
    MSG2 "4.3 Create ceph-mon"
    ceph-deploy mon create-initial

    # step 4: Push configuration and client.admin key to a remoth configuration and client.admin key to a remoteu
    MSG2 "4.4 Push config and key"
    for NODE in "${CEPH_NODE[@]}"; do
        ceph-deploy admin ${NODE}
    done

    # step 5: create ceph-mgr
    MSG2 "4.5 Create ceph-mgr"
    ceph-deploy mgr create ${CEPH_NODE[0]}

    # step 6: create ceph-osd
    MSG2 "4.6 Create ceph-osd"
    for NODE in "${CEPH_NODE[@]}"; do
        ceph-deploy osd create ${NODE} --data /dev/sdb
    done

    ## setp 7: add more ceph-mon
    MSG2 "4.7 Add more ceph-mon"
    ceph-deploy mon add ${CEPH_NODE[1]}
    ceph-deploy mon add ${CEPH_NODE[2]}

    # step 8: add more ceph-mgr
    MSG2 "4.8 Add more ceph-mgr"
    ceph-deploy mgr create ${CEPH_NODE[1]} ${CEPH_NODE[2]}
}



0_check_root_and_os
1_ssh_public_key_auth
2_prepare_for_ceph
3_optimize_for_ceph
4_install_ceph
