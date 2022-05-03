#!/usr/bin/env bash

1_upgrade_system() {
    echo "1. [`hostname`] Upgrade system"

    source /etc/os-release
    local linuxID=$ID
    local linuxVersion=$( echo $VERSION | awk -F'[.| ]' '{print $1}' )
    local linuxCodeName=$VERSION_CODENAME
    local mirror
    local defaultMirror="http://mirror.nju.edu.cn"
    local docker_mirror
    local isDockerMirror

    if [[ $TIMEZONE == "Asia/Shanghai" || $TIMEZONE == "Asia/Chongqing" ]]; then
        # Official Archive Mirrors for Ubuntu
        # https://launchpad.net/ubuntu/+archivemirrors
        # 1. ustc 使用太多会限速甚至是连不上,先测试下 nju
        case ${LINUX_SOFTWARE_MIRROR,,} in
        nju)      mirror="http://mirror.nju.edu.cn"; isDockerMirror=1 ;;        # 南京大学, 10Gbps
        bupt)     mirror="http://mirrors.bupt.edu.cn" isDockerMirror=1 ;;       # 北京邮电大学, 10Gbps
        ustc)     mirror="http://mirrors.ustc.edu.cn"; isDockerMirror=1 ;;      # 中国科技技术大学, 10Gbps
        aliyun)   mirror="http://mirrors.aliyun.com"; isDockerMirror=1 ;;       # 阿里云, 2Gbps
        tencent)  mirror="http://mirrors.cloud.tencent.com"; isDockerMirror=1 ;; # 腾讯云, 2Gbps
        sjtu)     mirror="http://ftp.sjtu.edu.cn" ;;                            # 上海交通大学, 1Gbps
        bjtu)     mirror="http://mirror.bjtu.edu.cn" ;;                         # 北京交通大学, 1Gbps
        dlut)     mirror="http://mirror.dlut.edu.cn" ;;                         # 大连理工大学, 1Gbps
        hit)      mirror="http://mirrors.hit.edu.cn"; isDockerMirror=1 ;;       # 哈尔滨工业大学, 1Gbps
        huawei)   mirror="http://repo.huaweicloud.com"; isDockerMirror=1 ;;     # 华为云, 1Gbps
        njupt)    mirror="http://mirrors.njupt.edu.cn"; isDockerMirror=1 ;;     # 南京邮电大学, 1Gbps
        sohu)     mirror="http://mirrors.sohu.com" ;;                           # 搜狐, 1Gbps
        xjtu)     mirror="http://mirrors.xjtu.edu.cn"; isDockerMirror=1 ;;      # 西安交通大学, 1Gbps
        skyshe)   mirror="http://mirrors.skyshe.cn"; isDockerMirror=1 ;;        # xTom open source software, 1Gbps
        lzu)      mirror="http://mirror.lzu.edu.cn"; ;;                         # 兰州大学, 100Mbps
        cqu)      mirror="http://mirrors.cqu.edu.cn" ;;                         # 重庆大学, 100Mbps
        dgut)     mirror="http://mirrors.dgut.edu.cn" ;;                        # 东莞理工学院, 100Mbps
        tsinghua) mirror="http://mirrors.tuna.tsinghua.edu.cn"; isDockerMirror=1 ;; # 清华大学
        bfsu)     mirror="http://mirrors.bfsu.edu.cn"; isDockerMirror=1 ;;      # 北京外国语大学
        163)      mirror="http://mirrors.163.com" ;;                            # 网易
        *)        mirror=$defaultMirror ;;
        esac
        docker_mirror=$mirror
        [ $isDockerMirror ] || docker_mirror="http://mirror.nju.edu.cn"

        # generate debian repository
        source_list=(
            "deb $mirror/$linuxID $linuxCodeName main contrib non-free"
            "deb $mirror/$linuxID $linuxCodeName-updates main contrib non-free"
            "deb $mirror/$linuxID $linuxCodeName-backports main contrib non-free"
            "deb $mirror/$linuxID-security $linuxCodeName-security main contrib non-free"
            "#deb-src $mirror/$linuxID $linuxCodeName main contrib non-free"
            "#deb-src $mirror/$linuxID $linuxCodeName-updates main contrib non-free"
            "#deb-src $mirror/$linuxID $linuxCodeName-backports main contrib non-free"
            "#deb-src $mirror/$linuxID-security $linuxCodeName-security main contrib non-free")
        yes | cp /etc/apt/sources.list /etc/apt/sources.list.$(date +%Y%m%d%H%M)
        printf "%s\n" "${source_list[@]}" > /etc/apt/sources.list

        # generate docker repository
        _apt_wait && apt-get update -y
        _apt_wait && apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common
        while true; do
            if curl -fsSL $docker_mirror/docker-ce/linux/$linuxID/gpg | gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
                break; fi
            sleep 1
        done
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $docker_mirror/docker-ce/linux/$linuxID $linuxCodeName stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null

    else
        mirror="https://download.docker.com"
        # generate docker repository
        _apt_wait && apt-get update -y
        _apt_wait && apt-get install -y apt-transport-https ca-certificates curl gnupg software-properties-common
        while true; do
            if curl -fsSL $mirror/linux/$linuxID/gpg | gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
                break; fi
            sleep 1
        done
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $mirror/linux/$linuxID $linuxCodeName stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    export DEBIAN_FRONTEND=noninteractive
    _apt_wait && apt-get update -y
    _apt_wait && apt-get -o Dpkg::Options::="--force-confold" upgrade -q -y
    _apt_wait && apt-get -o Dpkg::Options::="--force-confold" dist-upgrade -q -y
    _apt_wait && apt-get autoremove -y
    _apt_wait && apt-get autoclean -y
}


2_install_necessary_package() {
    echo "2. [`hostname`] Install necessary package"

    _apt_wait && apt-get install -y coreutils apt-file apt-transport-https software-properties-common \
        iputils-ping bash-completion wget curl zip unzip bzip2 vim net-tools \
        git zsh fish rsync psmisc procps dnsutils lvm2 jq sysstat tree \
        lsof virt-what conntrack ipset open-iscsi ipvsadm auditd socat multitail
}


3_disable_firewald_and_selinux() {
    echo "3. [`hostname`] Disable firewalld and selinux"

    :
}


4_set_timezone_and_ntp_client() {
    echo "4. [`hostname`] Set timezone and ntp"

    echo "timezone: $TIMEZONE"
    timedatectl set-timezone $TIMEZONE

    timedatectl set-ntp true
    systemctl restart rsyslog
    systemctl restart cron
}


5_configure_sshd() {
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


6_configure_ulimit() {
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



main() {
    1_upgrade_system
    2_install_necessary_package
    3_disable_firewald_and_selinux
    4_set_timezone_and_ntp_client
    5_configure_sshd
    6_configure_ulimit
}
