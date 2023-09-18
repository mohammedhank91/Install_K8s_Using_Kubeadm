# Installing Kubernetes on Ubuntu 20.04 using kubeadm

This guide provides step-by-step instructions for setting up a Kubernetes cluster on Ubuntu using `kubeadm`. Kubernetes is a powerful container orchestration platform for managing containerized applications.

## Step 1: Install Kubernetes Servers

Provision the servers to be used in the deployment of Kubernetes on Ubuntu 20.04. The setup process will vary depending on the virtualization or cloud environment you're using. Once the servers are ready, update them.

```bash
sudo apt update && sudo apt -y full-upgrade
[ -f /var/run/reboot-required ] && sudo reboot -f
```

## Step 2: Install kubelet, kubeadm, and kubectl

```bash
sudo apt -y install curl apt-transport-https
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Then install the required packages.
```bash
sudo apt update
sudo apt -y install  kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```
# For a specific version of Kubernetes, use the version tag. For example, we will use version 1.26.9-00.
```bash
sudo apt install -y kubeadm=1.26.9-00 kubelet=1.26.9-00 kubectl=1.26.9-00
```

Confirm the installation by checking the version of kubectl.

```bash
kubectl version --client && kubeadm version
```

## Step 3: Disable Swap
Turn off swap.
```bash
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```
Now disable Linux swap space permanently in /etc/fstab. Search for a swap line and add # (hashtag) sign in front of the line.
```bash
sudo swapoff -a
sudo mount -a
free -h
```
Enable kernel modules and configure sysctl.
```bash
# Enable kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Add some settings to sysctl
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload sysctl
sudo sysctl --system
```
## Step 4: Install Container runtime
To run containers in Pods, Kubernetes uses a container runtime. Supported container runtimes are Docker, CRI-O, and Containerd. You have to choose one runtime at a time.
### Install and Use Docker CE runtime
Add the repository and install Docker packages.
```bash
sudo apt update
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io docker-ce docker-ce-cli
```

Create required directories and configure Docker daemon.
```bash 
sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Start and enable Services
sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker
```

## Step 5:  Install cri-dockerd
### Debian based systems ###
```bash
sudo apt update
sudo apt install git wget curl
```
Once the tools are installed, use them to download the latest binary package of cri-dockerd. But first, let’s get the latest release version:
```bash
VER=$(curl -s https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest|grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo $VER
```
### For Intel 64-bit CPU ###
```bash
wget https://github.com/Mirantis/cri-dockerd/releases/download/v${VER}/cri-dockerd-${VER}.amd64.tgz
tar xvf cri-dockerd-${VER}.amd64.tgz
```
Move cri-dockerd binary package to /usr/local/bin directory
```bash
sudo mv cri-dockerd/cri-dockerd /usr/local/bin/
```
Validate successful installation by running the commands below:
```bash
$ cri-dockerd --version
cri-dockerd 0.3.4 (e88b1605)
```
Configure systemd units for cri-dockerd:
```bash
wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service
wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket
sudo mv cri-docker.socket cri-docker.service /etc/systemd/system/
sudo sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
```
Start and enable the services
```bash
sudo systemctl daemon-reload
sudo systemctl enable cri-docker.service
sudo systemctl enable --now cri-docker.socket
```
Confirm the service is now running:
```bash
$ systemctl status cri-docker.socket
● cri-docker.socket - CRI Docker Socket for the API
   Loaded: loaded (/etc/systemd/system/cri-docker.socket; enabled; vendor preset: disabled)
   Active: active (listening) since Fri 2023-03-10 10:02:13 UTC; 4s ago
   Listen: /run/cri-dockerd.sock (Stream)
    Tasks: 0 (limit: 23036)
   Memory: 4.0K
   CGroup: /system.slice/cri-docker.socket

Mar 10 10:02:13 rocky8.mylab.io systemd[1]: Starting CRI Docker Socket for the API.
Mar 10 10:02:13 rocky8.mylab.io systemd[1]: Listening on CRI Docker Socket for the API.
```

## Step 6: Initialize master node
Login to the server to be used as master and make sure that the br_netfilter module is loaded:
```bash 
$ lsmod | grep br_netfilter
br_netfilter           22256  0 
bridge                151336  2 br_netfilter,ebtable_broute
```
Enable kubelet service.
```bash
sudo systemctl enable kubelet
```

We now want to initialize the machine that will run the control plane components which includes etcd (the cluster database) and the API Server.

These are the basic kubeadm init options that are used to bootstrap cluster.
- --control-plane-endpoint :  set the shared endpoint for all control-plane nodes. Can be DNS/IP
- --pod-network-cidr : Used to set a Pod network add-on CIDR
- --cri-socket : Use if have more than one container runtime to set runtime socket path
- --apiserver-advertise-address : Set advertise address for this particular control-plane node's API server

As a regular user with sudo privileges, open a terminal on the host that you installed kubeadm on.

Initialize the control plane using the following command.
```bash
sudo sysctl -p
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=unix:///var/run/cri-dockerd.sock
```
Configure kubectl using commands in the output:
```bash
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
Check cluster status:
```bash
kubectl cluster-info
```

## Step 7:Install Calico
Install the Tigera Calico operator and custom resource definitions.
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
```
Install Calico by creating the necessary custom resource
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
```

Confirm that all of the pods are running with the following command.
```bash
watch kubectl get pods -A
```
Wait until each pod has the **STATUS** of **Running**.

**NOTE**
The Tigera operator installs resources in the calico-system namespace. Other install methods may use the kube-system namespace instead.
Remove the taints on the control plane so that you can schedule pods on it.
```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node-role.kubernetes.io/master-
```
It should return the following.
```
node/<your-hostname> untainted
```
Confirm that you now have a node in your cluster with the following command.
```
kubectl get nodes -o wide
```
It should return something like the following.
```
NAME              STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION    CONTAINER-RUNTIME
<your-hostname>   Ready    master   52m   v1.12.2   10.128.0.28   <none>        Ubuntu 18.04.1 LTS   4.15.0-1023-gcp   docker://18.6.1
```

**Congratulations! You now have a single-host Kubernetes cluster with Calico.**

## Clean Up

If you used disposable servers for your cluster, for testing, you can switch those off and do no further clean up. You can use kubectl config delete-cluster to delete your local references to the cluster.

However, if you want to deprovision your cluster more cleanly, you should first drain the node and make sure that the node is empty, then deconfigure the node.

### Remove the node
Talking to the control-plane node with the appropriate credentials, run:
```bash
kubectl drain <node name> --delete-emptydir-data --force --ignore-daemonsets
```

Before removing the node, reset the state installed by kubeadm:
```bash
kubeadm reset
```
The reset process does not reset or clean up iptables rules or IPVS tables. If you wish to reset iptables, you must do so manually:
```bash
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
```

If you want to reset the IPVS tables, you must run the following command:
```bash
ipvsadm -C
```
Now remove the node:
```bash 
kubectl delete node <node name>
```
If you wish to start over, run **kubeadm init** or **kubeadm join** with the appropriate arguments

# Troubleshooting

### Pod errors due to “too many open files” 
This may be caused by running out of inotify resources. Resource limits are defined by fs.inotify.max_user_watches and fs.inotify.max_user_instances system variables. For example, in Ubuntu these default to 8192 and 128 respectively, which is not enough to create a cluster with many nodes.

To increase these limits temporarily run the following commands on the host:

```bash
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512
```
To make the changes persistent, edit the file **/etc/sysctl.conf** and add these lines:
```bash
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
```



## License
![Logo](https://i.ibb.co/hfVvghB/image-2023-09-16-174427188.png)

