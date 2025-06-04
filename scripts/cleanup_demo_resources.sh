#!/bin/bash
set -euo pipefail

green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function warn() { echo -e "${red}[WARN]${nc} $1"; }

info "Deleting Bookinfo application resources in 'default' namespace..."
kubectl delete deployment,svc,serviceaccount,configmap,secret,role,rolebinding -l app=productpage -n default --ignore-not-found
kubectl delete deployment,svc,serviceaccount,configmap,secret,role,rolebinding -l app=details -n default --ignore-not-found
kubectl delete deployment,svc,serviceaccount,configmap,secret,role,rolebinding -l app=reviews -n default --ignore-not-found
kubectl delete deployment,svc,serviceaccount,configmap,secret,role,rolebinding -l app=ratings -n default --ignore-not-found

info "Deleting Gateway and HTTPRoute resources..."
kubectl delete gateway bookinfo-gateway -n default --ignore-not-found
kubectl delete httproute bookinfo -n default --ignore-not-found

info "Deleting Istio security policies..."
kubectl delete peerauthentication default -n default --ignore-not-found
kubectl delete authorizationpolicy allow-internal -n default --ignore-not-found

info "Deleting Kiali and Prometheus addons..."
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/kiali.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/prometheus.yaml --ignore-not-found

info "Deleting generated YAML files (if present)..."
rm -f gateway.yaml httproute.yaml peerauth.yaml authorizationpolicy.yaml

warn "If you want to remove Gateway API CRDs, run:"
echo "kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml"

info "Cleanup complete. AKS cluster and Istio control plane are not deleted by this script." 