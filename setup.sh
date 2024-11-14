echo "Still on testing"
script_folder=$PWD
mkdir ~/osh
git clone https://opendev.org/openstack/openstack-helm-infra.git ~/osh/openstack-helm-infra
git clone https://opendev.org/zuul/zuul-jobs.git ~/osh/zuul-jobs
pip install ansible
export ANSIBLE_ROLES_PATH=~/osh/openstack-helm-infra/roles:~/osh/zuul-jobs/roles

read -p "Install kubernetes (singlenode/multinode)? " mode
if [ "$mode" == "multinode" ] ;then
    echo "install k8s multi_node"
    bash ./install_k8s/install_k8s_multinode.sh
elif [ "$mode" == "singlenode" ] ;then
    echo "install k8s single_node"
    bash ./install_k8s/install_k8s_singlenode.sh
else
    echo "wrong value"
fi
sleep 2s
cd $script_folder
read -p "install rook-ceph?(y/n): " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    read -p "enter Ceph OSD device(must be empty disk):" osd_device
    if [[ $osd_device == "/dev/"* ]]; then
        echo "osd device is $osd_device";
        else
        osd_device='/dev/loop100'
        echo "use default $osd_device";
    fi
    echo "execute rook-ceph script(this may take up to 15mins)"
    bash rook-ceph-install/install_rook-ceph.sh $osd_device
    echo "ceph installation complete"
else
    echo "installation canceled"
fi
sleep 2s
cd $script_folder
read -p "install openstack?(y/n): " answer 
if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo "start openstack install script(this may take sometime)"
    bash openstack-helm-install/install_openstack.sh
    node_ip=$(kubectl get nodes -l openstack-control-plane=enabled -o wide | awk -v OFS='\t\t' '{print $6}' | sed -n '2 p')
    echo "openstack installation complete"
    echo "you can visit horizon by accessing http://"$node_ip":30375"
else
    echo "openstack install canceled"
fi


