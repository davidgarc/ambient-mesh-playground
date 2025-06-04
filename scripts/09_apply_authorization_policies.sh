#!/bin/bash
set -euo pipefail

green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

NAMESPACE="default"
PRODUCTPAGE_LABEL="app=productpage"
GATEWAY_SA="cluster.local/ns/default/sa/bookinfo-gateway-istio"
WAYPOINT_SA="cluster.local/ns/default/sa/waypoint"
CURL_DEPLOY="curl"

info "Applying Layer 4 AuthorizationPolicy to restrict access to productpage..."
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: productpage-ztunnel
  namespace: $NAMESPACE
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - $GATEWAY_SA
EOF

info "Deploying curl pod (if not present) for validation..."
kubectl get deploy/$CURL_DEPLOY -n $NAMESPACE &>/dev/null || \
  kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/curl/curl.yaml

info "Waiting for curl pod to be ready..."
kubectl rollout status deployment/$CURL_DEPLOY -n $NAMESPACE --timeout=60s

info "Validating that curl pod CANNOT access productpage (should fail)..."
if kubectl exec deploy/$CURL_DEPLOY -n $NAMESPACE -- curl -sSf http://productpage:9080/productpage; then
  error "curl pod unexpectedly accessed productpage! L4 policy not enforced."
  exit 1
else
  info "Access denied as expected. L4 AuthorizationPolicy is working."
fi

info "Creating waypoint proxy for namespace to enable L7 policies..."
istioctl waypoint apply --enroll-namespace --wait -n $NAMESPACE

info "Verifying waypoint proxy is ready..."
kubectl get gtw waypoint -n $NAMESPACE | grep -q 'True' || { error "Waypoint proxy not ready!"; exit 1; }

info "Applying Layer 7 AuthorizationPolicy to allow only GET from curl to productpage..."
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: productpage-waypoint
  namespace: $NAMESPACE
spec:
  targetRefs:
  - kind: Service
    group: ""
    name: productpage
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/default/sa/curl
    to:
    - operation:
        methods: ["GET"]
EOF

info "Updating L4 AuthorizationPolicy to also allow waypoint proxy..."
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: productpage-ztunnel
  namespace: $NAMESPACE
spec:
  selector:
    matchLabels:
      app: productpage
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - $GATEWAY_SA
        - $WAYPOINT_SA
EOF

info "Validating L7 policy: GET from curl should succeed..."
info "Generating multiple GET requests from curl to productpage for Kiali traffic..."
for i in {1..10}; do
  kubectl exec deploy/$CURL_DEPLOY -n $NAMESPACE -- curl -sSf http://productpage:9080/productpage > /dev/null || true
done
if kubectl exec deploy/$CURL_DEPLOY -n $NAMESPACE -- curl -sSf http://productpage:9080/productpage | grep -q '<title>'; then
  info "GET from curl succeeded as expected."
else
  error "GET from curl failed! L7 policy not working as expected."
  exit 1
fi

info "Validating L7 policy: DELETE from curl should be denied..."
info "Generating multiple DELETE requests from curl to productpage for Kiali traffic..."
for i in {1..10}; do
  kubectl exec deploy/$CURL_DEPLOY -n $NAMESPACE -- curl -s -X DELETE http://productpage:9080/productpage > /dev/null || true
done
if kubectl exec deploy/$CURL_DEPLOY -n $NAMESPACE -- curl -s -X DELETE http://productpage:9080/productpage | grep -q 'RBAC: access denied'; then
  info "DELETE from curl denied as expected."
else
  error "DELETE from curl did not return expected RBAC error!"
  exit 1
fi

info "Validating L7 policy: GET from reviews-v1 should be denied..."
info "Generating multiple GET requests from reviews-v1 to productpage for Kiali traffic..."
for i in {1..10}; do
  kubectl exec deploy/reviews-v1 -n $NAMESPACE -- curl -s http://productpage:9080/productpage > /dev/null || true
done
if kubectl exec deploy/reviews-v1 -n $NAMESPACE -- curl -s http://productpage:9080/productpage | grep -q 'RBAC: access denied'; then
  info "GET from reviews-v1 denied as expected."
else
  error "GET from reviews-v1 did not return expected RBAC error!"
  exit 1
fi

info "Authorization policies applied and validated successfully." 