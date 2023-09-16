#!/bin/bash

# Step 6: Initialize master node
echo "Step 6: Initialize master node"

# Check if the br_netfilter module is loaded
if lsmod | grep -q br_netfilter; then
  echo "br_netfilter module is loaded."
else
  echo "br_netfilter module is not loaded. Please ensure it's loaded before proceeding."
  exit 1
fi

# Enable kubelet service
echo "Enabling kubelet service..."
sudo systemctl enable kubelet

# Pull container images
echo "Pulling container images..."
sudo kubeadm config images pull

# Initialize the control plane
echo "Initializing the control plane..."
sudo sysctl -p
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Configure kubectl
echo "Configuring kubectl..."
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Check cluster status
echo "Checking cluster status..."
kubectl cluster-info

# Print instructions for joining worker nodes
echo "To add worker nodes to the cluster, run the following command on each worker node:"
echo "sudo kubeadm join <master-node-ip>:<master-node-port> --token <token> --discovery-token-ca-cert-hash <ca-cert-hash>"

# Print kubectl commands for managing the cluster
echo "You can use the following kubectl commands to manage the cluster:"
echo "kubectl get nodes            # View cluster nodes"
echo "kubectl get pods -n kube-system  # View system pods"

