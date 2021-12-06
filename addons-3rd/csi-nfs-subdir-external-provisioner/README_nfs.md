## 我修改过的地方

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app: nfs-subdir-external-provisioner
      topologyKey: kubernetes.io/hostname
```

