# WireGuard VPN Server Deployment Guide

This comprehensive guide covers the complete deployment process for the WireGuard VPN server on Proxmox infrastructure.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Generate Server Keys](#generate-server-keys)
4. [Configure Ansible Vault](#configure-ansible-vault)
5. [Deploy WireGuard Server](#deploy-wireguard-server)
6. [Configure Firewall](#configure-firewall)
7. [Add VPN Clients](#add-vpn-clients)
8. [Verification and Testing](#verification-and-testing)
9. [Post-Deployment Tasks](#post-deployment-tasks)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements

- **Proxmox VE**: 8.0 or later
- **Ansible**: 2.15 or later on control node
- **Network**: Management network (vmbr0) configured
- **Firewall**: LXC container 101 with WAN access
- **Storage**: 10GB free space on Proxmox storage pool

### Software Requirements

Install on your Ansible control node (workstation):

```bash
# macOS
brew install wireguard-tools qrencode ansible

# Debian/Ubuntu
sudo apt update
sudo apt install wireguard-tools qrencode ansible

# Fedora/RHEL
sudo dnf install wireguard-tools qrencode ansible
```

### Network Topology Understanding

```
Internet
   ↓
Firewall CT 101 (vmbr2 WAN, vmbr3 DMZ)
   ↓
Management Network (vmbr0: 192.168.0.0/16)
   ↓
WireGuard CT 190 (192.168.1.190/24)
   ↓
VPN Tunnel Network (192.168.100.0/24)
   ↓
VPN Clients (192.168.100.2-254)
```

---

## Pre-Deployment Checklist

Before deploying, verify these items:

- [ ] Proxmox host is accessible via SSH
- [ ] Ansible inventory configured with Proxmox host
- [ ] Management network (vmbr0) is operational
- [ ] Container ID 190 is available (not in use)
- [ ] IP address 192.168.1.190 is available on management network
- [ ] You have access to firewall container (CT 101) for port forwarding
- [ ] You have your public IP or DDNS hostname
- [ ] Ansible Vault password is available

---

## Generate Server Keys

WireGuard uses Curve25519 public-key cryptography. Generate the server keypair first.

### Step 1: Generate Private Key

```bash
# Generate server private key
wg genkey | tee server_private.key

# Example output: 6MHqFZxyz5lDQg8F+tXzOLrL9Z0qeV8bNpvzgG8E0Eg=
```

### Step 2: Generate Public Key

```bash
# Derive public key from private key
wg pubkey < server_private.key | tee server_public.key

# Example output: jP3YG5lZ+YvXLq8H7B9tKzL0mR4pF3gD8qT6nE5C2Wk=
```

### Step 3: Securely Store Keys

```bash
# Display keys for vault entry
echo "Private Key: $(cat server_private.key)"
echo "Public Key:  $(cat server_public.key)"

# IMPORTANT: Save public key - you'll need it for client configs
# Save private key to Ansible Vault (next section)

# Clean up key files after vault entry
shred -u server_private.key server_public.key
```

**SECURITY NOTE:**
- Never commit private keys to version control unencrypted
- The private key will be stored in Ansible Vault only
- The public key will be used in client configurations
- Keep a secure backup of the private key

---

## Configure Ansible Vault

Store sensitive credentials in encrypted Ansible Vault.

### Step 1: Create or Edit Vault File

```bash
cd /path/to/Proxmox_config

# Create new vault file (if doesn't exist)
ansible-vault create inventory/group_vars/all/secrets.yml

# Or edit existing vault
ansible-vault edit inventory/group_vars/all/secrets.yml
```

### Step 2: Add WireGuard Variables

Add these variables to the vault file:

```yaml
---
# WireGuard VPN Server Secrets

# Container root password (generate with: openssl rand -base64 32)
vault_wireguard_root_password: "SECURE_PASSWORD_HERE"

# WireGuard server private key (from previous step)
vault_wireguard_private_key: "6MHqFZxyz5lDQg8F+tXzOLrL9Z0qeV8bNpvzgG8E0Eg="
```

Save and exit (`:wq` in vim).

### Step 3: Verify Vault Encryption

```bash
# Verify file is encrypted
cat inventory/group_vars/all/secrets.yml

# Should show encrypted content starting with: $ANSIBLE_VAULT;1.1;AES256

# Verify you can decrypt it
ansible-vault view inventory/group_vars/all/secrets.yml
```

### Step 4: Test Vault Access in Playbook

```bash
# Dry-run to test vault variables
ansible-playbook playbooks/wireguard-deploy.yml --ask-vault-pass --check

# If successful, variables are properly configured
```

---

## Deploy WireGuard Server

Now deploy the WireGuard server using the Ansible playbook.

### Step 1: Review Configuration Variables

Check `inventory/group_vars/all/wireguard.yml`:

```yaml
---
wireguard_container_id: 190
wireguard_hostname: wireguard
wireguard_bridge: "{{ management_bridge }}"  # vmbr0
wireguard_ip_config: "192.168.1.190/24"
wireguard_gateway: "192.168.1.1"
wireguard_listen_port: 51820
wireguard_tunnel_address: "192.168.100.1/24"
wireguard_private_key: "{{ vault_wireguard_private_key }}"
wireguard_peer_configs: []  # Start with no peers
```

Adjust if needed (e.g., different container ID or IP address).

### Step 2: Run Deployment Playbook

```bash
cd /path/to/Proxmox_config

# Dry-run first (check mode)
ansible-playbook playbooks/wireguard-deploy.yml --ask-vault-pass --check

# If dry-run succeeds, deploy for real
ansible-playbook playbooks/wireguard-deploy.yml --ask-vault-pass
```

### Step 3: Monitor Deployment

Expected output:

```
PLAY [Deploy WireGuard VPN Server] *******************************************

TASK [Verify Ansible Vault variables are defined] ***************************
ok: [proxmox-host]

TASK [wireguard : Download template for WireGuard container] ****************
changed: [proxmox-host]

TASK [wireguard : Ensure WireGuard container exists] ************************
changed: [proxmox-host]

TASK [wireguard : Start WireGuard container] ********************************
changed: [proxmox-host]

TASK [wireguard : Install WireGuard packages] *******************************
changed: [proxmox-host]

TASK [wireguard : Deploy WireGuard configuration] ***************************
changed: [proxmox-host]

TASK [wireguard : Enable WireGuard service] *********************************
changed: [proxmox-host]

TASK [wireguard : Ensure WireGuard service is running] **********************
changed: [proxmox-host]

PLAY RECAP *******************************************************************
proxmox-host : ok=15   changed=10   unreachable=0    failed=0
```

### Step 4: Verify Deployment

```bash
# Check container exists
ssh root@proxmox-host pct list | grep 190

# Check WireGuard service is running
ssh root@proxmox-host pct exec 190 -- systemctl status wg-quick@wg0

# Get server public key (needed for client configs)
ssh root@proxmox-host pct exec 190 -- wg show wg0 public-key
```

---

## Configure Firewall

Configure the firewall to forward WireGuard traffic from the Internet to the server.

### Option A: Using nftables (Recommended)

```bash
# SSH into firewall container
ssh root@172.16.10.101

# Add port forward rule
nft add rule inet nat prerouting iifname eth0 udp dport 51820 dnat to 192.168.1.190:51820

# Add forward rules
nft add rule inet filter forward iifname eth0 udp dport 51820 ip daddr 192.168.1.190 ct state new,established counter accept
nft add rule inet filter forward iifname eth1 udp sport 51820 ip saddr 192.168.1.190 ct state established counter accept

# Save rules
nft list ruleset > /etc/nftables.conf
systemctl enable nftables
systemctl restart nftables
```

### Option B: Using iptables

```bash
# SSH into firewall container
ssh root@172.16.10.101

# Add port forward rule
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 51820 -j DNAT --to-destination 192.168.1.190:51820

# Add forward rules
iptables -A FORWARD -i eth0 -p udp --dport 51820 -d 192.168.1.190 -j ACCEPT
iptables -A FORWARD -i eth1 -p udp --sport 51820 -s 192.168.1.190 -j ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4
systemctl enable netfilter-persistent
```

### Verify Firewall Configuration

```bash
# From firewall, test connectivity to WireGuard server
nc -u -v -w 1 192.168.1.190 51820

# From external network, test public IP
nc -u -v YOUR_PUBLIC_IP 51820
```

**See [Firewall Configuration Guide](firewall-configuration.md) for detailed instructions.**

---

## Add VPN Clients

Add authorized clients (peers) to the VPN.

### Step 1: Generate Client Configuration

Use the provided script:

```bash
cd /path/to/Proxmox_config

# Generate client config
./scripts/wireguard-gen-client.sh \
  john-laptop \
  192.168.100.10 \
  "jP3YG5lZ+YvXLq8H7B9tKzL0mR4pF3gD8qT6nE5C2Wk=" \
  vpn.viljo.se:51820

# Replace:
#   john-laptop          - with client name
#   192.168.100.10       - with unique VPN IP (192.168.100.2-254)
#   jP3YG5lZ...          - with SERVER public key from deployment
#   vpn.viljo.se:51820   - with your public endpoint
```

Output:

```
========================================
WireGuard Client Configuration Generator
========================================

Client Name:       john-laptop
VPN IP:            192.168.100.10/32
Server Public Key: jP3YG5lZ...C2Wk=
Endpoint:          vpn.viljo.se:51820

Generating client keys...
Client configuration created: ./wireguard-clients/john-laptop.conf
QR code created: ./wireguard-clients/john-laptop-qr.png

========================================
Client Keys
========================================

Private Key:
yH8tFz5aL9qX3bG2mT7pK4nJ1rE6wD0vC8oI9uY3sA0=

Public Key:
xR7gN4kT2fL9pD5mH8bZ1qW3yC6vJ0oA4eU7iS2nK1=

========================================
Next Steps
========================================

1. Add this peer to Ansible inventory:

# Add to inventory/group_vars/all/wireguard.yml
wireguard_peer_configs:
  - name: "john-laptop"
    public_key: "xR7gN4kT2fL9pD5mH8bZ1qW3yC6vJ0oA4eU7iS2nK1="
    allowed_ips: "192.168.100.10/32"
    persistent_keepalive: 25

2. Redeploy WireGuard configuration:
   ansible-playbook playbooks/wireguard-deploy.yml --ask-vault-pass

3. Distribute client configuration securely
4. Test connectivity
```

### Step 2: Add Peer to Ansible Inventory

Edit `inventory/group_vars/all/wireguard.yml`:

```yaml
wireguard_peer_configs:
  - name: "john-laptop"
    public_key: "xR7gN4kT2fL9pD5mH8bZ1qW3yC6vJ0oA4eU7iS2nK1="
    allowed_ips: "192.168.100.10/32"
    persistent_keepalive: 25
```

### Step 3: Redeploy Configuration

```bash
# Redeploy to add peer
ansible-playbook playbooks/wireguard-deploy.yml --ask-vault-pass

# This will update wg0.conf and restart WireGuard service
```

### Step 4: Distribute Client Configuration

**For Desktop Clients:**

```bash
# Securely send the configuration file
scp wireguard-clients/john-laptop.conf user@client-host:~/

# Or use encrypted email, password-protected zip, etc.
```

**For Mobile Clients:**

```bash
# Display QR code in terminal
qrencode -t ANSIUTF8 -r wireguard-clients/john-laptop.conf

# Or share the PNG file
open wireguard-clients/john-laptop-qr.png
```

### Step 5: Client Installation and Connection

**macOS:**
1. Install WireGuard from App Store
2. Import configuration: File → Import Tunnel(s) from File
3. Select `john-laptop.conf`
4. Click "Activate"

**Linux:**
```bash
sudo apt install wireguard
sudo cp john-laptop.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf
sudo wg-quick up wg0
```

**Windows:**
1. Download WireGuard from wireguard.com/install
2. Import tunnel from file
3. Activate

**iOS/Android:**
1. Install WireGuard app
2. Add tunnel → Scan QR code
3. Toggle connection on

---

## Verification and Testing

### Step 1: Verify Server Status

```bash
# Check WireGuard service
ssh root@proxmox-host pct exec 190 -- systemctl status wg-quick@wg0

# Check interface status
ssh root@proxmox-host pct exec 190 -- wg show

# Expected output:
# interface: wg0
#   public key: jP3YG5lZ+YvXLq8H7B9tKzL0mR4pF3gD8qT6nE5C2Wk=
#   private key: (hidden)
#   listening port: 51820
#
# peer: xR7gN4kT2fL9pD5mH8bZ1qW3yC6vJ0oA4eU7iS2nK1=
#   endpoint: 1.2.3.4:51234
#   allowed ips: 192.168.100.10/32
#   latest handshake: 15 seconds ago
#   transfer: 2.15 KiB received, 5.32 KiB sent
```

### Step 2: Test Client Connectivity

**From VPN Client:**

```bash
# Check VPN interface
wg show

# Ping VPN gateway
ping 192.168.100.1

# Ping management network gateway
ping 192.168.1.1

# Ping WireGuard server
ping 192.168.1.190

# Ping other infrastructure services
ping 192.168.1.3  # Proxmox host

# DNS resolution test (if DNS configured)
nslookup proxmox.infra.local
```

### Step 3: Verify Routing

**From VPN Client:**

```bash
# Check routing table
ip route show

# Should see route for management network via VPN
# 192.168.0.0/16 via 192.168.100.1 dev wg0

# Traceroute to infrastructure
traceroute 192.168.1.1
```

### Step 4: Test Performance

**Latency Test:**

```bash
# From VPN client, measure latency
ping -c 10 192.168.1.1

# Expected: <10ms overhead compared to direct connection
```

**Throughput Test:**

```bash
# Install iperf3 on WireGuard server
ssh root@proxmox-host pct exec 190 -- apt install -y iperf3

# Run iperf3 server
ssh root@proxmox-host pct exec 190 -- iperf3 -s

# From VPN client, test throughput
iperf3 -c 192.168.1.190 -t 30

# Expected: >100 Mbps for typical infrastructure use
```

### Step 5: Connection Stability Test

**Leave VPN connected for 1 hour:**

```bash
# Start continuous ping
ping -i 60 192.168.100.1 | ts '[%Y-%m-%d %H:%M:%S]' > vpn-stability.log

# Check for packet loss after 1 hour
# Expected: 0% packet loss, connections persist through NAT
```

---

## Post-Deployment Tasks

### 1. Documentation

Document the following for your team:

- [ ] VPN endpoint (domain/IP and port)
- [ ] Server public key
- [ ] Available VPN IP range (192.168.100.2-254)
- [ ] Onboarding process for new users
- [ ] Troubleshooting contacts

### 2. Monitoring

Set up monitoring (future enhancement):

```bash
# Monitor WireGuard service status
ssh root@proxmox-host pct exec 190 -- systemctl is-active wg-quick@wg0

# Monitor active peer count
ssh root@proxmox-host pct exec 190 -- wg show wg0 peers | wc -l

# Monitor bandwidth
ssh root@proxmox-host pct exec 190 -- wg show wg0 transfer
```

### 3. Backup

Backup WireGuard configuration:

```bash
# Manual backup
ssh root@proxmox-host pct exec 190 -- cat /etc/wireguard/wg0.conf > wireguard-backup.conf

# Proxmox container backup (automated via PBS)
# Ensure CT 190 is included in PBS backup schedule
```

### 4. User Onboarding Process

Create standard operating procedure:

1. User requests VPN access
2. Admin generates client config: `./scripts/wireguard-gen-client.sh`
3. Admin adds peer to `wireguard.yml`
4. Admin redeploys: `ansible-playbook playbooks/wireguard-deploy.yml --ask-vault-pass`
5. Admin securely distributes client config
6. User installs and tests connection
7. Admin verifies handshake: `wg show`

---

## Troubleshooting

### Issue 1: Container Fails to Create

**Symptoms:** `pct create` fails with error

**Solutions:**
```bash
# Check container ID is available
pct list | grep 190

# Check storage space
df -h /var/lib/vz

# Check template exists
ls -lh /var/lib/vz/template/cache/debian-13*

# Manual cleanup if needed
pct destroy 190 --purge
```

### Issue 2: WireGuard Service Won't Start

**Symptoms:** `systemctl status wg-quick@wg0` shows failed

**Diagnosis:**
```bash
ssh root@proxmox-host pct exec 190 -- journalctl -u wg-quick@wg0 -n 50
```

**Common Causes:**
- Invalid private key → Regenerate and update vault
- Missing nesting feature → Check container config
- Port 51820 in use → Change listen port

**Solutions:**
```bash
# Enable nesting
pct set 190 -features nesting=1
pct restart 190

# Verify private key format (44 chars base64)
echo "{{ vault_wireguard_private_key }}" | wc -c  # Should be 44

# Check port availability
ssh root@proxmox-host pct exec 190 -- ss -ulnp | grep 51820
```

### Issue 3: Clients Can't Connect

**Symptoms:** Handshake timeout, no connection

**Diagnosis:**
```bash
# Check firewall port forward
ssh root@172.16.10.101 nft list ruleset | grep 51820

# Monitor firewall traffic
ssh root@172.16.10.101 tcpdump -i eth0 udp port 51820 -n

# Check WireGuard server receives packets
ssh root@proxmox-host pct exec 190 -- tcpdump -i eth0 udp port 51820 -n
```

**Solutions:**
- Configure firewall port forwarding (see Firewall Configuration Guide)
- Verify public IP/domain in client config
- Check client public key matches server config

### Issue 4: Connected but Can't Reach Management Network

**Symptoms:** Handshake succeeds, but ping to 192.168.x.x fails

**Diagnosis:**
```bash
# Check IP forwarding
ssh root@proxmox-host pct exec 190 -- sysctl net.ipv4.ip_forward

# Check PostUp rules executed
ssh root@proxmox-host pct exec 190 -- iptables -t nat -L -n -v

# Check routing
ssh root@proxmox-host pct exec 190 -- ip route show
```

**Solutions:**
```bash
# Enable IP forwarding
ssh root@proxmox-host pct exec 190 -- sysctl -w net.ipv4.ip_forward=1

# Verify PostUp rules in config
ssh root@proxmox-host pct exec 190 -- cat /etc/wireguard/wg0.conf

# Restart WireGuard
ssh root@proxmox-host pct exec 190 -- systemctl restart wg-quick@wg0
```

---

## Success Criteria

Your deployment is successful when:

- [x] Container 190 is running and accessible
- [x] WireGuard service is active and enabled
- [x] Firewall forwards UDP 51820 to 192.168.1.190
- [x] At least one client can connect and get handshake
- [x] Client can ping 192.168.100.1 (VPN gateway)
- [x] Client can ping 192.168.1.1 (management gateway)
- [x] Client can access infrastructure services on 192.168.0.0/16
- [x] Connection latency overhead is <10ms
- [x] No packet loss during stability test
- [x] Documentation is complete and accurate

**Congratulations! Your WireGuard VPN server is now operational!**

---

## Related Documentation

- [Firewall Configuration](firewall-configuration.md)
- [Architecture Overview](../../roles/wireguard/README.md)
- [Feature Specification](../../specs/planned/006-wireguard-vpn/spec.md)
- [Quickstart Guide](../../specs/planned/006-wireguard-vpn/quickstart.md)

---

**Deployment Date:** _________
**Deployed By:** _________
**Server Public Key:** _________
**Public Endpoint:** _________
