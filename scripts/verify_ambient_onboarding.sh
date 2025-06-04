#!/bin/bash
set -euo pipefail

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

NAMESPACE="default"
LABEL_KEY="istio.io/dataplane-mode"
LABEL_VALUE="ambient"

info "Checking if namespace '$NAMESPACE' is labeled for ambient mesh..."
LABEL=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}')
if [[ "$LABEL" == "$LABEL_VALUE" ]]; then
  info "Namespace '$NAMESPACE' is labeled with $LABEL_KEY=$LABEL_VALUE."
else
  error "Namespace '$NAMESPACE' is NOT labeled with $LABEL_KEY=$LABEL_VALUE."
  exit 1
fi

info "Checking that all pods in namespace '$NAMESPACE' are Running..."
NOT_READY=$(kubectl get pods -n "$NAMESPACE" --no-headers | awk '$3 != "Running" {print $1}')
if [[ -n "$NOT_READY" ]]; then
  error "The following pods are not running: $NOT_READY"
  kubectl get pods -n "$NAMESPACE"
  exit 1
else
  info "All pods in namespace '$NAMESPACE' are running."
fi

info "Namespace '$NAMESPACE' is onboarded to ambient mesh and all pods are healthy." 