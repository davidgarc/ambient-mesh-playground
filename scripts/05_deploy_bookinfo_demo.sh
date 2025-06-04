#!/bin/bash
set -euo pipefail

# Variables
ISTIO_VERSION="1.26.1"
BOOKINFO_URL="https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml"

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

info "Applying Bookinfo sample application manifest from $BOOKINFO_URL ..."
kubectl apply -f "$BOOKINFO_URL"

info "Waiting for Bookinfo pods to be running ..."
TIMEOUT=120
END=$((SECONDS+TIMEOUT))
while true; do
  NOT_READY=$(kubectl get pods -n default --selector=app=details,app=productpage,app=ratings,app=reviews --no-headers 2>/dev/null | awk '$3 != "Running" {print $1}')
  if [[ -z "$NOT_READY" ]]; then
    info "All Bookinfo pods are running."
    break
  fi
  if (( SECONDS > END )); then
    error "Timeout waiting for Bookinfo pods to be running: $NOT_READY"
    kubectl get pods -n default
    exit 1
  fi
  sleep 5
done

info "Bookinfo sample application deployed successfully."

info "You can use port-forward to access the productpage locally:"
echo -e "${green}kubectl port-forward svc/productpage 9080:9080${nc}"
echo -e "Then open: ${green}http://localhost:9080/productpage${nc} in your browser." 