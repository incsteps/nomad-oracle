# CI/CD Policy
# This policy allows automated systems to deploy and monitor jobs

namespace "*" {
  policy = "write"
  
  capabilities = [
    "list-jobs",
    "read-job",
    "submit-job",
    "dispatch-job",
    "read-logs",
    "read-fs"
  ]
}

# CI/CD systems need to read node information for placement
node {
  policy = "read"
}

# Allow reading agent info for health checks
agent {
  policy = "read"
}

quota {
  policy = "read"
}

host_volume "*" {
  policy = "write"
}

plugin {
  policy = "read"
}

# Optional: Allow scaling operations
# Uncomment if CI/CD needs to scale jobs
# operator {
#   policy = "read"
# }
