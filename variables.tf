variable "pc_endpoint" {
  description = "Prism Central IP or FQDN, as shown in the NC2 console after the cluster is Running."
  type        = string
}

variable "lab" {
  description = "true only while Prism Central still has its self-signed certificate (sets provider insecure = true)."
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "Public key for the cloud-init user on web-01."
  type        = string
}
