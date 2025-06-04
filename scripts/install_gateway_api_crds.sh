#!/bin/bash
set -euo pipefail

# Gateway API CRDs version
GATEWAY_API_VERSION="v1.0.0"
GATEWAY_API_URL="https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

info "Applying Gateway API CRDs from $GATEWAY_API_URL ..."
kubectl apply -f "$GATEWAY_API_URL"

info "Verifying Gateway API CRDs installation..."
REQUIRED_CRDS=(
  "gatewayclasses.gateway.networking.k8s.io"
  "gateways.gateway.networking.k8s.io"
  "httproutes.gateway.networking.k8s.io"
)

MISSING=0
for crd in "${REQUIRED_CRDS[@]}"; do
  if kubectl get crd "$crd" > /dev/null 2>&1; then
    info "CRD '$crd' is present."
  else
    error "CRD '$crd' is MISSING!"
    MISSING=1
  fi
done

if [[ $MISSING -eq 1 ]]; then
  error "One or more required Gateway API CRDs are missing. Please check your cluster and try again."
  exit 1
fi

info "All required Gateway API CRDs are installed successfully." 