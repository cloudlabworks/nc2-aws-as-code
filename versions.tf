terraform {
  required_version = ">= 1.6"
  required_providers {
    nutanix = {
      source  = "nutanix/nutanix"
      version = "2.4.2"
    }
  }
}
