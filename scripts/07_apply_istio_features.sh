#!/bin/bash
set -euo pipefail

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }

# Observability: Prometheus, Kiali only
info "Applying Istio addon manifests for Prometheus and Kiali ..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/kiali.yaml

info "Waiting for Prometheus and Kiali pods to be running ..."
for svc in prometheus kiali; do
  kubectl rollout status deployment/$svc -n istio-system --timeout=120s || true
done

# Print dashboard access instructions
info "To access dashboards, use the following commands:"
echo -e "${green}istioctl dashboard kiali${nc}  # Opens Kiali in your browser (recommended)"
echo -e "Or manually:"
echo -e "${green}kubectl port-forward svc/kiali -n istio-system 20001:20001${nc}"
echo -e "Then open: ${green}http://localhost:20001${nc} (Kiali)"
echo -e "${green}kubectl port-forward svc/prometheus -n istio-system 9090:9090${nc}"
echo -e "Then open: ${green}http://localhost:9090${nc} (Prometheus)"

info "Prometheus and Kiali are now enabled for observability." 