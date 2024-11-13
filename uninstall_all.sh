echo "uninstall all helm chart"

read -p "Delete all Openstack component and helm plugin? (y/n) " answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
helm ls --all --short -n openstack  | xargs -L1 helm delete
helm plugin uninstall osh
kubectl delete all --all -n openstack
kubectl delete ns openstack
else
echo "do nothing"
fi

