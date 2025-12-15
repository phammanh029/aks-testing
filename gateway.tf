# Namespace for Envoy Gateway
resource "kubernetes_namespace_v1" "envoy_gateway_system" {
  metadata {
    name = "envoy-gateway-system"

    labels = {
      provisioned_by = "terraform"
    }
  }
}

data "http" "envoy_gateway_crds" {
  url = "https://github.com/envoyproxy/gateway/releases/download/v1.6.1/install.yaml"
}

# Apply the CRDs using kubectl_manifest
resource "kubectl_manifest" "envoy_gateway_crds" {
  depends_on = [data.http.envoy_gateway_crds]

  for_each = {
    for idx, manifest in [
      for doc in split("---", data.http.envoy_gateway_crds.response_body) :
      doc if length(trim(doc, " \t\n\r")) > 0 &&
      can(yamldecode(doc)) &&
      try(yamldecode(doc).kind, "") == "CustomResourceDefinition"
    ] : idx => manifest
  }

  yaml_body = each.value

  server_side_apply = true
}

resource "helm_release" "envoy_gateway_system" {

  name             = "gateway-helm"
  skip_crds        = true
  namespace        = kubernetes_namespace_V1.envoy_gateway_system.metadata[0].name
  create_namespace = false
  chart            = "gateway-helm"
  repository       = "oci://docker.io/envoyproxy"
  version          = "v1.6.1"

  values = [
    yamlencode({
      deployment = {
        envoyGateway = {
          replicas = 1
          pod = {
          }
        }
      }
      hpa = {
        enabled     = true
        minReplicas = 1
        maxReplicas = 1
      }
      config = {
        envoyGateway = {
          apiVersion = "gateway.envoyproxy.io/v1alpha1"
          kind       = "EnvoyGateway"
          gateway = {
            controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
          }
          logging = {
            level = {
              default = "info"
            }
          }
          provider = {
            kubernetes = {
              envoyService = {
                type = "ClusterIP"
              }
              rateLimitDeployment = {
                patch = {
                  type = "StrategicMerge"
                  value = {
                    spec = {
                      template = {
                        spec = {
                          containers = [
                            {
                              imagePullPolicy = "IfNotPresent"
                              name            = "envoy-ratelimit"
                              image           = "docker.io/envoyproxy/ratelimit:60d8e81b"
                            }
                          ]
                        }
                      }
                    }
                  }
                }
              }
            }
            type = "Kubernetes"
          }
          extensionApis = {
            enableEnvoyPatchPolicy = true
            enableBackend          = true
          }
          extensionManager = {
            backendResources = [
              {
                group   = "inference.networking.x-k8s.io"
                kind    = "InferencePool"
                version = "v1alpha2"
              }
            ]
            hooks = {
              xdsTranslator = {
                translation = {
                  listener = {
                    includeAll = true
                  }
                  route = {
                    includeAll = true
                  }
                  cluster = {
                    includeAll = true
                  }
                  secret = {
                    includeAll = true
                  }
                }
                post = [
                  "Translation",
                  "Cluster",
                  "Route"
                ]
              }
            }
            # service = {
            #   fqdn = {
            #     hostname = "ai-gateway-controller.envoy-ai-gateway-system.svc.cluster.local"
            #     port     = 1063
            #   }
            # }
          }
        }
      }
    })
  ]
}

resource "kubernetes_manifest" "envoy_gateway_class" {

  depends_on = [
    helm_release.envoy_gateway_system
  ]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "envoy-gateway"
    }
    spec = {
      controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
    }
  }
}


# Envoy Gateway Helm chart
resource "helm_release" "envoy_gateway" {
  name       = "envoy-gateway"
  repository = "oci://docker.io/envoyproxy/gateway-helm"
  chart      = "envoy-gateway"
  version    = "1.6.1" # pin a version you like

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
    namespace = kubernetes_namespace_v1.envoy_gateway.metadata[0].name
  }

  depends_on = [helm_release.envoy_gateway]
}
