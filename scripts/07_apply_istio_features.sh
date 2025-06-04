#!/bin/bash
set -euo pipefail

# Colors for output
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

EXTERNAL=false
for arg in "$@"; do
  if [[ "$arg" == "--external" ]]; then
    EXTERNAL=true
  fi
done

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

# 1. Traffic Management: Gateway and HTTPRoute
info "Creating gateway.yaml ..."
cat <<EOF > gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: bookinfo-gateway
  namespace: default
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

info "Creating httproute.yaml ..."
cat <<EOF > httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bookinfo
  namespace: default
spec:
  parentRefs:
    - name: bookinfo-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /productpage
      backendRefs:
        - name: productpage
          port: 9080
EOF

info "Applying gateway and HTTPRoute ..."
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml

if $EXTERNAL; then
  info "Patching productpage service to type LoadBalancer ..."
  kubectl patch svc productpage -n default -p '{"spec": {"type": "LoadBalancer"}}'
fi

# 2. Security: mTLS and AuthorizationPolicy
info "Creating peerauth.yaml ..."
cat <<EOF > peerauth.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
EOF

info "Applying PeerAuthentication ..."
kubectl apply -f peerauth.yaml

info "Creating authorizationpolicy.yaml ..."
cat <<EOF > authorizationpolicy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-internal
  namespace: default
spec:
  rules:
    - from:
        - source:
            namespaces: ["default"]
EOF

info "Applying AuthorizationPolicy ..."
kubectl apply -f authorizationpolicy.yaml

# 3. Observability: Prometheus, Kiali (no Jaeger)
info "Applying Istio addon manifests for Prometheus and Kiali ..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/kiali.yaml

info "Cleaning up Jaeger resources if present ..."
kubectl delete deployment jaeger -n istio-system --ignore-not-found
kubectl delete svc jaeger-query jaeger-collector tracing zipkin -n istio-system --ignore-not-found
kubectl delete serviceaccount jaeger -n istio-system --ignore-not-found
kubectl delete configmap jaeger-configuration -n istio-system --ignore-not-found

info "Waiting for Prometheus and Kiali pods to be running ..."
for svc in prometheus kiali; do
  kubectl rollout status deployment/$svc -n istio-system --timeout=120s || true
done

# Print access instructions
if $EXTERNAL; then
  info "Checking for external access to the productpage service ..."
  SERVICE_TYPE=$(kubectl get svc productpage -n default -o jsonpath='{.spec.type}')
  if [[ "$SERVICE_TYPE" == "LoadBalancer" ]]; then
    EXTERNAL_IP=""
    TIMEOUT=60
    END=$((SECONDS+TIMEOUT))
    while [[ -z "$EXTERNAL_IP" && $SECONDS -lt $END ]]; do
      EXTERNAL_IP=$(kubectl get svc productpage -n default -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
      [[ -z "$EXTERNAL_IP" ]] && EXTERNAL_IP=$(kubectl get svc productpage -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
      sleep 2
    done
    if [[ -n "$EXTERNAL_IP" ]]; then
      PORT=$(kubectl get svc productpage -n default -o jsonpath='{.spec.ports[0].port}')
      info "You can access the Bookinfo productpage in your browser at:"
      echo -e "${green}http://$EXTERNAL_IP:$PORT/productpage${nc}"
    else
      error "LoadBalancer external IP/hostname not available yet. Please check again later with: kubectl get svc productpage -n default"
    fi
  else
    error "Service type is not LoadBalancer. External access is not available."
  fi
else
  info "No external LoadBalancer detected. You can use port-forward to access the productpage locally:"
  echo -e "${green}kubectl port-forward svc/productpage 9080:9080 -n default${nc}"
  echo -e "Then open: ${green}http://localhost:9080/productpage${nc} in your browser."
fi

# Print dashboard access instructions
info "To access dashboards, use the following commands:"
echo -e "${green}istioctl dashboard kiali${nc}  # Opens Kiali in your browser (recommended)"
echo -e "Or manually:"
echo -e "${green}kubectl port-forward svc/kiali -n istio-system 20001:20001${nc}"
echo -e "Then open: ${green}http://localhost:20001${nc} (Kiali)"
echo -e "${green}kubectl port-forward svc/prometheus -n istio-system 9090:9090${nc}"
echo -e "Then open: ${green}http://localhost:9090${nc} (Prometheus)"

info "All Istio features applied. Traffic management, security, and observability (with Kiali) are now enabled for Bookinfo." 