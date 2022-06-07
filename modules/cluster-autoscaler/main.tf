## kubernetes cluster autoscaler

locals {
  helm_default = {
    name           = "cluster-autoscaler"
    chart          = "cluster-autoscaler"
    namespace      = "kube-system"
    serviceaccount = "cluster-autoscaler"
    version        = "9.19.1"
    repository     = "https://kubernetes.github.io/autoscaler"
  }
}

module "irsa" {
  source         = "../iam-role-for-serviceaccount"
  name           = join("-", ["irsa", local.name])
  namespace      = try(var.helm.namespace, local.helm_default.namespace)
  serviceaccount = try(var.helm.serviceaccount, local.helm_default.serviceaccount)
  oidc_url       = var.oidc.url
  oidc_arn       = var.oidc.arn
  policy_arns    = [aws_iam_policy.autoscaler.arn]
  tags           = var.tags
}

resource "aws_iam_policy" "autoscaler" {
  name        = local.name
  description = format("Allow cluster-autoscaler to manage AWS resources")
  path        = "/"
  policy = jsonencode({
    Statement = [{
      Action = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:DescribeInstanceTypes"
      ]
      Effect   = "Allow"
      Resource = ["*"]
    }]
    Version = "2012-10-17"
  })
}

resource "helm_release" "autoscaler" {
  name             = try(var.helm.name, local.helm_default.name)
  chart            = try(var.helm.chart, local.helm_default.chart)
  version          = try(var.helm.version, local.helm_default.version)
  repository       = try(var.helm.repository, local.helm_default.repository)
  namespace        = try(var.helm.namespace, local.helm_default.namespace)
  cleanup_on_fail  = true
  create_namespace = true
  atomic           = true
  reset_values     = true
  force_update     = true
  lint             = true
  max_history      = 10

  values = [
    <<YAML
extraVolumes:
- name: ssl-certs
  hostPath:
    path: /etc/ssl/certs/ca-bundle.crt

extraVolumeMounts:
- name: ssl-certs
  mountPath: /etc/ssl/certs/ca-certificates.crt
  readOnly: true

resources:
  limits:
    cpu: 100m
    memory: 300Mi
  requests:
    cpu: 100m
    memory: 300Mi

lables:
  k8s-addon: cluster-autoscaler.addons.k8s.io
  k8s-app: cluster-autoscaler

podAnnotations:
  prometheus.io/scrape: 'true'
  prometheus.io/port: '8085'

securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
YAML
  ]

  dynamic "set" {
    for_each = merge({
      "autoDiscovery.clusterName"                                      = var.cluster_name
      "fullnameOverride"                                               = try(var.helm.name, local.helm_default.name)
      "rbac.pspEnabled"                                                = true
      "rbac.serviceAccount.name"                                       = try(var.helm.serviceaccount, local.helm_default.serviceaccount)
      "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = module.irsa.arn
      "awsRegion"                                                      = var.aws_region
      # https://github.com/kubernetes/autoscaler/blob/cluster-autoscaler-release-1.23/cluster-autoscaler/main.go
      "extraArgs.expander"                       = "least-waste"
      "extraArgs.emit-per-nodegroup-metrics"     = true
      "extraArgs.cordon-node-before-terminating" = true
      "extraArgs.ignore-daemonsets-utilization"  = true
      "extraArgs.ignore-mirror-pods-utilization" = true
    }, lookup(var.helm, "vars", {}))
    content {
      name  = set.key
      value = set.value
      type  = "auto"
    }
  }
}
