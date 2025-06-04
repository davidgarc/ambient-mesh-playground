# Ambient Mesh Playground on Azure AKS

## Overview
This project provides a hands-on environment for testing and demonstrating Istio Ambient Mesh features and capabilities on Azure Kubernetes Service (AKS). It automates cluster provisioning, verification, and teardown, and is designed for experimentation, learning, and validation of Istio Ambient Mesh in a cloud-native context.

## Prerequisites
- Azure CLI ([Install Guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli))
- kubectl ([Install Guide](https://kubernetes.io/docs/tasks/tools/))
- Bash shell (Linux/macOS or WSL on Windows)
- Azure subscription with permissions to create and delete AKS clusters and resource groups

## Project Structure
- `scripts/provision_aks_cluster.sh` – Provision and verify an AKS cluster
- `scripts/destroy_aks_cluster.sh` – Destroy the AKS cluster and resource group
- `scripts/install_gateway_api_crds.sh` – Install Gateway API CRDs
- `scripts/install_istio_ambient.sh` – Install Istio Ambient Mesh
- `scripts/verify_istio_installation.sh` – Verify Istio installation health
- `scripts/deploy_bookinfo_demo.sh` – Deploy the Bookinfo sample application (with optional external access)
- `scripts/verify_ambient_onboarding.sh` – Verify namespace onboarding to ambient mesh
- `scripts/apply_istio_features.sh` – Enable traffic management, security, and observability for Bookinfo
- `scripts/PRD.txt` – Product Requirements Document and project plan

## Usage

### 1. Provision the AKS Cluster
```bash
bash scripts/provision_aks_cluster.sh
```
- This script will create the resource group and AKS cluster (if they do not exist), retrieve credentials, and verify the cluster is ready.

### 2. Install Gateway API CRDs
```bash
bash scripts/install_gateway_api_crds.sh
```
- Installs the required Gateway API CRDs for Istio Ambient Mesh.

### 3. Install Istio Ambient Mesh
```bash
bash scripts/install_istio_ambient.sh
```
- Installs Istio with the ambient profile using istioctl.

### 4. Verify Istio Installation
```bash
bash scripts/verify_istio_installation.sh
```
- Checks that all Istio pods are running and the ztunnel DaemonSet is healthy.

### 5. Deploy the Bookinfo Sample Application
#### Local access (default):
```bash
bash scripts/deploy_bookinfo_demo.sh
```
- Use port-forward to access the app:
  ```bash
  kubectl port-forward svc/productpage 9080:9080
  # Then open http://localhost:9080/productpage in your browser
  ```

#### External access (LoadBalancer):
```bash
bash scripts/deploy_bookinfo_demo.sh --external
```
- The script will print the external URL (e.g., http://<external-ip>:9080/productpage) for browser access.

### 6. Onboard Namespace to Ambient Mesh
```bash
kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite
bash scripts/verify_ambient_onboarding.sh
```

### 7. Enable Istio Features: Traffic Management, Security, Observability
```bash
bash scripts/apply_istio_features.sh
```
- **Traffic Management:** Sets up Gateway and HTTPRoute for Bookinfo
- **Security:** Enables mTLS and applies an internal-only AuthorizationPolicy
- **Observability:** Deploys Prometheus and Kiali for metrics and mesh visualization

#### Access Kiali Dashboard
**Recommended (opens browser automatically):**
```bash
istioctl dashboard kiali
```
- This command will open Kiali in your default browser and set up port-forwarding automatically.

**Manual Port-Forward:**
```bash
kubectl port-forward svc/kiali -n istio-system 20001:20001
```
- Then open: [http://localhost:20001](http://localhost:20001) in your browser.

#### Access Prometheus Dashboard
```bash
kubectl port-forward svc/prometheus -n istio-system 9090:9090
```
- Then open: [http://localhost:9090](http://localhost:9090)

#### Generate Traffic for Kiali Visualization
To see live service graphs and metrics in Kiali, you need to generate traffic to the Bookinfo app:

**If using local port-forwarding (default):**
1. In a separate terminal, run:
   ```bash
   kubectl port-forward svc/productpage 9080:9080 -n default
   ```
2. Open your browser and visit: [http://localhost:9080/productpage](http://localhost:9080/productpage)
3. Refresh the page several times, or click around the Bookinfo UI to generate traffic.

**If using external access (with --external flag):**
- Visit the external URL printed by the script (e.g., `http://<external-ip>:9080/productpage`) and interact with the app.

**In Kiali:**
- Go to the **Graph** view and select the `default` namespace to visualize service interactions and traffic flow.

### 8. Enable Mutual TLS (mTLS)
To enforce secure service-to-service communication in the mesh, enable STRICT mutual TLS (mTLS) in the `default` namespace:

```bash
bash scripts/enable_mtls.sh
```
- This script applies a PeerAuthentication policy in the `default` namespace to require mTLS for all workloads.
- The script is idempotent and verifies that the policy is applied.

**What this does:**
- Enforces mTLS for all traffic in the `default` namespace (handled by Istio ztunnel in ambient mode).
- Ensures all service-to-service communication is encrypted and authenticated.

You can verify mTLS status in Kiali or by checking the PeerAuthentication resource:
```bash
kubectl get peerauthentication default -n default -o yaml
```

### Troubleshooting Gateway API Ingress

If you cannot access the app via the Gateway external IP:

- **Check the Gateway status:**
  ```bash
  kubectl get gateway -n default bookinfo-gateway -o yaml
  ```
  - Ensure `status.addresses` shows a public IP and `Programmed: True`.

- **If the IP is not reachable:**
  - Check Azure NSG/firewall rules for port 80.
  - Confirm the IP is public, not internal.
  - Use the Azure Portal to inspect the load balancer and its rules.

- **Workaround:**
  - You can use the LoadBalancer service for direct access, but this bypasses mesh features.

### Namespace Usage

This demo uses the `default` namespace for Bookinfo and mesh resources for simplicity. If you wish to use a different namespace (e.g., `bookinfo`), update the scripts and commands accordingly.

### Verification Steps

#### Verify Ambient Mesh Onboarding
To verify that pods are onboarded to the ambient mesh:
```bash
bash scripts/verify_ambient_onboarding.sh
```
- All pods should show as healthy and onboarded.

#### Verify Istio Installation
To check that Istio is installed and healthy:
```bash
bash scripts/verify_istio_installation.sh
```
- All Istio pods and the ztunnel DaemonSet should be running.

#### Verify mTLS
To confirm mTLS is enforced:
```bash
kubectl get peerauthentication default -n default -o yaml
```
- Look for `mode: STRICT` in the output.
- You can also check the Kiali dashboard for mTLS lock icons between services.

## Project Status

- [x] Provision AKS cluster
- [x] Install Gateway API CRDs
- [x] Install Istio Ambient Mesh
- [x] Verify Istio installation
- [x] Deploy Bookinfo sample application (local and external access)
- [x] Onboard namespace to ambient mesh (label namespace)
- [x] Enable traffic management, security, and observability features
- [x] Destroy/teardown environment

## Next Step
- **Onboard the default namespace to the ambient mesh:**
  ```bash
  kubectl label namespace default istio.io/dataplane-mode=ambient --overwrite
  ```
  This will enable ambient mesh features for all pods in the default namespace.

## References
- [Istio Ambient Mesh Getting Started](https://istio.io/latest/docs/ambient/getting-started/)
- [Azure AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)

## Cleanup

To remove all resources created by this demo, follow these steps:

### 1. Clean Up Demo Resources in the Cluster
This script removes the Bookinfo application, Gateway/HTTPRoute, Istio security policies, Kiali, Prometheus, and any generated YAML files. It leaves the AKS cluster and Istio control plane intact.

```bash
bash scripts/cleanup_demo_resources.sh
```
- **What it does:**
  - Deletes Bookinfo deployments, services, and related resources in the `default` namespace.
  - Removes Gateway and HTTPRoute resources.
  - Deletes PeerAuthentication and AuthorizationPolicy resources.
  - Removes Kiali and Prometheus addons.
  - Deletes generated YAML files (gateway.yaml, httproute.yaml, peerauth.yaml, authorizationpolicy.yaml).
- **What remains:**
  - The AKS cluster and Istio control plane are still running.

#### Optionally Remove Gateway API CRDs
If you want to remove the Gateway API CRDs from the cluster:
```bash
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```
- **Warning:** This will remove Gateway API support from your cluster.

### 2. Destroy Azure AKS Cluster and Cloud Resources
This script deletes the entire AKS cluster and its resource group, including all associated Azure resources. **This action is irreversible.**

```bash
bash scripts/destroy_aks_cluster.sh
```
- **What it does:**
  - Deletes the AKS cluster.
  - Deletes the resource group and all resources within it (load balancers, public IPs, disks, etc.).
- **Warning:** All cloud resources in the specified resource group will be permanently deleted.

### 3. Verify Deletion
- You can monitor the deletion progress in the Azure Portal or with the Azure CLI:
  ```bash
  az group show --name <your-resource-group>
  ```
  - The resource group will disappear when deletion is complete.

---

By following these steps, you can ensure your Kubernetes cluster and Azure environment are fully cleaned up after running the demo.

For more details, see the [scripts/PRD.txt](scripts/PRD.txt) for the full requirements and roadmap. 