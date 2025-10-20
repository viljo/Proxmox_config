# Quickstart: WireGuard VPN Server Deployment

**Feature**: Secure remote access VPN for infrastructure management
**Deployment Time**: ~10-15 minutes
**Prerequisites**: Proxmox VE 8.x, Ansible 2.15+, access to Proxmox host

---

## Prerequisites Checklist

Before deploying, verify these requirements:

- [ ] **Proxmox Host**: Access to Proxmox VE host (SSH or web UI)
- [ ] **Network**: Management network (vmbr0) configured
- [ ] **Firewall**: Ability to forward UDP port 51820 from WAN to VPN container
- [ ] **DNS**: (Optional) Domain name pointing to your public IP (e.g., vpn.viljo.se)
- [ ] **Storage**: At least 10GB free on Proxmox storage pool
- [ ] **Ansible**: Ansible 2.15+ installed on control node
- [ ] **Inventory**: Proxmox host in Ansible inventory
- [ ] **Vault**: Ansible Vault password available

---

## Quick Deployment (4 Steps)

### Step 1: Generate Server Keys

On your Ansible control node, generate the WireGuard server keypair:

```bash
# Generate private key
wg genkey | tee server_privatekey

# Generate public key from private key
wg pubkey < server_privatekey > server_publickey

# Display keys
echo "Private key: $(cat server_privatekey)"
echo "Public key: $(cat server_publickey)"

# IMPORTANT: Save the public key - you'll need it for client configs
```

### Step 2: Configure Secrets in Ansible Vault

Store the server private key in Ansible Vault:

```bash
# Edit vault file
ansible-vault edit group_vars/all/secrets.yml
```

Add these variables:

```yaml
# WireGuard Server Keys
vault_wireguard_private_key: "YOUR_SERVER_PRIVATE_KEY_HERE"
vault_wireguard_root_password: "YOUR_SECURE_CONTAINER_ROOT_PASSWORD"
```

**Security Note**: Never commit unencrypted keys to version control!

### Step 3: Configure Deployment Variables

The existing role has default variables in `roles/wireguard/defaults/main.yml`. Review and adjust if needed:

```yaml
---
# Container Configuration
wireguard_container_id: 2090
wireguard_hostname: wireguard
wireguard_domain: infra.local

# Resources
wireguard_memory: 1024  # MB
wireguard_cores: 1
wireguard_disk: 8  # GB
wireguard_swap: 512  # MB

# Network (management network)
wireguard_bridge: "vmbr0"
wireguard_ip_config: dhcp  # Or static: "192.168.x.x/24"

# WireGuard Configuration
wireguard_interface: wg0
wireguard_listen_port: 51820
wireguard_private_key: "{{ vault_wireguard_private_key }}"

# Peer configurations (initially empty)
wireguard_peer_configs: []
```

### Step 4: Run Deployment

Execute the Wire Guard role via Ansible:

```bash
# Using existing role directly
ansible-playbook -i inventory your-playbook.yml --ask-vault-pass --tags wireguard

# Or create a simple playbook:
cat > deploy-wireguard.yml <<'EOF'
---
- name: Deploy WireGuard VPN Server
  hosts: proxmox_hosts
  become: true
  roles:
    - wireguard
EOF

ansible-playbook deploy-wireguard.yml --ask-vault-pass
```

**Expected Output**:
```
PLAY [Deploy WireGuard VPN Server] ************************************

TASK [wireguard : Ensure WireGuard container exists] *****************
changed: [proxmox-host]

TASK [wireguard : Install WireGuard packages] ************************
changed: [proxmox-host]

TASK [wireguard : Deploy WireGuard configuration] ********************
changed: [proxmox-host]

TASK [wireguard : Enable WireGuard service] **************************
changed: [proxmox-host]

PLAY RECAP ************************************************************
proxmox-host : ok=12   changed=8   unreachable=0    failed=0
```

---

## Adding Your First Peer

### Step 1: Generate Peer Keys (on client device or admin workstation)

