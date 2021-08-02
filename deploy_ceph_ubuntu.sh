#!/usr/bin/env bash
# OS:   Ubuntu18
# Ceph: ceph-nautils

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }



#========== ceph
declare -A CEPH_NODE
CEPH_NODE=( 
    [sh-u18-ceph-node1]=10.250.19.11
    [sh-u18-ceph-node2]=10.250.19.12
    [sh-u18-ceph-node3]=10.250.19.13)
CEPH_ROOT_PASS="toor"
CEPH_CLUSTER_NETWORK="10.250.0.0/16"
CEPH_PUBLIC_NETWORK="10.250.0.0/16"
CEPH_OSD_DISK="/dev/sdb"



function upgrade_system {
    MSG1 "1. Upgrade System"

    local DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get -o Dpkg::Options::="--force-confold" upgrade -q -y
    apt-get -o Dpkg::Options::="--force-confold" dist-upgrade -q -y
    apt-get autoremove -y
    apt-get autoclean -y
}



function 1_configure_ssh_authentication {
    MSG1 "1. Configure SSH Authentication"

    # 生成 /etc/hosts 文件
    for HOST in "${!CEPH_NODE[@]}"; do
        local IP=${CEPH_NODE[$HOST]}
        sed -r -i "/(.*)${HOST}(.*)/d" /etc/hosts
        echo "${IP} ${HOST}" >> /etc/hosts
    done

    # 1.安装 sshpass 软件包
    # 2.生成 ssh 密钥对
    if ! command -v sshpass; then apt-get update -y && apt-get install -y sshpass; fi
    if [[ ! -d "/root/.ssh" ]]; then rm -rf /root/.ssh; mkdir /root/.ssh; chmod 0700 /root/.ssh; fi
    if [[ ! -s "/root/.ssh/id_rsa" ]]; then ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa; fi 
    if [[ ! -s "/root/.ssh/id_ecdsa" ]]; then ssh-keygen -t ecdsa -N '' -f /root/.ssh/id_ecdsa; fi
    if [[ ! -s "/root/.ssh/id_ed25519" ]]; then ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519; fi
    #if [[ ! -s "/root/.ssh/id_xmss" ]]; then ssh-keyscan -t xmss -N '' -f /root/.ssh/id_xmss; fi

    # 1.收集所有 ceph 节点的主机指纹
    # 2.将本机的 SSH 公钥拷贝到所有的 ceph 节点上
    # 3.将本机的 /etc/hosts 拷贝到其它 ceph 节点上
    # 4.设置所有节点的主机名
    for HOST in "${!CEPH_NODE[@]}"; do
        local IP=${CEPH_NODE[$HOST]}
        ssh-keyscan "${HOST}" >> /root/.ssh/known_hosts 2> /dev/null
        sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${HOST}"
        sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${HOST}"
        sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${HOST}"
        #sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_xmss.pub root@"${HOST}"
        ssh root@${HOST} "hostnamectl set-hostname ${HOST}"
        scp /etc/hosts root@${HOST}:/etc/
    done
}



function 2_all_ceph_upgrade {
    MSG1 "2. Ceph Node Upgrade"

    for HOST in "${!CEPH_NODE[@]}"; do
        local IP=${CEPH_NODE[$HOST]}
        MSG2 "${HOST} upgrade"
        ssh root@${HOST} "
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y
            apt-get -o Dpkg::Options::=\"--force-confold\" upgrade -q -y
            apt-get -o Dpkg::Options::=\"--force-confold\" dist-upgrade -q -y
            apt-get autoremove -y
            apt-get autoclean -y"
    done
}



