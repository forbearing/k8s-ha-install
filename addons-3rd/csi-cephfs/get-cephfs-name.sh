#!/usr/bin/env bash
ceph_mon_ip=10.250.20.11

ssh root@${ceph_mon_ip} ceph fs ls | awk '{print $2}' |awk -F ',' '{print $1}'
