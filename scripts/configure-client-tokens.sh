#!/bin/bash
# Configure Client Tokens
# This script fetches the client token from the server and configures all clients

set -e

# Check if required variables are set
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <server_ip> <client_ip_1> [client_ip_2] ..."
    echo "Example: $0 84.8.137.209 10.0.2.122"
    exit 1
fi

SERVER_IP=$1
shift
CLIENT_IPS=("$@")

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

echo "==================================="
echo "Configure Client Tokens"
echo "==================================="
echo "Server: $SERVER_IP"
echo "Clients: ${CLIENT_IPS[@]}"
echo ""

# Wait for server to be ready and token to be created
echo "Step 1: Waiting for server ACL bootstrap..."
for i in {1..60}; do
    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$SERVER_IP "sudo test -f /etc/nomad.d/secrets/client-token.txt" 2>/dev/null; then
        echo "✓ Client token found on server"
        break
    fi
    echo "  Waiting... ($i/60)"
    sleep 5
done

# Fetch client token from server
echo ""
echo "Step 2: Fetching client token from server..."
CLIENT_TOKEN=$(ssh -i "$SSH_KEY" ubuntu@$SERVER_IP "sudo cat /etc/nomad.d/secrets/client-token.txt")

if [ -z "$CLIENT_TOKEN" ]; then
    echo "✗ Failed to fetch client token"
    exit 1
fi

echo "✓ Client token fetched: ${CLIENT_TOKEN:0:8}..."

# Configure each client
echo ""
echo "Step 3: Configuring clients..."
for CLIENT_IP in "${CLIENT_IPS[@]}"; do
    echo "  Configuring client: $CLIENT_IP"
    
    # Create token file on client
    ssh -i "$SSH_KEY" -J ubuntu@$SERVER_IP ubuntu@$CLIENT_IP "echo '$CLIENT_TOKEN' | sudo tee /etc/nomad.d/secrets/client-token.txt > /dev/null && sudo chmod 600 /etc/nomad.d/secrets/client-token.txt"
    
    # Update systemd service
    ssh -i "$SSH_KEY" -J ubuntu@$SERVER_IP ubuntu@$CLIENT_IP "sudo tee /etc/systemd/system/nomad.service > /dev/null" << 'EOF'
[Unit]
Description=HashiCorp Nomad
Documentation=https://www.nomadproject.io/
Requires=network-online.target
After=network-online.target docker.service

[Service]
User=root
Group=root
EnvironmentFile=-/etc/nomad.d/secrets/client-token.env
ExecStartPre=/bin/bash -c 'if [ -f /etc/nomad.d/secrets/client-token.txt ]; then echo "NOMAD_TOKEN=$(cat /etc/nomad.d/secrets/client-token.txt)" > /etc/nomad.d/secrets/client-token.env; fi'
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    # Restart Nomad
    ssh -i "$SSH_KEY" -J ubuntu@$SERVER_IP ubuntu@$CLIENT_IP "sudo systemctl daemon-reload && sudo systemctl restart nomad"
    
    echo "  ✓ Client $CLIENT_IP configured and restarted"
done

echo ""
echo "==================================="
echo "Configuration Complete!"
echo "==================================="
echo ""
echo "Verify client registration:"
echo "  export NOMAD_ADDR=http://$SERVER_IP:4646"
echo "  export NOMAD_TOKEN=\$(ssh -i $SSH_KEY ubuntu@$SERVER_IP 'sudo cat /etc/nomad.d/secrets/nomad-token.env | grep NOMAD_TOKEN | cut -d= -f2')"
echo "  nomad node status"
