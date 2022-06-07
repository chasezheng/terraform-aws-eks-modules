## kubernetes prometheus

locals {
  helm_default = {
    name       = "prometheus"
    repository = "https://prometheus-community.github.io/helm-charts"
    chart      = "prometheus"
    namespace  = "prometheus"
    version    = "15.9.2"
    vars = {
      "alertmanager.persistentVolume.storageClass" = "gp2"
      "server.persistentVolume.storageClass"       = "gp2"
    }
    cleanup_on_fail = true
  }
}

resource "helm_release" "prometheus" {
  name             = try(var.helm.name, local.helm_default.name)
  chart            = try(var.helm.chart, local.helm_default.chart)
  version          = try(var.helm.version, local.helm_default.version)
  repository       = try(var.helm.repository, local.helm_default.repository)
  namespace        = try(var.helm.namespace, local.helm_default.namespace)
  cleanup_on_fail  = try(var.helm.cleanup_on_fail, local.helm_default.cleanup_on_fail)
  create_namespace = true
  atomic           = true
  reset_values     = true
  force_update     = true
  lint             = true
  max_history      = 10

  dynamic "set" {
    for_each = merge(local.helm_default.vars, try(var.helm.vars, {}))
    content {
      name  = set.key
      value = set.value
    }
  }
}
