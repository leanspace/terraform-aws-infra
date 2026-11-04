variable "component_category" {
  description = "The category of the component being deployed"
  type        = string
  default     = "platform-infrastructure"
}

variable "component_type" {
  description = "The name of the type of component being deployed"
  type        = string
  default     = "database-cluster"
}

variable "team_name" {
  description = "Team name tag for the db cluster"
  type        = string
  default     = "silver"
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "14.13"
}

variable "aurora_instances" {
  description = "Map of Aurora instances"
  type        = map(any)
  default = {
    1 = {
      instance_class               = "db.t3.medium"
      publicly_accessible          = false
      db_parameter_group_name      = "default.aurora-postgresql14"
      ca_cert_identifier           = "rds-ca-ecc384-g1"
      auto_minor_version_upgrade   = false
      performance_insights_enabled = true
    }
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key. When specifying `kms_key_id`, `storage_encrypted` needs to be set to `true`"
  type        = string
  default     = null
}

variable "via_service" {
  description = "AWS service that is using the KMS key (e.g., 'rds')"
  type        = string
  default     = "rds"
}