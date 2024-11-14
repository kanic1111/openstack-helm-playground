#!/bin/bash

export OPENSTACK_RELEASE=2024.1
export FEATURES="${OPENSTACK_RELEASE} ubuntu_jammy"
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
bash ./build_openstack-dependency.sh

echo "labeling openstack node"
kubectl label --overwrite nodes --all openstack-control-plane=enabled
kubectl label --overwrite nodes --all openstack-compute-node=enabled
kubectl label --overwrite nodes --all openvswitch=enabled
kubectl label --overwrite nodes --all linuxbridge=enabled

echo "install ceph-adapter"
helm upgrade --install ceph-adapter-rook openstack-helm-infra/ceph-adapter-rook \
    --namespace=openstack
helm osh wait-for-pods openstack

echo "install rabbitmq"
helm upgrade --install rabbitmq openstack-helm-infra/rabbitmq \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    --timeout=600s \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c rabbitmq ${FEATURES})
helm osh wait-for-pods openstack
echo "install mariaDB"
helm upgrade --install mariadb openstack-helm-infra/mariadb \
    --namespace=openstack \
    --set pod.replicas.server=1 \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c mariadb ${FEATURES})
helm osh wait-for-pods openstack
echo "install Memcached"
helm upgrade --install memcached openstack-helm-infra/memcached \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c memcached ${FEATURES})
helm osh wait-for-pods openstack
echo "install keystone"
helm upgrade --install keystone openstack-helm/keystone \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c keystone ${FEATURES})
helm osh wait-for-pods openstack
echo "install heat"
helm upgrade --install heat openstack-helm/heat \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c heat ${FEATURES})
helm osh wait-for-pods openstack
echo "install glance & glance pvc"
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
echo "install cinder"
helm upgrade --install cinder openstack-helm/cinder \
    --namespace=openstack \
    --timeout=600s \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c cinder ${FEATURES})
helm osh wait-for-pods openstack
echo "install openvswitch"
helm upgrade --install openvswitch openstack-helm-infra/openvswitch \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c openvswitch ${FEATURES})
helm osh wait-for-pods openstack
echo "install libvirt" #(doesn't need to wait for running status)
helm upgrade --install libvirt openstack-helm-infra/libvirt \
    --namespace=openstack \
    --set conf.ceph.enabled=true \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c libvirt ${FEATURES})
echo "install placement"
helm upgrade --install placement openstack-helm/placement \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c placement ${FEATURES})
echo "install nova"
helm upgrade --install nova openstack-helm/nova \
    --namespace=openstack \
    --set bootstrap.wait_for_computes.enabled=true \
    --set conf.ceph.enabled=true \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c nova ${FEATURES})
echo "setup neutron-interface: ${PROVIDER_INTERFACE}"
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
echo "install neutron"
helm upgrade --install neutron openstack-helm/neutron \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c neutron neutron_simple ${FEATURES})
helm osh wait-for-pods openstack
echo "install horizon"
helm upgrade --install horizon openstack-helm/horizon \
    --namespace=openstack \
    $(helm osh get-values-overrides -p ${OVERRIDES_DIR} -c horizon ${FEATURES})
helm osh wait-for-pods openstack
read -p "deploy nodeport for horizon? (y/n) " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
tee ./horizon-nodeport.yaml << EOF
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
EOF
kubectl apply -f ./horizon-nodeport.yaml
fi
echo "installation complete"
