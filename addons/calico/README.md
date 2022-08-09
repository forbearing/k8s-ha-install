### ref:

- [install calico in kubernetes](https://projectcalico.docs.tigera.io/getting-started/kubernetes/self-managed-onprem/)

- [install calico with etcd datastore](https://projectcalico.docs.tigera.io/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-etcd-datastore)

- [customize the manifest](https://projectcalico.docs.tigera.io/getting-started/kubernetes/installation/config-options)

- [system requirements](https://projectcalico.docs.tigera.io/getting-started/kubernetes/requirements)

- [system requirements with specific version](https://projectcalico.docs.tigera.io/archive/v3.21/getting-started/kubernetes/requirements)

    



### 如何知道你要安装的 calico 版本

- 你看下你的 kubernetes 是哪个版本, 再从 [system requirements](https://projectcalico.docs.tigera.io/getting-started/kubernetes/requirements) 确认 calico 是否匹配了你的 kubernetes 版本.

- 下载指定版本的 calico

    例如你要下载 v3.7 版本的 calico

    https://docs.projectcalico.org/v3.7/manifests/calico.yaml # 老链接,已失效

    https://projectcalico.docs.tigera.io/v3.7/manifests/calico-etcd.yaml  # 新链接, 这里个链接也有可能下载不到的情况, 比如 3.21 版本, 就是用老链接.

    ```bash
    # 3.7
    curl https://projectcalico.docs.tigera.io/v3.7/manifests/calico.yaml -o calico-v3.7.yaml
    curl https://projectcalico.docs.tigera.io/v3.7/manifests/calico-etcd.yaml -o calico-etcd-v3.7.yaml
    curl https://projectcalico.docs.tigera.io/v3.7/manifests/calico-typha.yaml -o calico-typha-v3.7.yaml
    
    # 3.19
    curl https://docs.projectcalico.org/v3.19/manifests/calico.yaml -o calico-v3.19.yaml
    curl https://docs.projectcalico.org/v3.19/manifests/calico-etcd.yaml -o calico-etcd-v3.19.yaml
    curl https://docs.projectcalico.org/v3.19/manifests/calico-typha.yaml -o calico-typha-v3.19.yaml
    # 3.20
    curl https://docs.projectcalico.org/v3.20/manifests/calico.yaml -o calico-v3.20.yaml
    curl https://docs.projectcalico.org/v3.20/manifests/calico-etcd.yaml -o calico-etcd-v3.20.yaml
    curl https://docs.projectcalico.org/v3.20/manifests/calico-typha.yaml -o calico-typha-v3.20.yaml
    # 3.21
    curl https://docs.projectcalico.org/v3.21/manifests/calico.yaml -o calico-v3.21.yaml
    curl https://docs.projectcalico.org/v3.21/manifests/calico-etcd.yaml -o calico-etcd-v3.21.yaml
    curl https://docs.projectcalico.org/v3.21/manifests/calico-typha.yaml -o calico-typha-v3.21.yaml
    # 3.22
    curl https://projectcalico.docs.tigera.io/v3.22/manifests/calico.yaml -o calico-v3.22.yaml
    curl https://projectcalico.docs.tigera.io/v3.22/manifests/calico.yaml
    curl https://projectcalico.docs.tigera.io/v3.22/manifests/calico-etcd.yaml -o calico-etcd-v3.22.yaml
    curl https://projectcalico.docs.tigera.io/v3.22/manifests/calico-typha.yaml -o calico-typha-v3.22.yaml
    # latest
    curl https://projectcalico.docs.tigera.io/manifests/calico.yaml -o calico-latest.yaml
    curl https://projectcalico.docs.tigera.io/manifests/calico-etcd.yaml -o calico-etcd-latest.yaml
    curl https://projectcalico.docs.tigera.io/manifests/calico-typha.yaml -o calico-typha-latest.yaml
    ```
    
     