function 3_optimizate_system {
    MSG1 "3. Optimizate System"
    
    # configure ssh
    local SSH_CONF_PATH="/etc/ssh/sshd_config"
    sed -i "/^UseDNS/d" ${SSH_CONF_PATH}
    sed -i "/^GSSAPIAuthentication/d" ${SSH_CONF_PATH}
    sed -i "/^PermitRootLogin/d" ${SSH_CONF_PATH}
    sed -i "/^PasswordAuthentication/d" ${SSH_CONF_PATH}
    sed -i "/^PermitEmptyPasswords/d" ${SSH_CONF_PATH}
    sed -i "/^PubkeyAuthentication/d" ${SSH_CONF_PATH}
    sed -i "/^AuthorizedKeysFile/d" ${SSH_CONF_PATH}
    sed -i "/^ClientAliveInterval/d" ${SSH_CONF_PATH}
    sed -i "/^ClientAliveCountMax/d" ${SSH_CONF_PATH}
    sed -i "/^Protocol/d" ${SSH_CONF_PATH}

    echo "UseDNS no" >> ${SSH_CONF_PATH}
    echo "GSSAPIAuthentication no" >> ${SSH_CONF_PATH}
    echo "PermitRootLogin yes" >> ${SSH_CONF_PATH}
    echo "PasswordAuthentication yes" >> ${SSH_CONF_PATH}
    echo "PermitEmptyPasswords no" >> ${SSH_CONF_PATH}
    echo "PubkeyAuthentication yes" >> ${SSH_CONF_PATH}
    echo "AuthorizedKeysFile .ssh/authorized_keys" >> ${SSH_CONF_PATH}
    echo "ClientAliveInterval 360" >> ${SSH_CONF_PATH}
    echo "ClientAliveCountMax 0" >> ${SSH_CONF_PATH}
    echo "Protocol 2" >> ${SSH_CONF_PATH}

    # configure ulimits
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

    # copy /etc/ssh/sshd.conf, /etc/security/limits.conf to all ceph node
    for HOST in "${!CEPH_NODE[@]}"; do
        local IP=${CEPH_NODE[$HOST]}
        scp ${SSH_CONF_PATH}     root@${HOST}:/etc/ssh/
        scp ${ULIMITS_CONF_PATH} root@${HOST}:/etc/security/
        ssh root@${HOST} "
            systemctl restart sshd
            timedatectl set-timezone Asia/Shanghai
            timedatectl set-ntp true"
    done
}



function 4_install_ceph_package {
    MSG1 "4. Install Ceph Package"

    # import repository key
    while true; do
        #if wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -; then break; fi
        if wget -q -O- 'https://mirrors.ustc.edu.cn/ceph/keys/release.asc' | sudo apt-key add -; then break; fi
    done
    #echo deb https://download.ceph.com/debian-nautilus/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
    echo deb https://mirrors.ustc.edu.cn/ceph/debian-nautilus/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list

    # export all keyring and copy to all ceph node
    apt-key exportall > /tmp/trusted-keys
    apt-get update -y
    apt-get purge -y ceph-deploy
    apt-get install -y ceph-deploy

    for HOST in "${!CEPH_NODE[@]}"; do
        local IP=${CEPH_NODE[$HOST]}
        scp /tmp/trusted-keys                   root@${HOST}:/tmp/
        scp /etc/apt/sources.list.d/ceph.list   root@${HOST}:/etc/apt/sources.list.d/
        MSG2 "${HOST} install ceph"
        ssh root@${HOST} "
            export DEBIAN_FRONTEND=noninteractive
            apt-key add /tmp/trusted-keys
            apt-get update -y
            apt-get install -yq ceph ceph-common ceph-mon ceph-mgr ceph-osd ceph-mds radosgw radosgw-agent"
    done
}



function 5_deploy_ceph_cluster {
    MSG1 "5. Deploy Ceph Cluster"

    if [[ ! -d /root/ceph-deploy ]]; then rm -rf /root/ceph-deploy && mkdir /root/ceph-deploy; fi
    cd /root/ceph-deploy
    ceph-deploy --overwrite-conf new --cluster-network="${CEPH_CLUSTER_NETWORK}" --public-network="${CEPH_PUBLIC_NETWORK}" $(hostname)
    ceph-deploy --overwrite-conf mon create-initial
    for HOST in "${!CEPH_NODE[@]}"; do
        local IP=${CEPH_NODE[$HOST]}
        ceph-deploy --overwrite-conf admin ${HOST}
        ceph-deploy --overwrite-conf mon create ${HOST}
        ceph-deploy --overwrite-conf mgr create ${HOST}
        ceph-deploy --overwrite-conf mds create ${HOST}
        ceph-deploy --overwrite-conf osd create ${HOST} --data ${CEPH_OSD_DISK}
    done
    ceph config set mon mon_warn_on_insecure_global_id_reclaim false
    ceph config set mon mon_warn_on_insecure_global_id_reclaim_allowed false
}



1_configure_ssh_authentication
2_all_ceph_upgrade
3_optimizate_system
4_install_ceph_package
5_deploy_ceph_cluster