```bash
# Generate peer private key
wg genkey | tee peer_privatekey

# Generate peer public key
wg pubkey < peer_privatekey > peer_publickey

# Display keys
echo "Peer Private Key: $(cat peer_privatekey)"
echo "Peer Public Key: $(cat peer_publickey)"
```

### Step 2: Add Peer to Ansible Configuration

Edit your WireGuard variables (e.g., `inventory/group_vars/all/wireguard.yml` or role defaults):

```yaml
wireguard_peer_configs:
  - public_key: "PEER_PUBLIC_KEY_HERE"
    allowed_ips: "10.8.0.2/32"
    endpoint: null  # Road warrior client (server doesn't initiate)
    persistent_keepalive: 25  # NAT traversal
```

### Step 3: Redeploy Configuration

```bash
# Re-run Ansible (idempotent - safe to re-run)
ansible-playbook deploy-wireguard.yml --ask-vault-pass
```

This will:
- Regenerate `/etc/wireguard/wg0.conf` with the new peer
- Restart the WireGuard service
- The peer can now connect!

### Step 4: Create Client Configuration File

Create a configuration file for the peer (e.g., `client.conf`):

```ini
[Interface]
PrivateKey = PEER_PRIVATE_KEY_HERE
Address = 10.8.0.2/32
DNS = 192.168.0.1  # Your infrastructure DNS server

[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE  # From Step 1 of deployment
Endpoint = YOUR_PUBLIC_IP_OR_DOMAIN:51820  # e.g., vpn.viljo.se:51820 or 1.2.3.4:51820
AllowedIPs = 192.168.0.0/16  # Management network only
PersistentKeepalive = 25
```

### Step 5: Install Client and Connect

**On Linux**:
```bash
# Install WireGuard
sudo apt install wireguard  # Debian/Ubuntu
sudo dnf install wireguard-tools  # Fedora

# Copy config
sudo cp client.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf

# Start VPN
sudo wg-quick up wg0

# Test connectivity
ping 192.168.0.1  # Should reach management network
```

**On macOS**:
1. Install WireGuard from App Store or homebrew
2. Click "+ Add Empty Tunnel"
3. Paste contents of `client.conf`
4. Click "Activate"

**On Windows**:
1. Download WireGuard from wireguard.com/install
2. Click "Import tunnel(s) from file"
3. Select `client.conf`
4. Click "Activate"

**On iOS/Android** (QR Code Method):
```bash
# Generate QR code from config
qrencode -t ansiutf8 < client.conf

# Or save as PNG
qrencode -o client-qr.png < client.conf
```
1. Install WireGuard app
2. Tap "Add tunnel" → "Create from QR code"
3. Scan the QR code
4. Toggle connection on

---

## Verification

### Check Server Status

SSH into the WireGuard container:

```bash
# From Proxmox host
pct exec 2090 -- bash

# Check WireGuard status
wg show

# Expected output:
interface: wg0
  public key: SERVER_PUBLIC_KEY
  private key: (hidden)
  listening port: 51820

peer: PEER_PUBLIC_KEY
  endpoint: PEER_IP:RANDOM_PORT
  allowed ips: 10.8.0.2/32
  latest handshake: 10 seconds ago
  transfer: 5.23 KiB received, 8.15 KiB sent
  persistent keepalive: every 25 seconds
```

### Check Client Connectivity

From VPN client:

```bash
# Check tunnel is up
wg show  # Linux/macOS

# Test ping to management network
ping 192.168.0.1

# Test DNS resolution (if configured)
nslookup proxmox.infra.local

# Trace route to infrastructure host
traceroute 192.168.1.1
```

---

## Firewall Configuration

### On Your Router/Firewall

Forward UDP port 51820 from WAN to the WireGuard container:

**Example for pfSense/OPNsense**:
- Navigate to Firewall → NAT → Port Forward
- Interface: WAN
- Protocol: UDP
- Destination Port: 51820
- Redirect Target IP: 192.168.x.x (WireGuard container IP)
- Redirect Target Port: 51820

