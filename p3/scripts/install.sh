#!/bin/bash

# if there is no docker install it
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, installing..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo usermod -aG docker $USER
    sudo chmod 777 /var/run/docker.sock
    sudo systemctl start docker
    sudo systemctl enable docker
else
    echo "Docker is already installed"
fi

# install k3d
if ! command -v k3d &> /dev/null
then
    echo "k3d could not be found, installing..."
    curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
else
    echo "k3d is already installed"
fi

# install kubectl
if ! command -v kubectl &> /dev/null
then
    echo "kubectl could not be found, installing..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
    echo "kubectl is already installed"
fi

# create a k3d cluster if it doesn't exist
if ! k3d cluster list | grep -q iot-cluster
then
    echo "Creating k3d cluster..."
    export K3D_FIX_DNS=0
    k3d cluster create iot-cluster --agents 1
else
    echo "k3d cluster already exists"
fi

# create dev namespace if missing
if ! kubectl get ns | grep -q dev
then
    echo "Creating dev namespace..."
    kubectl create namespace dev
else
    echo "dev namespace already exists"
fi
# ArgoCD installation
if ! kubectl get ns | grep -q argocd
then
    echo "Installing ArgoCD..."
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
else
    echo "ArgoCD already installed"
fi
sleep 20
# apply argocd application from local file
kubectl apply -f  confs/application.yaml

# get admin password
echo "=== ArgoCD admin password ==="
sleep 20
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# Port-forward ArgoCD Dashboard
echo "Port-forwarding ArgoCD to https://localhost:8080"
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &

# Port-forward for app
echo "Port-forwarding Traefik (for Ingress) to http://app.lol:8081"
kubectl port-forward svc/traefik -n kube-system 8081:80 > /dev/null 2>&1 &
sleep 20
# Install ArgoCD CLI if not installed
echo "Installing ArgoCD CLI and syncing app..."
if ! command -v argocd &> /dev/null
then
    echo "ArgoCD CLI could not be found, installing..."
    curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x argocd
    sudo mv argocd /usr/local/bin/
    argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --insecure

    argocd app sync my-app
else
    echo "ArgoCD CLI is already installed"
fi  

echo "=== DONE ==="
echo "-> ArgoCD Dashboard: https://localhost:8080"
echo "-> Your App: http://app.lol:8081"