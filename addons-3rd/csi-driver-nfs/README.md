### 1. 安装 nfs driver

````bash
kubectl apply -f deploy/rbac-csi-nfs-controller.yaml
kubectl apply -f deploy/csi-nfs-driverinfo.yaml
kubectl apply -f deploy/csi-nfs-controller.yaml
kubectl apply -f deploy/csi-nfs-node.yaml
````

### 2. 安装 nfs-server

#### 方法一, 使用官方案例的 nfs-server，不推荐，重启数据就没有
```` bash
kubectl apply -f deploy/example/nfs-provisioner/nfs-server.yaml                         # install nfs server
kubectl apply -f deploy/example/nfs-provisioner/nginx-pod.yaml                          # To check if the NFS server is working
kubectl exec nginx-nfs-example -- bash -c "findmnt /var/www -o TARGET,SOURCE,FSTYPE"    # Verify if the NFS server is functional
```

#### 方法二：自己搭建 nfs server
````bash
apt-get install -y nfs-kernel-server
cat /etc/exports
# /srv/nfs/kubedata *(rw,sync,no_subtree_check,no_root_squash,no_all_squash,insecure)
apt-get install nfs-common			# 所有节点安装 nfs-common (我的系统是 ubuntu)
mkdir  /srv/nfs/kubedata
chown nobody:nogroup /src/nfs/kubedata
chmod 777 /src/nfs/kubedata
systemctl restart nfs-server
````

### 3. 部署 storageclass
````bash
kubectl apply -f deploy/example/storageclass-nfs.yaml           # 先修改 server 和 share 参数
kubectl apply -f deploy/example/pvc-nfs-csi-dynamic.yaml        # 测试 storageclass 是否部署成功
````

### 4. 卸载

```` bash
kubectl delete -f deploy/example/statefulset.yaml
kubectl delete -f deploy/example/storageclass-nfs.yaml 
kubectl delete -f deploy/rbac-csi-nfs-controller.yaml
kubectl delete -f deploy/csi-nfs-driverinfo.yaml 
kubectl delete -f deploy/csi-nfs-controller.yaml
kubectl delete -f deploy/csi-nfs-node.yaml
````

