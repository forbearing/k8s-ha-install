#!/usr/bin/env bash

# Copyright 2021 hybfkuf
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

prepare_software_mirror() {
    if [[ $TIMEZONE == "Asia/Shanghai" || $TIMEZONE == "Asia/Chongqing" ]]; then
        local mirror
        local defaultMirror="http://mirror.nju.edu.cn"
        local isRockyMirror
        # Official Archive Mirrors for Ubuntu
        # https://launchpad.net/ubuntu/+archivemirrors
        # 1. ustc 使用太多会限速甚至是连不上,先测试下 nju
        case ${LINUX_SOFTWARE_MIRROR,,} in
        nju)      mirror="http://mirror.nju.edu.cn"; isRockyMirror=1 ;;     # 南京大学, 10Gbps
        bupt)     mirror="http://mirrors.bupt.edu.cn" ;;                    # 北京邮电大学, 10Gbps
        ustc)     mirror="http://mirrors.ustc.edu.cn"; isRockyMirror=1 ;;   # 中国科技技术大学, 10Gbps
        aliyun)   mirror="http://mirrors.aliyun.com" ;;                     # 阿里云, 2Gbps
        tencent)  mirror="http://mirrors.cloud.tencent.com"; isRockyMirror=1 ;; # 腾讯云, 2Gbps
        sjtu)     mirror="http://ftp.sjtu.edu.cn" ;;                        # 上海交通大学, 1Gbps
        bjtu)     mirror="http://mirror.bjtu.edu.cn" ;;                     # 北京交通大学, 1Gbps
        dlut)     mirror="http://mirror.dlut.edu.cn" ;;                     # 大连理工大学, 1Gbps
        hit)      mirror="http://mirrors.hit.edu.cn" ;;                     # 哈尔滨工业大学, 1Gbps
        huawei)   mirror="http://repo.huaweicloud.com" ;;                   # 华为云, 1Gbps
        njupt)    mirror="http://mirrors.njupt.edu.cn" ;;                   # 南京邮电大学, 1Gbps
        sohu)     mirror="http://mirrors.sohu.com" ;;                       # 搜狐, 1Gbps
        xjtu)     mirror="http://mirrors.xjtu.edu.cn"; isRockyMirror=1 ;;   # 西安交通大学, 1Gbps
        skyshe)   mirror="http://mirrors.skyshe.cn"; isRockyMirror=1 ;;     # xTom open source software, 1Gbps
        lzu)      mirror="http://mirror.lzu.edu.cn" ;;                      # 兰州大学, 100Mbps
        cqu)      mirror="http://mirrors.cqu.edu.cn" ;;                     # 重庆大学, 100Mbps
        dgut)     mirror="http://mirrors.dgut.edu.cn" ;;                    # 东莞理工学院, 100Mbps
        tsinghua) mirror="http://mirrors.tuna.tsinghua.edu.cn" ;;           # 清华大学
        bfsu)     mirror="http://mirrors.bfsu.edu.cn" ;;                    # 北京外国语大学
        163)      mirror="http://mirrors.163.com" ;;                        # 网易
        *)        mirror=$defaultMirror ;;
        esac
        [ $isRockyMirror ] || mirror="http://mirror.nju.edu.cn"

        case $linuxID in
        debian)
            source_list=(
                "deb $mirror/$linuxID ${linuxCodeName} main non-free contrib"
                "deb $mirror/$linuxID ${linuxCodeName}-updates main non-free contrib"
                "deb $mirror/$linuxID-security ${linuxCodeName}-security main non-free contrib"
                "#deb-src $mirror/$linuxID ${linuxCodeName} main non-free contrib"
                "#deb-src $mirror/$linuxID ${linuxCodeName}-updates main non-free contrib"
                "#deb-src $mirror/$linuxID-security ${linuxCodeName}-security main non-free contrib")
            yes | cp /etc/apt/sources.list /etc/apt/sources.list.$(date +%Y%m%d%H%M)
            printf "%s\n" "${source_list[@]}" > /etc/apt/sources.list
            ;;
        ubuntu)
            source_list=(
                "deb $mirror/$linuxID $linuxCodeName main restricted universe multiverse"
                "deb $mirror/$linuxID $linuxCodeName-security main restricted universe multiverse"
                "deb $mirror/$linuxID $linuxCodeName-updates main restricted universe multiverse"
                "deb $mirror/$linuxID $linuxCodeName-proposed main restricted universe multiverse"
                "deb $mirror/$linuxID $linuxCodeName-backports main restricted universe multiverse"
                "#deb-src $mirror/$linuxID $linuxCodeName main restricted universe multiverse"
                "#deb-src $mirror/$linuxID $linuxCodeName-security main restricted universe multiverse"
                "#deb-src $mirror/$linuxID $linuxCodeName-updates main restricted universe multiverse"
                "#deb-src $mirror/$linuxID $linuxCodeName-proposed main restricted universe multiverse"
                "#deb-src $mirror/$linuxID $linuxCodeName-backports main restricted universe multiverse")
            yes | cp /etc/apt/sources.list /etc/apt/sources.list.$(date +%Y%m%d%H%M)
            printf "%s\n" "${source_list[@]}" > /etc/apt/sources.list
            ;;
        rocky)
            [ $linuxMajorVersion == "8" ] && \
                sed -r -e "s|^mirrorlist=|#mirrorlist=|g" \
                    -e "s|^#baseurl=http|baseurl=http|g" \
                    -e "s|baseurl=(.*)releasever|baseurl=$mirror/rocky/\$releasever|g" \
                    -i.$(date +%Y%m%d%H%M) \
                    /etc/yum.repos.d/Rocky*.repo 
            ;;
        centos)
            sed -r -e "s|^mirrorlist=|#mirrorlist=|g" \
                -e "s|^#baseurl=http|baseurl=http|g" \
                -e "s|baseurl=(.*)releasever|baseurl=$mirror/centos/\$releasever|g" \
                -i.$(date +%Y%m%d%H%M) \
                /etc/yum.repos.d/CentOS-*.repo
            ;;
        esac
    fi
}
_stage_prepare() {
    # 将 k8s 节点的主机名与 IP 对应关系写入 /etc/hosts 文件
    for HOST in "${!MASTER[@]}"; do
        local IP=${MASTER[$HOST]}
        sed -r -i "/(.*)$IP(.*)$HOST(.*)/d" /etc/hosts
        echo "$IP $HOST" >> /etc/hosts; done
    for HOST in "${!WORKER[@]}"; do
        local IP=${WORKER[$HOST]}
        sed -r -i "/(.*)$IP(.*)$HOST(.*)/d" /etc/hosts
        echo "$IP $HOST" >> /etc/hosts; done


    # 安装 sshpass ssh-keyscan multitail
    case $linuxID in 
    debian|ubuntu)
        _apt_wait && \
            apt-get update -y && \
            apt-get install -y sshpass multitail ;;
    rocky)
        yum localinstall -y rocky/pkgs/multitail-6.5.0-1.el${linuxMajorVersion}.x86_64.rpm
        yum localinstall -y rocky/pkgs/sshpass-1.06-9.el${linuxMajorVersion}.x86_64.rpm ;;
    centos)
        yum localinstall -y centos/pkgs/multitail-6.5.0-1.el$linuxMajorVersion.x86_64.rpm
        yum install -y sshpass ;;
    *)
        ERR "Not Support Linux $linuxID!"
        exit $EXIT_FAILURE
    esac
    # 生成 ssh 密钥对
    [[ ! -d $K8S_PATH ]] && rm -rf "$K8S_PATH"; mkdir -p "$K8S_PATH"
    [[ ! -d $KUBE_CERT_PATH ]] && rm -rf "$KUBE_CERT_PATH"; mkdir -p "$KUBE_CERT_PATH"
    [[ ! -d $ETCD_CERT_PATH ]] && rm -rf "$ETCD_CERT_PATH"; mkdir -p "$ETCD_CERT_PATH"
    if [[ ! -d "/root/.ssh" ]]; then rm -rf /root/.ssh; mkdir /root/.ssh; chmod 0700 /root/.ssh; fi
    if [[ ! -s "/root/.ssh/id_rsa" ]]; then ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa; fi 
    if [[ ! -s "/root/.ssh/id_ecdsa" ]]; then ssh-keygen -t ecdsa -N '' -f /root/.ssh/id_ecdsa; fi
    if [[ ! -s "/root/.ssh/id_ed25519" ]]; then ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519; fi
    #if [[ ! -s "/root/.ssh/id_xmss" ]]; then ssh-keygen -t xmss -N '' -f /root/.ssh/id_xmss; fi


    # 收集 master 节点和 worker 节点的主机指纹
    # 在当前 master 节点上配置好 ssh 公钥认证
    for node in "${ALL_NODE[@]}"; do 
        ssh-keyscan "$node" >> /root/.ssh/known_hosts; done
    for node in "${MASTER[@]}"; do
        ssh-keyscan "$node" >> /root/.ssh/known_hosts; done
    for node in "${WORKER[@]}"; do
        ssh-keyscan "$node" >> /root/.ssh/known_hosts; done
    for node in "${ALL_NODE[@]}"; do
        sshpass -p "$K8S_ROOT_PASS" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"$node" > /dev/null
        sshpass -p "$K8S_ROOT_PASS" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"$node" > /dev/null
        sshpass -p "$K8S_ROOT_PASS" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"$node" > /dev/null ; done
        #sshpass -p "$K8S_ROOT_PASS" ssh-copy-id -f -i /root/.ssh/id_xmss.pub root@"$node"


    # 设置 hostname
    # 将 /etc/hosts 文件复制到所有节点
    for node in "${ALL_NODE[@]}"; do
        ssh $node "hostnamectl set-hostname $node"
        scp /etc/hosts $node:/etc/hosts &
    done; wait


    # 所有节点设置默认 shell 为 bash
    for node in "${ALL_NODE[@]}"; do
        chsh -s "$(which bash)" &> /dev/null
    done


    # 如果操作系统为 CentOS/Rocky，则将 yum.repos.d 复制到所有的 k8s 节点的 /tmp 目录下
    case $linuxID in
    centos)
        for node in "${ALL_NODE[@]}"; do
            scp -q -r centos/pkgs centos/yum.repos.d $node:/tmp/ &
        done
        wait; ;;
    rocky)
        for node in "${ALL_NODE[@]}"; do
            scp -q -r rocky/pkgs rocky/yum.repos.d $node:/tmp/ &
        done
        wait; ;;
    ubuntu)
        for node in "${ALL_NODE[@]}"; do
            scp -q -r ubuntu/pkgs $node:/tmp/ &
        done
        wait; ;;
    esac
}

stage_prepare(){
    MSG1 "=============  Stage Prepare: Setup SSH Public Key Authentication ============="

    prepare_software_mirror
    mkdir -p "$K8S_DEPLOY_LOG_PATH/logs/stage-prepare"
    local LOG_FILE="$K8S_DEPLOY_LOG_PATH/logs/stage-prepare/prepare.log"
    _stage_prepare 2>&1 | tee -ai "$LOG_FILE"
}
