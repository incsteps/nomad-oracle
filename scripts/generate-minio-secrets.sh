#!/bin/bash
# Generate secure random credentials for MinIO
# Usage: ./scripts/generate-minio-secrets.sh

set -e

# Generate random username (12 chars alphanumeric)
MINIO_ROOT_USER=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)

# Generate random password (32 chars, strong)
MINIO_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)

# Output as shell exports
echo "# MinIO Credentials - Generated $(date)"
echo "export MINIO_ROOT_USER=\"${MINIO_ROOT_USER}\""
echo "export MINIO_ROOT_PASSWORD=\"${MINIO_ROOT_PASSWORD}\""
echo ""
echo "# Save these credentials securely!"
echo "# To use with Nomad: source this file before running nomad job run"

# Also save to file
SECRETS_FILE="minio-secrets.env"
cat > "$SECRETS_FILE" << EOF
# MinIO Credentials - Generated $(date)
# DO NOT COMMIT THIS FILE TO VERSION CONTROL
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
EOF

chmod 600 "$SECRETS_FILE"

echo ""
echo "Credentials saved to: $SECRETS_FILE"
echo "File permissions set to 600 (owner read/write only)"
