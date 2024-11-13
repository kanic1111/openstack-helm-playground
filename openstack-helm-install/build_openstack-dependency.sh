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
cd ~/osh
