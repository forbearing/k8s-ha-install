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

function usage {
    echo -e "Options: "
    echo -e "    -e      environment file"
    echo -e "    -a      delete k8s node"
    echo -e "    -d      delete k8s node"
    echo -e "    -h      help info\n"
    echo -e "Example: "
    echo -e "    ./setup.sh                     使用默认的 k8s.env 变量文件部署 k8s 集群"
    echo -e "    ./setup.sh -a                  使用默认的 k8s.env 变量文件添加 k8s worker 节点"
    echo -e "    ./setup.sh -e k8s-t20.env      使用自定义的 k8s-t20.env 变量文件部署 k8s 集群"
    echo -e "    ./setup.sh -e k8s-t20.env -a   使用自定义的 k8s-t20.env 变量文件添加 k8s worker 节点"
    echo -e "    ./setup.sh -d worker4          删除 k8s worker 节点"
}


function usage2 {

env_des="-e          指定变量文件(非必选), 如果不指定, 默认从当前路径下的 k8s.env 文件中读取变量. (需要参数)\n"
add_des="-a          添加 k8s worker 节点, 要添加的 k8s worker 节点列表是从环境变量中读取的. (不需要参数)\n"
del_des="-d          删除 k8s worker 节点, 需要提供你想删除的 worker 节点的名字, 这个 worker 节点\n
                    名字可以从 kubectl get node 中查找到. ( 需要参数)"
    printf "%s" ${del_des}
}

function print_environment {
    MSG1 "=================================== Environment ==================================="
    MSG2 "master node"
    for host in "${!MASTER[@]}"; do
        local ip=${MASTER[$host]}
        printf "%-20s%s\n" $host $ip; done

    MSG2 "worker node"
    for host in "${!WORKER[@]}"; do
        local ip=${WORKER[$host]}
        printf "%-20s%s\n" $host $ip; done

    MSG2 "all k8s node"
    for HOST in "${ALL_NODE[@]}"; do
        echo $HOST; done

    MSG2 "extra master node"
    for host in "${!EXTRA_MASTER[@]}"; do
        local ip=${EXTRA_MASTER[$host]}
        printf "%-20s%s\n" $host $ip; done

    MSG2 "add worker node"
    for host in "${!ADD_WORKER[@]}"; do
        local ip=${ADD_WORKER[$host]}
        printf "%-20s%s\n" $host $ip; done

    MSG2 "others environment"
    echo "CONTROL_PLANE_ENDPOINT:   $CONTROL_PLANE_ENDPOINT"
    echo "SRV_NETWORK_CIDR:         $SRV_NETWORK_CIDR"
    echo "SRV_NETWORK_IP:           $SRV_NETWORK_IP"
    echo "SRV_NETWORK_DNS_IP:       $SRV_NETWORK_DNS_IP"
    echo "POD_NETWORK_CIDR:         $POD_NETWORK_CIDR"
    echo "K8S_PATH                  $K8S_PATH"
    echo "K8S_VERSION:              $K8S_VERSION"
    echo "K8S_PROXY_MODE:           $K8S_PROXY_MODE"
    echo "KUBE_CERT_PATH:           $KUBE_CERT_PATH"
    echo "ETCD_CERT_PATH:           $ETCD_CERT_PATH"
    echo "K8S_DEPLOY_LOG_PATH:      $K8S_DEPLOY_LOG_PATH"
}

function check_root_and_os() {
    # 检测是否为支持的 Linux 版本，否则退出脚本
    # 检测是否为 root 用户，否则推出脚本
    [[ "$(uname)" != "Linux" ]] && ERR "Not Support OS !" && exit $EXIT_FAILURE
    [[ $(id -u) -ne 0 ]] && ERR "Not ROOT !" && exit $EXIT_FAILURE

    case $linuxID in
    centos|rocky)
        INSTALL_MANAGER="yum" ;;
    debian|ubuntu)
        INSTALL_MANAGER="apt-get" ;;
    *)
        ERR "Not Support Linux $linuxID!"
        EXIT $EXIT_FAILURE
    esac

    # if ! command -v ping &> /dev/null; then
    #     ERR "command ping not found, skip network detect!"
    # fi
    # # 检查网络是否可用，否则退出脚本
    # if ! timeout 15 ping -c 2 8.8.8.8 &> /dev/null; then
    #     ERR "maybe no network!"
    # fi
}

# refer: https://gist.github.com/tedivm/e11ebfdc25dc1d7935a3d5640a1f1c90
function _apt_wait() {
    while true; do
        if lsof /var/lib/dpkg/lock &> /dev/null; then
            sleep 1
            continue; fi
        if lsof /var/lib/dpkg/lock-frontend &> /dev/null; then
            sleep 1
            continue; fi
        if lsof /var/lib/apt/lists/lock &> /dev/null; then
            sleep 1
            continue; fi
        if lsof /var/lib/apt/daily_lock &> /dev/null; then
            sleep 1
            continue; fi
        if lsof /var/log/unattended-upgrades/unattended-upgrades.log &> /dev/null; then
            sleep 1
            continue; fi
        #echo "lock released"
        break
    done
}

# refer: https://gist.github.com/tedivm/e11ebfdc25dc1d7935a3d5640a1f1c90
function _apt_wait2() {
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
        sleep 1
    done
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
        sleep 1
    done
    while fuser /var/lib/apt/lists/lock >/dev/null 2>&1 ; do
        sleep 1
    done
    if [ -f /var/log/unattended-upgrades/unattended-upgrades.log ]; then
        while fuser /var/log/unattended-upgrades/unattended-upgrades.log >/dev/null 2>&1 ; do
            sleep 1
        done
    fi
}

_exportOSInfo() {
    source /etc/os-release
    linuxID=$ID
    linuxMajorVersion=$( echo $VERSION | awk -F'[.| ]' '{print $1}' )
    linuxCodeName=$VERSION_CODENAME
    [ -f /etc/lsb-release ] &&  \
        linuxMinorVersion=$(cat /etc/lsb-release  | awk -F'=' '/DISTRIB_RELEASE/ {print $2}' | awk -F'.'  '{print $2}')
    [ -f /etc/system-release ] && \
        linuxMinorVersion=$(cat /etc/system-release | awk '{print $4}' | awk -F'.' '{print $2}')
    export linuxID linuxMajorVersion linuxMinorVersion linuxCodeName
}
_exportOSInfo
