#!/bin/bash
set -euo pipefail

# Variables
ISTIO_VERSION="1.26.1"
ISTIO_DIR="istio-${ISTIO_VERSION}"

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

# Download Istio if not already present
if [ ! -d "$ISTIO_DIR" ]; then
  info "Downloading Istio $ISTIO_VERSION ..."
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
else
  info "Istio $ISTIO_VERSION already downloaded."
fi

cd "$ISTIO_DIR"

# Add istioctl to PATH for this session
export PATH=$PWD/bin:$PATH
info "istioctl version: $(istioctl version --remote=false)"

# Install Istio with ambient profile (idempotent)
if kubectl get ns istio-system > /dev/null 2>&1 && kubectl get pods -n istio-system | grep -q istiod; then
  info "Istio appears to be already installed. Skipping installation."
else
  info "Installing Istio with ambient profile ..."
  istioctl install --set profile=ambient --set meshConfig.accessLogFile=/dev/stdout -y
fi

# Verify Istio pods
info "Verifying Istio pods in istio-system namespace ..."
kubectl get pods -n istio-system

info "Istio Ambient Mesh installation complete." 