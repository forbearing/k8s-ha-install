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


[[ ${K8S_VERSION} ]]    || K8S_VERSION="v1.23"
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
