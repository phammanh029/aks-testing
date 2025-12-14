# Namespace for Envoy Gateway
resource "kubernetes_namespace" "envoy_gateway" {
  metadata {
    name = "envoy-gateway-system"
  }
}

# Envoy Gateway Helm chart
resource "helm_release" "envoy_gateway" {
  name       = "envoy-gateway"
  repository = "https://gateway.envoyproxy.io/helm"
  chart      = "envoy-gateway"
  version    = "1.3.0" # pin a version you like

  namespace        = kubernetes_namespace.envoy_gateway.metadata[0].name
  create_namespace = false

  # Minimal values – expose Envoy as public LoadBalancer
  values = [<<-YAML
    envoyGateway:
      provider:
        type: Kubernetes
        kubernetes:
          envoyService:
            type: LoadBalancer

    gateway:
      # install Gateway API CRDs
      gatewayClass:
        name: envoy-gateway-class
  YAML
  ]
}

# Read the LoadBalancer service created by the Envoy Gateway chart so we can output its external IP/hostname
data "kubernetes_service" "envoy_gateway_lb" {
  metadata {
    name      = helm_release.envoy_gateway.name
    namespace = kubernetes_namespace.envoy_gateway.metadata[0].name
  }

  depends_on = [helm_release.envoy_gateway]
}
