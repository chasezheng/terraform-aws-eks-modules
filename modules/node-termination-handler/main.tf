## kubernetes node termination handler

locals {
  helm_default = {
    name            = "aws-node-termination-handler"
    repository      = "https://aws.github.io/eks-charts"
    chart           = "aws-node-termination-handler"
    namespace       = "kube-system"
    version         = "0.18.5"
    serviceaccount  = "aws-node-termination-handler"
    cleanup_on_fail = true
    vars            = {}
  }
}

resource "helm_release" "node-termination-handler" {
  name             = try(var.helm.name, local.helm_default.name)
  chart            = try(var.helm.chart, local.helm_default.chart)
  version          = try(var.helm.version, local.helm_default.version)
  repository       = try(var.helm.repository, local.helm_default.repository)
  namespace        = try(var.helm.namespace, local.helm_default.namespace)
  cleanup_on_fail  = try(var.helm.cleanup_on_fail, local.helm_default.cleanup_on_fail)
  atomic           = true
  reset_values     = true
  force_update     = true
  create_namespace = true
  lint             = true
  max_history      = 10

  dynamic "set" {
    for_each = merge({}, lookup(var.helm, "vars", {}))
    content {
      name  = set.key
      value = set.value
    }
  }
}
