#!/usr/bin/env bash

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }


function 1_upgrade_system {
    MSG2 "1. Upgrade system"

    local DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get -o Dpkg::Options::="--force-confold" upgrade -q -y
    apt-get -o Dpkg::Options::="--force-confold" dist-upgrade -q -y
    apt-get autoremove -y
    apt-get autoclean -y

}


function 2_install_necessary_package {
    MSG2 "2. Install necessary package"

    apt-get install -y coreutils apt-file apt-transport-https software-properties-common iputils-ping bash-completion wget curl zip unzip bzip2 vim net-tools git zsh fish rsync psmisc procps dnsutils lvm2 ntp ntpdate jq sysstat tree lsof virt-what conntrack
    add-apt-repository universe
    if [[ $(virt-what) == "vmware" ]]; then
        apt-get install -y open-vm-tools
        systemctl enable --now open-vm-tools
    fi
}


function 3_disable_firewald_and_selinux {
    MSG2 "3. Disable firewalld and selinux"

    ufw disable
}


function 4_set_timezone_and_ntp_client {
    MSG2 "4. Set timezone and ntp"

    timedatectl set-timezone Asia/Shanghai
    timedatectl set-ntp true
    systemctl restart rsyslog
    systemctl restart cron
}


function 5_configure_sshd {
    MSG2 "5. Configure ssh"
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

    systemctl restart sshd
}


function 6_configure_ulimit {
    MSG2 "6. Configure ulimit"
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
1_upgrade_system
2_install_necessary_package
3_disable_firewald_and_selinux
4_set_timezone_and_ntp_client
5_configure_sshd
6_configure_ulimit
