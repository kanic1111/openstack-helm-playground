if [ -z ${1+x} ]; then 
kube_version=v1.30.1
echo "kube_version is unset set to default $kube_version"; 
else 
kube_version=$1
echo "kube_version is set to '$kube_version'"; 
fi
