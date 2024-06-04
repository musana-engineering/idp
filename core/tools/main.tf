locals {
  subscription_id = "94476f39-40ea-4489-8831-da5475ccc163"
  namespaces      = ["argo", "argocd", "argo-rollouts", "argo-events", "external-dns", "external-secrets"]
  tenant_id       = "de5b2627-b190-44c6-a3dc-11c4294198e1"
  client_id       = "3c61bf30-7604-4cbf-9468-b75a18738cbb"
  region          = "westus3"

  labels = {
    provisioner = "terraform"
    location    = "westus3"
    project     = "idp"
  }
}

// Download Kubeconfig File
resource "null_resource" "download_kubeconfig" {
  provisioner "local-exec" {
    command = <<-EOT
      az login --identity
      az account set --subscription ${local.subscription_id}
      az aks get-credentials --resource-group "${data.azurerm_resource_group.aks.name}" --name "${data.azurerm_kubernetes_cluster.aks.name}" --admin
      kubectl get namespace
    EOT
  }
}

// Creat the Kubernetes Namespaces for Argo CD, Argo Rollouts, External DNS, External Secrets
resource "kubernetes_namespace_v1" "namespaces" {
  count = length(local.namespaces)

  metadata {
    labels = local.labels

    name = local.namespaces[count.index]
  }
}

// Deploy External DNS
resource "kubernetes_secret_v1" "external-dns" {
  metadata {
    name      = "azure-config-file"
    namespace = "external-dns"
  }

  data = {
    "azure.json" = <<-EOT
      {
        "tenantId": "${local.tenant_id}",
        "subscriptionId": "${local.subscription_id}",
        "resourceGroup": "${data.azurerm_resource_group.aks.name}",
        "useManagedIdentityExtension": true,
        "userAssignedIdentityID": "${data.azurerm_user_assigned_identity.mi.client_id}"
      }
    EOT
  }
}

resource "kubernetes_secret_v1" "argocd_oidc_client" {
  metadata {
    name      = "argocd-oidc-client"
    namespace = "argocd"
    labels = {
      "app.kubernetes.io/part-of" = "argocd"
    }
  }
  data = {
    clientID     = "${local.client_id}"
    clientSecret = var.client_secret
    tenantID     = "${local.tenant_id}"

    type = "Opaque"
  }
}

resource "helm_release" "external-dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  namespace        = "external-dns"
  create_namespace = true
  values           = ["${file("values/external-dns.yaml")}"]
}

// Deploy External Secrets
resource "helm_release" "external-secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  values           = ["${file("values/external-secrets.yaml")}"]
}

// Deploy Argo CD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  values           = ["${file("values/argocd.yaml")}"]
}

resource "helm_release" "argo-workflows" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo"
  namespace        = "argo"
  create_namespace = true
  values           = ["${file("values/argo-workflows.yaml")}"]
}

// Deploy Argo Rollouts
resource "helm_release" "argo-rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
  values           = ["${file("values/rollouts.yaml")}"]
}

// Create the Cluster Secret Store (Azure Key vault)
resource "null_resource" "cluster_secret_store" {
  provisioner "local-exec" {
    command = <<-EOT

      kubectl apply -f - <<EOF
      apiVersion: external-secrets.io/v1beta1
      kind: ClusterSecretStore
      metadata:
        name: kv-idp-core
      spec:
        provider:
          azurekv:
            tenantId: "${local.tenant_id}"
            vaultUrl: "https://kv-idp-core.vault.azure.net"
            authType: ManagedIdentity
            identityId: "${data.azurerm_user_assigned_identity.mi.client_id}"
      EOF

    EOT
  }
}

//  Deploy the Ingress TLS Certificate in all Namespaces created above
resource "null_resource" "ingress_tls_secret" {
  count = length(local.namespaces)
  provisioner "local-exec" {
    command = <<-EOT

      kubectl apply -f - <<EOF
      apiVersion: external-secrets.io/v1beta1
      kind: ExternalSecret
      metadata:
        name: ingress-tls
        namespace: ${local.namespaces[count.index]}
      spec:
        refreshInterval: 1h
        secretStoreRef:
          kind: ClusterSecretStore
          name: kv-idp-core
        target:
          template:
            type: kubernetes.io/tls
            engineVersion: v2
            data:
              tls.crt: "{{ .tls | b64dec | pkcs12cert }}"
              tls.key: "{{ .tls | b64dec | pkcs12key }}"
        data:
        - secretKey: tls
          remoteRef:
            # Azure Key Vault certificates must be fetched as secret/cert-name
            key: secret/star-musana-eng
      EOF

    EOT
  }
}



