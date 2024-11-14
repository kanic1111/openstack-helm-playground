read -p "enter Ceph OSD device(must be empty disk):" osd_device
if [[ $osd_device == "/dev/"* ]]; then 
echo "osd device is $osd_device"; 
else 
osd_device='/dev/loop100'
echo "use default $osd_device"; 
fi
