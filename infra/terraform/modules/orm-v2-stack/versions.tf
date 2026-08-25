terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source                = "oracle/oci"
      version               = "= 8.26.0"
      configuration_aliases = [oci.home]
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "= 0.14.0"
    }
  }
}
