#!/bin/bash
set -euo pipefail

# Variables
ISTIO_VERSION="1.26.1"
BOOKINFO_URL="https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml"
EXTERNAL=false

# Parse arguments
for arg in "$@"; do
  if [[ "$arg" == "--external" ]]; then
    EXTERNAL=true
  fi
done

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

if $EXTERNAL; then
  info "Patching productpage service to type LoadBalancer ..."
  kubectl patch svc productpage -p '{"spec": {"type": "LoadBalancer"}}'
fi

info "Checking for external access to the productpage service ..."
SERVICE_TYPE=$(kubectl get svc productpage -o jsonpath='{.spec.type}')
if [[ "$SERVICE_TYPE" == "LoadBalancer" ]]; then
  EXTERNAL_IP=""
  TIMEOUT=60
  END=$((SECONDS+TIMEOUT))
  while [[ -z "$EXTERNAL_IP" && $SECONDS -lt $END ]]; do
    EXTERNAL_IP=$(kubectl get svc productpage -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    [[ -z "$EXTERNAL_IP" ]] && EXTERNAL_IP=$(kubectl get svc productpage -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    sleep 2
  done
  if [[ -n "$EXTERNAL_IP" ]]; then
    PORT=$(kubectl get svc productpage -o jsonpath='{.spec.ports[0].port}')
    info "You can access the Bookinfo productpage in your browser at:"
    echo -e "${green}http://$EXTERNAL_IP:$PORT/productpage${nc}"
  else
    error "LoadBalancer external IP/hostname not available yet. Please check again later with: kubectl get svc productpage"
  fi
else
  info "No external LoadBalancer detected. You can use port-forward to access the productpage locally:"
  echo -e "${green}kubectl port-forward svc/productpage 9080:9080${nc}"
  echo -e "Then open: ${green}http://localhost:9080/productpage${nc} in your browser."
fi 