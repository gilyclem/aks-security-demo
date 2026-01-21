# ============================================
# Demo 6: Istio Ingress Gateway with TLS
# ============================================
# Scenario: Expose store-front with HTTPS using TLS certificates from Key Vault
# Solution: Istio managed ingress + Azure Key Vault + CSI Driver add-on

$resourceGroup = "rg-aks-security-demo"
$clusterName = "aks-cilium-demo"
$location = "italynorth"
$keyVaultName = "kv-aks-demo-gc91"
$certDomain = "store-front.pet.com"

# Create Azure Key Vault with RBAC authorization
az keyvault create --name $keyVaultName --resource-group $resourceGroup --location $location --enable-rbac-authorization

# Enable Azure Key Vault provider for Secret Store CSI Driver add-on
az aks enable-addons --addons azure-keyvault-secrets-provider --resource-group $resourceGroup --name $clusterName --enable-secret-rotation

# Get CSI Driver add-on managed identity details
$clientId = az aks show --resource-group $resourceGroup --name $clusterName --query 'addonProfiles.azureKeyvaultSecretsProvider.identity.clientId' -o tsv
$objectId = az aks show --resource-group $resourceGroup --name $clusterName --query 'addonProfiles.azureKeyvaultSecretsProvider.identity.objectId' -o tsv
$tenantId = az keyvault show --resource-group $resourceGroup --name $keyVaultName --query 'properties.tenantId' -o tsv

# Get Key Vault resource ID for RBAC
$kvId = az keyvault show --resource-group $resourceGroup --name $keyVaultName --query 'id' -o tsv

# Assign Key Vault Secrets User role to CSI Driver add-on managed identity
az role assignment create --role "Key Vault Secrets User" --assignee-object-id $objectId --assignee-principal-type ServicePrincipal --scope $kvId

# Assign Key Vault Secrets Officer role to current user (to upload certificates)
$currentUser = az ad signed-in-user show --query id -o tsv
az role assignment create --role "Key Vault Secrets Officer" --assignee-object-id $currentUser --assignee-principal-type User --scope $kvId

# Generate TLS certificates
New-Item -ItemType Directory -Force -Path ".\store-front-certs" | Out-Null
$openssl = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"
if (-not (Test-Path $openssl)) { $openssl = "C:\Program Files (x86)\OpenSSL-Win64\bin\openssl.exe" }
if (-not (Test-Path $openssl)) { throw "OpenSSL not found. Install with: winget install --id ShiningLight.OpenSSL.Light" }

# Root CA certificate
& $openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=example Inc./CN=example.com' -keyout store-front-certs/example.com.key -out store-front-certs/example.com.crt

# Server certificate for store-front.example.com
& $openssl req -out store-front-certs/$certDomain.csr -newkey rsa:2048 -nodes -keyout store-front-certs/$certDomain.key -subj "/CN=$certDomain/O=store-front organization"
& $openssl x509 -req -sha256 -days 365 -CA store-front-certs/example.com.crt -CAkey store-front-certs/example.com.key -set_serial 0 -in store-front-certs/$certDomain.csr -out store-front-certs/$certDomain.crt

# Upload certificates to Key Vault
az keyvault secret set --vault-name $keyVaultName --name store-front-tls-key --file store-front-certs/$certDomain.key
az keyvault secret set --vault-name $keyVaultName --name store-front-tls-crt --file store-front-certs/$certDomain.crt

# Enable Istio service mesh add-on
az aks mesh enable --resource-group $resourceGroup --name $clusterName

# Enable Istio external ingress gateway (creates aks-istio-ingress namespace)
az aks mesh enable-ingress-gateway --resource-group $resourceGroup --name $clusterName --ingress-gateway-type external

# Deploy SecretProviderClass in aks-istio-ingress namespace
@"
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: store-front-credential-spc
  namespace: aks-istio-ingress
spec:
  provider: azure
  secretObjects:
  - secretName: store-front-credential
    type: kubernetes.io/tls
    data:
    - objectName: store-front-tls-key
      key: tls.key
    - objectName: store-front-tls-crt
      key: tls.crt
  parameters:
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$clientId"
    keyvaultName: "$keyVaultName"
    cloudName: ""
    objects: |
      array:
        - |
          objectName: store-front-tls-key
          objectType: secret
          objectAlias: "store-front-tls-key"
        - |
          objectName: store-front-tls-crt
          objectType: secret
          objectAlias: "store-front-tls-crt"
    tenantId: "$tenantId"
"@ | kubectl apply -f -

# Deploy temporary pod to trigger CSI driver sync
@"
apiVersion: v1
kind: Pod
metadata:
  name: secrets-store-sync-store-front
  namespace: aks-istio-ingress
spec:
  containers:
  - name: busybox
    image: mcr.microsoft.com/oss/busybox/busybox:1.33.1
    command:
    - "/bin/sleep"
    - "10"
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets-store"
      readOnly: true
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "store-front-credential-spc"
"@ | kubectl apply -f -

# Verify TLS secret created in aks-istio-ingress namespace
kubectl describe secret/store-front-credential -n aks-istio-ingress

# Enable Istio sidecar injection for default namespace
kubectl label namespace default istio.io/rev=asm-1-26 --overwrite

# Restart store-front to inject Istio sidecar
kubectl rollout restart deployment store-front -n default
kubectl rollout status deployment store-front -n default

# Deploy Gateway and VirtualService with TLS
@"
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: store-front-gateway
  namespace: default
spec:
  selector:
    istio: aks-istio-ingressgateway-external
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: store-front-credential
    hosts:
    - "$certDomain"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: store-front-vs
  namespace: default
spec:
  hosts:
  - "$certDomain"
  gateways:
  - store-front-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: store-front
        port:
          number: 80
"@ | kubectl apply -f -

# Get ingress gateway external IP
$ingressIP = kubectl get service aks-istio-ingressgateway-external -n aks-istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
$securePort = kubectl get service aks-istio-ingressgateway-external -n aks-istio-ingress -o jsonpath='{.spec.ports[?(@.name=="https")].port}'

# Configure hosts file for browser access (requires admin privileges)
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "$ingressIP $certDomain"

# Open browser and navigate to: https://store-front.pet.com
# Accept self-signed certificate warning
