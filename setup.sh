#!/usr/bin/env bash

# to-do-list (跟你无关，你不用关注这个)
#   - 提供选项 kube-proxy mode: ipvs, iptables
#   - 所有通用脚本，例如: 检查 Linux 版本、是否为 root 用户、检查网络，都放在 script/function.sh 文件中

# 描述: 一共分为 5 个阶段
#   Stage Prepare: 准备阶段，用来配置 ssh 免密码登录和主机名
#   Stage 1: Linux 系统准备
#   Stage 2: 为部署 Kubernetes 做好环境准备
#   Stage 3: 安装 Docker/Containerd
#   Stage 4: 部署 Kubernetes Cluster
#   Stage 5: 部署 Kubernetes 必要组件和插件

# Stage 1: 系统准备
#   1. 导入所需 yum 源
#   2. 安装必要软件
#   3. 升级系统
#   4. 关闭防火墙、SELinux
#   5. 设置时区、NTP 时间同步
#   6. 设置 sshd
#   7. ulimits 参数调整
# Stage 2: k8s 准备
#   1. 安装 k8s 所需软件
#   2. 关闭 swap 分区
#   4. 升级 Kernel
#   4. 加载 K8S 所需内核模块
#   5. 调整内核参数
# Stage 3: 安装 Docker
#   1. 安装 docker 所需软件
#   1. 安装 docker-ce
#   2. 调整 docker-ce 启动参数

# 注意事项：
#   1. 支持的系统: CentOS 7, Ubuntu 18, Ubuntu 20,  Debian 10 (Debian 10 还没有测试)
#   2. 运行此命令的节点必须是 master 节点，任何一台 master 节点都行，不能是 worker 节点
#   3. 你只需要提前配置好 k8s 节点的静态IP地址，不需要配置 ssh 无密钥登录，不需要配置
#      主机名，一键安装。节点的静态IP和主机名配置在变量中。
#   4. 所有 k8s 节点必须要相同的操作系统和 Linux 发行版本，要么都为 Ubuntu 要么都为 CentOS
#   5. EXTRA_MASTER_HOST 和 EXTRA_MASTER_IP 数组用来扩展 etcd 节点和 k8s master 节点
#      etcd 节点默认部署在 k8s master 节点上。
# 说明:
#   1. 安装 k8s 五个阶段的脚本都存放在 scripts 目录下，分别对应
#      scripts/0_stage_prepare.sh
#      scripts/1_stage_one.sh
#      scripts/2_stage_two.sh
#      scripts/3_stage_three.sh
#      scripts/4_stage_four.sh
#      scripts/5_stage_five.sh

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }

# k8s and etcd path
K8S_PATH="/etc/kubernetes"
KUBE_CERT_PATH="/etc/kubernetes/pki"
ETCD_CERT_PATH="/etc/etcd/ssl"
PKG_PATH="bin"
INSTALL_MANAGER=""                                              # like apt-get, yum etc, not set here

environment_file=""
while getopts "e:h" opt; do
    case "${opt}" in
        e) environment_file="${OPTARG}" ;;
        h) MSG1 "$(basename $0) -e environment_file" && exit $EXIT_SUCCESS ;;
        *) ERR "$(basename $0) -e environment_file" && exit $EXIT_FAILURE
    esac
done
#[ -z $environment_file ] && ERR "$(basename $0) -e environment_file" && exit $EXIT_FAILURE
[ -z $environment_file ] && environment_file="k8s.env"
source "$environment_file"


function print_environment {
    MSG1 "=================================== Environment ==================================="
    echo "MASTER_HOST:              ${MASTER_HOST[*]}"
    echo "WORKER_HOST:              ${WORKER_HOST[*]}"
    echo "EXTRA_MASTER_HOST:        ${EXTRA_MASTER_HOST[*]}"
    echo "MASTER_IP:                ${MASTER_IP[*]}"
    echo "WORKER_IP:                ${WORKER_IP[*]}"
    echo "EXTRA_MASTER_IP:          ${EXTRA_MASTER_IP[*]}"
    echo "CONTROL_PLANE_ENDPOINT:   ${CONTROL_PLANE_ENDPOINT}"
    echo "ALL_NODE:                 ${ALL_NODE[*]}"
    echo "SRV_NETWORK_CIDR:         ${SRV_NETWORK_CIDR[*]}"
    echo "SRV_NETWORK_IP:           ${SRV_NETWORK_IP}"
    echo "SRV_NETWORK_DNS_IP:       ${SRV_NETWORK_DNS_IP[*]}"
    echo "POD_NETWORK_CIDR:         ${POD_NETWORK_CIDR[*]}"
    #echo "ROOT_PASS:                ${K8S_ROOT_PASS}"
    echo "K8S_PATH                  ${K8S_PATH}"
    echo "KUBE_CERT_PATH:           ${KUBE_CERT_PATH}"
    echo "ETCD_CERT_PATH:           ${ETCD_CERT_PATH}"
    MSG1 "=================================== Environment ==================================="
}
function check_root_and_os() {
    # 检测是否为支持的 Linux 版本，否则退出脚本
    # 检测是否为 root 用户，否则推出脚本
    [[ "$(uname)" != "Linux" ]] && ERR "Not Support OS !" && exit $EXIT_FAILURE
    [[ $(id -u) -ne 0 ]] && ERR "Not ROOT !" && exit $EXIT_FAILURE
    source /etc/os-release
    if [[ "$ID" == "centos" || "$ID" == "rhel" ]]; then
        INSTALL_MANAGER="yum"
    elif [[ "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
        INSTALL_MANAGER="apt-get"
    else
        ERR "Not Support Linux !"
        EXIT $EXIT_FAILURE
    fi
    # 检查网络是否可用，否则退出脚本
    if ! timeout 2 ping -c 2 -i 1 114.114.114.114 &> /dev/null; then ERR "no network" && exit $EXIT_FAILURE; fi
}


print_environment
check_root_and_os
source scripts/0_stage_prepare.sh
source scripts/1_stage_one.sh
source scripts/2_stage_two.sh
source scripts/3_stage_three.sh
source scripts/4_stage_four.sh
source scripts/5_stage_five.sh

MSG1 "=============  Stage Prepare: Setup SSH Public Key Authentication ============="; stage_prepare
MSG1 "=================== Stage 1: Prepare for Linux Server ========================="; stage_one
MSG1 "====================== Stage 2: Prepare for Kubernetes ========================"; stage_two
MSG1 "========================= Stage 3: Install Docker ============================="; stage_three
MSG1 "============ Stage 4: Deployment Kubernetes Cluster from Binary ==============="; stage_four
MSG1 "==================== Stage 5: Deployment Kubernetes Addon ====================="; stage_five
MSG1 "NOT Forget Restart All Kubernetes Node !!!"
