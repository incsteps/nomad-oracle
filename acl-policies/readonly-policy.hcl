# Read-Only Policy
# This policy allows read-only access to most Nomad resources

namespace "*" {
  policy       = "read"
  capabilities = ["list-jobs", "read-job"]
}

node {
  policy = "read"
}

agent {
  policy = "read"
}

quota {
  policy = "read"
}

host_volume "*" {
  policy = "read"
}

plugin {
  policy = "read"
}
