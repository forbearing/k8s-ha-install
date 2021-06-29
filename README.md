# 1. 介绍

二进制部署 k8s

支持 Centos7、Ubuntu18、Ubuntu20、Debian10（ubuntu20 和 Debian 10 还没测试）



# 2. 使用

## 2.1 安装

bash setup_install-k8s.sh -e k8s-vm.env

## 2.2 你需要修改的地方

### 这是环境变量

\# k8s node hostname and ip
MASTER_HOST=(
    master1
    master2
    master3)
WORKER_HOST=(
    worker1
    worker2
    worker3)
EXTRA_MASTER_HOST=(
    master4
    master5
    master6)
MASTER_IP=(
    10.250.13.11
    10.250.13.12
    10.250.13.13)
WORKER_IP=(
    10.250.13.21
    10.250.13.22
    10.250.13.23)
EXTRA_MASTER_IP=(
    10.250.13.14
    10.250.13.15
    10.250.13.16)
MASTER=("${MASTER_HOST[@]}")
WORKER=("${WORKER_HOST[@]}")
ALL_NODE=("${MASTER[@]}" "${WORKER[@]}")
CONTROL_PLANE_ENDPOINT="10.250.13.10:8443"

\# k8s service nework cidr
\# k8s pod network cidr
\# SRV_NETWORK_IP: kubernetes.default.svc.cluster.local address (usually service netweork first ip)
\# SRV_NETWORK_DNS_IP: kube-dns.kube-system.svc.cluster.local address (coredns)
SRV_NETWORK_CIDR="172.18.0.0/16"
SRV_NETWORK_IP="172.18.0.1"
SRV_NETWORK_DNS_IP="172.18.0.10"</br>
POD_NETWORK_CIDR="192.168.0.0/16"

K8S_ROOT_PASS="toor"                                            # k8s node root passwd, set here

\# kubernetes addon
INSTALL_KUBOARD=1
INSTALL_INGRESS=1Cancel changes
INSTALL_LONGHORN=1
INSTALL_METALLB=1
INSTALL_CEPHCSI=""
INSTALL_TRAEFIK=""
INSTALL_KONG=""
INSTALL_NFSCLIENT=""
INSTALL_DASHBOARD=""
INSTALL_HARBOR=""

