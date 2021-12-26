#!/usr/bin/env bash

function 1_upgrade_system {
    echo "1. [`hostname`] Upgrade system"

    local mirrors
    local release
    if [[ ${TIMEZONE} == "Asia/Shanghai" || ${TIMEZONE} == "Asia/Chongqing" ]]; then
        if ! command -v lsb_release; then apt-get update; apt-get install -y lsb-release apt-transport-https; fi
        release=$(lsb_release -sc)
        #mirrors="https://mirrors.ustc.edu.cn/debian"
        #mirrors="https://mirrors.163.com/debian"
        mirrors="https://mirrors.aliyun.com/debian"
        source_list=(
            "deb ${mirrors} ${release} main non-free contrib"
            "deb ${mirrors} ${release}-updates main non-free contrib"
            "deb ${mirrors}-security ${release}-security main non-free contrib"
            "deb-src ${mirrors} ${release} main non-free contrib"
            "deb-src ${mirrors} ${release}-updates main non-free contrib"
            "deb-src ${mirrors}-security ${release}-security main non-free contrib")
        yes | cp /etc/apt/sources.list /etc/apt/sources.list.$(date +%Y%m%d%H%M)
        printf "%s\n" "${source_list[@]}" > /etc/apt/sources.list
    fi

    export DEBIAN_FRONTEND=noninteractive
    _apt_wait && apt-get update -y
    _apt_wait && apt-get -o Dpkg::Options::="--force-confold" upgrade -q -y
    _apt_wait && apt-get -o Dpkg::Options::="--force-confold" dist-upgrade -q -y
    _apt_wait && apt-get autoremove -y
    _apt_wait && apt-get autoclean -y
}


function 2_install_necessary_package {
    echo "2. [`hostname`] Install necessary package"

    _apt_wait && apt-get install -y coreutils apt-file apt-transport-https software-properties-common \
        iputils-ping bash-completion wget curl zip unzip bzip2 vim net-tools \
        git zsh fish rsync psmisc procps dnsutils lvm2 jq sysstat tree \
        lsof virt-what conntrack ipset open-iscsi ipvsadm auditd socat multitail

    #if [[ $(virt-what) == "vmware" ]]; then
        #apt-get install -y open-vm-tools
        #systemctl enable --now open-vm-tools; fi
}


function 3_disable_firewald_and_selinux {
    echo "3. [`hostname`] Disable firewalld and selinux"

    :
}


function 4_set_timezone_and_ntp_client {
    echo "4. [`hostname`] Set timezone and ntp"

    echo "timezone: ${TIMEZONE}"
    timedatectl set-timezone ${TIMEZONE}

    timedatectl set-ntp true
    systemctl restart rsyslog
    systemctl restart cron
}


function 5_configure_sshd {
    echo "5. [`hostname`] Configure ssh"
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


function 6_configure_ulimit {
    echo "6. [`hostname`] Configure ulimit"
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



function main {
    1_upgrade_system
    2_install_necessary_package
    3_disable_firewald_and_selinux
    4_set_timezone_and_ntp_client
    5_configure_sshd
    6_configure_ulimit
}
