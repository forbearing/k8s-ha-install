#!/usr/bin/env bash

# Copyright 2021 hybfkuf
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -e

usage() {
    echo "Usage:"
    echo "    `basename $0` -v <kubernetes version> [-p <amd64|arm|arm64|ppc64le|s390x>]"
    echo ""
    echo "Examples:"
    echo "    `basename $0` -v v1.22.9          # download kubernetes v1.22.9 binary files"
    echo "    `basename $0` -v 1.23.6           # download kubernetes v1.23.6 binary files"
    echo "    `basename $0` -v 1.24.0 -p amd64  # download kubernetes v1.24.0 binary files with amd64 platform (default is amd64)"
    echo "    `basename $0` -v 1.24.0 -p s390x  # download kubernetes v1.24.0 binary files with s390x platform (default is amd64)"
    exit 0
}

while getopts "p:v:h" flag; do
    case "$flag" in 
    p) platform="$OPTARG" ;;
    v) version="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
    esac
done

parseUrl() {
    if [ -z $version ]; then
        echo "Requires a k8s version"
        echo "Try \"`basename $0` -h\" for more information."
        exit 0
    fi
    version=$(echo "$version" | sed 's/v//')
    [ $platform ] || platform="amd64"
    if [[ $platform != "amd64" && \
          $platform != "arm" && \
          $platform != "arm64" && \
          $platform != "ppc64le" && \
          $platform != "s390x" ]]; then
        echo "Not support \"$platform\" architecture."
        echo "Try \"`basename $0` -h\" for more information."
        exit 0
    fi

    # kubernetes binary files download links
    templateUrl="https://dl.k8s.io/#KUBE_VERSION#/kubernetes-server-linux-#ARCH#.tar.gz"
    downloadUrl=$(echo $templateUrl | sed -e "s|#KUBE_VERSION#|v$version|" -e "s|#ARCH#|$platform|")

}

parseVersion() {
    fullVersion=$version
    version=$( echo "$version" | awk -F'.' '{printf "%s.%s", $1,$2}')
    if [[ $version != "1.20" && \
          $version != "1.21" && \
          $version != "1.22" && \
          $version != "1.23" && \
          $version != "1.24" ]]; then
        echo "Not support download kubernetes version: \"$fullVersion\" "
        exit 0
    fi

    mkdir -p bin/k8s/v$version
}

parseFetchCmd() {
    #if command -v axel &> /dev/null; then
    #    fetchCmd="axel -n 10 -a -o"
    #    ok=1
    #fi
    [ $ok ] ||  {
        if command -v wget &> /dev/null; then
            fetchCmd="wget --show-progress -c -O"
            ok=1
        fi }
    [ $ok ] || { 
        if command -v curl &> /dev/null; then
            fetchCmd="curl -# -L -o"
            ok=1
        fi }
    if [[ ! $ok ]]; then
        echo "don't have download utils (axel, curl, wget)"
        exit 1
    fi
}

download_and_compress() {
    pkgName=$(echo "$downloadUrl" |awk -F'/' '{print $NF}')

    echo "kubernetes version:       $fullVersion"
    echo "kubernetes platform:      $platform"
    echo "kubernetes download url:  $downloadUrl"
    echo "kubernetes download cmd:  $fetchCmd /tmp/$pkgName $downloadUrl"
    echo ""

    # start download kubernetes binary files
    eval "$fetchCmd /tmp/$pkgName $downloadUrl"

    # extract binary files
    tar -xf /tmp/$pkgName \
        --strip-components=3 \
        -C bin/k8s/v$version \
        kubernetes/server/bin/kube{let,ctl,-apiserver,-controller-manager,-scheduler,-proxy}

    # compress
    cd bin/k8s/v$version
    for pkg in $(echo kube-apiserver kube-controller-manager kube-scheduler kubelet kubectl kube-proxy); do
        echo "compressing $pkg..."
        tar -Jcf $pkg.tar.xz $pkg && echo "compress $pkg finished." &
    done
    wait

    # delete origin binary files
    for pkg in $(echo kube-apiserver kube-controller-manager kube-scheduler kubelet kubectl kube-proxy); do
        rm -rf $pkg
    done
}

main() {
    parseUrl
    parseVersion
    parseFetchCmd
    download_and_compress
}
main
