#!/usr/bin/env bash

CEPH_MON_IP=(                           # all ceph monitor node ip
    10.240.1.11
    10.240.1.12
    10.240.1.13)
CEPH_ROOT_PASS="toor"                       # ceph node root passwd
CEPH_CLUSTER_ID=""                          # ceph cluster id
CEPH_RBD_POOL="k8s-rbd"                     # ceph rbd pool name, if not exist, create it
CEPH_FS_POOL="k8s-fs"                       # ceph fs pool name, if not exist, create it
CEPH_USER="admin"
CEPH_USER_KEY=""                            # ceph client user key

CEPH_NAMESPACE="ceph"                       # which namespace is ceph deployed to
CEPH_RBD_SC="ceph-rbd"                      # ceph rbd volume snapshot StorageClass name
CEPH_RBD_SC_SNAPSHOT="ceph-rbd-snapshot"
CEPH_FS_SC="ceph-fs"                        # ceph fs StorageClass name
CEPH_FS_SC_SNAPSHOT="ceph-fs-snapshot"      # ceph fs volume snapshot StorageClass name 



function 1_ssh_authentication {
     Setup SSH Public Key Authentication
    for NODE in "${CEPH_MON_IP[@]}"; do
        ssh-keyscan ${NODE} >> /root/.ssh/know_hosts 2> /dev/null;
    done
    for NODE in "${CEPH_MON_IP[@]}"; do
        sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${NODE}"
        sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${NODE}"
        sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${NODE}"
        #sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_xmss.pub root@"${NODE}"
    done
}



function 2_create_k8s_pool {
    #  create ceph pool
    ssh root@${CEPH_MON_IP[0]} "
        ceph osd pool create ${CEPH_RBD_POOL} 64 64
        ceph osd pool application enable ${CEPH_RBD_POOL} rbd
        ceph osd pool create ${CEPH_FS_POOL}_metadata 8 8
        ceph osd pool create ${CEPH_FS_POOL}_data 64 64
        ceph fs new ${CEPH_FS_POOL} ${CEPH_FS_POOL}_metadata ${CEPH_FS_POOL}_data
        ceph osd lspools"

    # get ceph cluster id
    CEPH_CLUSTER_ID=$(ssh root@${CEPH_MON_IP[0]} "ceph -s" | grep 'id:' | awk '{print $2}')

    # get ceph admin key
    CEPH_USER_KEY=$(ssh root@${CEPH_MON_IP[0]} "ceph auth print-key client.${CEPH_USER}")
}



function 3_generate_yaml_file {
    local sed
    if [[ $(uname) == "Darwin" ]]; then
        sed="gsed"
    elif [[ $(uname) == "Linux"  ]]; then
        sed="sed"; fi
    rm -rf /tmp/csi-ceph && cp -r ../csi-ceph /tmp/

    #####
    # replace for ceph cluster
    #####

    # 1. replace CEPH_MON_IP
    for (( i=0; i<${#CEPH_MON_IP[@]}; i++ )); do
        ${sed} -i "s/#CEPH_MON_IP_$i#/${CEPH_MON_IP[i]}/" /tmp/csi-ceph/3_csi-config-map.yaml; done
    # 2. replace CEPH_CLUSTER_ID
    for YAML_FILE in \
        /tmp/csi-ceph/3_csi-config-map.yaml \
        /tmp/csi-ceph/8_storageclass.yaml \
        /tmp/csi-ceph/9_snapshotclass.yaml; do
        ${sed} -i "s/#CEPH_CLUSTER_ID#/${CEPH_CLUSTER_ID}/" ${YAML_FILE}; done
    # 3. replace CEPH_RBD_POOL
    ${sed} -i "s/#CEPH_RBD_POOL#/${CEPH_RBD_POOL}/" /tmp/csi-ceph/8_storageclass.yaml
    # replace CEPH_USER and CEPH_USER_KEY
    ${sed} -i "s/#CEPH_USER#/${CEPH_USER}/" /tmp/csi-ceph/7_secret.yaml
    ${sed} -i "s/#CEPH_USER_KEY#/${CEPH_USER_KEY}/" /tmp/csi-ceph/7_secret.yaml

    #####
    # replace for k8s cluster
    #####

    # 1. replace CEPH_NAMESPACE
    for YAML_FILE in /tmp/csi-ceph/*.yaml; do
        ${sed} -i "s/#CEPH_NAMESPACE#/${CEPH_NAMESPACE}/" ${YAML_FILE}; done
    # 2. replace CEPH_RBD_SC
    ${sed} -i "s/#CEPH_RBD_SC#/${CEPH_RBD_SC}/" /tmp/csi-ceph/8_storageclass.yaml
    # 3. replace CEPH_RBD_SC_SNAPSHOT
    ${sed} -i "s/#CEPH_RBD_SC_SNAPSHOT#/${CEPH_RBD_SC_SNAPSHOT}/" /tmp/csi-ceph/9_snapshotclass.yaml
}

function 4_deploy_ceph_csi {
    # 1. create namesapce
    kubectl create namespace ${CEPH_NAMESPACE}
    kubectl apply -f ../external-snapshotter/1_crd/
    kubectl apply -f ../external-snapshotter/2_snapshot-controller/
    kubectl apply -f /tmp/csi-ceph/
}

1_ssh_authentication
2_create_k8s_pool
3_generate_yaml_file
4_deploy_ceph_csi
