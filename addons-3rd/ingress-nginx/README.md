## 修改地方

```yaml
hostNetwork: true										# default false
hostPort:
	enabled: true											# default false
dnsPolicy: ClusterFirstWithHostNet	# default ClusterFirst
kind: DaemonSet											# default Deployment
nodeSelector:
	kubernetes.io/os: linux
  ingress-nginx: enabled
```

