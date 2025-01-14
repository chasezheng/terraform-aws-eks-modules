### helm
variable "helm" {
  description = "The helm release configuration"
  type        = any
  default     = {}
}

### security/policy
variable "oidc" {
  description = "The Open ID Connect properties"
  type        = object({ url = string, arn = string })
}

### description
variable "cluster_name" {
  description = "The kubernetes cluster name"
  type        = string
}

variable "petname" {
  description = "An indicator whether to append a random identifier to the end of the name to avoid duplication"
  type        = bool
  default     = true
}

### tags
variable "tags" {
  description = "The key-value maps for tagging"
  type        = map(string)
  default     = {}
}
