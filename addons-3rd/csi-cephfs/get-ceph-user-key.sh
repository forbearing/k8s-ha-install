#!/usr/bin/env bash
ceph_mon_ip=10.250.20.11
#ceph_user=u18-k8s
ceph_user=admin

ssh root@${ceph_mon_ip} ceph auth print-key client.${ceph_user}
