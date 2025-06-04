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

# Deploy Bookinfo Gateway and HTTPRoute (Ambient Mesh demo)
info "Applying Bookinfo Gateway and HTTPRoute resources ..."
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: bookinfo-gateway
  namespace: default
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
EOF

cat <<EOF | kubectl apply -f -
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

info "Annotating gateway to use ClusterIP service type ..."
kubectl annotate gateway bookinfo-gateway networking.istio.io/service-type=ClusterIP --namespace=default --overwrite

info "Waiting for gateway to be programmed ..."
TIMEOUT=60
END=$((SECONDS+TIMEOUT))
while true; do
  STATUS=$(kubectl get gateway bookinfo-gateway -n default -o jsonpath='{.status.programmed}')
  if [[ "$STATUS" == "true" ]]; then
    info "Gateway is programmed."
    break
  fi
  if (( SECONDS > END )); then
    error "Timeout waiting for gateway to be programmed."
    kubectl get gateway bookinfo-gateway -n default -o yaml
    exit 1
  fi
  sleep 2
done

info "You can use port-forward to access the Bookinfo productpage via the gateway locally:"
echo -e "${green}kubectl port-forward svc/bookinfo-gateway-istio 8080:80${nc}"
echo -e "Then open: ${green}http://localhost:8080/productpage${nc} in your browser." 