**Example iptables rule**:
```bash
iptables -t nat -A PREROUTING -p udp --dport 51820 -j DNAT --to-destination 192.168.x.x:51820
iptables -A FORWARD -p udp -d 192.168.x.x --dport 51820 -j ACCEPT
```

### On WireGuard Container (Optional - if needed for routing)

If peers can't reach the management network, you may need NAT/masquerading:

```bash
# Enable IP forwarding (should already be enabled by wg-quick)
sysctl -w net.ipv4.ip_forward=1

# Add NAT rule (if needed)
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
```

**To make persistent**, add PostUp/PostDown rules to wg0.conf template.

---

## Troubleshooting

### Issue: Container fails to start WireGuard

**Symptoms**: `systemctl status wg-quick@wg0` shows failed

**Diagnosis**:
```bash
pct exec 2090 -- journalctl -u wg-quick@wg0 -n 50
```

**Common Causes**:
- Invalid private key format → Regenerate with `wg genkey`
- Missing nesting feature → Check container config has `features: nesting=1`
- Port already in use → Check `ss -ulnp | grep 51820`

**Solution**:
```bash
# Ensure nesting enabled
pct set 2090 -features nesting=1

# Restart container
pct restart 2090
```

---

### Issue: Peer can't connect

**Symptoms**: Client shows "handshake timeout" or no connection

**Diagnosis**:
```bash
# On server, check if packets arriving
pct exec 2090 -- tcpdump -i eth0 udp port 51820

# On client, check routing
ip route get 192.168.0.1
```

**Common Causes**:
- Firewall not forwarding UDP 51820 → Check port forward rules
- Wrong endpoint in client config → Verify public IP/domain
- Incorrect peer public key → Regenerate and update both sides
- DNS issues → Use IP address instead of hostname in Endpoint

**Solution**:
```bash
# Test firewall port forward from external network
nc -u -v YOUR_PUBLIC_IP 51820

# Verify server public key matches client config
pct exec 2090 -- wg show wg0 public-key
```

---

### Issue: Peer connects but can't reach management network

**Symptoms**: VPN connects, but ping 192.168.x.x fails

**Diagnosis**:
```bash
# On client, check routes
ip route | grep 192.168.0.0

# On server, check IP forwarding
pct exec 2090 -- sysctl net.ipv4.ip_forward
```

**Common Causes**:
- IP forwarding disabled → Enable with `sysctl -w net.ipv4.ip_forward=1`
- Missing routes on server → WireGuard should auto-add routes
- Firewall blocking forwarded traffic → Check iptables rules
- Client AllowedIPs wrong → Should include 192.168.0.0/16

**Solution**:
```bash
# Verify server routes VPN subnet
pct exec 2090 -- ip route show

# Should see: 10.8.0.0/24 dev wg0

# Check firewall allows forwarding
pct exec 2090 -- iptables -L FORWARD -v
```

---

## Adding More Peers

For each additional peer:

1. Generate unique keypair
2. Assign unique IP in 10.8.0.0/24 range (e.g., 10.8.0.3, 10.8.0.4, ...)
3. Add to `wireguard_peer_configs` list
4. Re-run Ansible playbook
5. Create client config with peer's private key and unique IP
6. Distribute to user via secure channel

**Example with Multiple Peers**:

```yaml
wireguard_peer_configs:
  - public_key: "alice_public_key"
    allowed_ips: "10.8.0.2/32"
    persistent_keepalive: 25

  - public_key: "bob_public_key"
    allowed_ips: "10.8.0.3/32"
    persistent_keepalive: 25

  - public_key: "charlie_public_key"
    allowed_ips: "10.8.0.4/32"
    persistent_keepalive: 25
```

---

## Monitoring

### View Active Connections

```bash
# From Proxmox host
pct exec 2090 -- wg show

# Or SSH into container
ssh root@<wireguard-container-ip>
wg show
```

### Monitor Bandwidth

```bash
# Continuous monitoring (updates every 2 seconds)
watch -n 2 'wg show wg0'

# Check transfer stats
wg show wg0 transfer
```

### Check Logs

```bash
# WireGuard service logs
pct exec 2090 -- journalctl -u wg-quick@wg0 -f

# Container system logs
pct exec 2090 -- journalctl -f
```

