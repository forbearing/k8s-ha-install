kubectl create namespace nfs-provisioner
helm install nfs-subdir-external-provisioner ./ -n nfs-provisioner
