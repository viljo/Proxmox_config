# SSH Access Methods

This document describes the two methods for accessing the Proxmox infrastructure via SSH.

## Overview

There are two primary access methods depending on your network location:

1. **Internet Access** (via SSH Bastion) - For remote access from any location
2. **Admin Network Access** (Direct) - For access from the management network (192.168.1.0/16)

## Network Architecture

```
Internet
    ↓
Firewall (Container 101)
    ├── WAN Interface (eth0): Dynamic DHCP IP (e.g., 85.24.186.100)
    ├── DMZ Interface (eth1): 172.16.10.101
    └── Management Interface (eth2): 192.168.1.1
         ↓
Management Network (192.168.1.0/16 via vmbr0)
    ├── Bastion Host (Container 110): 192.168.1.10
    └── Proxmox Host: 192.168.1.3
```

## Method 1: Internet Access (via SSH Bastion)

Use this method when accessing from the internet or any external network.

### Architecture

```
Internet → ssh.viljo.se:22 (85.24.186.100)
  ↓ Firewall DNAT (port 22)
  ↓ Bastion (192.168.1.10)
  ↓ SSH Jump
  ↓ Proxmox/Infrastructure (192.168.1.0/16)
```

### DNS Configuration

- **Domain**: ssh.viljo.se
- **IP**: Dynamic (currently 85.24.186.100)
- **Auto-updated**: Via Loopia DDNS service (every 15 minutes)

### Bastion Credentials

- **Host**: ssh.viljo.se
- **User**: root
- **Authentication**: SSH key (no password)
- **Container ID**: 110
- **IP**: 192.168.1.10

### Usage Examples

#### Basic Connection to Bastion

```bash
ssh root@ssh.viljo.se
```

#### SSH Jump to Proxmox Host

```bash
# Single command with ProxyJump
ssh -J root@ssh.viljo.se root@192.168.1.3

# Execute command on Proxmox via bastion
ssh -J root@ssh.viljo.se root@192.168.1.3 "pct list"

# With options to skip host key verification (for automation)
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -J root@ssh.viljo.se root@192.168.1.3 "command"
```

#### SSH Jump to DMZ Containers

```bash
# Access containers on DMZ network (172.16.10.0/24)
ssh -J root@ssh.viljo.se root@192.168.1.3 "pct exec 155 -- bash"
```

#### Configure SSH Config File

Add to `~/.ssh/config` for easier access:

```
Host bastion
    HostName ssh.viljo.se
    User root
    IdentityFile ~/.ssh/id_rsa

Host proxmox
    HostName 192.168.1.3
    User root
    ProxyJump bastion
    IdentityFile ~/.ssh/id_rsa
```

Then connect with:
```bash
ssh proxmox
```

### Firewall Configuration

The firewall (container 101) performs DNAT:

```nftables
# /etc/nftables.conf in container 101
table ip nat {
  chain prerouting {
    # DNAT port 22 to SSH bastion on management network
    iifname "eth0" tcp dport 22 dnat to 192.168.1.10
  }
}
```

### Security Considerations

- SSH key authentication only (passwords disabled)
- Bastion is isolated on management network
- All SSH access from internet must go through bastion
- Firewall logs all connections

## Method 2: Admin Network Access (Direct)

Use this method when physically on-site or connected to the management network (192.168.1.0/16).

### Prerequisites

- Connected to management network (192.168.1.0/16)
- SSH access configured to Proxmox host

### Usage Examples

#### Direct Connection to Proxmox Host

```bash
# Direct SSH to Proxmox
ssh root@192.168.1.3

# Execute commands directly
ssh root@192.168.1.3 "pct list"
```

#### Access Containers Directly via pct

```bash
# Execute commands in containers
ssh root@192.168.1.3 "pct exec 155 -- bash"

# Check container status
ssh root@192.168.1.3 "pct status 163"
```

#### Access Web Interfaces Directly

From the admin network, you can access services directly via their internal IPs:

- Proxmox Web UI: https://192.168.1.3:8006
- Containers: http://172.16.10.XXX (via Proxmox host routing)

### Network Configuration

The management network (192.168.1.0/16) is on Proxmox bridge `vmbr0`:

```
# /etc/network/interfaces on Proxmox host
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.3/16
    gateway 192.168.1.1
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

## Choosing the Right Method

| Scenario | Method | Reason |
|----------|--------|--------|
| Remote work / Home | Internet (Bastion) | No direct network access |
| On-site management | Direct | Faster, no extra hop |
| Automation scripts (external) | Internet (Bastion) | Scripts run from external networks |
| Ansible from admin laptop | Direct | On management network |
| Emergency access | Internet (Bastion) | Always available via ssh.viljo.se |
| Quick container checks | Direct | Lower latency |

## Troubleshooting

### Cannot Connect via Bastion

1. Check DNS resolution:
   ```bash
   dig +short ssh.viljo.se
   ```

2. Verify bastion container is running:
   ```bash
   # From admin network:
   ssh root@192.168.1.3 "pct status 110"
   ```

3. Test firewall DNAT:
   ```bash
   # From internet:
   nc -zv ssh.viljo.se 22
   ```

### Cannot Connect Directly

1. Verify you're on the management network:
   ```bash
   ip route | grep 192.168.1.0
   ```

2. Check Proxmox host is reachable:
   ```bash
   ping -c 3 192.168.1.3
   ```

3. Verify SSH service:
   ```bash
   nc -zv 192.168.1.3 22
   ```

### SSH Host Key Changes

If you see "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED":

```bash
# Remove old host keys
ssh-keygen -R ssh.viljo.se
ssh-keygen -R 192.168.1.3

# Accept new keys
ssh -o StrictHostKeyChecking=accept-new root@ssh.viljo.se
ssh -o StrictHostKeyChecking=accept-new root@192.168.1.3
```

## Best Practices

1. **Always use SSH keys** - Never use password authentication
2. **Use SSH config** - Configure ~/.ssh/config for easier access
3. **Keep keys secure** - Protect your private SSH keys
4. **Use screen/tmux** - For long-running operations via bastion
5. **Document access** - Log when and why you accessed infrastructure
6. **Test both methods** - Ensure redundant access paths work
7. **Update DNS** - Loopia DDNS auto-updates, but verify after IP changes

## Related Documentation

- [Network Topology](../architecture/network-topology.md)
- [Firewall Deployment](../deployment/firewall-deployment.md)
- [Container Mapping](../architecture/container-mapping.md)
- [Troubleshooting Firewall NAT](./troubleshooting-firewall-nat.md)

## Container List

| Container ID | Name | Network | IP | Access Method |
|--------------|------|---------|-----|---------------|
| 101 | Firewall | WAN/DMZ/Mgmt | Multiple | Direct (mgmt) |
| 110 | Bastion | Management | 192.168.1.10 | Direct (mgmt) |
| 150 | PostgreSQL | DMZ | 172.16.10.150 | pct exec |
| 151 | Keycloak | DMZ | 172.16.10.151 | pct exec |
| 153 | GitLab | DMZ | 172.16.10.153 | pct exec |
| 154 | GitLab Runner | DMZ | 172.16.10.154 | pct exec |
| 155 | Nextcloud | DMZ | 172.16.10.155 | pct exec |
| 158 | Redis | DMZ | 172.16.10.158 | pct exec |
| 160 | Demo Site | DMZ | 172.16.10.160 | pct exec |
| 163 | Mattermost | DMZ | 172.16.10.163 | pct exec |
| 170 | Webtop | DMZ | 172.16.10.170 | pct exec |

Note: DMZ containers (172.16.10.0/24) are accessed via `pct exec` from the Proxmox host.
