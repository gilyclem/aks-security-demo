# Demo 1: Azure Policy - Trusted Container Registries
# This demo shows how to enforce container image policies on AKS

# Parameters
$resourceGroup = "rg-aks-security-demo"
$clusterName = "aks-cilium-demo"
$location = "italynorth"
$acrName = "acrdemogc91"
$serviceBusNamespace = "sbstoredemogc91"

# Create resource group
az group create --name $resourceGroup --location $location

# Create Azure Container Registry
az acr create --resource-group $resourceGroup --name $acrName --sku Basic --location $location

# Create Azure Service Bus namespace and queue
az servicebus namespace create --name $serviceBusNamespace --resource-group $resourceGroup --location $location
az servicebus queue create --name orders --resource-group $resourceGroup --namespace-name $serviceBusNamespace

# Create authorization rule for sending messages (connection string approach)
az servicebus queue authorization-rule create --name sender --namespace-name $serviceBusNamespace --resource-group $resourceGroup --queue-name orders --rights Send

# Get connection string (this will be detected by GitHub Advanced Security)
$serviceBusConnectionString = az servicebus queue authorization-rule keys list --namespace-name $serviceBusNamespace --resource-group $resourceGroup --queue-name orders --name sender --query primaryConnectionString -o tsv

# Extract SharedAccessKey from connection string for YAML
$serviceBusKey = ($serviceBusConnectionString -split ';' | Where-Object { $_ -like 'SharedAccessKey=*' }) -replace 'SharedAccessKey=', ''

# Assign read permission to current user for monitoring
$currentUserId = az ad signed-in-user show --query id -o tsv
$serviceBusId = az servicebus namespace show --name $serviceBusNamespace --resource-group $resourceGroup --query id -o tsv
az role assignment create --role "Azure Service Bus Data Receiver" --assignee $currentUserId --scope $serviceBusId

# Create AKS cluster with Azure CNI Powered by Cilium + Overlay + ACNS + Workload Identity + Azure Policy
az aks create --resource-group $resourceGroup --name $clusterName --network-plugin azure --network-plugin-mode overlay --network-dataplane cilium --pod-cidr 192.168.0.0/16 --enable-acns --enable-oidc-issuer --enable-workload-identity --enable-addons azure-policy --node-count 2 --node-vm-size Standard_D2s_v3 --generate-ssh-keys --attach-acr $acrName

# Configure Azure Policy to allow only images from trusted registries
$aksId = az aks show --resource-group $resourceGroup --name $clusterName --query id -o tsv
$allowedRegistries = @(
    "$acrName.azurecr.io"
    "mcr.microsoft.com"
)

$policyParameters = @{
    allowedContainerImagesRegex = @{
        value = "^(" + ($allowedRegistries -join '|') + ")/.+`$"
    }
    effect = @{
        value = "Deny"
    }
}

$paramsFile = "policy-params.json"
$policyParameters | ConvertTo-Json -Depth 10 | Out-File -FilePath $paramsFile -Encoding utf8

az policy assignment create --name "allowed-container-registries" --display-name "Allowed Container Registries - Only Trusted Sources" --scope $aksId --policy "febd0533-8e55-448f-b837-bd0e06f16469" --params "@$paramsFile"

Remove-Item $paramsFile

# Build and push Docker images to ACR
az acr import --name $acrName --source ghcr.io/azure-samples/aks-store-demo/product-service:latest --image aks-store-demo/product-service:latest
az acr build --registry $acrName --image aks-store-demo/order-service:latest ./aks-store-demo/src/order-service/
az acr build --registry $acrName --image aks-store-demo/store-front:latest ./aks-store-demo/src/store-front/

# List images in ACR
az acr repository list --name $acrName --output table

# Get credentials
az aks get-credentials --resource-group $resourceGroup --name $clusterName --overwrite-existing

# Replace Service Bus key in YAML (hardcoded - bad practice for GHAS demo)
# This file will be committed to Git for GitHub Advanced Security to detect the exposed secret
$deployYaml = "./aks-store-demo/aks-store-quickstart-deployed.yaml"
(Get-Content ./aks-store-demo/aks-store-quickstart.yaml) -replace 'REPLACE_WITH_SERVICEBUS_KEY', $serviceBusKey | Set-Content $deployYaml

# Deploy application
kubectl apply -f $deployYaml

# Show pod status
kubectl get pods

# Show services and store-front external IP
kubectl get service store-front
# Test store-front: http://<EXTERNAL_IP>/api/products

# Test Azure Policy - Deploy a non-trusted image (from docker.io) to verify policy enforcement
# NOTE: This YAML contains TWO security issues for GitHub Advanced Security demo:
#   1. Container image from docker.io (NOT in allowed registries - policy will block this)
#   2. Hardcoded credentials (RABBITMQ_DEFAULT_USER/PASS - GHAS should detect these)

kubectl apply -f ./aks-store-demo/aks-store-demo-1-policy-acr.yaml

kubectl describe statefulset rabbitmq

# Cleanup test
kubectl delete -f ./aks-store-demo/aks-store-demo-1-policy-acr.yaml
