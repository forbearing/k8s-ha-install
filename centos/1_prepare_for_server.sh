#!/usr/bin/env bash

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }


function 1_import_repo {
    MSG2 "1. [`hostname`] Imort yum repo"

    if [[ ${TIMEZONE} == "Asia/Shanghai" || ${TIMEZONE} == "Asia/Chongqing" ]]; then
        echo y | cp /etc/yum.repos.d/CentOS-Base.repo               /etc/yum.repos.d/CentOS-Base.repo.$(date +%Y%m%d%H%M)
        echo y | cp /tmp/yum.repos.d/CentOS-Base.repo-ustc          /etc/yum.repos.d/CentOS-Base.repo
        echo y | cp /tmp/yum.repos.d/elrepo.repo-ustc               /etc/yum.repos.d/elrepo.repo
        echo y | cp /tmp/yum.repos.d/ceph-nautilus.repo-tsinghua    /etc/yum.repos.d/ceph.repo
    else
        echo y | cp /tmp/yum.repos.d/ceph-nautilus.repo-official    /etc/yum.repos.d/ceph.repo
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
        yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
    fi

    yum makecache
}


function 2_install_necessary_package {
    MSG2 "2. [`hostname`] Install necessary package"

    yum clean all
    yum install -y epel-release

    if [[ ${TIMEZONE} == "Asia/Shanghai" || ${TIMEZONE} == "Asia/Chongqing" ]]; then
        echo y | cp /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.$(date +%Y%m%d%H%M)
        echo y | cp /tmp/yum.repos.d/epel.repo-ustc /etc/yum.repos.d/epel.repo; fi

    yum install -y coreutils bash-completion iputils wget curl zip unzip bzip2 vim net-tools \
        git zsh fish rsync psmisc procps-ng bind-utils yum-utils device-mapper-persistent-data \
        lvm2 ntp ntpdate jq sysstat nc tree lsof virt-what audit iscsi-initiator-utils socat multitail

    #if [[ $(virt-what) == "vmware" ]]; then
        #yum install -y open-vm-tools
        #systemctl enable --now vmtoolsd
    #fi
}


function 3_upgrade_system {
    MSG2 "3. [`hostname`] Upgrade system"

    yum update -y --exclude="docker-ce,kernel-lt"
}


function 4_disable_firewald_and_selinux {
    MSG2 "4. [`hostname`] Disable firewalld and selinux"

    systemctl disable --now firewalld
    setenforce 0
    sed -i "/^SELINUX=/d" /etc/selinux/config
    echo "SELINUX=disabled" >> /etc/selinux/config
}


function 5_set_timezone_and_ntp_client {
    MSG2 "5. [`hostname`] Set timezone and ntp"

    timedatectl set-timezone ${TIMEZONE}
    timedatectl set-ntp 1
    systemctl restart rsyslog
    systemctl restart crond
}


function 6_configure_sshd {
    MSG2 "6. [`hostname`] Configure ssh"
    local SSH_CONF_PATH="/etc/ssh/sshd_config"

    sed -i "/^UseDNS/d" ${SSH_CONF_PATH}
    sed -i "/^GSSAPIAuthentication/d" ${SSH_CONF_PATH}
    sed -i "/^PermitRootLogin/d" ${SSH_CONF_PATH}
    sed -i "/^PasswordAuthentication/d" ${SSH_CONF_PATH}
    sed -i "/^PermitEmptyPasswords/d" ${SSH_CONF_PATH}
    sed -i "/^PubkeyAuthentication/d" ${SSH_CONF_PATH}
    sed -i "/^AuthorizedKeysFile/d" ${SSH_CONF_PATH}
    #sed -i "/^ClientAliveInterval/d" ${SSH_CONF_PATH}
    #sed -i "/^ClientAliveCountMax/d" ${SSH_CONF_PATH}
    sed -i "/^Protocol/d" ${SSH_CONF_PATH}

    echo "UseDNS no" >> ${SSH_CONF_PATH}
    echo "GSSAPIAuthentication no" >> ${SSH_CONF_PATH}
    echo "PermitRootLogin yes" >> ${SSH_CONF_PATH}
    echo "PasswordAuthentication yes" >> ${SSH_CONF_PATH}
    echo "PermitEmptyPasswords no" >> ${SSH_CONF_PATH}
    echo "PubkeyAuthentication yes" >> ${SSH_CONF_PATH}
    echo "AuthorizedKeysFile .ssh/authorized_keys" >> ${SSH_CONF_PATH}
    #echo "ClientAliveInterval 360" >> ${SSH_CONF_PATH}
    #echo "ClientAliveCountMax 0" >> ${SSH_CONF_PATH}
    echo "Protocol 2" >> ${SSH_CONF_PATH}

    systemctl restart sshd
}


function 7_configure_ulimit {
    MSG2 "7. [`hostname`] Configure ulimit"
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
}



MSG1 "*** `hostname` *** Prepare for Linux Server"
1_import_repo
2_install_necessary_package
3_upgrade_system
4_disable_firewald_and_selinux
5_set_timezone_and_ntp_client
6_configure_sshd
7_configure_ulimit
