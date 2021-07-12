#!/usr/bin/env bash
#ceph_admin=10.230.20.11
ssh root@$ceph_admin ceph -s | grep "id:" | awk '{print $2}'
