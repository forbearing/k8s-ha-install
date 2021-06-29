#!/usr/bin/env bash

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }

DEL_WORKER_HOSTNAME=""



while getopts "H:h" opt; do
    case "${opt}" in
        "H" )
            DEL_WORKER_HOSTNAME=${OPTARG} ;;
        "h")
            MSG1 "Usage: $(basename $0) -H [del_wroker_hostname]" && exit $EXIT_SUCCESS ;;
        *)
            ERR "Usage: $(basename $0) -H [del_worker_hostname]" && exit $EXIT_FAILURE
    esac
done
[ -z ${DEL_WORKER_HOSTNAME} ] && ERR "Usage: $(basename $0) -H [del_worker_hostname]" && exit $EXIT_FAILURE



kubectl drain ${DEL_WORKER_HOSTNAME} --force --ignore-daemonsets --delete-emptydir-data --delete-local-data
kubectl delete node ${DEL_WORKER_HOSTNAME}

