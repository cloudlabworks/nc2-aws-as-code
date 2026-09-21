resource "nutanix_images_v2" "ubuntu" {
  name        = "ubuntu-24.04-cloud"
  description = "Ubuntu 24.04 cloud image, from the public repository"
  type        = "DISK_IMAGE"
  source {
    url_source {
      url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    }
  }
}

resource "nutanix_category_v2" "env_lab" {
  key   = "environment"
  value = "lab"
}

data "nutanix_clusters_v2" "nc2" {
  filter = "config/clusterFunction/any(t:t eq Clustermgmt.Config.ClusterFunctionRef'AOS')"
}

resource "nutanix_virtual_machine_v2" "web01" {
  name                 = "web-01"
  num_sockets          = 2
  num_cores_per_socket = 1
  memory_size_bytes    = 4 * pow(1024, 3)

  cluster    { ext_id = data.nutanix_clusters_v2.nc2.cluster_entities[0].ext_id }
  categories { ext_id = nutanix_category_v2.env_lab.id }

  disks {
    disk_address { bus_type = "SCSI", index = 0 }
    backing_info {
      vm_disk {
        data_source {
          reference {
            image_reference { image_ext_id = nutanix_images_v2.ubuntu.id }
          }
        }
        disk_size_bytes = 40 * pow(1024, 3)
      }
    }
  }

  nics {
    nic_network_info {
      virtual_ethernet_nic_network_info {
        nic_type = "NORMAL_NIC"
        subnet { ext_id = nutanix_subnet_v2.app["app-web"].id }
      }
    }
  }

  # cloud-init runs on first boot only; changing this block replaces the VM (the provider says so — plan for it)
  guest_customization {
    config {
      cloud_init {
        cloud_init_script {
          user_data {
            value = base64encode(templatefile("${path.module}/templates/web.yaml", { ssh_key = var.ssh_public_key }))
          }
        }
      }
    }
  }

  boot_config {
    uefi_boot { boot_order = ["DISK", "NETWORK"] }
  }
  power_state = "ON"
}

# A floating IP from the AWS VPC range, attached to the VM's NIC — the provider's NC2 sample pattern
resource "nutanix_floating_ip_v2" "web01" {
  name                      = "fip-web-01"
  external_subnet_reference = data.nutanix_subnets_v2.ext_nat.subnets[0].ext_id
  association {
    vm_nic_association {
      vm_nic_reference = nutanix_virtual_machine_v2.web01.nics[0].ext_id
    }
  }
}
