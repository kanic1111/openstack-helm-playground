# openstack-helm-playground
>[!Note]
>This document is base on [Openstack-helm offical installation guide](https://docs.openstack.org/openstack-helm/latest/install/index.html) with customize setting

## Install kubernetes using Ansible and Openstack-helm playbook
```bash=
mkdir ~/osh
cd ~/osh
git clone https://opendev.org/openstack/openstack-helm-infra.git
git clone https://opendev.org/zuul/zuul-jobs.git
pip install ansible
export ANSIBLE_ROLES_PATH=~/osh/openstack-helm-infra/roles:~/osh/zuul-jobs/roles
```
### 準備Ansible Inventory

```bash=
export primary_ip=<primary ip>
export k8s-control_ip=<control ip>
export k8s-worker1_ip=<worker1 ip>
export k8s-worker2_ip=<worker2 ip>

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
```
>[!Caution]
>**當primary以及node-1的主機為相同主機的時候會導致apt安裝時出錯**


**準備Ansible playbook**
```bash=
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
ansible-playbook -i inventory.yaml deploy-env.yaml #執行playbook內容
```

>[!Warning]
>**這邊設定問題會很多，特別是與k8s部屬於同個節點的時候，還有因為它會修改/etc/resolvd.conf為8.8.8.8 如果在VM內會導致DNS出錯，這時麻煩請修改他的playbook(若不影響請跳過底下的步驟)**

修改openstack-helm playbook
---
>[!Note]
>**因為DNS需使用127.0.0.53，但Openstack會嘗試修改DNS至8.8.8.8，因此為避免安裝時錯誤(主要是image會抓不下來)，我們要修改Playbook讓他不要修改resloved.conf**

**主要需要修改三個Playbook**

### k8s_common.yaml
- **第一個是k8s_common.yaml，會嘗試將DNS設定成8.8.8.8導致K8s安裝時會出錯**
    ```bash=
    nano openstack-helm-infra/playbooks/roles/deploy-env/tasks/k8s_common.yaml
    #將下面的Task刪掉 讓他不要修改resolved.conf
    - name: Configure resolv.conf
      template:
        src: files/resolv.conf
        dest: /etc/resolv.conf
        owner: root
        group: root
        mode: 0644
      vars:
        nameserver_ip: "8.8.8.8"

    - name: Disable systemd-resolved
      service:
        name: systemd-resolved
        enabled: false
        state: stopped
      ignore_errors: true

    - name: Disable unbound
      service:
        name: unbound
        enabled: false
        state: stopped
      ignore_errors: true
    ```
    
### coredns_resolver  
- **第二個是coredns_resolver 他會嘗試讓我們本機使用CoreDns與k8s內部服務進行連線，然後CoreDns會使用8.8.8.8幫我們轉發DNS封包**
    ```bash=
    nano openstack-helm-infra/playbooks/roles/deploy-env/tasks/coredns_resolver.yaml
    #將Playbook的內容修改成使用本機的resolve file
    - name: Enable recursive queries for coredns
      become: false
      shell: |
        tee > /tmp/coredns_configmap.yaml <<EOF
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: coredns
          namespace: kube-system
        data:
          Corefile: |
            .:53 {
                errors
                health {
                  lameduck 5s
                }    
                ready
                kubernetes cluster.local in-addr.arpa ip6.arpa {
                  pods insecure
                  fallthrough in-addr.arpa ip6.arpa
                }
                prometheus :9153
                forward . "/etc/resolv.conf"
                cache 30
                loop
                reload
                loadbalance
            } # STUBDOMAINS - Rancher specific change
        EOF
        kubectl apply -f /tmp/coredns_configmap.yaml
        kubectl rollout restart -n kube-system deployment/coredns
        kubectl rollout status -n kube-system deployment/coredns
      when: inventory_hostname in (groups['primary'] | default([]))
    ```

### openstack_metallb_endpoint
- **第三個是openstack_metallb_endpoint，他會嘗試將Dnsmasq的資訊複寫到resloved.conf**
    ```bash=
    nano openstack-helm-infra/playbooks/roles/deploy-env/tasks/openstack_metallb_endpoint.yaml
    #將會修改resloved的task刪掉
    - name: Configure /etc/resolv.conf
      template:
        src: files/resolv.conf
        dest: /etc/resolv.conf
        owner: root
        group: root
        mode: 0644
    ```
  
