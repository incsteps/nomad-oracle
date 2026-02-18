
locals {
  final_ssh_public_key_content = var.dev_ssh_public_key_path != null ? file(var.dev_ssh_public_key_path) : var.ssh_public_key_content
}
