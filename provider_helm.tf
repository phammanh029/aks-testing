provider "helm" {
  kubernetes = {
    host                   = "https://${azurerm_kubernetes_cluster.default.fqdn}:443"
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--environment",
        "AzurePublicCloud",
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630", # Note: The AAD server app ID of AKS Managed AAD is always 6dae42f8-4368-4678-94ff-3960e28e3630 in any environments. https://azure.github.io/kubelogin/concepts/aks.html#azure-kubernetes-service-aad-client
        "--client-id",
        data.azurerm_client_config.current.client_id,
        "--tenant-id",
        data.azurerm_subscription.current.tenant_id, # AAD Tenant Id
        "--login",
        "azurecli"
      ]
    }
  }
}
