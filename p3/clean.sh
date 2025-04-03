#!/bin/bash

echo "=== Cleaning EVERYTHING ==="

# Delete k3d cluster
if k3d cluster list | grep -q iot-cluster; then
    echo "Deleting k3d cluster..."
    k3d cluster delete iot-cluster
fi

# Delete ArgoCD namespaces if exist
kubectl delete namespace argocd --ignore-not-found
kubectl delete namespace dev --ignore-not-found

# Remove k3d binary
if command -v k3d &> /dev/null; then
    echo "Removing k3d..."
    sudo rm -f $(which k3d)
fi

# Remove kubectl binary
if command -v kubectl &> /dev/null; then
    echo "Removing kubectl..."
    sudo rm -f $(which kubectl)
fi

#remove argocd
if command -v argocd &> /dev/null; then
    echo "Removing argocd..."
    sudo rm -f $(which argocd)
fi
# Remove docker if you want (optional)
sudo apt-get purge -y docker.io containerd runc
sudo apt-get autoremove -y
pkill -f "kubectl port-forward"
echo "=== Clean-up complete ==="
