data "oci_core_services" "all_oci_services" {
  filter {
    name = "name"
    values = ["All (.+) Services In Oracle Services Network"]
    regex  = true
  }
}

# 1. Virtual Cloud Network (VCN)
resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_block     = var.vcn_cidr_block
  display_name   = var.vcn_display_name
  dns_label      = var.vcn_dns_label
  is_ipv6enabled = var.is_ipv6_enabled

  freeform_tags = {
    "Project" = "NomadCluster"
    "Client"  = var.vcn_display_name
  }
}

# 2. Internet Gateway (IGW)
resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_display_name}-igw"
  # is_enabled está implícito y por defecto es true
}

# 3. NAT Gateway
resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_display_name}-natgw"
}

# 4. Service Gateway (SGW)
resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_display_name}-sgw"
  services {
    service_id = data.oci_core_services.all_oci_services.services[0].id # Accede al ID del primer servicio encontrado
  }
}

# 5. Public route table
resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_display_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

# 6. Private route table
resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_display_name}-private-rt"

  route_rules {
    cidr_block        = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.this.id
  }

  route_rules {
    network_entity_id = oci_core_service_gateway.this.id
    destination = data.oci_core_services.all_oci_services.services[0].cidr_block
    # Accede al CIDR del primer servicio encontrado
    destination_type  = "SERVICE_CIDR_BLOCK"
  }
}

# 7. Public subnet
resource "oci_core_subnet" "public_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr_block
  display_name               = "${var.vcn_display_name}-public-subnet"
  route_table_id             = oci_core_route_table.public_rt.id
  dns_label                  = "${var.vcn_dns_label}pub"
  prohibit_public_ip_on_vnic = false
}

# 8. Private subnet
resource "oci_core_subnet" "private_subnet" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.private_subnet_cidr_block
  display_name               = "${var.vcn_display_name}-private-subnet"
  route_table_id             = oci_core_route_table.private_rt.id
  dns_label                  = "${var.vcn_dns_label}priv"
  prohibit_public_ip_on_vnic = true
}