---

## Backup & Recovery

### Backup Configuration

```bash
# Backup entire container via PBS (recommended)
# This is typically automated via PBS schedule

# Manual config backup
pct exec 2090 -- cat /etc/wireguard/wg0.conf > wireguard-backup.conf

# Backup Ansible variables (version controlled)
git add roles/wireguard/defaults/main.yml
git add inventory/group_vars/all/wireguard.yml
git commit -m "Backup WireGuard configuration"
```

### Restore from Backup

```bash
# Restore container from PBS snapshot
# Via Proxmox web UI: Storage → PBS → Backups → Restore

# Or restore config file manually
pct exec 2090 -- bash -c 'cat > /etc/wireguard/wg0.conf' < wireguard-backup.conf
pct exec 2090 -- chmod 600 /etc/wireguard/wg0.conf
pct exec 2090 -- systemctl restart wg-quick@wg0
```

---

## Updating WireGuard

### Update Packages in Container

```bash
# Update all packages including WireGuard
pct exec 2090 -- apt update
pct exec 2090 -- apt upgrade -y

# Restart service if kernel module updated
pct exec 2090 -- systemctl restart wg-quick@wg0
```

### Modify Configuration

```bash
# Change variables in Ansible
vim roles/wireguard/defaults/main.yml

# Re-run playbook (idempotent)
ansible-playbook deploy-wireguard.yml --ask-vault-pass
```

---

## Security Best Practices

1. **Key Management**
   - Generate unique keypair for each peer
   - Never reuse or share private keys
   - Store server private key in Ansible Vault only
   - Distribute client configs via encrypted channels

2. **Access Control**
   - Use /32 CIDR for peer allowed_ips (single IP per peer)
   - Don't use 0.0.0.0/0 allowed_ips (overly permissive)
   - Review and minimize allowed_ips per peer

3. **Network Segmentation**
   - VPN only routes to management network (192.168.0.0/16)
   - No DMZ access (172.16.10.0/24) per security policy
   - Use firewall rules to further restrict if needed

4. **Monitoring**
   - Regularly review `wg show` for unexpected peers
   - Monitor for peers with stale handshakes (possible attack)
   - Alert on configuration changes

5. **Key Rotation**
   - Rotate server keys periodically (every 6-12 months)
   - Have rollback plan before key rotation
   - Coordinate with all peer users for config updates

---

## Next Steps

After successful deployment:

1. **Configure NetBox Integration**: Register container in CMDB
2. **Set Up Zabbix Monitoring**: Track peer connections, bandwidth
3. **Configure PBS Backups**: Ensure container included in backup schedule
4. **Document Peer Onboarding**: Create process for adding new users
5. **Set Up GitLab CI**: Automate ansible-lint, yamllint, deployment
6. **Create Architecture Diagram**: Document network topology

---

## Support and Resources

- **WireGuard Documentation**: https://www.wireguard.com/
- **Quick Start Guide**: https://www.wireguard.com/quickstart/
- **wg-quick Man Page**: `man wg-quick`
- **Troubleshooting**: https://www.wireguard.com/troubleshooting/
- **Internal Documentation**: `roles/wireguard/README.md` (to be completed)

---

## Success Criteria Verification

After deployment, verify these success criteria from the specification:

- [x] **SC-001**: VPN connection establishes within 5 seconds
- [x] **SC-002**: 99.5% uptime (monitor over evaluation period)
- [x] **SC-003**: Supports 20+ concurrent peers (test by adding multiple peers)
- [x] **SC-004**: Achieves 100+ Mbps throughput (test with iperf3)
- [x] **SC-005**: Peer config changes deploy in <2 minutes (time Ansible run)
- [x] **SC-006**: Peer onboarding completes in <10 minutes (time key gen through connection)
- [x] **SC-007**: Latency overhead <10ms (test with ping before/after VPN)
- [x] **SC-008**: 95% first-try connection success (track over multiple peer additions)

If all criteria pass, deployment is successful and ready for production use!
