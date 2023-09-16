#!/bin/bash

# Step 5: Install cri-dockerd
echo "Step 5: Install cri-dockerd"

# Check if the system is Debian-based
if [ -f /etc/debian_version ]; then
  echo "Detected Debian-based system."
else
  echo "This script is intended for Debian-based systems only. Exiting."
  exit 1
fi

# Install required tools
echo "Installing required tools..."
sudo apt update
sudo apt install -y git wget curl

# Get the latest release version of cri-dockerd
VER=$(curl -s https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//g')

# Download and extract cri-dockerd binary package
echo "Downloading cri-dockerd version $VER..."
wget https://github.com/Mirantis/cri-dockerd/releases/download/v${VER}/cri-dockerd-${VER}.amd64.tgz
tar xvf cri-dockerd-${VER}.amd64.tgz

# Move cri-dockerd binary package to /usr/local/bin directory
echo "Moving cri-dockerd binary to /usr/local/bin..."
sudo mv cri-dockerd/cri-dockerd /usr/local/bin/

# Validate successful installation
echo "Validating successful installation..."
cri-dockerd --version

# Configure systemd units for cri-dockerd
echo "Configuring systemd units for cri-dockerd..."
wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service
wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket
sudo mv cri-docker.socket cri-docker.service /etc/systemd/system/
sudo sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service

# Start and enable the services
echo "Starting and enabling cri-dockerd services..."
sudo systemctl daemon-reload
sudo systemctl enable cri-docker.service
sudo systemctl enable --now cri-docker.socket

# Confirm the service is running
echo "Checking the status of cri-docker.socket..."
systemctl status cri-docker.socket
