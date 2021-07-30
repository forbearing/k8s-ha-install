#!/usr/bin/env bash
ceph_mon_ip=10.250.20.11
ssh root@$ceph_mon_ip ceph -s | grep "id:" | awk '{print $2}'
