# openstack-helm-playground
**安裝Openstack的元件(前置作業)**
---

**首先 我們要確定節點可以安裝哪些服務 預設就全部節點都裝**
```bash=
kubectl label --overwrite nodes --all openstack-control-plane=enabled
kubectl label --overwrite nodes --all openstack-compute-node=enabled
kubectl label --overwrite nodes --all openvswitch=enabled
kubectl label --overwrite nodes --all linuxbridge=enabled
```

**確定好後可以開始安裝設定openstack的資訊**

```bash=
export OPENSTACK_RELEASE=2024.1
# Features enabled for the deployment. This is used to look up values overrides.
export FEATURES="${OPENSTACK_RELEASE} ubuntu_jammy"
# Directory where values overrides are looked up or downloaded to.
export OVERRIDES_DIR=$(pwd)/overrides
INFRA_OVERRIDES_URL=https://opendev.org/openstack/openstack-helm-infra/raw/branch/master
for chart in rabbitmq mariadb memcached openvswitch libvirt; do
    helm osh get-values-overrides -d -u ${INFRA_OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done

OVERRIDES_URL=https://opendev.org/openstack/openstack-helm/raw/branch/master
for chart in keystone heat glance cinder placement nova neutron horizon; do
    helm osh get-values-overrides -d -u ${OVERRIDES_URL} -p ${OVERRIDES_DIR} -c ${chart} ${FEATURES}
done

git clone https://github.com/openstack/openstack-helm
```
**這樣應該可以看到osh的目錄底下有overrides的資料夾跟openstack_infra與openstack_helm的資料夾**
**我們先將helm chart的資訊都安裝上去(不裝的話可能會噴錯)**

```bash=
cd ~/osh/openstack-helm-infra/ceph-adapter-rook
helm dependency build 
cd ~/osh/openstack-helm-infra/rabbitmq
helm dependency build 
cd ~/osh/openstack-helm-infra/mariadb
helm dependency build
cd ~/osh/openstack-helm-infra/memcached
helm dependency build
cd ~/osh/openstack-helm/keystone
helm dependency build
cd ~/osh/openstack-helm/heat
helm dependency build
cd ~/osh/openstack-helm/glance
helm dependency build
cd ~/osh/openstack-helm/cinder
helm dependency build
cd ~/osh/openstack-helm-infra/openvswitch
helm dependency build
cd ~/osh/openstack-helm-infra/libvirt
helm dependency build
cd ~/osh/openstack-helm/placement
helm dependency build
cd ~/osh/openstack-helm/nova
helm dependency build
cd ~/osh/openstack-helm/neutron
helm dependency build
cd ~/osh/openstack-helm/horizon
helm dependency build
```


**安裝Openstack的元件**
---

### **1. rabbitmq**

```bash=
helm upgrade --install rabbitmq openstack-helm-infra/rabbitmq \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    --timeout=600s \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c rabbitmq ${FEATURES})
    helm osh wait-for-pods openstack
```
<!-- **如果有發生PV沒有建立的情況，我們幫他建立起來**
```yaml=
apiVersion: v1
kind: PersistentVolume
metadata:
  name: rabbitmq-pv
  namespace: openstack
  labels:
    type: local
spec:
  storageClassName: general
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/rabbitmq"
``` -->
### 2. **MariaDB**

```bash=
    helm upgrade --install mariadb openstack-helm-infra/mariadb \
--namespace=openstack \
--set pod.replicas.server=1 \
$(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c mariadb ${FEATURES})
helm osh wait-for-pods openstack
```
<!-- **如果有發生PV沒有建立的情況，我們幫他建立起來**
```yaml=
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mariadb-pv
  namespace: openstack
  labels:
    type: local
spec:
  storageClassName: general
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/mariadb"
``` -->

### 3. Memcached
```bash=
helm upgrade --install memcached openstack-helm-infra/memcached \
--namespace=openstack \
$(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c memcached ${FEATURES})

helm osh wait-for-pods openstack
```

### 4. Keystone
```bash=
helm upgrade --install keystone openstack-helm/keystone \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c keystone ${FEATURES})

helm osh wait-for-pods openstack
```
### 5. Heat

```bash=
helm upgrade --install heat openstack-helm/heat \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c heat ${FEATURES})

helm osh wait-for-pods openstack
```
### 6. glance

