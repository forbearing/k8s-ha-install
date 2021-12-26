#!/usr/bin/env bash

function stage_two {
    MSG1 "====================== Stage 2: Prepare for Kubernetes ========================";

    source /etc/os-release
    mkdir -p "${K8S_DEPLOY_LOG_PATH}/logs/stage-two"
    case ${ID} in
    centos|rhel)
        # Linux: centos/rhel
        source centos/2_prepare_for_k8s.sh
        for NODE in "${ALL_NODE[@]}"; do
            MSG2 "*** ${NODE} *** is Preparing for Kubernetes"
            ssh root@${NODE} \
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
                 &> ${K8S_DEPLOY_LOG_PATH}/logs/stage-two/${NODE}.log &
        done
        MSG2 "Please Waiting... (multitail -s 3 -f ${K8S_DEPLOY_LOG_PATH}/logs/stage-two/*.log)"
        wait
        ;;
    rocky)
        # Linux: rocky
        source rocky/2_prepare_for_k8s.sh
        for NODE in "${ALL_NODE[@]}"; do
            MSG2 "*** ${NODE} *** is Preparing for Kubernetes"
            ssh root@${NODE} \
                "$(typeset -f 1_install_necessary_package_for_k8s)
                 $(typeset -f 2_disable_swap)
                 $(typeset -f 3_upgrade_kernel)
                 $(typeset -f 4_load_kernel_module)
                 $(typeset -f 5_configure_kernel_parameter)
                 1_install_necessary_package_for_k8s
                 2_disable_swap
                 4_load_kernel_module
                 5_configure_kernel_parameter" \
                 &> ${K8S_DEPLOY_LOG_PATH}/logs/stage-two/${NODE}.log &
        done
        MSG2 "Please Waiting... (multitail -s 3 -f ${K8S_DEPLOY_LOG_PATH}/logs/stage-two/*.log)"
        wait
        ;;
    ubuntu)
        # Linux: ubuntu
        source ubuntu/2_prepare_for_k8s.sh
        for NODE in "${ALL_NODE[@]}"; do
            MSG2 "*** ${NODE} *** is Preparing for Kubernetes"
            ssh root@${NODE} \
                "$(typeset -f _apt_wait)
                 $(typeset -f 1_disable_swap)
                 $(typeset -f 2_load_kernel_module)
                 $(typeset -f 3_configure_kernel_parameter)
                 _apt_wait
                 1_disable_swap
                 2_load_kernel_module
                 3_configure_kernel_parameter" \
                 &> ${K8S_DEPLOY_LOG_PATH}/logs/stage-two/${NODE}.log &
        done
        MSG2 "Please Waiting... (multitail -s 3 -f ${K8S_DEPLOY_LOG_PATH}/logs/stage-two/*.log)"
        wait
        ;;
    debian)
        # Linux: debian
        source debian/2_prepare_for_k8s.sh
        for NODE in "${ALL_NODE[@]}"; do
            MSG2 "*** ${NODE} *** is Preparing for Kubernetes"
            ssh root@${NODE} \
                "$(typeset -f _apt_wait)
                 $(typeset -f 1_disable_swap)
                 $(typeset -f 2_load_kernel_module)
                 $(typeset -f 3_configure_kernel_parameter)
                 _apt_wait
                 1_disable_swap
                 2_load_kernel_module
                 3_configure_kernel_parameter" \
                 &> ${K8S_DEPLOY_LOG_PATH}/logs/stage-two/${NODE}.log &
        done
        MSG2 "Please Waiting... (multitail -s 3 -f ${K8S_DEPLOY_LOG_PATH}/logs/stage-two/*.log)"
        wait
        ;;
    *)
        ERR "Not Support Linux !" && exit $EXIT_FAILURE ;;
    esac
}
