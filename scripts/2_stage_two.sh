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

function stage_two {
    MSG1 "====================== Stage 2: Prepare for Kubernetes ========================";

    mkdir -p "$K8S_DEPLOY_LOG_PATH/logs/stage-two"
    case $linuxID in
    centos)
        # Linux: centos
        source centos/2_prepare_for_k8s.sh
        for node in "${ALL_NODE[@]}"; do
            MSG3 "*** $node *** is Preparing for Kubernetes"
            ssh root@$node \
                "$(typeset -f 1_install_necessary_package_for_k8s)
                 $(typeset -f 2_disable_swap)
                 $(typeset -f 3_upgrade_kernel)
                 $(typeset -f 4_load_kernel_module)
                 $(typeset -f 5_configure_kernel_parameter)
                 1_install_necessary_package_for_k8s
                 2_disable_swap
                 3_upgrade_kernel
                 4_load_kernel_module
                 5_configure_kernel_parameter" \
                 &>> "$K8S_DEPLOY_LOG_PATH/logs/stage-two/$node.log" &
        done
        MSG3 "please wait... (multitail -s 3 -f $K8S_DEPLOY_LOG_PATH/logs/stage-two/*.log)"
        wait
        ;;
    rocky)
        # Linux: rocky
        source rocky/2_prepare_for_k8s.sh
        for node in "${ALL_NODE[@]}"; do
            MSG3 "*** $node *** is Preparing for Kubernetes"
            ssh root@$node \
                "$(typeset -f 1_install_necessary_package_for_k8s)
                 $(typeset -f 2_disable_swap)
                 $(typeset -f 3_upgrade_kernel)
                 $(typeset -f 4_load_kernel_module)
                 $(typeset -f 5_configure_kernel_parameter)
                 1_install_necessary_package_for_k8s
                 2_disable_swap
                 4_load_kernel_module
                 5_configure_kernel_parameter" \
                 &>> "$K8S_DEPLOY_LOG_PATH/logs/stage-two/$node.log" &
        done
        MSG3 "please wait... (multitail -s 3 -f $K8S_DEPLOY_LOG_PATH/logs/stage-two/*.log)"
        wait
        ;;
    ubuntu)
        # Linux: ubuntu
        source ubuntu/2_prepare_for_k8s.sh
        for node in "${ALL_NODE[@]}"; do
            MSG3 "*** $node *** is Preparing for Kubernetes"
            ssh root@$node \
                "$(typeset -f _apt_wait)
                 $(typeset -f 1_disable_swap)
                 $(typeset -f 2_load_kernel_module)
                 $(typeset -f 3_configure_kernel_parameter)
                 _apt_wait
                 1_disable_swap
                 2_load_kernel_module
                 3_configure_kernel_parameter" \
                 &>> "$K8S_DEPLOY_LOG_PATH/logs/stage-two/$node.log" &
        done
        MSG3 "please wait... (multitail -s 3 -f $K8S_DEPLOY_LOG_PATH/logs/stage-two/*.log)"
        wait
        ;;
    debian)
        # Linux: debian
        source debian/2_prepare_for_k8s.sh
        for node in "${ALL_NODE[@]}"; do
            MSG3 "*** $node *** is Preparing for Kubernetes"
            ssh root@$node \
                "$(typeset -f _apt_wait)
                 $(typeset -f 1_disable_swap)
                 $(typeset -f 2_load_kernel_module)
                 $(typeset -f 3_configure_kernel_parameter)
                 _apt_wait
                 1_disable_swap
                 2_load_kernel_module
                 3_configure_kernel_parameter" \
                 &>> "$K8S_DEPLOY_LOG_PATH/logs/stage-two/$node.log" &
        done
        MSG3 "please wait... (multitail -s 3 -f $K8S_DEPLOY_LOG_PATH/logs/stage-two/*.log)"
        wait
        ;;
    *)
        ERR "Not Support Linux !" && exit $EXIT_FAILURE ;;
    esac
}
