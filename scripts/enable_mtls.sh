#!/bin/bash
set -euo pipefail

green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

function info() { echo -e "${green}[INFO]${nc} $1"; }
function error() { echo -e "${red}[ERROR]${nc} $1"; }

NAMESPACE="default"

info "Applying PeerAuthentication policy to enforce STRICT mTLS in namespace '$NAMESPACE'..."

cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: $NAMESPACE
spec:
  mtls:
    mode: STRICT
EOF

info "Verifying PeerAuthentication policy in namespace '$NAMESPACE'..."
kubectl get peerauthentication default -n $NAMESPACE -o yaml | grep 'mode:' || error "PeerAuthentication not found!"

info "STRICT mTLS is now enforced in namespace '$NAMESPACE'." 