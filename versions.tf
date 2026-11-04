terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.95.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.0.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
  }

  # Configured via -backend-config at init time (address/lock_address/unlock_address
  # point at the Vault-backed state store, same convention as the rest of the
  # platform-infrastructure pipeline).
  backend "http" {}
}
