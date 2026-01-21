# ============================================
# Demo 7: Complete Cleanup Script
# ============================================
# Purpose: Reset AKS cluster to clean state for demos
# Use this when you need to start fresh after testing multiple scenarios

# Parameters
$resourceGroup = "rg-aks-security-demo"
$clusterName = "aks-cilium-demo"
$serviceBusNamespace = "sbstoredemogc91"

# Get credentials to ensure we're connected
az aks get-credentials --resource-group $resourceGroup --name $clusterName --overwrite-existing

kubectl get all --all-namespaces | Select-String -Pattern "default|aks-istio" | Out-String -Width 200

# Delete all resources in default namespace
kubectl delete all --all -n default --ignore-not-found=true

# Delete ConfigMaps, Secrets, PVCs (keep default service account)
kubectl delete configmap --all -n default --ignore-not-found=true
kubectl delete secret --all -n default --field-selector type!=kubernetes.io/service-account-token --ignore-not-found=true
kubectl delete pvc --all -n default --ignore-not-found=true

# Delete ServiceAccounts (except default)
$serviceAccounts = kubectl get serviceaccount -n default -o jsonpath='{.items[?(@.metadata.name!="default")].metadata.name}'
if ($serviceAccounts) {
    $serviceAccounts -split ' ' | ForEach-Object {
        kubectl delete serviceaccount $_ -n default --ignore-not-found=true
    }
}

# Delete Istio resources in default namespace
kubectl delete gateway --all -n default --ignore-not-found=true 2>$null
kubectl delete virtualservice --all -n default --ignore-not-found=true 2>$null
kubectl delete destinationrule --all -n default --ignore-not-found=true 2>$null
kubectl delete peerauthentication --all -n default --ignore-not-found=true 2>$null
kubectl delete authorizationpolicy --all -n default --ignore-not-found=true 2>$null

# Delete aks-istio-ingress namespace if exists
$istioNamespace = kubectl get namespace aks-istio-ingress --ignore-not-found=true -o name
if ($istioNamespace) {
    kubectl delete namespace aks-istio-ingress --ignore-not-found=true
}

# Cleanup Cilium NetworkPolicies
kubectl delete networkpolicy --all -n default --ignore-not-found=true
kubectl delete ciliumnetworkpolicy --all -n default --ignore-not-found=true 2>$null

# Cleanup Key Vault CSI resources
kubectl delete secretproviderclass --all -n default --ignore-not-found=true 2>$null

# Cleanup Workload Identity resources
kubectl delete serviceaccount --all -n default --field-selector metadata.name!=default --ignore-not-found=true

