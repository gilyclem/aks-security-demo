# ============================================
# Demo 3: Workload Identity (Remediation)
# ============================================
# Scenario: Remove hardcoded secrets detected in Demo 2
# Solution: Azure Workload Identity - no credentials in code

$resourceGroup = "rg-aks-security-demo"
$clusterName = "aks-cilium-demo"
$serviceBusNamespace = "sbstoredemogc91"
$serviceBusQueue = "orders"
$identityName = "id-order-service"
$serviceAccountNamespace = "default"
$serviceAccountName = "order-service-sa"

# Get AKS OIDC issuer
$oidcIssuer = az aks show --resource-group $resourceGroup --name $clusterName --query "oidcIssuerProfile.issuerUrl" -o tsv

# Create managed identity
az identity create --name $identityName --resource-group $resourceGroup --location italynorth

$identityClientId = az identity show --name $identityName --resource-group $resourceGroup --query clientId -o tsv
$identityPrincipalId = az identity show --name $identityName --resource-group $resourceGroup --query principalId -o tsv

# Assign Azure Service Bus Data Sender role
$serviceBusId = az servicebus namespace show --name $serviceBusNamespace --resource-group $resourceGroup --query id -o tsv
az role assignment create --role "Azure Service Bus Data Sender" --assignee $identityPrincipalId --scope "$serviceBusId/queues/$serviceBusQueue"

# Configure federated credential
az identity federated-credential create --name "fc-order-service" --identity-name $identityName --resource-group $resourceGroup --issuer $oidcIssuer --subject "system:serviceaccount:${serviceAccountNamespace}:${serviceAccountName}"

# Create Kubernetes ServiceAccount
@"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $serviceAccountName
  namespace: $serviceAccountNamespace
  annotations:
    azure.workload.identity/client-id: $identityClientId
"@ | kubectl apply -f -

# Update order-service deployment with Workload Identity
kubectl set serviceaccount deployment/order-service $serviceAccountName
$patchJson = @"
{
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "azure.workload.identity/use": "true"
        }
      },
      "spec": {
        "containers": [{
          "name": "order-service",
          "env": [
            {"name": "ORDER_QUEUE_HOSTNAME", "value": "$serviceBusNamespace.servicebus.windows.net"},
            {"name": "USE_WORKLOAD_IDENTITY_AUTH", "value": "true"}
          ]
        }]
      }
    }
  }
}
"@
kubectl patch deployment order-service -p $patchJson

# Verify Workload Identity configuration
$podName = kubectl get pod -l app=order-service -o jsonpath='{.items[0].metadata.name}'
kubectl describe pod $podName | Select-String "azure.workload.identity","ServiceAccount"
kubectl exec $podName -- env | Select-String "AZURE_"
kubectl logs $podName --tail=20
