
# AKS Security Demo - Azure CNI Powered by Cilium

## 🧑‍💻 Demo Step-by-Step

This demo consists of 6 main scenarios, each designed to showcase a best practice or advanced security/management feature on AKS:

1. **Azure CNI Powered by Cilium + ACNS + Observability**
   - Demonstrates advanced networking with Cilium (eBPF), overlay mode, ACNS, and integrated observability tools.
2. **Ingress Controller**
   - Deploy and configure an Ingress Controller for secure exposure of application services.
3. **Azure Policy**
   - Enforce policies to allow only trusted registry images and block non-compliant deployments.
4. **Maximize Availability**
   - Strategies and configurations to increase application availability (e.g., replicas, pod disruption budgets, readiness/liveness probes).
5. **GitHub Advanced Security for Azure DevOps**
   - Demonstrates advanced security features: secret scanning, code scanning, dependency scanning, and push protection.
6. **Workload Identity**
   - Passwordless authentication between Kubernetes workloads and Azure services using OIDC and Managed Identity, with no hardcoded secrets.

For each scenario, practical examples and verification commands are available in the following sections of the README.

This is a complete demo of Azure Kubernetes Service (AKS) with Azure CNI Powered by Cilium, Azure Policy for trusted Container Registry, passwordless authentication via Workload Identity, and automated deployment of the AKS Store Demo application.

## 📋 Overview

This project demonstrates how to create and configure a production-ready AKS cluster with:

- **Azure CNI Powered by Cilium**: eBPF-based network dataplane for superior performance and security
- **Overlay Mode**: Separation of pod and node networking for greater flexibility
- **ACNS (Azure Container Networking Service)**: Managed service for container networking
- **Azure Container Registry (ACR)**: Private registry with automatic authentication
- **Azure Policy**: Enforcement of trusted container registries with Deny effect
- **Workload Identity**: Passwordless authentication with Azure Service Bus using Managed Identity
- **Azure Service Bus**: Secure asynchronous messaging without hardcoded credentials
- **Automated Deployment**: PowerShell script for complete end-to-end setup

## 🏗️ Architecture

**Azure Components:**
- **Resource Group**: `rg-aks-security-demo-v6`
- **AKS Cluster**: `aks-cilium-demo-v6`
- **Azure Container Registry**: `acrdemogc93.azurecr.io`
- **Azure Service Bus**: `sbstoredemogc93.servicebus.windows.net`
- **Managed Identity**: `id-order-service` (for Workload Identity)
- **Location**: `italynorth`

**Cluster Configuration:**
- **Node Count**: 2 nodes
- **Node Size**: Standard_D2s_v3
- **Pod CIDR**: 192.168.0.0/16
- **Network Plugin**: Azure CNI + Cilium
- **Network Mode**: Overlay
- **Addons**: Azure Policy
- **OIDC Issuer**: Enabled (for Workload Identity)

**Security Features:**
- ✅ Azure Policy enforcement for trusted registries (Deny effect)
- ✅ ACR integrated with automatic AcrPull role
- ✅ Workload Identity enabled with federated credentials
- ✅ OIDC Issuer for passwordless authentication
- ✅ Service Bus with Managed Identity authentication (no password)
- ✅ Kubernetes ServiceAccount with Azure Workload Identity annotations


## 🚀 Prerequisites

### Software Requirements

- **Azure CLI** version 2.61.0 or higher
- **PowerShell** 5.1 or higher (or PowerShell Core 7.x)
- **kubectl** for managing the Kubernetes cluster
- An active Azure subscription with resource creation permissions

### Azure CLI Installation and Configuration

