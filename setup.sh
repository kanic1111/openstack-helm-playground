#!/bin/bash
OPTIND=1
verbose=0
KEYFILE=/home/ubuntu/.ssh/id_rsa
DEVICE="/dev/sdb";
DIR=~/osh
VERSION="2024.1"
############################################################
# Help                                                     #
############################################################

Help()
{
   # Display Help
   echo "Option to use this script."
   echo
   echo "To install Singlenode Cluster use:"
   echo "./setup.sh --install-k8s singlenode"
   echo
   echo "To install multinode Cluster use:"
   echo "./setup.sh --install-k8s multinode"
   echo
   echo "Use custom install directory and openstack version use"
   echo "./setup.sh --install-k8s singlenode --version 2023.2 --install-dir=/home/ubuntu/custom_folder"
   echo
   echo "you can found Openstack release Version in Offical site: https://github.com/openstack/openstack-helm"
   echo 
   echo "options:                                   description: "
   echo "--device                                   Choose Ceph OSD Device(default: /dev/sdb)"
   echo "--install-k8s (singleNode,multiNode)       install kubernetes ."
   echo "--version (version)                        installed Openstack Version(default: 2024.1)"
   echo "--install-dir (directory)                  choose install directory (default: ~/osh)"
   echo "--ssh-key (private-key)                    ssh private key file (default: /home/ubuntu/.ssh/id_rsa)"
   echo
}

if [[ "$1" =~ ^((-{1,2})([Hh]$|[Hh][Ee][Ll][Pp])|)$ ]]; then
    echo "Please enter k8s install mode"
    Help; exit 1
  else
    while [[ $# -gt 0 ]]; do
      opt="$1"
      shift;
      current_arg="$1"
     if [[ "$current_arg" =~ ^-{1,2}.* ]] || [ -z "${current_arg}" ]; then
        echo "WARNING: You may have left an argument blank. Double check your command." 
        Help
        exit 0
     fi
      case "$opt" in
        "--install-k8s"     ) MODE="$1"; shift;;
        "--version"         ) VERSION="$1"; shift;;
        "--device"          ) DEVICE="$1"; shift;;
        "--install-dir"     ) DIR="$1"; shift;;
        "--ssh-key"         ) KEYFILE="$1"; shift;;
        *                   ) Help
                              echo "ERROR: Invalid option: \""$opt"\"" >&2
                              exit 1;;
      esac
    done
  fi

echo "Ceph using device $DEVICE"
echo "Still on testing $DIR"

#install Ansible and Playbook
script_folder=$PWD
mkdir $DIR
git clone https://opendev.org/openstack/openstack-helm-infra.git $DIR/openstack-helm-infra
git clone https://opendev.org/zuul/zuul-jobs.git $DIR/zuul-jobs
pip install ansible
export ANSIBLE_ROLES_PATH=$DIR/openstack-helm-infra/roles:$DIR/osh/zuul-jobs/roles
echo $ANSIBLE_ROLES_PATH

#execute Script to auto create and run playbook
if [ "$MODE" == "multinode" ] ;then
    echo "install k8s multi_node"
    bash ./install_k8s/install_k8s_multinode.sh -D $DIR -K $KEYFILE
elif [ "$MODE" == "singlenode" ] ;then
    echo "install k8s single_node"
    bash ./install_k8s/install_k8s_singlenode.sh -D $DIR -K $KEYFILE
else
    echo "please set kubernetes installation mode"
    Help
    exit 0
fi
sleep 1s

#install cephcluster
cd $script_folder
read -p "install rook-ceph?(y/n): " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    if [ "$MODE" == "multinode" ] ;then
        echo "execute rook-ceph script(this may take up to 15mins)"
        echo "ceph will use device: $DEVICE"
        bash rook-ceph-install/install_rook-ceph.sh $DEVICE
        echo "ceph installation complete"
    elif [ "$MODE" == "singlenode" ] ;then
        echo "singlenode only deploy 1 OSD"
        echo "ceph will use device: $DEVICE"
        bash rook-ceph-install/install_rook-ceph_singlenode.sh $DEVICE
        echo "ceph installaton complete"
    else
        echo "please set the installation mode "
        exit 1
else
    echo "Ceph installation canceled"
fi
sleep 1s

#install openstack
cd $script_folder
read -p "install openstack?(y/n): " answer 
if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo "start openstack install script(this may take sometime)"
    bash openstack-helm-install/install_openstack.sh --override-dir $DIR --version $VERSION --chart-dir $DIR
    node_ip=$(kubectl get nodes -l openstack-control-plane=enabled -o wide | awk -v OFS='\t\t' '{print $6}' | sed -n '2 p')
    echo "openstack installation complete"
    echo "you can visit horizon by accessing http://"$node_ip":30375"
else
    echo "openstack install canceled"
fi


