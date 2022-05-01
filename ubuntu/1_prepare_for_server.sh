#!/usr/bin/env bash

function 1_upgrade_system {
    echo "1. [`hostname`] Upgrade system"

    source /etc/os-release
    local linuxVersion=$( echo $VERSION | awk -F'[.| ]' '{print $1}' )
    local linuxCodeName=$VERSION_CODENAME
    local mirror

    if [[ $TIMEZONE == "Asia/Shanghai" || $TIMEZONE == "Asia/Chongqing" ]]; then
        # Official Archive Mirrors for Ubuntu
        # https://launchpad.net/ubuntu/+archivemirrors
        # 1. ustc 使用太多会限速甚至是连不上,先测试下 nju
        case ${LINUX_SOFTWARE_MIRROR,,} in
        nju)      mirror="http://mirror.nju.edu.cn/ubuntu" ;;          # 南京大学, 10Gbps
        bupt)     mirror="http://mirrors.bupt.edu.cn/ubuntu" ;;        # 北京邮电大学, 10Gbps
        ustc)     mirror="http://mirrors.ustc.edu.cn/ubuntu" ;;        # 中国科学技术大学, 10Gbps
        aliyun)   mirror="http://mirrors.aliyun.com/ubuntu" ;;         # 阿里云, 2Gbps
        tencent)  mirror="http://mirrors.cloud.tencent.com/ubuntu" ;;  # 腾讯云, 2Gbps
        sjtu)     mirror="http://ftp.sjtu.edu.cn/ubuntu" ;;            # 上海交通大学, 1Gbps
        bjtu)     mirror="http://mirror.bjtu.edu.cn/ubuntu" ;;         # 北京交通大学, 1Gbps
        dlut)     mirror="http://mirror.dlut.edu.cn/ubuntu" ;;         # 大连理工大学, 1Gbps
        hit)      mirror="http://mirrors.hit.edu.cn/ubuntu" ;;         # 哈尔滨工业大学, 1Gbps
        huawei)   mirror="http://repo.huaweicloud.com/ubuntu" ;;       # 华为云, 1Gbps
        njupt)    mirror="http://mirrors.njupt.edu.cn/ubuntu" ;;       # 南京邮电大学, 1Gbps
        sohu)     mirror="http://mirrors.sohu.com/ubuntu" ;;           # 搜狐, 1Gbps
        xjtu)     mirror="http://mirrors.xjtu.edu.cn/ubuntu" ;;        # 西安交通大学, 1Gbps
        skyshe)   mirror="http://mirrors.skyshe.cn/ubuntu" ;;          # xTom open source software, 1Gbps
        lzu)      mirror="http://mirror.lzu.edu.cn/ubuntu" ;;          # 兰州大学, 100Mbps
        cqu)      mirror="http://mirrors.cqu.edu.cn/ubuntu" ;;         # 重庆大学, 100Mbps
        dgut)     mirror="http://mirrors.dgut.edu.cn/ubuntu" ;;        # 东莞理工学院, 100Mbps
        tsinghua) mirror="http://mirrors.tuna.tsinghua.edu.cn/ubuntu" ;; # 清华大学
        bfsu)     mirror="http://mirrors.bfsu.edu.cn/ubuntu" ;;        # 北京外国语大学
        163)      mirror="http://mirrors.163.com/ubuntu" ;;            # 网易
        *)        mirror="http://cn.archive.ubuntu.com/ubuntu" ;;
        esac
        source_list=(
            "deb $mirror $linuxCodeName main restricted universe multiverse"
            "deb $mirror $linuxCodeName-security main restricted universe multiverse"
            "deb $mirror $linuxCodeName-updates main restricted universe multiverse"
            "deb $mirror $linuxCodeName-proposed main restricted universe multiverse"
            "deb $mirror $linuxCodeName-backports main restricted universe multiverse"
            "deb-src $mirror $linuxCodeName main restricted universe multiverse"
            "deb-src $mirror $linuxCodeName-security main restricted universe multiverse"
            "deb-src $mirror $linuxCodeName-updates main restricted universe multiverse"
            "deb-src $mirror $linuxCodeName-proposed main restricted universe multiverse"
            "deb-src $mirror $linuxCodeName-backports main restricted universe multiverse")
        cp -f /etc/apt/sources.list /etc/apt/sources.list.$(date +%Y%m%d%H%M)
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

    ufw --force disable
}


