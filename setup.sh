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

K8S_PATH="/etc/kubernetes"                              # k8s config path
KUBE_CERT_PATH="/etc/kubernetes/pki"                    # k8s cert path
ETCD_CERT_PATH="/etc/etcd/ssl"                          # etcd cert path
K8S_DEPLOY_LOG_PATH="/root/k8s-deploy-log"              # k8s install log dir path
INSTALL_MANAGER=""                                      # like apt-get yum, set by script, not set here
environment_file=""                                     # default k8s environment file is k8s.env

source scripts/function.sh                              # base function script
source scripts/0_stage_prepare.sh                       # deploy k8s cluster stage prepare script
source scripts/1_stage_one.sh                           # deploy k8s cluster stage one script
source scripts/2_stage_two.sh                           # deploy k8s cluster stage two script
source scripts/3_stage_three.sh                         # deploy k8s cluster stage three script
source scripts/4_stage_four.sh                          # deploy k8s cluster stage four script
source scripts/5_stage_five.sh                          # deploy k8s cluster stage five script
source scripts/add-k8s-node.sh                          # add k8s worker node script
source scripts/del-k8s-node.sh                          # del k8s worker node script

while getopts "e:ad:h" opt; do
    case "${opt}" in
        e) environment_file="${OPTARG}" ;;
        a) i_want_add_k8s_node="true" ;;
        d) i_want_del_k8s_node="true";
           DEL_WORKER="${OPTARG}" ;;
        h) usage; exit $EXIT_SUCCESS ;;
        *) usage; exit $EXIT_FAILURE ;;
    esac
done
[[ ${environment_file} ]] || environment_file="k8s.env"
source ${environment_file}
ALL_NODE=( ${!MASTER[@]} ${!WORKER[@]} )


[[ ${K8S_VERSION} ]]    || K8S_VERSION="v1.21"
[[ ${TIMEZONE} ]]       || TIMEZONE="Asia/Shanghai"
[[ ${K8S_PROXY_MODE} ]] || K8S_PROXY_MODE="ipvs"
[[ ${i_want_add_k8s_node} ]] && add_k8s_node && exit ${EXIT_SUCCESS}
[[ ${i_want_del_k8s_node} ]] && del_k8s_node && exit ${EXIT_SUCCESS}


check_root_and_os
print_environment

function main {
    stage_prepare
    stage_one
    stage_two
    stage_three
    stage_four
    stage_five
    MSG1 "NOT Forget Restart All Kubernetes Node !!!"
}
main
