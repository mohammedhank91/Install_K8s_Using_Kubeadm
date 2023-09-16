#!/bin/bash

# Step 1: Install Kubernetes Servers
echo "Step 1: Install Kubernetes Servers"
echo "Provision the servers to be used in the deployment of Kubernetes on Ubuntu 20.04."
echo "The setup process will vary depending on the virtualization or cloud environment you're using."
echo "Once the servers are ready, update them."

sudo apt update && sudo apt -y full-upgrade
[ -f /var/run/reboot-required ] && sudo reboot -f

# Step 2: Install kubelet, kubeadm, and kubectl
echo "Step 2: Install kubelet, kubeadm, and kubectl"
echo "Adding Kubernetes repository for Ubuntu 20.04..."
sudo apt -y install curl apt-transport-https
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Prompt the user to choose a Kubernetes version
echo "Please choose a Kubernetes version:"
echo "1) Latest stable version"
echo "2) Specific version (e.g., 1.26.9-00)"
read -p "Enter your choice (1/2): " k8s_version_choice

case $k8s_version_choice in
  1)
    k8s_version="latest"
    ;;
  2)
    read -p "Enter the specific version (e.g., 1.26.9-00): " k8s_version
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Installing required packages
echo "Installing required packages..."
sudo apt update
sudo apt -y install kubelet kubeadm kubectl

if [ "$k8s_version" != "latest" ]; then
  # For a specific version of Kubernetes, use the version tag.
  echo "Installing Kubernetes version $k8s_version..."
  sudo apt install -y "kubeadm=$k8s_version" "kubelet=$k8s_version" "kubectl=$k8s_version"
fi

sudo apt-mark hold kubelet kubeadm kubectl

echo "Confirming the installation by checking the version of kubectl..."
kubectl version --client && kubeadm version

# Step 3: Disable Swap
echo "Step 3: Disable Swap"
echo "Turning off swap..."
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Disabling Linux swap space permanently in /etc/fstab..."
sudo swapoff -a
sudo mount -a
free -h

echo "Enabling kernel modules and configuring sysctl..."
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

# Step 4: Install Container runtime (Docker)
echo "Step 4: Install Container runtime (Docker)"
echo "Adding Docker repository and installing Docker packages..."
sudo apt update
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io docker-ce docker-ce-cli

echo "Creating required directories and configuring Docker daemon..."
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

echo "Starting and enabling Docker services..."
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker

echo "Script execution completed."