function 4_set_timezone_and_ntp_client {
    echo "4. [`hostname`] Set timezone and ntp"

    echo "timezone: $TIMEZONE"
    timedatectl set-timezone $TIMEZONE

    source /etc/os-release
    linuxVersion=$( echo $VERSION | awk -F'[.| ]' '{print $1}' )
    case "$linuxVersion" in
    18)
        _apt_wait && apt-get install -y ntp ntpdate
        systemctl enable --now ntp
        systemctl restart ntp ;;
    20|22)
        _apt_wait && apt-get install -y systemd-timesyncd
        systemctl enable --now systemd-timesyncd.service
        systemctl restart systemd-timesyncd.service ;;
    esac

    timedatectl set-ntp true
    systemctl restart rsyslog
    systemctl restart cron
}


function 5_configure_sshd {
    echo "5. [`hostname`] Configure ssh"
    local SSH_CONF_PATH="/etc/ssh/sshd_config"

    sed -i "/^UseDNS/d" $SSH_CONF_PATH
    sed -i "/^GSSAPIAuthentication/d" $SSH_CONF_PATH
    sed -i "/^PermitRootLogin/d" $SSH_CONF_PATH
    sed -i "/^PasswordAuthentication/d" $SSH_CONF_PATH
    sed -i "/^PermitEmptyPasswords/d" $SSH_CONF_PATH
    sed -i "/^PubkeyAuthentication/d" $SSH_CONF_PATH
    sed -i "/^AuthorizedKeysFile/d" $SSH_CONF_PATH
    #sed -i "/^ClientAliveInterval/d" $SSH_CONF_PATH
    #sed -i "/^ClientAliveCountMax/d" $SSH_CONF_PATH
    sed -i "/^Protocol/d" $SSH_CONF_PATH

    echo "UseDNS no" >> $SSH_CONF_PATH
    echo "GSSAPIAuthentication no" >> $SSH_CONF_PATH
    echo "PermitRootLogin yes" >> $SSH_CONF_PATH
    echo "PasswordAuthentication yes" >> $SSH_CONF_PATH
    echo "PermitEmptyPasswords no" >> $SSH_CONF_PATH
    echo "PubkeyAuthentication yes" >> $SSH_CONF_PATH
    echo "AuthorizedKeysFile .ssh/authorized_keys" >> $SSH_CONF_PATH
    #echo "ClientAliveInterval 360" >> $SSH_CONF_PATH
    #echo "ClientAliveCountMax 0" >> $SSH_CONF_PATH
    echo "Protocol 2" >> $SSH_CONF_PATH

    systemctl restart sshd
}


function 6_configure_ulimit {
    echo "6. [`hostname`] Configure ulimit"
    local ULIMITS_CONF_PATH="/etc/security/limits.conf"

    sed -i -r "/^\*(.*)soft(.*)nofile(.*)/d" $ULIMITS_CONF_PATH
    sed -i -r "/^\*(.*)hard(.*)nofile(.*)/d" $ULIMITS_CONF_PATH
    sed -i -r "/^\*(.*)soft(.*)nproc(.*)/d" $ULIMITS_CONF_PATH
    sed -i -r "/^\*(.*)hard(.*)nproc(.*)/d" $ULIMITS_CONF_PATH
    sed -i -r "/^\*(.*)soft(.*)memlock(.*)/d" $ULIMITS_CONF_PATH
    sed -i -r "/^\*(.*)hard(.*)memlock(.*)/d" $ULIMITS_CONF_PATH

    echo "* soft nofile 655360" >> $ULIMITS_CONF_PATH
    echo "* hard nofile 131072" >> $ULIMITS_CONF_PATH
    echo "* soft nproc 655360" >> $ULIMITS_CONF_PATH
    echo "* hard nproc 655360" >> $ULIMITS_CONF_PATH
    echo "* soft memlock unlimited" >> $ULIMITS_CONF_PATH
    echo "* hard memlock unlimited" >> $ULIMITS_CONF_PATH
}


function main {
    1_upgrade_system
    2_install_necessary_package
    3_disable_firewald_and_selinux
    4_set_timezone_and_ntp_client
    5_configure_sshd
    6_configure_ulimit
}
