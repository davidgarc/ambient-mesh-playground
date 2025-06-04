#!/bin/bash
set -euo pipefail

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

info "Checking Istio pods in istio-system namespace..."
PODS=$(kubectl get pods -n istio-system --no-headers)
NOT_READY=$(echo "$PODS" | awk '$3 != "Running" {print $1}')
if [[ -n "$NOT_READY" ]]; then
  error "The following pods are not running: $NOT_READY"
  kubectl get pods -n istio-system
  exit 1
else
  info "All pods in istio-system are running."
fi

info "Checking ztunnel DaemonSet status..."
DS_STATUS=$(kubectl get daemonset ztunnel -n istio-system -o json)
DESIRED=$(echo "$DS_STATUS" | jq .status.desiredNumberScheduled)
CURRENT=$(echo "$DS_STATUS" | jq .status.currentNumberScheduled)
READY=$(echo "$DS_STATUS" | jq .status.numberReady)
AVAILABLE=$(echo "$DS_STATUS" | jq .status.numberAvailable)

if [[ $DESIRED -eq $CURRENT && $CURRENT -eq $READY && $READY -eq $AVAILABLE ]]; then
  info "ztunnel DaemonSet is fully available on all nodes."
else
  error "ztunnel DaemonSet is not fully available: DESIRED=$DESIRED, CURRENT=$CURRENT, READY=$READY, AVAILABLE=$AVAILABLE"
  kubectl get daemonset ztunnel -n istio-system
  exit 1
fi

info "Istio Ambient Mesh installation is healthy." 