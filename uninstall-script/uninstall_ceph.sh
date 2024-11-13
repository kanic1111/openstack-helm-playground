echo "uninstalling ceph"

helm uninstall rook-ceph -n rook-ceph
helm uninstall rook-ceph-cluster -n ceph

kubectl delete all --all -n rook-ceph
kubectl delete ns rook-ceph --force 
kubectl delete all --all -n ceph
kubectl delete cephcluster ceph -n ceph --force 
#kubectl get cephcluster -n ceph -o json   | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/"  | kubectl replace --raw /apis/ceph.rook.io/v1/cephclusters -f -

kubectl delete ns ceph --force --wait=false
kubectl get namespace "ceph" -o json   | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/"   | kubectl replace --raw /api/v1/namespaces/ceph/finalize -f -

sleep 1
echo "this does not delete file in /var/lib/rook pls delete on ceph machine"
sleep 1
