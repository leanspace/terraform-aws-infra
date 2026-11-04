variable "component_category" {
  description = "The category of the component being deployed"
  type        = string
  default     = "platform-infrastructure"
}

variable "component_type" {
  description = "The name of the type of component being deployed"
  type        = string
  default     = "networking"
}
variable "team_name" {
  description = "Team name tag for the component"
  type        = string
  default     = "silver"
}

variable "name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
  default     = "leanspace-vpc"
}

variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
  default     = []
}

variable "enable_flow_log" {
  description = "Whether or not to enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_log_destination_type" {
  description = "Type of flow log destination. Can be s3, kinesis-data-firehose or cloud-watch-logs"
  type        = string
  default     = "s3"
}

variable "flow_log_destination_arn" {
  description = "The ARN of the CloudWatch log group or S3 bucket where VPC Flow Logs will be pushed. If this ARN is a S3 bucket the appropriate permissions need to be set on that bucket's policy. When create_flow_log_cloudwatch_log_group is set to false this argument must be provided"
  type        = string
  default     = ""
}
