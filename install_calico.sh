#!/bin/bash

# Step 7: Install Calico
echo "Step 7: Install Calico"

# Install the Tigera Calico operator and custom resource definitions
echo "Installing Calico operator and custom resource definitions..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# Install Calico by creating the necessary custom resource
echo "Installing Calico..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml

# Wait for all pods to be in the Running state
echo "Waiting for Calico pods to be in the Running state..."
while ! kubectl get pods -A | grep -q "Running"; do
  sleep 5
done

# Remove taints on the control plane
echo "Removing taints on the control plane..."
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node-role.kubernetes.io/master-

# Confirm that the taints are removed
echo "Checking taints..."
if kubectl get nodes -o custom-columns="NAME:.metadata.name,TAINTS:.spec.taints" | grep -q "<your-hostname> untainted"; then
  echo "Taints removed successfully."
else
  echo "Failed to remove taints."
fi

# Confirm the status of the nodes
echo "Checking node status..."
kubectl get nodes -o wide

echo "Congratulations! You now have a single-host Kubernetes cluster with Calico."
