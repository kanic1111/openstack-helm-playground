# openstack-helm-playground
**[官方的腳本](https://opendev.org/openstack/openstack-helm-infra/src/branch/master/tools/deployment/ceph/ceph-rook.sh)修改**
**將OSD Device修改成/dev/sdb**
**確認cluster狀態**
```bash=
kubectl get cephcluster -n ceph 
```
![image](https://hackmd.io/_uploads/S1NAjLOZ1e.png)
>[!Caution]
>**HEALTH狀態只有HEALTH_WARN跟HEALTH_OK 其他狀態皆屬於有問題，但若無OSD不會跳錯誤，需透過底下的指令查看是否有OSD可用，無OSD會導致最後Openstack在部屬Volume時會出錯**

**cluster部屬完成後也可以透過ceph-toolbox內確認OSD皆正常部署成功**
```bash=
kubectl exec -it -t $(kubectl get pod -l app=rook-ceph-tools -n ceph -o name) -n ceph -- bash -c "ceph osd df tree"
```
**output應該會像如此**
![image](https://hackmd.io/_uploads/H1U1sLub1e.png)
**乾淨的環境應該是使用率接近0**

**確認部屬完成後即可回到Openstack-helm安裝步驟**
