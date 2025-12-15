locals {
  frontends = {
    app1 = {
      image = "nginxdemos/hello:plain-text"
      port  = 80
    }
    app2 = {
      image = "hashicorp/http-echo:0.2.3"
      port  = 80
      args  = ["-listen=:80", "-text=hello from app2"]
    }
  }
}

resource "kubernetes_namespace_v1" "frontend" {
  for_each = local.frontends

  metadata {
    name   = each.key
    labels = { expose-via-envoy = "true" }
  }
}

resource "kubernetes_deployment" "frontend" {
  for_each = local.frontends

  metadata {
    name      = "${each.key}-deploy"
    namespace = kubernetes_namespace_v1.frontend[each.key].metadata[0].name
    labels    = { app = each.key }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = each.key }
    }

    template {
      metadata {
        labels = { app = each.key }
      }

      spec {
        container {
          name  = each.key
          image = each.value.image
          args  = try(each.value.args, null)

          port {
            container_port = each.value.port
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend" {
  for_each = local.frontends

  metadata {
    name      = "${each.key}-svc"
    namespace = kubernetes_namespace_v1.frontend[each.key].metadata[0].name
    labels    = { app = each.key }
  }

  spec {
    selector = { app = each.key }

    port {
      name        = "http"
      port        = 80
      target_port = each.value.port
    }
  }
}
