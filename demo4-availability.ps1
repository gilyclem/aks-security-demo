# ============================================
# Demo 4: Maximize Availability
# ============================================
# Scenario: Guarantee high availability during maintenance/disruptions
# Solution: PodDisruptionBudgets, health probes, multi-replica

$resourceGroup = "rg-aks-security-demo"
$clusterName = "aks-cilium-demo"

# Scale deployments to 3 replicas for high availability
kubectl scale deployment/order-service --replicas=3
kubectl scale deployment/product-service --replicas=3
kubectl scale deployment/store-front --replicas=3

# Create PodDisruptionBudgets
@"
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: order-service-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: order-service
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: product-service-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: product-service
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: store-front-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: store-front
"@ | kubectl apply -f -

# Verify PDB
kubectl get pdb

# Test disruption: drain a node
$nodeName = kubectl get nodes -o jsonpath='{.items[0].metadata.name}'

kubectl drain $nodeName --ignore-daemonsets --delete-emptydir-data --timeout=60s

# Uncordon node
kubectl uncordon $nodeName
