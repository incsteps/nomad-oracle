
resource "oci_core_network_security_group" "private_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "private-nsg"
}

resource "oci_core_network_security_group_security_rule" "private_rules" {
  for_each = {
    private_ingress = {
      direction   = "INGRESS", protocol = "All", source_type = "CIDR_BLOCK",
      source      = oci_core_vcn.this.cidr_block,
      description = "allow all private network."
    },
    egress_to_internet = {
      direction        = "EGRESS", protocol = "All",
      destination_type = "CIDR_BLOCK",
      destination      = "0.0.0.0/0",
      description      = "Permitir todo el tráfico de salida desde el Bastion a Internet."
    }
  }

  network_security_group_id = oci_core_network_security_group.private_nsg.id
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

resource "oci_core_network_security_group_security_rule" "fss_ingress_rules" {
  for_each = {
    # Ingress TCP para NFS desde toda la VCN
    nfs_tcp_ingress = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK",
      source    = oci_core_vcn.this.cidr_block,
      ports     = [111, 804, 805, 2048, 2049, 2050], description = "Permitir NFS TCP (Portmapper, NFS, NLM) desde la VCN."
    },
    # Ingress UDP para NFS desde toda la VCN
    nfs_udp_ingress = {
      direction = "INGRESS", protocol = "17", source_type = "CIDR_BLOCK",
      source    = oci_core_vcn.this.cidr_block,
      ports     = [111, 804, 805, 2048, 2049, 2050], description = "Permitir NFS UDP (Portmapper, NFS, NLM) desde la VCN."
    },
  }

  network_security_group_id = oci_core_network_security_group.private_nsg.id
  direction                 = each.value.direction
  protocol                  = each.value.protocol
  source_type               = each.value.source_type
  source                    = each.value.source
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

