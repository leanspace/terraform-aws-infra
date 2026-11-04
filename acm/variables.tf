variable "domain_name" {
  description = "Domain name for the certificate"
  type        = string
}

variable "alternative_names" {
  description = "List of alternative domain names for the certificate"
  type        = list(string)
  default     = []
}