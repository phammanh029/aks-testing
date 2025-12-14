resource "kubernetes_namespace" "gateway" {
  metadata {
    name = "gateways"
  }
}

# Shared Gateway exposed via Envoy's LoadBalancer
resource "kubernetes_manifest" "shared_gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "shared-gw"
      namespace = kubernetes_namespace.gateway.metadata[0].name
    }
    spec = {
      gatewayClassName = "envoy-gateway-class"
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          hostname = "*.demo.local"
          allowedRoutes = {
            namespaces = {
              from = "Selector"
              selector = {
                matchLabels = {
                  expose-via-envoy = "true"
                }
              }
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.envoy_gateway]
}

# One HTTPRoute per app namespace
resource "kubernetes_manifest" "app_route" {
  for_each = local.frontends

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${each.key}-route"
      namespace = kubernetes_namespace.frontend[each.key].metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name      = kubernetes_manifest.shared_gateway.manifest.metadata.name
          namespace = kubernetes_namespace.gateway.metadata[0].name
        }
      ]
      hostnames = ["${each.key}.demo.local"]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = kubernetes_service.frontend[each.key].metadata[0].name
              port = 80
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_deployment.frontend,
    kubernetes_service.frontend,
    kubernetes_manifest.shared_gateway,
  ]
}
