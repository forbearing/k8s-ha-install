#!/usr/bin/env bash
ceph_mon_ip=10.230.20.11
ceph_user=c7-k8s

ssh root@${ceph_mon_ip} ceph auth print-key client.${ceph_user}
