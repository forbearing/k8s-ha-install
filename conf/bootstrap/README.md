## 配置 RBAC

- 允许 system:bootstrap 用户创建并且自动批准 CSR，允许 system:nodes 用户组自动更新 CSR

----

| Group                | ClusterRoles                                                 |                                    |
| -------------------- | ------------------------------------------------------------ | ---------------------------------- |
| system:bootstrappers | system:node-bootstrapper                                     | 自动创建和获取 CSR                 |
| system:bootstrappers | system:certificates.k8s.io:certificatesigningrequests:nodeclient | CSR 被 controller-manager 自动批准 |
| system:nodes         | system:certificates.k8s.io:certificatesigningrequests:selfnodeclient | 证书续期                           |

---

| Group                                   | ClusterRoles                                                 |      |
| --------------------------------------- | ------------------------------------------------------------ | ---- |
| system:bootstrappers:default-node-token | system:node-bootstrapper                                     |      |
| system:bootstrappers:default-node-token | system:certificates.k8s.io:certificatesigningrequests:nodeclient |      |
| system:nodes                            | system:certificates.k8s.io:certificatesigningrequests:selfnodeclient |      |



## 配置 bootstrap token

我们需要配置一个 bootstrap token，kubelet 使用这个低权限 token 向 apiserver 发起 CSR 请求，apiserver 批准后controller 为 kubelet 生成证书，kubelet 获取证书到本地之后，自动配置 kubeconf 文件，将证书写入 kubeconf 文件中，之后 kubelet 使用证书与 apiserver 进行通信。

#### 在 master 中创建 bootstrap token

```bash
token_id=$(openssl rand -hex 3)
token_secret=$(openssl rand -hex 8)
# 配置token有效期为一天
token_expiration=$(date -u -d '1 day' +'%FT%TZ')
kubectl -n kube-system create secret generic bootstrap-token-${token_id} \
		--type "bootstrap.kubernetes.io/token" \
		--from-literal description="tls bootstrap token" \
		--from-literal token-id=${token_id} \
		--from-literal token-secret=${token_secret} \
		--from-literal expiration=${token_expiration} \
		--from-literal usage-bootstrap-authentication=true \
		--from-literal usage-bootstrap-signing=true
```

#### 配置bootstrap-kubelet.conf文件

kubelet 启动的时候，如果没有给 kubelet 配置证书，kubelet 会去读取 bootstrap-kubelet.conf 中从信息，使用里面的token 向 apiserver 发起 CSR 请求

将下面生成的bootstrap-kubelet.conf 分发到所有节点（master和worker节点）的/etc/kubernetes目录

```bash
cat > bootstrap-kubelet.conf.j2 <<EOF
apiVersion: v1
kind: Config
preferences: {}
clusters:
- cluster:
    certificate-authority-data: /etc/kubernetes/pki/ca.crt
    server: https://127.0.0.1:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: tls-bootstrap-token-user
  name: tls-bootstrap-token-user@kubernetes
current-context: tls-bootstrap-token-user@kubernetes
users:
- name: tls-bootstrap-token-user
  user:
    token: ${token_id}.${token_secret}
EOF
```

## Kubernetes TLS bootstrapping 流程分析

https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping/

#### 初始化流程

1. kubelet启动
2. 发现本地没有kubeconfig文件
3. 寻找 bootstrap-kubeconfig 文件
4. 读取 bootstrap-kubeconfig 中的 apiserver 地址和 bootstrap token，bootstrap 的格式参考 https://kubernetes.io/docs/reference/access-authn-authz/bootstrap-tokens/
5. 使用 bootstrap token 作为凭证反问 apiserver
6. 该 token 有权限去创建和获取证书签名请求（CSR），bootstrap token 的命名具有特定的格式，可以被 apiserver 识别，username为system:bootstrap:\<token id\>  属于system:bootstrappers用户组，该用户组需要绑定system:node-bootstrapper的clusterrole，以便可以拥有创建csr的权限
7. kubelet为自己创建一个CSR，签发者（csr.Spec.SignerName）为[kubernetes.io/kube-apiserver-client-kubelet](http://kubernetes.io/kube-apiserver-client-kubelet)
8. CSR被自动或者手动approved
    1. controller-manager自动approve，需要system:bootstrappers用户组绑定
    2. system:[certificates.k8s.io](http://certificates.k8s.io/):certificatesigningrequests:nodeclient 的 clusterrole。controller-manager 的CSRApprovingController 会通过 SubjectAccessReview API 的方式来校验 csr 中的 username 和 group 是否有对应权限，同时检查签发者是否为[kubernetes.io/kube-apiserver-client-kubelet](http://kubernetes.io/kube-apiserver-client-kubelet)
    3. 通过kubectl等手动approve
9. kubelet 证书在 approved 之后由 controller-manager创建
10. controller-manager 将证书更新到 csr 的 status字段中
11. kubelet 从 apiserver 获取证书
12. kubelet 根据取回来的 key 和证书生成对应的 kubeconfig
13. kubelet 使用生成的 kubeconfig 开始正常工作
14. 如果配置了证书自动续期，则 kubelet 会在证书快过期的时候利用旧的 kubeconfig 来续约旧的证书
15. 续约的证书被自动或者手动approved签发 —— 自动approve需要system:nodes用户组绑定system:[certificates.k8s.io](http://certificates.k8s.io/):certificatesigningrequests:selfnodeclient的clusterrole（system:nodes是kubelet之前申请的证书的group，即证书的组织O为system:nodes）

#### 涉及的用户、用户组、权限

1. bootstrap token的username为system:bootstrap:\<token id\>
2. system:bootstrappers用户组，bootstrap token都属于该用户组
3. clusterrole system:node-bootstrapper，拥有创建和获取CSR的权限，system:bootstrappers用户组一般需要绑定该role
4. clusterrole system:certificates.k8s.io:certificatesigningrequests:nodeclient，属于该group的user申请的CSR可以被controller-manager自动approve，system:bootstrappers用户组一般需要绑定该role
5. system:nodes用户组，kubelet从apiserver获取的证书一般都属于该用户组，即证书的组织O为system:nodes
6. clusterrole system:certificates.k8s.io:certificatesigningrequests:selfnodeclient，属于该group的user在证书续期时可以被controller-manager自动approve，system:nodes用户组一般需要绑定该role

#### 前置依赖

1. kube-apiserver 需要指定client CA: --client-ca-file，客户端使用证书鉴权时，apiserver根据这个CA来校验客户端证书的合法性
2. kube-apiserver使用static token或者bootstrap token:
    1. 使用static token需要指定--token-auth-file文件
    2. 使用bootstrap token需要开启对应功能： --enable-bootstrap-token-auth=true
3. kube-controller-manager需要指定和kube-apiserver相同的--client-ca-file，同时需要指定--cluster-signing-cert-file和--cluster-signing-key-file用户签发kubelet证书
4. kube-controller-manager自动approve需要为system:bootstrappers用户组和system:nodes用户组绑定对应的角色：system:certificates.k8s.io:certificatesigningrequests:nodeclient，system:certificates.k8s.io:certificatesigningrequests:selfnodeclient，同时csr的签发者为kubernetes.io/kube-apiserver-client-kubelet
5. kubelet需要指定--bootstrap-kubeconfig