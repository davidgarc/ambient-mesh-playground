#!/bin/bash
set -euo pipefail

# Variables (edit as needed)
RESOURCE_GROUP="istio-ambient-demo-rg"
CLUSTER_NAME="istio-ambient-cluster"

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

info "Checking if AKS cluster '$CLUSTER_NAME' exists in resource group '$RESOURCE_GROUP'..."
if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" > /dev/null 2>&1; then
  info "Deleting AKS cluster '$CLUSTER_NAME'..."
  az aks delete --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --yes --no-wait
else
  info "AKS cluster '$CLUSTER_NAME' does not exist. Skipping cluster deletion."
fi

info "Checking if resource group '$RESOURCE_GROUP' exists..."
if az group show --name "$RESOURCE_GROUP" > /dev/null 2>&1; then
  info "Deleting resource group '$RESOURCE_GROUP' and all its resources..."
  az group delete --name "$RESOURCE_GROUP" --yes --no-wait
else
  info "Resource group '$RESOURCE_GROUP' does not exist. Skipping resource group deletion."
fi

info "Teardown initiated. Resources will be deleted asynchronously. Check Azure Portal or CLI for status." 