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

source scripts/functions                        # small utils collections
source scripts/0_stage_prepare.sh               # deploy k8s cluster stage prepare script
source scripts/1_stage_one.sh                   # deploy k8s cluster stage one script
source scripts/2_stage_two.sh                   # deploy k8s cluster stage two script
source scripts/3_stage_three.sh                 # deploy k8s cluster stage three script
source scripts/4_stage_four.sh                  # deploy k8s cluster stage four script
source scripts/5_stage_five.sh                  # deploy k8s cluster stage five script
source scripts/6_stage_six.sh                   # deploy k8s cluster stage six script
source scripts/7_stage_seven.sh                 # deploy k8s cluster stage seven script
source scripts/add_k8s_node.sh                  # add k8s worker node script
source scripts/del_k8s_node.sh                  # del k8s worker node script
source scripts/upg_k8s_cluster.sh               # upgrade k8s cluster script

while getopts "e:ad:uh" opt; do
    case "$opt" in
    e) ENV_FILE="$OPTARG" ;;
    a) is_add="true" ;;
    d) is_del="true"; DEL_WORKER="$OPTARG" ;;
    u) is_upg="true" ;;
    h) usage ;;
    *) usage ;;
    esac
done

check_root_and_os
prepare_pre_environ
[ $ENV_FILE ] || ENV_FILE="k8s.env"
source $ENV_FILE
prepare_post_environ
print_environ

[ $is_add ] && add_k8s_node && exit $EXIT_SUCCESS
[ $is_del ] && del_k8s_node && exit $EXIT_SUCCESS
[ $is_upg ] && upg_k8s_cluster && exit $EXIT_SUCCESS

main() {
    stage_prepare
    stage_one
    stage_two
    stage_three
    stage_four
    stage_five
    stage_six
    stage_seven
    MSG1 "NOT Forget Restart All Kubernetes Node!!!"
}
main
