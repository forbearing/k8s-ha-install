#!/usr/bin/env bash

EXIT_SUCCESS=0
EXIT_FAILURE=1
ERR(){ echo -e "\033[31m\033[01m$1\033[0m"; }
MSG1(){ echo -e "\n\n\033[32m\033[01m$1\033[0m\n"; }
MSG2(){ echo -e "\n\033[33m\033[01m$1\033[0m"; }


function 1_disable_swap {
    MSG2 "1. Disable swap"

    sed -i -r "/(.*)swap(.*)swap(.*)/d" /etc/fstab
    swapoff -a
}


function 2_load_kernel_module {
    MSG2 "2. Load kernel module"

    k8s_modules=(
        "ip_vs"
        "ip_vs_rr"
        "ip_vs_wrr"
        "ip_vs_lc"
        "ip_vs_wlc"
        "ip_vs_lblc"
        "ip_vs_lblcr"
        "ip_vs_sh"
        "ip_vs_dh"
        "ip_vs_fo"
        "ip_vs_nq"
        "ip_vs_sed"
        "ip_vs_ftp"
        "br_netfilter"
        "nf_conntrack"
        "nf_conntrack_ipv4"
        "nf_conntrack_ipv6"
        "ip_tables"
        "ip_set"
        "xt_set"
        "ipt_set"
        "ipt_rpfilter"
        "ipt_REJECT"
        "ipip"
    )
    printf '%s\n' "${k8s_modules[@]}" > /etc/modules-load.d/k8s.conf
    systemctl enable --now systemd-modules-load.service
}


function 3_configure_kernel_parameter {
    MSG2 "3. Configure kernel parameter"

    k8s_sysctl=(
        "net.ipv4.ip_forward = 1"
        "net.bridge.bridge-nf-call-iptables = 1"
        "net.bridge.bridge-nf-call-ip6tables = 1"
        "fs.may_detach_mounts = 1"
        "fs.inotify.max_user_instances = 81920"
        "fs.inotify.max_user_watches = 1048576"
        "fs.file-max = 52706963"
        "fs.nr_open = 52706963"
        "vm.swappiness = 0"
        "vm.overcommit_memory = 1"
        "vm.panic_on_oom = 0"
        "net.ipv4.tcp_tw_recycle = 0"
        "net.ipv6.conf.all.disable_ipv6 = 1"
        "net.netfilter.nf_conntrack_max = 2310720"
        "net.ipv4.tcp_keepalive_time = 600"
        "net.ipv4.tcp_keepalivve_probes = 3"
        "net.ipv4.tcp_keepalive_intvl = 15"
        "net.ipv4.tcp_max_tw_buckets = 36000"
        "net.tcp_tw_reuse = 1"
        "net.ipv4.tcp_max_orphans = 327680"
        "net.ipv4.tcp_orphan_retries = 3"
        "net.ipv4.tcp_syncookies = 1"
        "net.ipv4.tcp_max_syn_backlog = 16384"
        "net.ipv4.ip_conntrack_max = 65536"
        "net.ipv4.tcp.max_syn_backlog = 16384"
        "net.ipv4.tcp_timestamps = 0"
        "net.core.somaxconn = 16384"
        "net.ipv4.neigh.default.gc_thresh1 = 1024"
        "net.ipv4.neigh.default.gc_thresh2 = 2048"
        "net.ipv4.neigh.default.gc_thresh3 = 4096"
    )
    printf '%s\n' "${k8s_sysctl[@]}" > /etc/sysctl.d/98-k8s.conf
    sysctl --system
}


MSG1 "*** `hostname` *** Prepare for Kubernetes"
1_disable_swap
2_load_kernel_module
3_configure_kernel_parameter
