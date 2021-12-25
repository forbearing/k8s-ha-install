#!/usr/bin/env bash

function stage_one {
    MSG1 "=================== Stage 1: Prepare for Linux Server =========================";

    source /etc/os-release
    mkdir -p "${K8S_DEPLOY_LOG_PATH}/logs/stage-one"
    case ${ID} in
    centos|rhel)
        # Linux: centos/rhel
        source centos/1_prepare_for_server.sh
        for NODE in "${ALL_NODE[@]}"; do
            MSG2 "*** ${NODE} *** is Preparing for Linux Server"
            ssh root@${NODE} \
                "export TIMEZONE=${TIMEZONE}
                 $(typeset -f 1_import_repo)
                 $(typeset -f 2_install_necessary_package)
                 $(typeset -f 3_upgrade_system)
                 $(typeset -f 4_disable_firewald_and_selinux)
                 $(typeset -f 5_set_timezone_and_ntp_client)
                 $(typeset -f 6_configure_sshd)
                 $(typeset -f 7_configure_ulimit)
                 1_import_repo
                 2_install_necessary_package
                 3_upgrade_system
                 4_disable_firewald_and_selinux
                 5_set_timezone_and_ntp_client
                 6_configure_sshd
                 7_configure_ulimit" \
                 &> ${K8S_DEPLOY_LOG_PATH}/logs/stage-one/${NODE}.log &
        done
        MSG2 "Please Waiting... (multitail -s 3 -f ${K8S_DEPLOY_LOG_PATH}/logs/stage-one/*.log)"
        wait
        ;;
    rocky)
        # Linux: rocky
        source rocky/1_prepare_for_server.sh
        for NODE in "${ALL_NODE[@]}"; do
            MSG2 "*** ${NODE} *** is Preparing for Linux Server"
            ssh root@${NODE} \
                "export TIMEZONE=${TIMEZONE}
                 $(typeset -f 1_import_repo)
                 $(typeset -f 2_install_necessary_package)
                 $(typeset -f 3_upgrade_system)
                 $(typeset -f 4_disable_firewald_and_selinux)
                 $(typeset -f 5_set_timezone_and_ntp_client)
                 $(typeset -f 6_configure_sshd)
                 $(typeset -f 7_configure_ulimit)
                 1_import_repo
                 2_install_necessary_package
                 3_upgrade_system
                 4_disable_firewald_and_selinux
                 5_set_timezone_and_ntp_client
                 6_configure_sshd
                 7_configure_ulimit" \
                 &> ${K8S_DEPLOY_LOG_PATH}/logs/stage-one/${NODE}.log &
        done
        MSG2 "Please Waiting... (multitail -s 3 -f ${K8S_DEPLOY_LOG_PATH}/logs/stage-one/*.log)"
        wait
        ;;
    ubuntu)
        # Linux: ubuntu
        source ubuntu/1_prepare_for_server.sh
        for NODE in "${ALL_NODE[@]}"; do
            MSG2 "*** ${NODE} *** is Preparing for Linux Server"
            ssh root@${NODE} \
                "export TIMEZONE=${TIMEZONE}
                 $(typeset -f _apt_wait)
                 $(typeset -f 1_upgrade_system)
                 $(typeset -f 2_install_necessary_package)
                 $(typeset -f 3_disable_firewald_and_selinux)
                 $(typeset -f 4_set_timezone_and_ntp_client)
                 $(typeset -f 5_configure_sshd)
                 $(typeset -f 6_configure_ulimit)
                 _apt_wait
                 1_upgrade_system
                 2_install_necessary_package
                 3_disable_firewald_and_selinux
                 4_set_timezone_and_ntp_client
                 5_configure_sshd
                 6_configure_ulimit" \
                 &> ${K8S_DEPLOY_LOG_PATH}/logs/stage-one/${NODE}.log &
        done
        MSG2 "Please Waiting... (multitail -s 3 -f ${K8S_DEPLOY_LOG_PATH}/logs/stage-one/*.log)"
        wait
        ;;
    debian)
        # Linux: debian
        :
        ;;
    *)
        ERR "Not Support Linux !" && exit $EXIT_FAILURE ;;
    esac
}
