# Developer Policy
# This policy allows developers to submit and manage jobs

namespace "*" {
  policy = "write"
  
  capabilities = [
    "list-jobs",
    "read-job",
    "submit-job",
    "dispatch-job",
    "read-logs",
    "read-fs",
    "alloc-exec",
    "alloc-node-exec",
    "alloc-lifecycle"
  ]
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
  policy = "write"
}

plugin {
  policy = "read"
}
