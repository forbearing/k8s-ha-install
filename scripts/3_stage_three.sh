#!/usr/bin/env bash

source /etc/os-release
case "$ID" in
    centos|rhel)
        stage_one_script_path="centos/1_prepare_for_server.sh"
        stage_two_script_path="centos/2_prepare_for_k8s.sh"
        stage_three_script_path="centos/3_install_docker.sh" ;;
    ubuntu)
        stage_one_script_path="ubuntu/1_prepare_for_server.sh"
        stage_two_script_path="ubuntu/2_prepare_for_k8s.sh"
        stage_three_script_path="ubuntu/3_install_docker.sh" ;;
    debian)
        stage_one_script_path="debian/1_prepare_for_server.sh"
        stage_two_script_path="debian/2_prepare_for_k8s.sh"
        stage_three_script_path="debian/3_install_docker.sh" ;;
    *)
        ERR "Not Support Linux !" && exit $EXIT_FAILURE ;;
esac

function stage_three {
    for NODE in "${ALL_NODE[@]}"; do
        MSG2 "*** ${NODE} *** is Installing Docker"
        ssh "${NODE}" "bash -s" < "${stage_three_script_path}" &> /dev/null &
    done
    MSG2 "Please Waiting ..."
    wait
}
