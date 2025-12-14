locals {
  envoy_gateway_address = try(
    element(
      compact([
        try(data.kubernetes_service.envoy_gateway_lb.status[0].load_balancer[0].ingress[0].ip, ""),
        try(data.kubernetes_service.envoy_gateway_lb.status[0].load_balancer[0].ingress[0].hostname, ""),
      ]),
      0,
    ),
    "",
  )
}

output "envoy_gateway_service_name" {
  description = "Envoy Gateway Service installed by the Helm chart"
  value       = data.kubernetes_service.envoy_gateway_lb.metadata[0].name
}

output "envoy_gateway_external_ip" {
  description = "LoadBalancer IP (may be empty until provisioned)"
  value       = try(data.kubernetes_service.envoy_gateway_lb.status[0].load_balancer[0].ingress[0].ip, "")
}

output "envoy_gateway_external_hostname" {
  description = "LoadBalancer hostname (for clouds that return hostname instead of IP)"
  value       = try(data.kubernetes_service.envoy_gateway_lb.status[0].load_balancer[0].ingress[0].hostname, "")
}

output "envoy_gateway_address" {
  description = "Primary LoadBalancer address (IP or hostname)"
  value       = local.envoy_gateway_address
}

output "envoy_gateway_curl_examples" {
  description = "Quick test commands for the two demo frontends (replace hostnames if you change them)"
  value = {
    app1 = format("curl -H \"Host: app1.demo.local\" http://%s/", local.envoy_gateway_address != "" ? local.envoy_gateway_address : "LB_ADDRESS")
    app2 = format("curl -H \"Host: app2.demo.local\" http://%s/", local.envoy_gateway_address != "" ? local.envoy_gateway_address : "LB_ADDRESS")
  }
}
