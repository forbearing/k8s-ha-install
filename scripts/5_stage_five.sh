#!/usr/bin/env bash

function deploy_dashboard {
    MSG2 "Deploy kubernetes dashboard"
    kubectl apply -f addons-3rd/dashboard/dashboard.yaml
    #kubectl apply -f dashboard/dashboard-user.yaml
}


function deploy_kuboard {
    MSG2 "Deploy Kuboard"
    kubectl apply -f addons-3rd/kuboard/kuboard-v2.yaml                         # v2
    #kubectl apply -f https://addons.kuboard.cn/kuboard/kuboard-v3.yaml          # v3
}


function deploy_ingress {
    MSG2 "Deploy Ingress-nginx"
    while true; do
        ALL_RUNNING_NODE=($(kubectl get node | sed -n '2,$p' | awk '{print $2}'))
        if [[ "${ALL_RUNNING_NODE[*]}" =~ NotReady ]]; then
            echo "Waiting All Node Ready ..."
            sleep 5; 
        else
            echo "All Node is Ready, Start Installing Ingress-nginx ..."
            local count=0
            for HOST in "${!WORKER[@]}"; do
                kubectl label node ${HOST} ingress-nginx="enabled" --overwrite;
                if [[ $count -eq 2 ]]; then break; fi
                (( count++ ))
            done
            helm install -n ingress-nginx --create-namespace ingress-controller addons-3rd/ingress-nginx/v1.0.4/ \
                --set controller.metrics.enabled=true \
                --set-string controller.podAnnotations."prometheus\.io/scrape"="true" \
                --set-string controller.podAnnotations."prometheus\.io/port"="10254"
                # --set controller.metrics.serviceMonitor.enabled=true \
                # --set controller.metrics.serviceMonitor.namespace=ingress-nginx \
            # helm install -n ingress-controller --create-namespace ingress-nginx addons-3rd/ingress-nginx/v1.0.4/
            # helm install -n ingress-controller --create-namespace ingress-nginx addons-3rd/ingress-nginx/v0.44.0/
            ## helm get values ingress-controller --namespace ingress-nginx
            break
        fi
    done
}


function deploy_traefik {
    MSG2 "Deploy Traefik"
    helm install --create-namespace -n traefik traefik addons-3rd/traefik/traefik
}


