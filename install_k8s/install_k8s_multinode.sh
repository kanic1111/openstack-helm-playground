#!/bin/bash

echo "please check if 8.8.8.8 is avaliable for you"
sleep 1s
echo "if not you has to edit the openstack-helm playbook: k8s_common.yaml,coredns_resolver.yaml,openstack_metallb_endpoint.yaml"
read -p "Is system.resolved able to connect to DNS server 8.8.8.8 ? (y/n) " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
echo "setup cluster information"
read -p "enter primary ip: " primary_ip;
read -p "enter k8s control ip: " k8s_control_ip;
read -p "enter k8s worker1 ip: " k8s_worker1_ip;
read -p "enter k8s worker2 ip: " k8s_worker2_ip;
cat > ~/osh/inventory.yaml <<EOF
---
all:
  vars:
    ansible_port: 22
    ansible_user: ubuntu
    ansible_ssh_private_key_file: /home/ubuntu/.ssh/id_rsa
    ansible_ssh_extra_args: -o StrictHostKeyChecking=no
    client_ssh_user: root
    cluster_ssh_user: root
    # The user and group that will be used to run Kubectl and Helm commands.
    kubectl:
      user: ubuntu
      group: ubuntu
    # The user and group that will be used to run Docker commands.
    docker_users:
      - ubuntu
    # The MetalLB controller will be installed on the Kubernetes cluster.
    metallb_setup: true
    # Loopback devices will be created on all cluster nodes which then can be used
    # to deploy a Ceph cluster which requires block devices to be provided.
    # Please use loopback devices only for testing purposes. They are not suitable
    # for production due to performance reasons.
    loopback_setup: false
    loopback_device: /dev/loop100
    loopback_image: /var/lib/openstack-helm/ceph-loop.img
    loopback_image_size: 12G
  children:
    # The primary node where Kubectl and Helm will be installed. If it is
    # the only node then it must be a member of the groups k8s_cluster and
    # k8s_control_plane. If there are more nodes then the wireguard tunnel
    # will be established between the primary node and the k8s_control_plane node.
    primary:
      hosts:
        primary:
          ansible_host: $primary_ip # 要ssh去其他節點的host
    # The nodes where the Kubernetes components will be installed.
    k8s_cluster:
      hosts:
        node-1:
          ansible_host: $k8s_control_ip
        node-2:
          ansible_host: $k8s_worker1_ip
        node-3:
          ansible_host: $k8s_worker2_ip
    # The control plane node where the Kubernetes control plane components will be installed.
    # It must be the only node in the group k8s_control_plane.
    k8s_control_plane:
      hosts:
        node-1:
          ansible_host: $k8s_control_ip
    # These are Kubernetes worker nodes. There could be zero such nodes.
    # In this case the Openstack workloads will be deployed on the control plane node.
    k8s_nodes:
      hosts:
        node-2:
          ansible_host: $k8s_worker1_ip
        node-3:
          ansible_host: $k8s_worker2_ip
EOF

cat > ~/osh/deploy-env.yaml <<EOF
---
- hosts: all
  become: true
  gather_facts: true
  roles:
    - ensure-python
    - ensure-pip
    - clear-firewall
    - deploy-env
EOF
cd ~/osh
#ansible-playbook -i inventory.yaml deploy-env.yaml
else
echo "do nothing..."
fi
