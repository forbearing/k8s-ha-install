#!/usr/bin/env bash

K8S_IP=(
    10.240.1.11 \
    10.240.1.12 \
    10.240.1.13 \
    10.240.1.21 \
    10.240.1.22 \
    10.240.1.23
    )


for IP in ${K8S_IP[@]}; do
    scp ceph-images.tar.gz root@$IP:/tmp/
    ssh root@$IP tar xvf /tmp/ceph-images.tar.gz -C /tmp/
    ssh root@${IP} 'for i in /tmp/docker-images/*; do docker load -i $i; done'
done
