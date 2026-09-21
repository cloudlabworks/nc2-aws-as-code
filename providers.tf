# One provider, pointed at Prism Central. There is no Prism Element in the NC2 workflow to point a second one at.
provider "nutanix" {
  endpoint     = var.pc_endpoint     # Prism Central IP or FQDN from the NC2 console
  port         = 9440
  insecure     = var.lab             # only until a real certificate is on PC
  wait_timeout = 10
}
