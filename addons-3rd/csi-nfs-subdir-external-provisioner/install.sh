#! /usr/bin/env bash

if [[ $1 == "-u" ]]; then
    helm -n nfs-provisioner uninstall nfs-provisioner
    exit 0
fi

helm install --create-namespace -n nfs-provisioner \
    nfs-provisioner ./nfs-subdir-external-provisioner \
    --set image.repository="registry.cn-shanghai.aliyuncs.com/hybfkuf/nfs-subdir-external-provisioner" \
    --set nfs.server="10.240.1.21" \
    --set nfs.path="/srv/nfs/kubedata" \
    --set storageClass.create=true \
    --set storageClass.provisionerName="nfs-provisioner" \
    --set storageClass.name="nfs-sc" \
    --set storageClass.defaultClass=false \
    --set storageClass.allowVolumeExpansion=true \
    --set storageClass.reclaimPolicy=Delete
