#!/usr/bin/env bash

1_import_repo() {
    echo "1. [`hostname`] Import yum repo"

    if [[ $TIMEZONE == "Asia/Shanghai" || $TIMEZONE == "Asia/Chongqing" ]]; then
        source /etc/os-release
        local linuxMajorVersion=$( echo $VERSION | awk -F'[.| ]' '{print $1}' )
        local linuxMinorVersion=$(cat /etc/system-release | awk '{print $4}' | awk -F'.' '{print $2}')
        local mirror
        local defaultMirror="http://mirror.nju.edu.cn"
        local epelMirror
        local isElrepoMirror elrepoMirror
        local isDockerMirror dockerMirror

        # open source mirror in china
        case ${LINUX_SOFTWARE_MIRROR,,} in
        nju)      mirror="http://mirror.nju.edu.cn"; isElrepoMirror=1; isDockerMirror=1 ;;
        bupt)     mirror="http://mirrors.bupt.edu.cn"; isDockerMirror=1 ;;
        ustc)     mirror="http://mirrors.ustc.edu.cn"; isElrepoMirror=1; isDockerMirror=1 ;;
        aliyun)   mirror="http://mirrors.aliyun.com"; isElrepoMirror=1; isDockerMirror=1 ;;
        tencent)  mirror="http://mirrors.cloud.tencent.com"; isDockerMirror=1 ;;
        sjtu)     mirror="http://ftp.sjtu.edu.cn" ;;
        bjtu)     mirror="http://mirror.bjtu.edu.cn" ;;
        dlut)     mirror="http://mirror.dlut.edu.cn" ;;
        hit)      mirror="http://mirrors.hit.edu.cn"; isDockerMirror=1 ;;
        huawei)   mirror="http://repo.huaweicloud.com"; isDockerMirror=1 ;;
        njupt)    mirror="http://mirrors.njupt.edu.cn"; isDockerMirror=1 ;;
        sohu)     mirror="http://mirrors.sohu.com" ;;
        xjtu)     mirror="http://mirrors.xjtu.edu.cn"; isDockerMirror=1 ;;
        skyshe)   mirror="http://mirrors.skyshe.cn"; isDockerMirror=1 ;;
        lzu)      mirror="http://mirror.lzu.edu.cn"; isElrepoMirror=1 ;;
        cqu)      mirror="http://mirrors.cqu.edu.cn" ;;
        dgut)     mirror="http://mirrors.dgut.edu.cn" ;;
        tsinghua) mirror="http://mirrors.tuna.tsinghua.edu.cn"; isElrepoMirror=1; isDockerMirror=1 ;;
        bfsu)     mirror="http://mirrors.bfsu.edu.cn"; isElrepoMirror=1; isDockerMirror=1 ;;
        163)      mirror="http://mirrors.163.com" ;;
        *)        mirror=$defaultMirror ;;
        esac
        # set the default docker and elrepo repository, if not match
        epelMirror=$mirror
        elrepoMirror=$mirror
        dockerMirror=$mirror
        [ $isElrepoMirror ] || elrepoMirror=$defaultMirror
        [ $isDockerMirror ] || dockerMirror=$defaultMirror

        # replace centos repository
        # install and replace elrepo repository
        case $linuxMajorVersion in 
        7)
            # replace centos repository
            sed -r -e "s|^mirrorlist=|#mirrorlist=|g" \
                -e "s|^#baseurl=http|baseurl=http|g" \
                -e "s|baseurl=(.*)releasever|baseurl=$mirror/centos/\$releasever|g" \
                -i.$(date +%Y%m%d%H%M) \
                /etc/yum.repos.d/CentOS*.repo 
            # install and replace elrepo repository
            yum localinstall -y /tmp/pkgs/elrepo-release-7.el7.elrepo.noarch.rpm
            sed -r -e "s|^mirrorlist=|#mirrorlist=|g" \
                -e "s|baseurl=(.*)elrepo(.*)el7(.*)|baseurl=$elrepoMirror/elrepo/elrepo\2el7/\$basearch/|g" \
                -e "s|baseurl=(.*)testing(.*)el7(.*)|baseurl=$elrepoMirror/elrepo/testing\2el7/\$basearch/|g" \
                -e "s|baseurl=(.*)kernel(.*)el7(.*)|baseurl=$elrepoMirror/elrepo/kernel\2el7/\$basearch/|g" \
                -e "s|baseurl=(.*)extras(.*)el7(.*)|baseurl=$elrepoMirror/elrepo/extras\2el7/\$basearch/|g" \
                -e "s|gpgcheck=1|gpgcheck=0|g" \
                -e "/coreix/d" \
                -e "/rackspace/d" \
                -e "/fnal/d" \
                -i.$(date +%Y%m%d%H%M) \
                /etc/yum.repos.d/elrepo.repo
            ;;
        8)
            # replace centos repository
            sed -r -e "s|^mirrorlist=|#mirrorlist=|g" \
                -e "s|^#baseurl=http|baseurl=http|g" \
                -e "s|baseurl=(.*)releasever|baseurl=$mirror/centos/\$releasever|g" \
                -i.$(date +%Y%m%d%H%M) \
                /etc/yum.repos.d/CentOS*.repo
            # install and replace elrepo repository
            yum localinstall -y /tmp/pkgs/elrepo-release-8.el8.elrepo.noarch.rpm
            sed -r -e "s|^mirrorlist=|#mirrorlist=|g" \
                -e "s|baseurl=(.*)elrepo(.*)el8(.*)|baseurl=$elrepoMirror/elrepo/elrepo\2el8/\$basearch/|g" \
                -e "s|baseurl=(.*)testing(.*)el8(.*)|baseurl=$elrepoMirror/elrepo/testing\2el8/\$basearch/|g" \
                -e "s|baseurl=(.*)kernel(.*)el8(.*)|baseurl=$elrepoMirror/elrepo/kernel\2el8/\$basearch/|g" \
                -e "s|baseurl=(.*)extras(.*)el8(.*)|baseurl=$elrepoMirror/elrepo/extras\2el8/\$basearch/|g" \
                -e "s|gpgcheck=1|gpgcheck=0|g" \
                -e "/coreix/d" \
                -e "/rackspace/d" \
                -e "/fnal/d" \
                -i.$(date +%Y%m%d%H%M) \
                /etc/yum.repos.d/elrepo.repo
            ;;
        esac

        # install and replace epel repository
        yum install -y epel-release
        sed -r -e "s|^metalink=|#metalink=|g" \
            -e "s|^#baseurl=http|baseurl=http|g" \
            -e "s|baseurl=(.*)releasever|baseurl=$epelMirror/epel/\$releasever|g" \
            -e "s|baseurl=(.*)7|baseurl=$epelMirror/epel/7|g" \
            -i.$(date +%Y%m%d%H%M) \
            /etc/yum.repos.d/epel*.repo
        # copy and replace docker repository file
        yes | cp /tmp/yum.repos.d/docker-ce.repo /etc/yum.repos.d/
        sed -r -e "s|baseurl=(.*)releasever|baseurl=$dockerMirror/docker-ce/linux/centos/\$releasever|g" -i.$(date +%Y%m%d%H%M) /etc/yum.repos.d/docker-ce.repo

    # if TIMEZONE isn't Asia/Shanghai or Asia/Chongqing
    else
        # install elrepo-release
        case $linuxMajorVersion in
        7)
            rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
            yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm ;;
        8)
            rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
            yum install -y https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm ;;
        esac
        # install epel-release
        yum install -y epel-release
        # copy docker repository file
        yes | cp /tmp/yum.repos.d/docker-ce.repo /etc/yum.repos.d/
        #wget -O /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/centos/docker-ce.repo
        #yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    fi
}


