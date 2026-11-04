variable "deployment_mode" {
  description = "The mode of deployment for the OpenSearch cluster (PROD, DEV, or CUSTOM)"
  type        = string
  validation {
    condition     = contains(["PROD", "DEV", "CUSTOM"], var.deployment_mode)
    error_message = "The mode must be either 'PROD', 'DEV', or 'CUSTOM'."
  }
}

variable "high_availability" {
  description = "Enable high availability for the OpenSearch cluster"
  type        = bool
  default     = false
  validation {
    condition     = var.deployment_mode == "PROD" ? var.high_availability == true : true
    error_message = "high_availability must be true when deployment_mode is PROD."
  }
  validation {
    condition     = var.master_node_type != null ? var.high_availability == true : true
    error_message = "high_availability must be true when master_node_type is specified."
  }
}

variable "opensearch_version" {
  description = "Version of OpenSearch to deploy"
  type        = string
  default     = "OpenSearch_2.11"
}

variable "opensearch_tls_security_policy" {
  description = "TLS security policy for OpenSearch"
  type        = string
  default     = "Policy-Min-TLS-1-2-2019-07"
}

variable "data_node_count" {
  description = "Number of data nodes (Only applicable if mode is CUSTOM)"
  type        = number
  default     = null
  validation {
    condition     = var.deployment_mode == "CUSTOM" ? var.data_node_count != null : true
    error_message = "data_node_count must be specified when deployment_mode is CUSTOM."
  }
}

variable "data_node_type" {
  description = "Instance type for data nodes (Only applicable if mode is CUSTOM)"
  type        = string
  default     = null
  validation {
    condition     = var.deployment_mode == "CUSTOM" ? var.data_node_type != null : true
    error_message = "data_node_type must be specified when deployment_mode is CUSTOM."
  }
}

variable "master_node_type" {
  description = "Instance type for master nodes (Only applicable if mode is CUSTOM)"
  type        = string
  default     = null
  validation {
    condition     = var.deployment_mode == "CUSTOM" ? var.master_node_type != null : true
    error_message = "master_node_type must be specified when deployment_mode is CUSTOM."
  }
}

variable "component_category" {
  description = "The category of the component being deployed"
  type        = string
  default     = "platform-infrastructure"
}

variable "component_type" {
  description = "The name of the type of component being deployed"
  type        = string
  default     = "opensearch-cluster"
}

variable "team_name" {
  description = "Team name tag for the opensearch cluster"
  type        = string
  default     = "silver"
}