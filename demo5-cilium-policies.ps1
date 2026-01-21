# ============================================
# Demo 5: Cilium Network Policies + ACNS + Observability
# ============================================
# Scenario: Secure pod-to-pod communication with L3/L4 and L7 network policies
# Solution: Cilium Network Policies + Hubble for observability

$resourceGroup = "rg-aks-security-demo"
$clusterName = "aks-cilium-demo"

# Enable L7 Policy Preview feature
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingL7PolicyPreview"
az provider register --namespace Microsoft.ContainerService

# Enable L7 policies on the cluster
az aks update --resource-group $resourceGroup --name $clusterName --acns-advanced-networkpolicies L7

# Create L3/L4 Network Policy: deny all ingress to order-service, allow only from store-front
@"
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: order-service-l4-policy
spec:
  endpointSelector:
    matchLabels:
      app: order-service
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: store-front
    toPorts:
    - ports:
      - port: "3000"
        protocol: TCP
"@ | kubectl apply -f -

# Create L7 HTTP Policy: allow only POST to /orders endpoint
@"
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: order-service-l7-policy
spec:
  endpointSelector:
    matchLabels:
      app: order-service
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: store-front
    toPorts:
    - ports:
      - port: "3000"
        protocol: TCP
      rules:
        http:
        - method: "POST"
          path: "/orders"
"@ | kubectl apply -f -

# Create egress policy: order-service can only connect to Service Bus
@"
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: order-service-egress
spec:
  endpointSelector:
    matchLabels:
      app: order-service
  egress:
  - toEndpoints:
    - matchLabels:
        "k8s:io.kubernetes.pod.namespace": kube-system
  - toFQDNs:
    - matchName: "sbstoredemogc91.servicebus.windows.net"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
      - port: "5671"
        protocol: TCP
      - port: "5672"
        protocol: TCP
"@ | kubectl apply -f -

# Verify policies
kubectl get ciliumnetworkpolicies

# Test 1: Access from pod without store-front label (BLOCKED by L4 policy - no matching label)
kubectl run curl-test --rm -it --image=curlimages/curl:latest --restart=Never --annotations="sidecar.istio.io/inject=false" -- curl -m 5 http://order-service:3000/health

# View Cilium logs for network flow information
kubectl logs -n kube-system -l k8s-app=cilium --tail=50 | Select-String "policy"
