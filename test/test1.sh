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
   echo "Usage: ./setup.sh --install-k8s singlenode"
   echo "options:                                   description: "
   echo "--device                                   Choose Ceph OSD Device(default: /dev/sdb)"
   echo "--install-k8s (SingleNode,MultiNode)       install kubernetes ."
   echo "--version (version)                        installed Openstack Version(default: 2024.1)"
   echo "--install-dir (directory)                  choose install directory (default: ~/osh)"
   echo "--ssh-key (private-key)                    ssh private key file (default: /home/ubuntu/.ssh/id_rsa)"
   echo
}

if [[ "$1" =~ ^((-{1,2})([Hh]$|[Hh][Ee][Ll][Pp])|)$ ]]; then
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

script_folder=$PWD
mkdir $DIR
git clone https://opendev.org/openstack/openstack-helm-infra.git $DIR/openstack-helm-infra
git clone https://opendev.org/zuul/zuul-jobs.git $DIR/zuul-jobs
pip install ansible
export ANSIBLE_ROLES_PATH=$DIR/openstack-helm-infra/roles:$DIR/osh/zuul-jobs/roles
echo $ANSIBLE_ROLES_PATH

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
sleep 2s

cd $script_folder
read -p "install rook-ceph?(y/n): " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo "execute rook-ceph script(this may take up to 15mins)"
    echo "ceph will use device: $DEVICE"
    bash rook-ceph-install/install_rook-ceph.sh $DEVICE
    echo "ceph installation complete"
else
    echo "installation canceled"
fi
sleep 2s
#exit 0
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