1. **Install Azure CLI** (if not already installed):
  - Windows: Download the [MSI installer](https://aka.ms/installazurecliwindowsx64)
  - Linux/macOS: Follow the [official instructions](https://docs.microsoft.com/cli/azure/install-azure-cli)

2. **Upgrade Azure CLI to the latest version:**
  ```powershell
  az upgrade
  ```

3. **Install the AKS Preview extension** (required for ACNS):
  ```powershell
  az extension add --name aks-preview
  ```
   
  > **Note**: The `aks-preview` extension is required to use the `--enable-acns` parameter that enables Azure Container Networking Service.

4. **Login to Azure:**
  ```powershell
  az login
  ```

5. **Check the active subscription:**
  ```powershell
  az account show
  ```

### Azure Requirements for ACNS

- **Supported regions**: Ensure that the `italynorth` region supports ACNS and Cilium
- **Feature Flags**: You may need to register preview features on your subscription:
  ```powershell
  az feature register --namespace Microsoft.ContainerService --name AzureOverlayPreview
  az feature register --namespace Microsoft.ContainerService --name CiliumDataplanePreview
  az feature register --namespace Microsoft.ContainerService --name AzureContainerNetworkingServicesPreview
  ```

- **Check feature registration:**
  ```powershell
  az feature show --namespace Microsoft.ContainerService --name AzureOverlayPreview
  az feature show --namespace Microsoft.ContainerService --name CiliumDataplanePreview
  az feature show --namespace Microsoft.ContainerService --name AzureContainerNetworkingServicesPreview
  ```

- **Update the provider** (after registration):
  ```powershell
  az provider register --namespace Microsoft.ContainerService
  ```

> **⚠️ Important**: Feature registration may take up to 10-15 minutes. Wait until the status is `Registered` before proceeding with cluster creation.

## 📦 Deployment

### What the script does

The `create-aks-cilium.ps1` script automates:

1. **Resource Group creation** in italynorth
2. **Azure Container Registry creation** (Basic SKU) with automatic cluster integration
3. **Azure Service Bus creation** with namespace, `orders` queue, and authorization rule
4. **AKS cluster creation** with:
  - Azure CNI Powered by Cilium with overlay networking
  - ACNS (Azure Container Networking Service) enabled
  - Azure Policy addon for trusted registry enforcement
  - Workload Identity and OIDC Issuer enabled
  - ACR integration with `--attach-acr` (automatic managed identity)
5. **Azure Policy configuration** to block images from untrusted registries (Deny effect)
6. **Managed Identity creation** for the order-service
7. **Workload Identity configuration:**
  - Federated credential for OIDC trust between AKS and Azure AD
  - "Azure Service Bus Data Sender" role assignment to the managed identity
  - YAML update with the managed identity client ID
8. **Application deployment** with passwordless Service Bus configuration
9. **Verification test** for policy blocking with untrusted images

### Running the script

```powershell
# Run the deployment script
./create-aks-cilium.ps1
```

The script is fully automated and requires no manual intervention.

### Deployment verification

After running the script, you can verify that everything is configured correctly:

```powershell
# Verifica il cluster
az aks show --resource-group rg-aks-security-demo-v6 --name aks-cilium-demo-v6 --query "{name:name, location:location, oidcIssuer:oidcIssuerProfile.issuerUrl, workloadIdentity:securityProfile.workloadIdentity.enabled}"

# Verifica i nodi
kubectl get nodes

# Verifica i pod di Cilium
kubectl get pods -n kube-system | Select-String cilium

# Verifica Azure Policy assignment
az policy assignment list --resource-group rg-aks-security-demo-v6 --query "[?displayName=='Kubernetes cluster containers should only use allowed images'].{name:name, effect:parameters.effect.value}"

# Verifica Service Bus
az servicebus queue show --resource-group rg-aks-security-demo-v6 --namespace-name sbstoredemogc93 --name orders --query name

# Verifica Managed Identity e federated credential
az identity show --resource-group rg-aks-security-demo-v6 --name id-order-service --query "{name:name, clientId:clientId, principalId:principalId}"

az identity federated-credential list --resource-group rg-aks-security-demo-v6 --identity-name id-order-service --query "[].{name:name, issuer:issuer, subject:subject}"

# Verifica role assignment su Service Bus
az role assignment list --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-aks-security-demo-v6/providers/Microsoft.ServiceBus/namespaces/sbstoredemogc93 --query "[?roleDefinitionName=='Azure Service Bus Data Sender'].{role:roleDefinitionName, principal:principalName}"

# Verifica l'applicazione deployata
kubectl get pods
kubectl get serviceaccount order-service-sa -o yaml

# Verifica i log del servizio order-service per confermare l'autenticazione workload identity
kubectl logs -l app=order-service --tail=50 | Select-String "workload identity"
```


## 🔧 Useful Commands

### Cluster Management

```powershell
# Get cluster credentials
az aks get-credentials --resource-group rg-aks-security-demo-v6 --name aks-cilium-demo-v6

# Show cluster status
kubectl cluster-info

# List all pods in the cluster
kubectl get pods --all-namespaces
```

### Azure Policy Test

The script already includes an automatic test, but you can also test manually:

```powershell
# Try to deploy an image from an untrusted registry (should be blocked)
kubectl apply -f aks-store-policy-deny.yaml

# Check that the pod does not start (policy in action)
kubectl get pods rabbitmq-0

# Check the blocking event
kubectl describe statefulset rabbitmq

# Cleanup the test
kubectl delete -f aks-store-policy-deny.yaml
```

The policy blocks **at the admission controller level** any image that is not from:
- `acrdemogc93.azurecr.io/*`
- `mcr.microsoft.com/*`

### Workload Identity Test

```powershell
# Check that the pod has the correct annotations
kubectl describe pod -l app=order-service

# Look for environment variables automatically injected by Workload Identity
kubectl exec -it $(kubectl get pod -l app=order-service -o jsonpath='{.items[0].metadata.name}') -- env | Select-String "AZURE"

# You should see:
# AZURE_CLIENT_ID=<managed-identity-client-id>
# AZURE_TENANT_ID=<tenant-id>
# AZURE_FEDERATED_TOKEN_FILE=/var/run/secrets/azure/tokens/azure-identity-token

# Check that messages arrive on Service Bus
# Go to Azure Portal -> Service Bus -> sbstoredemogc93 -> Queues -> orders -> Service Bus Explorer
# Or use Azure CLI:
az servicebus queue show --resource-group rg-aks-security-demo-v6 --namespace-name sbstoredemogc93 --name orders --query "countDetails.activeMessageCount"
```

### Cilium Network Test

```powershell
# Check Cilium version
kubectl exec -n kube-system -it $(kubectl get pod -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') -- cilium version

# Check Cilium status
kubectl exec -n kube-system -it $(kubectl get pod -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}') -- cilium status

# List network policies
kubectl get networkpolicies --all-namespaces
```

## 🛍️ AKS Store Demo Application

The application is automatically deployed by the script with passwordless Service Bus configuration.

### Application Architecture

The AKS Store Demo application is composed of 3 containerized microservices:

**Services:**
- **store-front** (Port 8080): Web frontend
  - User interface to view products and place orders
  - Exposed via LoadBalancer for public access
  - Image: `ghcr.io/azure-samples/aks-store-demo/store-front:2.1.0`

- **product-service** (Port 3002): Product catalog service (Go)
  - REST API for product catalog management
  - Image: `ghcr.io/azure-samples/aks-store-demo/product-service:2.1.0`

- **order-service** (Port 3000): Order management service (Node.js/Fastify)
  - Handles order creation and processing
  - **Integrated with Azure Service Bus** for asynchronous messaging
  - **Passwordless authentication** via Workload Identity and DefaultAzureCredential
  - SDK: `@azure/service-bus` + `@azure/identity`
  - Image: `ghcr.io/azure-samples/aks-store-demo/order-service:2.1.0`

**Azure Infrastructure:**
- **Azure Container Registry (ACR)**: `acrdemogc93.azurecr.io` - trusted registry for custom images
- **Azure Service Bus**: `sbstoredemogc93.servicebus.windows.net` - `orders` queue for messaging
- **Managed Identity**: `id-order-service` - identity for passwordless authentication
- **Azure Kubernetes Service (AKS)**: cluster with Cilium CNI and Workload Identity

### Passwordless Authentication

The `order-service` uses **Workload Identity** to authenticate with Azure Service Bus **without passwords**:

1. **Kubernetes ServiceAccount** with `azure.workload.identity/client-id` annotation
2. **Pod label** `azure.workload.identity/use: "true"`
3. **Federated Credential** establishing OIDC trust between the ServiceAccount and the Managed Identity
4. **DefaultAzureCredential** in code that automatically detects the Kubernetes token
5. **Token exchange**: JWT token → Azure AD token → access to Service Bus

No password, connection string, or secret is hardcoded in the code or YAML files.

### Application Access

```powershell
# Check services
kubectl get services

# Get the external IP of the LoadBalancer (may take a few minutes)
kubectl get service store-front -w

# Or extract the IP directly
$storeIP = kubectl get service store-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "Application available at: http://$storeIP"
```

Access the application in your browser at `http://<EXTERNAL-IP>`

## 🌐 Demo #2: Ingress Controller with Kubernetes Gateway API

This demo focuses on configuring and using an Ingress Controller with the **Kubernetes Gateway API** (preview) - the modern, Kubernetes-native standard for ingress traffic management.

### Demo Overview

In this demo you will:
- Enable Istio service mesh as infrastructure prerequisite
- **Enable Kubernetes Gateway API** (preview feature)
- Deploy an application with Istio sidecar injection
- **Configure Kubernetes Gateway and HTTPRoute** resources
- **Test advanced L7 routing** with automatic resource management
- **Monitor ingress traffic** and verify security features

### Why Kubernetes Gateway API?

**Kubernetes Gateway API** is the successor to Kubernetes Ingress and offers:
- ✅ **Standard K8s API** - Official Kubernetes project (gateway.networking.k8s.io)
- ✅ **Automatic resource management** - Auto-creates Deployment, Service, HPA, PDB
- ✅ **Role-oriented design** - Separation of concerns for cluster operators and app developers
- ✅ **Advanced routing** - Header-based, path-based, weighted traffic splitting
- ✅ **Multiple implementations** - Works with Istio, NGINX, Envoy, and others

### Prerequisites

- AKS cluster already created (from Demo #1)
- `kubectl` configured with cluster credentials
- **Istio addon version `asm-1-26` or higher** (for Gateway API support)

---

## Part 1: Setup - Enable Istio and Gateway API

First, enable Istio and the Kubernetes Gateway API feature.

### Step 1.1: Enable Istio Addon (v1.26+)

```powershell
# Enable Istio addon on AKS with minimum version asm-1-26 for Gateway API support
az aks mesh enable --resource-group rg-aks-security-demo-v6 --name aks-cilium-demo-v6 --revision asm-1-26

# Verify Istio control plane is running
kubectl get pods -n aks-istio-system

# Check Istio version
kubectl get deployment -n aks-istio-system istiod-asm-1-26 -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Expected output: Istio control plane pods (istiod) running in `aks-istio-system` namespace.

### Step 1.2: Enable Managed Gateway API (Preview)

```powershell
# Enable Kubernetes Gateway API feature (preview)
az aks mesh enable-managed-gateway-api --resource-group rg-aks-security-demo-v6 --name aks-cilium-demo-v6

# Verify Gateway API CRDs are installed
kubectl get crd | Select-String gateway

# Check for GatewayClass
kubectl get gatewayclass
```

Expected output: Gateway API CRDs installed and `istio` GatewayClass available.

### Step 1.3: Verify Gateway API ConfigMap

```powershell
# Wait for the default ConfigMap to be created (may take 2-5 minutes)
kubectl wait --for=condition=ready configmap/istio-gateway-class-defaults -n aks-istio-system --timeout=300s

# View default Gateway settings
kubectl get configmap istio-gateway-class-defaults -n aks-istio-system -o yaml
```

### Step 1.4: Prepare Application Namespace

```powershell
# Create namespace for the application
kubectl create namespace pets

# Label namespace for automatic Istio sidecar injection
kubectl label namespace pets istio.io/rev=asm-1-26

# Verify the label
kubectl get namespace pets --show-labels
```

---

## Part 2: Ingress Controller Demo - Kubernetes Gateway API

Now let's focus on the **Ingress Controller** using the modern Kubernetes Gateway API.

### Step 2.1: Deploy Application with Sidecar Injection

```powershell
# Deploy AKS Store Demo application
kubectl apply -f aks-store-demo/aks-store-quickstart.yaml -n pets

# Wait for pods to be ready
kubectl get pods -n pets -w

# Verify each pod has 2 containers: app + istio-proxy sidecar
kubectl get pods -n pets
```

### Step 2.2: Create Kubernetes Gateway (Standard API)

This is the core of the demo - using the **Kubernetes Gateway API** standard.

```powershell
# Create Gateway resource with gatewayClassName: istio
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: store-front-gateway
  namespace: pets
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
EOF

# Verify Gateway is created
kubectl get gateway -n pets
kubectl describe gateway store-front-gateway -n pets
```

**What just happened?**
The Gateway API **automatically created** these resources:
- ✅ **Deployment** - Gateway pods (min 2 replicas by default)
- ✅ **Service** - LoadBalancer to expose the gateway
- ✅ **HorizontalPodAutoscaler** - Auto-scaling configuration
- ✅ **PodDisruptionBudget** - High availability protection

### Step 2.3: Verify Auto-Created Resources

```powershell
# Check the auto-generated Deployment
kubectl get deployment -n pets
kubectl get deployment store-front-gateway-istio -n pets

# Check the LoadBalancer Service
kubectl get service -n pets
kubectl get service store-front-gateway-istio -n pets

# Check HPA (Horizontal Pod Autoscaler)
kubectl get hpa -n pets
kubectl get hpa store-front-gateway-istio -n pets

# Check PDB (Pod Disruption Budget)
kubectl get pdb -n pets
kubectl get pdb store-front-gateway-istio -n pets
```

### Step 2.4: Create HTTPRoute for Traffic Routing

Now create an HTTPRoute to route traffic from the Gateway to the application.

```powershell
# Create HTTPRoute resource
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: store-front-route
  namespace: pets
spec:
  parentRefs:
  - name: store-front-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: store-front
      port: 80
EOF

# Verify HTTPRoute
kubectl get httproute -n pets
kubectl describe httproute store-front-route -n pets
```

**Key concepts:**
- **Gateway**: Defines the ingress point (ports, protocols, listeners) - Kubernetes standard API
- **HTTPRoute**: Routes HTTP traffic from Gateway to backend services - Kubernetes standard API
- **Automatic Management**: Deployment, Service, HPA, PDB created automatically

### Step 2.5: Get Gateway External IP

```powershell
# Wait for Gateway to be programmed
kubectl wait --for=condition=programmed gateway/store-front-gateway -n pets --timeout=300s

# Get the external LoadBalancer IP
$ingressIP = kubectl get gateway store-front-gateway -n pets -o jsonpath='{.status.addresses[0].value}'

# Alternatively, get it from the Service
kubectl get service store-front-gateway-istio -n pets

Write-Host "`nGateway URL: http://$ingressIP`n" -ForegroundColor Green
```

### Step 2.6: Test Application via Gateway

```powershell
# Open in browser
Start-Process "http://$ingressIP"

# Or test with curl
curl http://$ingressIP

# Check response headers (notice Istio headers)
curl -I http://$ingressIP
```

---

## Part 3: Gateway API Advanced Features

### Inspect Gateway and HTTPRoute Configuration

```powershell
# View Gateway configuration in detail
kubectl get gateway store-front-gateway -n pets -o yaml

# View HTTPRoute routing rules
kubectl get httproute store-front-route -n pets -o yaml

# Check gateway pod logs
kubectl logs -n pets -l gateway.networking.k8s.io/gateway-name=store-front-gateway --tail=50
```

### View Auto-Generated Resource Details

```powershell
# Inspect Deployment details
kubectl describe deployment store-front-gateway-istio -n pets

# Check HPA metrics and scaling
kubectl describe hpa store-front-gateway-istio -n pets

# View PDB configuration
kubectl describe pdb store-front-gateway-istio -n pets
```

### Test Ingress Traffic Routing

```powershell
# Send multiple requests to see routing
for ($i=1; $i -le 10; $i++) {
    Write-Host "Request $i:"
    curl -s "http://$ingressIP" | Select-String -Pattern "<title>"
}
```

### Verify Ingress Security (mTLS)

```powershell
# Check that backend services use ClusterIP (not exposed directly)
kubectl get svc -n pets

# Verify mTLS is enabled between ingress and backend
kubectl exec -n pets $(kubectl get pod -n pets -l app=store-front -o jsonpath='{.items[0].metadata.name}') -c istio-proxy -- curl -s localhost:15000/config_dump | Select-String "mode"
```

### Monitor Gateway Metrics

```powershell
# Check gateway pod metrics
$gatewayPod = kubectl get pod -n pets -l gateway.networking.k8s.io/gateway-name=store-front-gateway -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n pets $gatewayPod -- curl -s localhost:15020/stats/prometheus | Select-String "istio_requests_total"
```

### Customize Gateway Resources via ConfigMap

You can customize HPA, PDB, and Deployment settings:

```powershell
# Create a ConfigMap to customize Gateway resources
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: store-gateway-config
  namespace: pets
data:
  horizontalPodAutoscaler: |
    spec:
      minReplicas: 3
      maxReplicas: 10
  deployment: |
    metadata:
      labels:
        custom-label: "demo-gateway"
EOF

# Update Gateway to reference the ConfigMap
kubectl patch gateway store-front-gateway -n pets --type=merge -p '
spec:
  infrastructure:
    parametersRef:
      group: ""
      kind: ConfigMap
      name: store-gateway-config
'

# Verify HPA is updated
kubectl get hpa store-front-gateway-istio -n pets
```

---

## Ingress Controller Demo - Key Takeaways

- ✅ **Kubernetes Gateway API**: Official K8s standard for ingress (gateway.networking.k8s.io/v1)
- ✅ **Automatic Resource Management**: Deployment, Service, HPA, PDB auto-created
- ✅ **Gateway Resource**: Configures listeners, ports, protocols - K8s standard
- ✅ **HTTPRoute**: L7 routing rules (path, headers, weights) - K8s standard
- ✅ **Role-oriented Design**: Separation between infrastructure (Gateway) and routes (HTTPRoute)
- ✅ **Automatic mTLS**: Traffic encrypted from gateway to backend services
- ✅ **Centralized Entry Point**: Single external IP for all services
- ✅ **Azure Managed**: Fully managed by Azure with preview support
- ✅ **Future-proof**: Gateway API is the successor to Kubernetes Ingress

### API Comparison

| Feature | Istio Gateway API | Kubernetes Gateway API (Preview) |
|---------|-------------------|----------------------------------|
| API Group | networking.istio.io | gateway.networking.k8s.io |
| Status | GA (Production) | Preview |
| Standard | Istio-specific | Kubernetes official standard |
| Resource Management | Manual | **Automatic** (Deployment/HPA/PDB) |
| Maturity | Stable | Evolving (K8s SIG Network) |
| Future | Maintained | **Long-term K8s standard** |

### Ingress vs LoadBalancer Comparison

| Feature | LoadBalancer (Demo #1) | Gateway API (Demo #2) |
|---------|------------------------|------------------------|
| External IPs | One per service | One for all services |
| Routing | L4 (TCP/UDP) | L7 (HTTP/HTTPS) |
| TLS Termination | No | Yes |
| Path-based routing | No | Yes |
| Host-based routing | No | Yes |
| Auto-scaling | Manual | Automatic (HPA) |
| Resource Management | Manual | Automatic |
| Cost | Higher (multiple IPs) | Lower (single IP) |

---

## Cleanup Gateway API Demo

```powershell
# Delete HTTPRoute and Gateway
kubectl delete httproute store-front-route -n pets
kubectl delete gateway store-front-gateway -n pets

# Verify auto-created resources are cleaned up
kubectl get deployment,service,hpa,pdb -n pets

# Delete application namespace
kubectl delete namespace pets

# (Optional) Disable Gateway API feature
az aks mesh disable-managed-gateway-api --resource-group rg-aks-security-demo-v6 --name aks-cilium-demo-v6

# (Optional) Disable Istio completely
az aks mesh disable --resource-group rg-aks-security-demo-v6 --name aks-cilium-demo-v6
```

## 🧹 Cleanup

To delete all created resources:

```powershell
# Delete the resource group (this will remove the cluster, ACR, Service Bus, Managed Identity, and all associated resources)
az group delete --name rg-aks-security-demo-v6 --yes --no-wait
```

The `--no-wait` flag starts the deletion in the background without waiting for completion.

## 📚 References

### Azure Documentation

- [Azure CNI Powered by Cilium](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium)
- [Azure CNI Overlay](https://learn.microsoft.com/azure/aks/azure-cni-overlay)
- [Azure Container Networking Service](https://learn.microsoft.com/azure/aks/advanced-container-networking-services-overview)
- [Azure Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-overview)
- [Azure Policy for AKS](https://learn.microsoft.com/azure/aks/use-azure-policy)
- [Azure Service Bus](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-messaging-overview)
- [DefaultAzureCredential](https://learn.microsoft.com/dotnet/api/azure.identity.defaultazurecredential)

### Cilium Documentation

- [Cilium Documentation](https://docs.cilium.io/)
- [eBPF - Extended Berkeley Packet Filter](https://ebpf.io/)

### Application Repository

- [AKS Store Demo - GitHub](https://github.com/Azure-Samples/aks-store-demo)

## 🔐 Security Features

### Azure Policy for Container Registry

The cluster has an Azure policy with **Deny effect** that blocks deployment of images from unauthorized registries:

- **Policy**: Kubernetes cluster containers should only use allowed images (built-in)
- **Effect**: **Deny** (admission webhook blocking)
- **Trusted registries**:
  - `acrdemogc93.azurecr.io/*` - your private ACR
  - `mcr.microsoft.com/*` - Microsoft Container Registry (system images)

Any attempt to deploy images from Docker Hub, GHCR, or other registries is **automatically blocked** by the policy addon.

### Workload Identity for Service Bus

**Passwordless authentication** between Kubernetes and Azure Service Bus:

- ✅ **No password** or connection string in code
- ✅ **No Kubernetes Secret** to manage
- ✅ **OIDC tokens** issued by AKS and exchanged with Azure AD
- ✅ **DefaultAzureCredential** automatically detects the workload identity environment
- ✅ **Federated Credential** establishes trust between Kubernetes ServiceAccount and Azure Managed Identity
- ✅ **Role-based access** via Azure RBAC (Azure Service Bus Data Sender)

**Authentication flow:**
```
Pod order-service
  ↓ (uses ServiceAccount order-service-sa)
AKS Workload Identity Webhook injects:
  - AZURE_CLIENT_ID
  - AZURE_TENANT_ID  
  - AZURE_FEDERATED_TOKEN_FILE (JWT token)
  ↓
DefaultAzureCredential reads the token
  ↓
Token exchange with Azure AD (federated credential)
  ↓
Azure AD token with Service Bus scope
  ↓
Access to Service Bus via Managed Identity
```

### Cilium and eBPF

Cilium provides advanced kernel-level security features:

- **eBPF-based Network Policies**: High-performance network policies
- **Identity-based Security**: Security based on workload identity
- **Transparent Encryption**: Transparent encryption of pod-to-pod traffic (optional)
- **API-aware Network Security**: L7 security (HTTP, gRPC, Kafka)
- **Observability**: Full network traffic visibility

## 🔒 GitHub Advanced Security Demo

This repository includes a demonstration of **GitHub Advanced Security** (GHAS) features to detect and prevent code vulnerabilities:

### Intentional Vulnerability: Hardcoded Secret

The file `aks-store-demo/aks-store-quickstart.yaml` **intentionally** contains a hardcoded Azure Service Bus key:

```yaml
- name: ORDER_QUEUE_PASSWORD
  value: "E1nW178O3LepYk0s3iZuolHRwQks9f6Ne-ASbOfKAG4$"
```

This is a **bad security practice** that GHAS automatically detects.

### Demonstrated GHAS Features

**1️⃣ Secret Scanning**
- Automatically detects hardcoded credentials and secrets in code
- Identifies the Service Bus key in `aks-store-quickstart.yaml`
- Alerts visible in the "Advanced Security" tab in Azure DevOps or GitHub

**2️⃣ Push Protection**
- Blocks commits containing new secrets
- Prevents accidental credential leaks in the repository
- Test: Try adding this fake AWS secret and commit:
  ```
  # AWS Access Key: AKIAIOSFODNN7EXAMPLE
  ```

**3️⃣ Code Scanning (CodeQL)**
- Static code analysis for security vulnerabilities
- Supports Go, JavaScript, Rust, Python in the application
- Identifies insecure code patterns (SQL injection, XSS, etc.)

**4️⃣ Dependency Scanning**
- Detects vulnerabilities in npm, Go modules, Cargo crates dependencies
- Automatic alerts for known CVEs
- Automatic update suggestions

### Solution: Workload Identity (Passwordless)

The file `aks-store-demo/aks-store-workload-id.yaml` shows the **secure version**:
- ❌ No hardcoded password
- ✅ Authentication via Azure Managed Identity
- ✅ OIDC token for Service Bus access
- ✅ Zero-trust security model

### How to Enable GHAS

**On GitHub (public repositories - free):**
1. Settings → Code security and analysis
2. Enable: Secret scanning, Push protection, Dependabot, CodeQL

**On Azure DevOps:**
1. Install the "Advanced Security" extension
2. Project Settings → Repositories → Advanced Security
3. Enable: Secret scanning, Code scanning, Dependency scanning

## 📝 Notes

- The cluster uses Azure CNI in overlay mode to separate pod and node networking
- ACNS provides advanced networking, telemetry, and troubleshooting features
- SSH keys are automatically generated during cluster creation
- **No password or secret** is saved in YAML files thanks to Workload Identity
- Service Bus authentication is performed via OIDC token, with no hardcoded credentials
- Azure Policy blocks deployments at the admission controller level (before pod creation)
- The file `aks-store-workload-id.yaml` contains the managed identity client ID (public value, not a secret)

## 🎯 Use Cases

This project is ideal to demonstrate:

- ✅ AKS security best practices (no hardcoded secrets)
- ✅ Advanced networking with Cilium and eBPF
- ✅ Automatic policy enforcement for container images
- ✅ Passwordless authentication with Azure services
- ✅ Microservices architecture on Kubernetes
- ✅ Complete deployment automation with PowerShell
- ✅ Integration between AKS and managed Azure services (ACR, Service Bus)

## 📄 License

This project is for demonstration and educational purposes only.
