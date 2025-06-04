#!/bin/bash
set -euo pipefail

# Variables (edit as needed)
RESOURCE_GROUP="istio-ambient-demo-rg"
LOCATION="eastus"
CLUSTER_NAME="istio-ambient-cluster"
NODE_COUNT=3
NODE_VM_SIZE="Standard_D4s_v3"

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

info "Logging in to Azure..."
az account show > /dev/null 2>&1 || az login

info "Checking if resource group '$RESOURCE_GROUP' exists..."
if az group show --name "$RESOURCE_GROUP" > /dev/null 2>&1; then
  info "Resource group '$RESOURCE_GROUP' already exists. Skipping creation."
else
  info "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
fi

info "Checking if AKS cluster '$CLUSTER_NAME' exists..."
if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" > /dev/null 2>&1; then
  info "AKS cluster '$CLUSTER_NAME' already exists. Skipping creation."
else
  info "Creating AKS cluster '$CLUSTER_NAME' ($NODE_COUNT nodes, $NODE_VM_SIZE, default K8s version)..."
  az aks create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$NODE_VM_SIZE" \
    --network-plugin azure \
    --enable-managed-identity \
    --generate-ssh-keys
fi

info "Getting kubectl credentials for cluster..."
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing

info "Verifying cluster nodes..."
kubectl get nodes

info "Checking Kubernetes version..."
kubectl version

info "All steps completed. AKS cluster '$CLUSTER_NAME' is ready for the next step!" 