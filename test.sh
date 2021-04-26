#!/usr/bin/env bash

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
WARN(){ echo -e "\033[33m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\033[32m\033[01m$1\033[0m"; }
MSG2(){ echo -e "\033[34m\033[01m$1\033[0m"; }

MASTER_HOST=(master1
             master2
             master3)
MASTER_IP=(10.230.11.11
           10.230.11.12
           10.230.11.13)
WORKER_HOST=(worker1
             worker2
             worker3)
WORKER_IP=(10.230.11.21
           10.230.11.22
           10.230.11.23)
MASTER=(${MASTER_HOST[@]})
WORKER=(${WORKER_HOST[@]})
ALL_NODE=(${MASTER[@]} ${WORKER[@]})



ssh 10.230.11.21 "bash -s" < 1_prepare_for_server.sh
