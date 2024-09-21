locals {
  subscription_id         = ""
  namespaces              = ["argo", "argocd", "argo-rollouts", "argo-events", "external-dns", "external-secrets", "cert-manager"]
  tenant_id               = ""
  client_id               = ""
  region                  = "westus3"
  letsencrypt_dns_name    = "packetdance.com"
  letsencrypt_common_name = "*.packetdance.com"
  letsencrypt_email       = "musanajim@gmail.com"

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
      az login --identity --username ${data.azurerm_user_assigned_identity.mi.client_id}
      az account set --subscription ${local.subscription_id}
      az aks get-credentials --resource-group "${data.azurerm_resource_group.aks.name}" --name "${data.azurerm_kubernetes_cluster.aks.name}" --admin --overwrite-existing
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
  depends_on = [null_resource.download_kubeconfig]
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
  depends_on = [kubernetes_namespace_v1.namespaces,
  null_resource.download_kubeconfig]
}

// Service Principal used by ArgoCD SSO Configuration
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
  depends_on = [null_resource.download_kubeconfig,
  kubernetes_namespace_v1.namespaces]
}


// External DNS
resource "helm_release" "external-dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  namespace        = "external-dns"
  create_namespace = true
  values           = ["${file("values/external-dns.yaml")}"]

  depends_on = [null_resource.download_kubeconfig,
  kubernetes_namespace_v1.namespaces]
}

// External Secrets
resource "helm_release" "external-secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  values           = ["${file("values/external-secrets.yaml")}"]
  depends_on = [helm_release.external-dns,
    null_resource.download_kubeconfig,
  kubernetes_namespace_v1.namespaces]
}

// Argo CD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  values           = ["${file("values/argo-cd.yaml")}"]

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    null_resource.download_kubeconfig,
  kubernetes_namespace_v1.namespaces]
}

// Argo Events
resource "helm_release" "argo-events" {
  name             = "argo-events"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-events"
  namespace        = "argo-events"
  create_namespace = true
  values           = ["${file("values/argo-events.yaml")}"]

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
  kubernetes_namespace_v1.namespaces]
}

// Kubernetes Secret Replicator
resource "helm_release" "kubernetes-replicator" {
  name             = "kubernetes-replicator"
  repository       = "https://helm.mittwald.de"
  chart            = "kubernetes-replicator"
  namespace        = "kube-system"
  create_namespace = true
  values           = ["${file("values/kubernetes-replicator.yaml")}"]

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
  kubernetes_namespace_v1.namespaces]
}

// Argo Rollouts
resource "helm_release" "argo-rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
  values           = ["${file("values/argo-rollouts.yaml")}"]

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
  kubernetes_namespace_v1.namespaces]
}

// Cert Manager
resource "helm_release" "cert-manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  values           = ["${file("values/cert-manager.yaml")}"]

  set {
    name  = "extraArgs"
    value = "{--dns01-recursive-nameservers-only,--dns01-recursive-nameservers=8.8.8.8:53\\,1.1.1.1:53}"
  }

  set {
    name  = "crds.enabled"
    value = "true"
  }

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-rollouts,
  kubernetes_namespace_v1.namespaces]
}

resource "azurerm_federated_identity_credential" "cert-manager" {
  name                = "cert-manager"
  resource_group_name = data.azurerm_resource_group.aks.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = data.azurerm_user_assigned_identity.mi.id
  subject             = "system:serviceaccount:cert-manager:cert-manager"

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-rollouts,
    kubernetes_namespace_v1.namespaces,
  helm_release.cert-manager]
}

resource "azurerm_federated_identity_credential" "argo-workflows" {
  name                = "argo-workflows"
  resource_group_name = data.azurerm_resource_group.aks.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = data.azurerm_user_assigned_identity.mi.id
  subject             = "system:serviceaccount:argo:argo-workflows"

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-rollouts,
    kubernetes_namespace_v1.namespaces,
  helm_release.cert-manager]
}

resource "azurerm_federated_identity_credential" "external-dns" {
  name                = "external-dns"
  resource_group_name = data.azurerm_resource_group.aks.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = data.azurerm_user_assigned_identity.mi.id
  subject             = "system:serviceaccount:external-dns:external-dns"

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-rollouts,
    kubernetes_namespace_v1.namespaces,
  helm_release.cert-manager]
}

resource "azurerm_federated_identity_credential" "external-secrets" {
  name                = "external-secrets"
  resource_group_name = data.azurerm_resource_group.aks.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = data.azurerm_user_assigned_identity.mi.id
  subject             = "system:serviceaccount:external-secrets:external-secrets"

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-rollouts,
    kubernetes_namespace_v1.namespaces,
  helm_release.cert-manager]
}

resource "null_resource" "argo_workflows" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f values/argo-workflows.yaml
    EOT
  }
  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-events,
    helm_release.argo-rollouts,
    helm_release.cert-manager,
  kubernetes_namespace_v1.namespaces]
}

