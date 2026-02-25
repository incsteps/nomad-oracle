# Client Node ACL Token Setup

## Issue
When Nomad ACL is enabled, client nodes need a valid token to register with the server. Without it, clients will fail to register with "Permission denied" errors.

## Solution Implemented

### 1. Create Node Policy
Created `acl-policies/node-policy.hcl` that allows nodes to register:
```hcl
node {
  policy = "write"
}

agent {
  policy = "read"
}
```

### 2. Apply Policy to Nomad
```bash
nomad acl policy apply -description "Node policy for clients" node-policy acl-policies/node-policy.hcl
```

### 3. Create Client Token
```bash
nomad acl token create -name="client-node-token" -policy=node-policy -type=client
```

**Client Token Generated**: `22104c67-67f1-ba9e-904d-33fd0c543db5`

### 4. Configure Client to Use Token

Updated `/etc/systemd/system/nomad.service` on the client to include token as environment variable:

```ini
[Unit]
Description=HashiCorp Nomad
Documentation=https://www.nomadproject.io/
Requires=network-online.target
After=network-online.target docker.service

[Service]
User=root
Group=root
Environment="NOMAD_TOKEN=22104c67-67f1-ba9e-904d-33fd0c543db5"
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
```

### 5. Restart Client
```bash
sudo systemctl daemon-reload
sudo systemctl restart nomad
```

## Verification

### Check Node Status
```bash
source nomad-token.env
nomad node status
```

Output:
```
ID        Node Pool  DC   Name            Class   Drain  Eligibility  Status
802656a1  default    dc1  nomad-client-1  <none>  false  eligible     ready
```

### Node Resources
- **CPU**: 16,000 MHz (16 cores)
- **Memory**: 12 GiB
- **Disk**: 193 GiB
- **Drivers**: Docker, Exec

## For Future Deployments

### Option 1: Automate in Cloud-Init (Recommended)
To automate this for future client deployments, the cloud-init should:

1. Create the client token on the server during bootstrap
2. Store it in `/etc/nomad.d/secrets/client-token.env`
3. Pass it to clients via cloud-init metadata or secure distribution

### Option 2: Manual Setup (Current)
For each new client:
1. Create a token: `nomad acl token create -name="client-X" -policy=node-policy -type=client`
2. SSH to client
3. Update systemd service with the token
4. Restart Nomad

## Troubleshooting

### Client Shows "Permission denied"
1. Check client logs: `ssh client "sudo journalctl -u nomad -f"`
2. Verify token is set: `ssh client "sudo systemctl show nomad | grep NOMAD_TOKEN"`
3. Recreate token if needed

### Client Not Appearing in Node List
1. Check network connectivity: `ssh client "nc -zv SERVER_IP 4647"`
2. Check firewall rules
3. Verify ACL token is valid: `nomad acl token self -token=<client-token>`

## Security Considerations

- **Token Type**: Client tokens are less privileged than management tokens
- **Policy**: Node policy only allows node registration, not job management
- **Rotation**: Tokens can be revoked and recreated without affecting running allocations
- **Storage**: Token is stored in systemd environment, not written to disk in plain text

## Related Files

- `acl-policies/node-policy.hcl` - Node registration policy
- `nomad-token.env` - Management token (for creating client tokens)
- Client systemd service: `/etc/systemd/system/nomad.service` (on client node)

---

**Updated**: February 24, 2026  
**Client Token**: 22104c67-67f1-ba9e-904d-33fd0c543db5  
**Node ID**: 802656a1-1d2c-2089-10e8-f0f057622b57
