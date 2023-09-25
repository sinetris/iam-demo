# Work with transform secrets engine
path "sys/managed-keys/*" {
  capabilities = ["create", "read", "update", "list"]
}

# List enabled secrets engine
path "sys/mounts" {
  capabilities = ["read", "list"]
}

# Enable secrets engine
path "sys/mounts/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Work with pki secrets engine
path "pki*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}
