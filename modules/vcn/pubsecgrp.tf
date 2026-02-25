resource "oci_core_network_security_group" "public_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "public-nsg"
}

# Security rules for Nomad Server (public)
resource "oci_core_network_security_group_security_rule" "public_rules" {
  for_each = {
    ssh_ingress = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.ssh_source_cidr,
      ports = [22], description = "Allow SSH from specified CIDR"
    },
    nomad_http_ingress_public = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.ssh_source_cidr,
      ports = [4646], description = "Allow Nomad HTTP API from user IP"
    },
    minio_api_ingress = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.ssh_source_cidr,
      ports = [9000], description = "Allow MinIO S3 API from user IP"
    },
    minio_console_ingress = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.ssh_source_cidr,
      ports = [9001], description = "Allow MinIO Console from user IP"
    },
    minio_api_ingress_vcn = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.vcn_cidr_block,
      ports = [9000], description = "Allow MinIO S3 API from VCN (Nomad tasks)"
    },
    minio_console_ingress_vcn = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.vcn_cidr_block,
      ports = [9001], description = "Allow MinIO Console from VCN"
    },
    nomad_http_ingress_vcn = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.vcn_cidr_block,
      ports = [4646], description = "Allow Nomad HTTP API from VCN"
    },
    nomad_rpc_ingress_vcn = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.vcn_cidr_block,
      ports     = [4647], description = "Allow Nomad RPC from VCN"
    },
    nomad_serf_tcp_ingress_vcn = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.vcn_cidr_block,
      ports     = [4648], description = "Allow Nomad Serf TCP from VCN"
    },
    nomad_serf_udp_ingress_vcn = {
      direction = "INGRESS", protocol = "17", source_type = "CIDR_BLOCK", source = var.vcn_cidr_block,
      ports     = [4648], description = "Allow Nomad Serf UDP from VCN"
    },
    egress_to_internet = {
      direction   = "EGRESS", protocol = "All", destination_type = "CIDR_BLOCK", destination = "0.0.0.0/0",
      description = "Allow all outbound traffic"
    }
  }

  network_security_group_id = oci_core_network_security_group.public_nsg.id
  direction                 = each.value.direction
  protocol                  = each.value.protocol
  source_type               = lookup(each.value, "source_type", null)
  source                    = lookup(each.value, "source", null)
  destination_type          = lookup(each.value, "destination_type", null)
  destination               = lookup(each.value, "destination", null)
  description               = each.value.description

  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" ? [1] : []
    content {
      destination_port_range {
        min = each.value.ports[0]
        max = each.value.ports[length(each.value.ports) - 1]
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol == "17" ? [1] : []
    content {
      destination_port_range {
        min = each.value.ports[0]
        max = each.value.ports[length(each.value.ports) - 1]
      }
    }
  }
}
