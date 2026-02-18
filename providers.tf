
provider "oci" {
  region = var.region
}

provider "oci" {
  alias  = "home"
  region = data.oci_identity_region_subscriptions.home_region.region_subscriptions[0].region_name
}
