data "nutanix_subnets_v2" "ext_nat" {
  filter = "name eq 'overlay-external-subnet-nat'"
}

resource "nutanix_vpc_v2" "app" {
  name        = "vpc-app"
  description = "application VPC, NAT egress via the NC2 transit VPC"
  external_subnets {
    subnet_reference = data.nutanix_subnets_v2.ext_nat.subnets[0].ext_id
  }
}

locals {
  # AWS resolver is the VPC's .2; derived from the PC address the same way the provider's NC2 sample does it
  dns_server = replace(var.pc_endpoint, "/^([0-9]+\\.[0-9]+)\\.[0-9]+\\.[0-9]+$/", "$1.0.2")
  subnets = {
    "app-web" = "192.168.10"
    "app-db"  = "192.168.20"
  }
}

resource "nutanix_subnet_v2" "app" {
  for_each      = local.subnets
  name          = each.key
  subnet_type   = "OVERLAY"
  vpc_reference = nutanix_vpc_v2.app.id
  ip_config {
    ipv4 {
      ip_subnet {
        ip { value = "${each.value}.0" }
        prefix_length = 24
      }
      default_gateway_ip { value = "${each.value}.1" }
      pool_list {
        start_ip { value = "${each.value}.10" }
        end_ip   { value = "${each.value}.200" }
      }
      dhcp_server_address { value = "${each.value}.2" }
    }
  }
  dhcp_options {
    domain_name_servers { ipv4 { value = local.dns_server } }
  }
}

# Default route out through the external NAT subnet. The VPC's route table is created with the VPC; look it up.
data "nutanix_route_tables_v2" "app" {
  filter     = "vpcReference eq '${nutanix_vpc_v2.app.id}'"
  depends_on = [nutanix_subnet_v2.app]
}

resource "nutanix_routes_v2" "app_default" {
  name               = "vpc-app-default"
  vpc_reference      = nutanix_vpc_v2.app.id
  route_table_ext_id = data.nutanix_route_tables_v2.app.route_tables[0].ext_id
  route_type         = "STATIC"
  destination {
    ipv4 {
      ip { value = "0.0.0.0" }
      prefix_length = 0
    }
  }
  next_hop {
    next_hop_type      = "EXTERNAL_SUBNET"
    next_hop_reference = data.nutanix_subnets_v2.ext_nat.subnets[0].ext_id
  }
}