function deploy_cephcsi {
    MSG2 "Deploy ceph csi"

    local CEPH_MON_IP=(10.250.20.11
                       10.250.20.12
                       10.250.20.13)
    local CEPH_ROOT_PASS="toor"
    local CEPH_CLUSTER_ID=""
    local CEPH_POOL="k8s"
    local CEPH_USER="u18-k8s"
    local CEPH_USER_KEY=""
    local CEPH_NAMESPACE="ceph"
    local CEPH_STORAGECLASS="ceph-rbd"


    # Setup SSH Public Key Authentication
    for NODE in "${CEPH_MON_IP[@]}"; do 
        ssh-keyscan "${NODE}" >> /root/.ssh/known_hosts 2> /dev/null; done
    for NODE in "${CEPH_MON_IP[@]}"; do
        sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_rsa.pub root@"${NODE}"
        sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ecdsa.pub root@"${NODE}"
        sshpass -p "${CEPH_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_ed25519.pub root@"${NODE}"; done
        #sshpass -p "${K8S_ROOT_PASS}" ssh-copy-id -f -i /root/.ssh/id_xmss.pub root@"${NODE}"


    # get ceph cluster id
    CEPH_CLUSTER_ID=`ssh ${CEPH_MON_IP[0]} "ceph -s" | grep 'id:' | awk '{print $2}'`
    # create ceph pool
    ssh ${CEPH_MON_IP[0]} "ceph osd pool create ${CEPH_POOL} 128 128"
    ssh ${CEPH_MON_IP[0]} "ceph osd pool application enable ${CEPH_POOL} rbd"
    # create ceph user
    ssh ${CEPH_MON_IP[0]} "ceph auth get-or-create client.${CEPH_USER} mon 'profile rbd' osd 'profile rbd pool=${CEPH_POOL}' mgr 'allow rw'"
    CEPH_USER_KEY=`ssh ${CEPH_MON_IP[0]} "ceph auth print-key client.${CEPH_USER}"`
    # create namesapce for ceph
    kubectl create namespace ${CEPH_NAMESPACE}


    rm -rf /tmp/csi-ceph && cp -r addons-3rd/csi-ceph/v2.0.1/ /tmp/csi-ceph
    for FILE in \
        /tmp/csi-ceph/1_cm_ceph-csi-config.yaml \
        /tmp/csi-ceph/2_cm_ceph-csi-encryption-kms-config.yaml \
        /tmp/csi-ceph/3_secret_csi-rbd-secret.yaml \
        /tmp/csi-ceph/4_rbac_rbd-csi-provisioner.yaml \
        /tmp/csi-ceph/5_rbac_rbd-csi-nodeplugin.yaml \
        /tmp/csi-ceph/6_csi-rbdplugin-provisioner.yaml \
        /tmp/csi-ceph/7_csi-rbdplugin.yaml \
        /tmp/csi-ceph/8_csi-rbd-storageclass.yaml; do
        sed -i "s%#CEPH_NAMESPACE#%${CEPH_NAMESPACE}%g" ${FILE}; done
    for (( i=0; i<${#CEPH_MON_IP[@]}; i++ )); do
        sed -i "s%#CEPH_MON_IP_$i#%${CEPH_MON_IP[$i]}%g" /tmp/csi-ceph/1_cm_ceph-csi-config.yaml; done
    sed -i "s%#CEPH_CLUSTER_ID#%${CEPH_CLUSTER_ID}%g" /tmp/csi-ceph/1_cm_ceph-csi-config.yaml
    sed -i "s%#CEPH_USER#%${CEPH_USER}%g" /tmp/csi-ceph/3_secret_csi-rbd-secret.yaml
    sed -i "s%#CEPH_USER_KEY#%${CEPH_USER_KEY}%g" /tmp/csi-ceph/3_secret_csi-rbd-secret.yaml
    sed -i "s%#CEPH_CLUSTER_ID#%${CEPH_CLUSTER_ID}%g" /tmp/csi-ceph/8_csi-rbd-storageclass.yaml
    sed -i "s%#CEPH_POOL#%${CEPH_POOL}%g" /tmp/csi-ceph/8_csi-rbd-storageclass.yaml
    sed -i "s%#CEPH_STORAGECLASS#%${CEPH_STORAGECLASS}%g" /tmp/csi-ceph/8_csi-rbd-storageclass.yaml


    # deploy ceph csi for kubernetes
    kubectl apply -f /tmp/csi-ceph/
}


function deploy_longhorn {
    MSG2 "Deploy longhorn"
    # service
    service_ui_type="NodePort"
    service_ui_nodePort=30008
    service_manager_type="ClusterIP"

    # ingress
    ingress_enabled="false"
    ingress_host="longhorn.example.com"
    ingress_tls="false"

    # longhorn
    defaultDataPath="/longhorn/disk1"
    storageOverProvisioningPercentage=500
    storageMinimalAvailablePercentage=10
    defaultReplicaCount=3
    defaultLonghornStaticStorageClass="longhorn"
    replicaSoftAntiAffinity="false"
    allowVolumeCreationWithDegradedAvailability="false"
    taintToleration="node-role.kubernetes.io/master:NoSchedule;node-role.kubernetes.io/storage:NoSchedule"
    guaranteedEngineManagerCPU=1
    guaranteedReplicaManagerCPU=1
    priorityClass="longhorn-priority"
    priorityClassValue="1000000"

    kubectl create priorityclass ${priorityClass} --value=${priorityClassValue} --global-default=false --description='longhorn priority'
    helm install --create-namespace -n longhorn-system longhorn addons-3rd/longhorn/longhorn \
        --set service.ui.type=${service_ui_type} \
        --set service.ui.nodePort=${service_ui_nodePort} \
        --set service.manager.type=${service_manager_type} \
        --set ingress.enabled=${ingress_enabled} \
        --set ingress.host=${ingress_host} \
        --set ingress.tls=${ingress_tls} \
        --set defaultSettings.defaultDataPath=${defaultDataPath} \
        --set defaultSettings.storageOverProvisioningPercentage=${storageOverProvisioningPercentage} \
        --set defaultSettings.storageMinimalAvailablePercentage=${storageMinimalAvailablePercentage} \
        --set defaultSettings.defaultReplicaCount=${defaultReplicaCount} \
        --set defaultSettings.defaultLonghornStaticStorageClass=${defaultLonghornStaticStorageClass} \
        --set defaultSettings.replicaSoftAntiAffinity=${replicaSoftAntiAffinity} \
        --set defaultSettings.allowVolumeCreationWithDegradedAvailability=${allowVolumeCreationWithDegradedAvailability} \
        --set defaultSettings.taintToleration=${taintToleration} \
        --set defaultSettings.guaranteedEngineManagerCPU=${guaranteedEngineManagerCPU} \
        --set defaultSettings.guaranteedReplicaManagerCPU=${guaranteedReplicaManagerCPU} \
        --set defaultSettings.priorityClass=${priorityClass} \
        --set longhornManager.priorityClass=${priorityClass} \
        --set longhornDriver.priorityClass=${priorityClass}
}

function deploy_nfsclient {
    local NFS_SERVER="10.250.11.11"
    local NFS_STORAGE_PATH="/nfs-storage"
    local NFS_STORAGECLASS="nfs-client"
    local NFS_NAMESPACE="nfs-provisioner"

    helm install --create-namespace -n ${NFS_NAMESPACE} \
        nfs-subdir-external-provisioner addons-3rd/nfs-subdir-external-provisioner \
        --set nfs.server=${NFS_SERVER} \
        --set nfs.path=${NFS_STORAGE_PATH} \
        --set nfs.storageClass.name=${NFS_STORAGECLASS}
}

function deploy_metallb {
    MSG2 "Deploy MetalLb"
    kubectl apply -f addons-3rd/metalLB/1_namespace.yaml
    bash addons-3rd/metalLB/2_create_secret.sh 
    kubectl apply -f addons-3rd/metalLB/3_metallb.yaml
}

function deploy_kong {
    MSG2 "Deploy Kong ApiGateway"

    namespace=kong
    storageClass=rook-ceph-block

    helm install --create-namespace -n ${namespace} kong addons-3rd/kong-kong/kong \
        --set deployment.kong.daemonset=false \
        --set replicaCount=3 \
        --set env.database=postgres \
        --set nginx_worker_processes=2 \
        --set admin.enabled=true \
        --set admin.type=ClusterIP \
        --set admin.http.enabled=true \
        --set admin.tls.enabled=false \
        --set status.enabled=true \
        --set status.http.enabled=true \
        --set status.tls.enabled=flase \
        --set cluster.enabled=false \
        --set proxy.enabled=true \
        --set proxy.type=NodePort \
        --set proxy.http.enabled=true \
        --set proxy.http.nodePort=32080 \
        --set proxy.tls.enabled=true \
        --set proxy.tls.nodePort=32443 \
        --set proxy.ingress.enabled=false \
        --set ingressController.enabled=true \
        --set ingressController.installCRDs=false \
        --set ingressController.ingressClass=kong \
        --set postgresql.enabled=true \
        --set postgresql.postgresqlUsername=kong \
        --set postgresql.postgresqlPassword=kong168 \
        --set postgresql.postgresqlDatabase=kong \
        --set postgresql.service.port=5432 \
        --set postgresql.persistence.storageClass=${storageClass} \
        --set resources.limits.cpu=1000m \
        --set resources.limits.memory=1024Mi \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=128Mi 
        #--set autoscaling.enabled=false \
        #--set autoscaling.minReplicas=1 \
        #--set autoscaling.maxReplicas=3 \
        #--set enterprise.enabled=false \
        #--set manager.enabled=true \
        #--set manager.type=NodePort \
        #--set manager.http.enabled=true \
        #--set manager.tls.enabled=true \
        #--set manager.ingress.enabled=false \
        #--set portal.enabled=true \
        #--set portal.type=NodePort \
        #--set portal.http.enabled=true \
        #--set portal.tls.enabled=true \
        #--set portalapi.enabled=true \
        #--set portalapi.type=NodePort \
        #--set portalapi.http.enabled=true \
        #--set portalapi.tls.enabled=true \
        #--set clustertelemetry.enabled=false
}

function deploy_harbor { :; }


function stage_five {
    MSG1 "==================== Stage 5: Deployment Kubernetes Addon =====================";
    [ ${INSTALL_KUBOARD} ]   && deploy_kuboard
    [ ${INSTALL_INGRESS} ]   && deploy_ingress
    [ ${INSTALL_TRAEFIK} ]   && deploy_traefik
    [ ${INSTALL_CEPHCSI} ]   && deploy_cephcsi
    [ ${INSTALL_LONGHORN} ]  && deploy_longhorn
    [ ${INSTALL_METALLB} ]   && deploy_metallb
    [ ${INSTALL_DASHBOARD} ] && deploy_dashboard
    [ ${INSTALL_HARBOR} ]    && deploy_harbor
    [ ${INSTALL_KONG} ]      && deploy_kong
    [ ${INSTALL_NFSCLIENT} ] && deploy_nfsclient
}