// Letsencrypt Cluster Issuer
resource "null_resource" "letsencrypt_cluster_issuer" {
  provisioner "local-exec" {
    command = <<EOT
      cat <<EOF > letsencrypt.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: "${local.letsencrypt_email}"
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - dns01:
        azureDNS:
          resourceGroupName: ${data.azurerm_resource_group.core.name}
          subscriptionID: ${local.subscription_id}
          hostedZoneName: "packetdance.com"
          environment: AzurePublicCloud
          managedIdentity:
            clientID: ${data.azurerm_user_assigned_identity.mi.client_id}
EOF
      kubectl apply -f letsencrypt.yaml
    EOT
  }
  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-events,
    helm_release.argo-rollouts,
    helm_release.cert-manager,
  kubernetes_namespace_v1.namespaces]
}

resource "null_resource" "letsencrypt_certificate" {
  provisioner "local-exec" {
    command = <<EOT
cat <<EOF | kubectl apply -f - -n cert-manager
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ingress-tls
spec:
  secretName: ingress-tls
  privateKey:
    rotationPolicy: Always
  commonName: "${local.letsencrypt_common_name}"
  dnsNames:
    - "${local.letsencrypt_common_name}"
  usages:
    - digital signature
    - key encipherment
    - server auth
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
  secretTemplate:
    annotations:
      replicator.v1.mittwald.de/replication-allowed: "true"  # permit replication
      replicator.v1.mittwald.de/replication-allowed-namespaces: "argo,argo-rollouts,argo-events,prod-[0-9]*" 
EOF
    EOT
  }

  depends_on = [
    helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-events,
    helm_release.argo-rollouts,
    helm_release.cert-manager,
    kubernetes_namespace_v1.namespaces,
    null_resource.letsencrypt_cluster_issuer
  ]
}

resource "helm_release" "argo-ingress" {
  name      = "argo-ingress"
  chart     = "values/ingress/"
  version   = "0.1.0"
  namespace = "argocd"

  set {
    name  = "ingress.argocd"
    value = "argocd.packetdance.com"
  }

  set {
    name  = "ingress.workflows"
    value = "argoworkflows.packetdance.com"
  }

  set {
    name  = "ingress.rollouts"
    value = "argorollouts.packetdance.com"
  }

  set {
    name  = "ingress.internal"
    value = "true"
  }

  set {
    name  = "ingress.subnet"
    value = "snet-idp-aks"
  }

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-events,
    helm_release.argo-rollouts,
    helm_release.cert-manager,
    kubernetes_namespace_v1.namespaces,
  null_resource.argo_workflows]
}

// External Secrets - Cluster Secret Store
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
            vaultUrl: "${data.azurerm_key_vault.kv.vault_uri}"
            authType: ManagedIdentity
            identityId: "${data.azurerm_user_assigned_identity.mi.client_id}"
      EOF
    EOT
  }

  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-events,
    helm_release.argo-rollouts,
    helm_release.cert-manager,
    kubernetes_namespace_v1.namespaces,
  null_resource.argo_workflows]
}

/*
module "keyvault_acmebot" {
  source  = "shibayan/keyvault-acmebot/azurerm"
  version = "~> 3.0"

  app_base_name       = "acmebot-idp"
  resource_group_name = data.azurerm_resource_group.core.name
  location            = "westus"
  mail_address        = "musanajim@gmail.com"
  vault_uri           = data.azurerm_key_vault.kv.vault_uri

#  auth_settings = {
#    enabled = true
#    active_directory = {
#      client_id            = "${local.client_id}"
#      client_secret        = "${var.client_secret}"
#      tenant_auth_endpoint = "https://login.microsoftonline.com/${local.tenant_id}/v2.0"
#    }
#  }

  azure_dns = {
    subscription_id = "${local.subscription_id}"
  }
}

resource "azurerm_role_assignment" "acmebot-dns" {
  principal_id         = module.keyvault_acmebot.principal_id
  role_definition_name = "DNS Zone Contributor"
  scope                = data.azurerm_dns_zone.azure_dns.id

  depends_on = [module.keyvault_acmebot]
}

resource "azurerm_role_assignment" "acmebot-keyvault" {
  principal_id         = module.keyvault_acmebot.principal_id
  role_definition_name = "Key Vault Secrets Officer"
  scope                = data.azurerm_key_vault.kv.id

  depends_on = [module.keyvault_acmebot]
}
*/

/*
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
  depends_on = [helm_release.external-dns,
    helm_release.external-secrets,
    helm_release.argocd,
    null_resource.download_kubeconfig,
    helm_release.argo-events,
    helm_release.argo-rollouts,
    helm_release.cert-manager,
    kubernetes_namespace_v1.namespaces,
    null_resource.argo_workflows,
  null_resource.cluster_secret_store]
}
*/


