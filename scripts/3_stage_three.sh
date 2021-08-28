#!/usr/bin/env bash

function stage_three {
    MSG1 "========================= Stage 3: Install Docker =============================";

    source /etc/os-release
    mkdir -p "${K8S_DEPLOY_LOG_PATH}/logs/stage-three"
    case ${ID} in
    centos|rhel)
        # Linux: centos/rhel
        source centos/3_install_docker.sh
        for NODE in "${ALL_NODE[@]}"; do
            MSG2 "*** ${NODE} *** is Installing Docker"
            ssh root@${NODE} \
                "$(typeset -f 1_install_docker)
                 $(typeset -f 2_configure_docker)
                 1_install_docker
                 2_configure_docker" \
                 &> ${K8S_DEPLOY_LOG_PATH}/logs/stage-three/${NODE}.log &
        done
        MSG2 "Please Waiting... (multitail -s 3 -f ${K8S_DEPLOY_LOG_PATH}/logs/stage-three/*.log)"
        wait
        ;;
    ubuntu)
        # Linux: ubuntu
        source ubuntu/3_install_docker.sh
        for NODE in "${ALL_NODE[@]}"; do
            MSG2 "*** ${NODE} *** is Installing Docker"
            ssh root@${NODE} \
                "$(typeset -f 1_install_docker)
                 $(typeset -f 2_configure_docker)
                 $(typeset -f 3_audit_for_docker)
                 1_install_docker
                 2_configure_docker
                 3_audit_for_docker" \
                 &> ${K8S_DEPLOY_LOG_PATH}/logs/stage-three/${NODE}.log &
        done
        MSG2 "Please Waiting... (multitail -s 3 -f ${K8S_DEPLOY_LOG_PATH}/logs/stage-three/*.log)"
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