```bash=
tee ${OVERRIDES_DIR}/glance/values_overrides/glance_pvc_storage.yaml <<EOF
storage: pvc
volume:
  class_name: general
  size: 10Gi
EOF

helm upgrade --install glance openstack-helm/glance \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c glance glance_pvc_storage ${FEATURES})

helm osh wait-for-pods openstack
```
<!-- **如果PV沒有建起來我們幫他建就好**
```yaml=
apiVersion: v1
kind: PersistentVolume
metadata:
  name: glance-pv
  namespace: openstack
  labels:
    type: local
spec:
  storageClassName: general
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/glance"
``` -->



### 7. Cinder
```bash=
helm upgrade --install cinder openstack-helm/cinder \
    --namespace=openstack \
    --timeout=600s \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c cinder ${FEATURES})

helm osh wait-for-pods openstack
```

### 8. Openvswitch and Libvirt

```bash=
helm upgrade --install openvswitch openstack-helm-infra/openvswitch \
--namespace=openstack \
$(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c openvswitch ${FEATURES})

helm osh wait-for-pods openstack
helm upgrade --install libvirt openstack-helm-infra/libvirt \
    --namespace=openstack \
    --set conf.ceph.enabled=true \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c libvirt ${FEATURES})
```
>[!Note]
> ### 這邊不需等待libvirt因為libvirt會需要等neutron設定完成後才會啟動

### 9. Placement, Nova, Neutron

>[!Important]
>### 注意neutron綁定的網卡會導致無法連線，別設定k8s安裝時的網路介面 <font color="#ff0">所以懂得都懂(他需要兩個介面不然你打下去恭喜K8S掛掉)</font>
```bash=
helm upgrade --install placement openstack-helm/placement \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c placement ${FEATURES})

helm upgrade --install nova openstack-helm/nova \
    --namespace=openstack \
    --set bootstrap.wait_for_computes.enabled=true \
    --set conf.ceph.enabled=true \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c nova ${FEATURES})

PROVIDER_INTERFACE=<provider_interface_name>
tee ${OVERRIDES_DIR}/neutron/values_overrides/neutron_simple.yaml << EOF
conf:
  neutron:
    DEFAULT:
      l3_ha: False
      max_l3_agents_per_router: 1
  # <provider_interface_name> will be attached to the br-ex bridge.
  # The IP assigned to the interface will be moved to the bridge.
  auto_bridge_add:
    br-ex: ${PROVIDER_INTERFACE}
  plugins:
    ml2_conf:
      ml2_type_flat:
        flat_networks: public
    openvswitch_agent:
      ovs:
        bridge_mappings: public:br-ex
EOF

helm upgrade --install neutron openstack-helm/neutron \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c neutron neutron_simple ${FEATURES})

helm osh wait-for-pods openstack
```

### 10. Horizon

```bash=
helm upgrade --install horizon openstack-helm/horizon \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c horizon ${FEATURES})

helm osh wait-for-pods openstack
```

#### 連線方法1:
```bash=
python3 -m venv ~/openstack-client
source ~/openstack-client/bin/activate
pip install python-openstackclient
mkdir -p ~/.config/openstack
tee ~/.config/openstack/clouds.yaml << EOF
clouds:
openstack_helm:
region_name: RegionOne
identity_api_version: 3
auth:
  username: 'admin'
  password: 'password'
  project_name: 'admin'
  project_domain_name: 'default'
  user_domain_name: 'default'
  auth_url: 'http://keystone.openstack.svc.cluster.local/v3'
EOF

openstack --os-cloud openstack_helm endpoint list

#或是用docker
docker run -it --rm --network host \
-v ~/.config/openstack/clouds.yaml:/etc/openstack/clouds.yaml \
-e OS_CLOUD=openstack_helm \
docker.io/openstackhelm/openstack-client:${OPENSTACK_RELEASE} \
openstack endpoint list

```
#### 連線方法2
**給Horizon一個Nodeport讓我們可以從外部連線**
```yaml=
apiVersion: v1
kind: Service
metadata:
  labels:
    app: horizon-nodeport
  name: horizon-nodeport
  namespace: openstack
spec:
  ports:
  - name: horizon-nodeport
    port: 80
    protocol: TCP
    targetPort: 80
    nodePort: 30375
  selector:
    app.kubernetes.io/name: horizon
  type: NodePort
```
**設定好後就可以從外部連線到Horizon了**

**兩個方式都可以(但是透過方法一的要確定dns可以連到k8s的coredns才能正常連線，不然就開一個ubuntu pod進去設定)**

**設定novnc**
```yaml=
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  labels:
    app: novncproxy-nodeport
  name: novncproxy-nodeport
  namespace: openstack
spec:
  ports:
  - name: novncproxy-nodeport
    port: 80
    protocol: TCP
    targetPort: 80
    nodePort: 30376
  selector:
    app: ingress-api
  type: NodePort
status:
  loadBalancer: {}
```
