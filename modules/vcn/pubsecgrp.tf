resource "oci_core_network_security_group" "public_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "public-nsg"
}

# Reglas de Seguridad para el Bastión
resource "oci_core_network_security_group_security_rule" "bastion_rules" {
  for_each = {
    ssh_ingress_external = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = var.ssh_source_cidr,
      ports = [22], description = "Permitir SSH (puerto 22) al Bastion desde CIDR de origen definido."
    },
    # --- headscale Ingress ---
    headscale_ingress = {
      direction = "INGRESS", protocol = "6", source_type = "CIDR_BLOCK", source = "0.0.0.0/0",
      ports = [443], description = "SSL Headscale."
    },
    headscale_oracle = {
      direction = "INGRESS", protocol = "17", source_type = "CIDR_BLOCK", source = "0.0.0.0/0",
      ports = [41641], description = "Requires for oracle cloud"
    },
    # Egreso a Internet (se mantiene)
    egress_to_internet = {
      direction = "EGRESS", protocol = "All", destination_type = "CIDR_BLOCK", destination = "0.0.0.0/0",
      description = "Permitir todo el tráfico de salida desde el Bastion a Internet."
    }
  }

  network_security_group_id = oci_core_network_security_group.public_nsg.id
  direction                 = each.value.direction
  protocol                  = each.value.protocol
  source_type = lookup(each.value, "source_type", null)
  source = lookup(each.value, "source", null)
  destination_type = lookup(each.value, "destination_type", null)
  destination = lookup(each.value, "destination", null)
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
