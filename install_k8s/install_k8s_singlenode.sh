#!/bin/bash

DIR=~/osh;
current_user=$USER
KEY=/home/ubuntu/.ssh/id_rsa

Help()
{
   # Display Help
   echo "Install K8s & Helm using Openstack-helm Playbook."
   echo
   echo "Example: ./install_k8s_singlenode.sh --dir folder --ssh-key keyfile "
   echo "options:                                   description: "
   echo "-D | --dir (directory)                     directory where Ansible-playbook stored(default: ~/osh) "
   echo "-U | --user (user)                         User to install kubernetes "
   echo "-K | --ssh-key (private-key)               ssh private key file (default: /home/ubuntu/.ssh/id_rsa)"
   echo
}


if [[ "$1" =~ ^((-{1,2})([Hh]$|[Hh][Ee][Ll][Pp])|)$ ]]; then
    DIR=~/osh;
    current_user=$USER
    KEY=/home/ubuntu/.ssh/id_rsa
    #exit 1
  else
    while [[ $# -gt 0 ]]; do
      opt="$1"
      shift;
      current_arg="$1"
     if [[ "$current_arg" =~ ^-{1,2}.* ]]; then
        echo "WARNING: You may have left an argument blank. Double check your command."
        Help
        exit 0
     fi
      case "$opt" in
        "-D"|"--dir"      ) DIR="$1"; shift;;
        "-U"|"--user"      ) current_user="$1"; shift;;
        "-K"|"--ssh-key"   ) KEY="$1"; shift;;
        *                   ) Help
                              echo "ERROR: Invalid option: \""$opt"\"" >&2
                              exit 1;;
      esac
    done
  fi

echo "please check if 8.8.8.8 is avaliable for you"
echo "if not you has to edit the openstack-helm playbook: k8s_common.yaml,coredns_resolver.yaml,openstack_metallb_endpoint.yaml"
sleep 1s
echo "installing directory: $DIR"
echo "Using ssh key : $KEY"

read -p "Is system.resolved able to connect to DNS server 8.8.8.8 ? (y/n) " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo "using default playbook"
elif [ "$answer" != "${answer#[Nn]}" ];then
    echo "edit playbook"
    cp ./install_k8s/custom_playbook/coredns_resolver.yaml $DIR/openstack-helm-infra/playbooks/roles/deploy-env/tasks/coredns_resolver.yaml
    cp ./install_k8s/custom_playbook/k8s_common.yaml $DIR/openstack-helm-infra/playbooks/roles/deploy-env/tasks/k8s_common.yaml
    cp ./install_k8s/custom_playbook/openstack_metallb_endpoint.yaml $DIR/openstack-helm-infra/playbooks/roles/deploy-env/tasks/openstack_metallb_endpoint.yaml
else
    echo "do nothing"
    exit 0
fi
echo "setup cluster information"
read -p "enter primary ip: " primary_ip;
read -p "enter k8s control ip: " k8s_control_ip;
cat > $DIR/inventory.yaml <<EOF
---
all:
  vars:
    ansible_port: 22
    ansible_user: $current_user
    ansible_ssh_private_key_file: $KEY
    ansible_ssh_extra_args: -o StrictHostKeyChecking=no
    client_ssh_user: $current_user
    cluster_ssh_user: $current_user
    # The user and group that will be used to run Kubectl and Helm commands.
    kubectl:
      user: $current_user
      group: $current_user
    # The user and group that will be used to run Docker commands.
    docker_users:
      - $current_user
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
    # The control plane node where the Kubernetes control plane components will be installed.
    # It must be the only node in the group k8s_control_plane.
    k8s_control_plane:
      hosts:
        node-1:
          ansible_host: $k8s_control_ip
    # These are Kubernetes worker nodes. There could be zero such nodes.
    # In this case the Openstack workloads will be deployed on the control plane node.
EOF

cat > $DIR/deploy-env.yaml <<EOF
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
cd $DIR
ansible-playbook -i inventory.yaml deploy-env.yaml
