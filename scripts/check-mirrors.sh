#!/usr/bin/env bash

4xx(){ echo -e "\033[31m\033[01m$1\033[0m"; }
2xx(){ echo -e "\033[32m\033[01m$1\033[0m"; }
3xx(){ echo -e "\033[33m\033[01m$1\033[0m"; }

mirrorsList=(
    "http://mirror.nju.edu.cn"
    "http://mirrors.bupt.edu.cn"
    "http://mirrors.ustc.edu.cn"
    "http://mirrors.aliyun.com"
    "http://mirrors.cloud.tencent.com"
    "http://ftp.sjtu.edu.cn"
    "http://mirror.bjtu.edu.cn"
    "http://mirror.dlut.edu.cn"
    "http://mirrors.hit.edu.cn"
    "http://repo.huaweicloud.com"
    "http://mirrors.njupt.edu.cn"
    "http://mirrors.sohu.com"
    "http://mirrors.xjtu.edu.cn"
    "http://mirrors.skyshe.cn"
    "http://mirror.lzu.edu.cn"
    "http://mirrors.cqu.edu.cn"
    "http://mirrors.dgut.edu.cn"
    "http://mirror.nju.edu.cn"
    "http://mirrors.bfsu.edu.cn"
    "http://mirrors.tuna.tsinghua.edu.cn"
)


checkMirror() {
    echo
    echo "========== $1 =========="
    for url in "${mirrorsList[@]}"; do
        sc=$(curl -s -I "$url/$1/" | head -1 | awk '{print $2}')
        if [[ sc -ge 400 ]]; then
            4xx "$sc - $url/${1/%\/}/"
        elif [[ sc -ge 300 ]]; then
            3xx "$sc - $url/${1/%\/}/"
        elif [[ sc -ge 200 ]]; then
            2xx "$sc - $url/${1/%\/}/"
        fi
    done
}
checkMirror "debian"
checkMirror "ubuntu"
checkMirror "rocky"
checkMirror "centos"
checkMirror "almalinux"
checkMirror "vzlinux"
checkMirror "docker-ce"