2_install_necessary_package() {
    echo "2. [`hostname`] Install necessary package"

    yum install -y coreutils bash-completion iputils wget curl zip unzip bzip2 vim net-tools \
        git zsh fish rsync psmisc procps-ng bind-utils yum-utils device-mapper-persistent-data \
        lvm2 ntp ntpdate jq sysstat nc tree lsof virt-what audit iscsi-initiator-utils socat multitail
}


3_upgrade_system() {
    echo "3. [`hostname`] Upgrade system"

    # yum update -y --exclude="docker-ce,kernel-lt"
    yum update -y
}


4_disable_firewald_and_selinux() {
    echo "4. [`hostname`] Disable firewalld and selinux"

    systemctl disable --now firewalld
    setenforce 0
    sed -i "/^SELINUX=/d" /etc/selinux/config
    echo "SELINUX=disabled" >> /etc/selinux/config
}


5_set_timezone_and_ntp_client() {
    echo "5. [`hostname`] Set timezone and ntp"

    echo "timezone: $TIMEZONE"
    timedatectl set-timezone "$TIMEZONE"
    timedatectl set-ntp 1
    systemctl restart rsyslog
    systemctl restart crond
}


6_configure_sshd() {
    echo "6. [`hostname`] Configure ssh"
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


7_configure_ulimit() {
    echo "7. [`hostname`] Configure ulimit"
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
    1_import_repo
    2_install_necessary_package
    3_upgrade_system
    4_disable_firewald_and_selinux
    5_set_timezone_and_ntp_client
    6_configure_sshd
    7_configure_ulimit
}
