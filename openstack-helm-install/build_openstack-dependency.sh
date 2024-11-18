
cd $1/openstack-helm-infra/ceph-adapter-rook
helm dependency build 
cd $1/openstack-helm-infra/rabbitmq
helm dependency build 
cd $1/openstack-helm-infra/mariadb
helm dependency build
cd $1/openstack-helm-infra/memcached
helm dependency build
cd $1/openstack-helm/keystone
helm dependency build
cd $1/openstack-helm/heat
helm dependency build
cd $1/openstack-helm/glance
helm dependency build
cd $1/openstack-helm/cinder
helm dependency build
cd $1/openstack-helm-infra/openvswitch
helm dependency build
cd $1/openstack-helm-infra/libvirt
helm dependency build
cd $1/openstack-helm/placement
helm dependency build
cd $1/openstack-helm/nova
helm dependency build
cd $1/openstack-helm/neutron
helm dependency build
cd $1/openstack-helm/horizon
helm dependency build
cd $1
