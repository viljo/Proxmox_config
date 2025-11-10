# Getting Started

Quick start guide for deploying and managing the Proxmox infrastructure with Coolify PaaS.

## Architecture Overview

This infrastructure uses **Coolify PaaS** in a single LXC container (ID: 200) to host all services as Docker containers. This simplified architecture eliminates the complexity of managing multiple LXC containers.

**Key Components**:
- **Proxmox VE 9**: Hypervisor (192.168.1.3 on vmbr0)
- **Coolify LXC 200**: Single container hosting all services
  - Management interface: 192.168.1.200/16 (eth1 on vmbr0)
  - Public interface: DHCP public IP (eth0 on vmbr2)
- **Services**: Deployed via Coolify API using Ansible

For complete architecture details, see [Network Topology](architecture/network-topology.md).

## Prerequisites

### Required Software
- **Ansible**: 2.14+ (with community.general collection)
- **Python**: 3.9+
- **Git**: For version control
- **SSH**: Access to Proxmox host (192.168.1.3)

### Required Access
- SSH access to Proxmox host as root
- Ansible Vault password (`.vault_pass.txt` or entered manually)
- Coolify API token (for service deployments)

## Initial Setup

### 1. Clone Repository

```bash
git clone git@github.com:viljo/Proxmox_config.git
cd Proxmox_config
```

### 2. Install Dependencies

```bash
# Install Python dependencies
pip install -r requirements.txt

# Install Ansible collections (if needed)
ansible-galaxy collection install community.general
```

### 3. Configure Ansible Vault

The vault password should be in `.vault_pass.txt` (gitignored):

```bash
echo "your-vault-password" > .vault_pass.txt
chmod 600 .vault_pass.txt
```

### 4. Verify Inventory

Check that you can connect to the Proxmox host:

```bash
ansible -i inventory/hosts.yml proxmox_hosts -m ping
```

Expected output:
```
proxmox_admin | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## Basic Usage

### Deploy Coolify Infrastructure

This repository manages the Proxmox infrastructure and Coolify deployment:

```bash
# Deploy Coolify LXC container to Proxmox
ansible-playbook -i inventory/production.ini playbooks/coolify-deploy.yml
```

### Deploy Application Services

Application services (GitLab, Nextcloud, media services, etc.) are deployed via the `/coolify_service/ansible` repository using Coolify API:

```bash
# Services are in separate repository
cd /path/to/coolify_service/ansible

# Deploy a service via Coolify API
ansible-playbook -i inventory/production.ini \
  playbooks/deploy-SERVICE-via-api.yml \
  --vault-password-file=.vault_pass.txt
```

### Verify Infrastructure

```bash
# Check Coolify container status
ssh root@192.168.1.3 pct status 200

# Check Coolify API
curl -s http://192.168.1.200:8000/health

# Check Docker containers
ssh root@192.168.1.3 pct exec 200 -- docker ps

# Check infrastructure status
bash scripts/check-infrastructure-status.sh
```

## Project Structure

```
Proxmox_config/
├── inventory/              # Ansible inventory and variables
│   ├── hosts.yml          # Proxmox host definition
│   └── group_vars/all/    # Service configuration (24 files)
├── playbooks/             # Ansible playbooks
│   ├── site.yml          # Main deployment playbook
│   └── demo-site-*.yml   # Demo site playbooks
├── roles/                 # Ansible roles (24 roles)
│   ├── firewall/         # Firewall LXC (container ID: 1)
│   ├── demo_site/        # Demo website (ID: 60)
│   ├── gitlab/           # GitLab (ID: 53)
│   └── ...               # 21 other roles
├── docs/                  # Documentation (you are here)
└── specs/                 # Feature specifications
```

## Network Overview

The infrastructure uses three network bridges:

| Bridge | Network | Purpose |
|--------|---------|---------|
| **vmbr0** | 192.168.1.0/24 | Management network (Proxmox host) |
| **vmbr2** | DHCP (ISP) | WAN uplink (firewall external) |
| **vmbr3** | 172.16.10.0/24 | DMZ network (all services) |

**Traffic Flow**: Internet → vmbr2 (firewall) → NAT → vmbr3 (services)

See [Network Topology](architecture/network-topology.md) for details.

## Container ID Mapping

All containers follow the pattern: **Container ID = Last octet of IP address**

Example:
- Firewall: ID `1` → IP `172.16.10.1`
- GitLab: ID `53` → IP `172.16.10.53`
- Demo Site: ID `60` → IP `172.16.10.60`

See [Container Mapping](architecture/container-mapping.md) for the complete list.

## Common Tasks

### View Service Configuration

```bash
# View GitLab configuration
cat inventory/group_vars/all/gitlab.yml

# View all DMZ containers
cat inventory/group_vars/all/dmz.yml
```

### Edit Vault Secrets

```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

### Destroy and Rebuild Service

```bash
# Example: Rebuild demo site
ansible-playbook -i inventory playbooks/demo-site-teardown.yml
ansible-playbook -i inventory playbooks/demo-site-deploy.yml
```

### Check Container Status

```bash
# On Proxmox host
ssh root@192.168.1.3 pct list
ssh root@192.168.1.3 pct status 60  # Demo site
```

## Key Services

| Service | Container ID | IP Address | URL |
|---------|--------------|------------|-----|
| Firewall | 1 | 172.16.10.1 | N/A (internal) |
| PostgreSQL | 50 | 172.16.10.50 | N/A (internal) |
| Keycloak | 51 | 172.16.10.51 | https://keycloak.viljo.se |
| NetBox | 52 | 172.16.10.52 | https://netbox.viljo.se |
| GitLab | 53 | 172.16.10.53 | https://gitlab.viljo.se |
| Demo Site | 60 | 172.16.10.60 | https://demosite.viljo.se |

See [Container Mapping](architecture/container-mapping.md) for all 16 services.

## Troubleshooting

### Cannot Connect to Proxmox

```bash
# Test SSH connection
ssh root@192.168.1.3

# Check Ansible can reach host
ansible -i inventory/hosts.yml proxmox_hosts -m ping
```

### Vault Decryption Failed

```bash
# Verify vault password file exists
cat .vault_pass.txt

# Manually decrypt to test
ansible-vault view inventory/group_vars/all/secrets.yml
```

### Deployment Failed

```bash
# Check for syntax errors
ansible-playbook -i inventory playbooks/site.yml --syntax-check

# Run in verbose mode
ansible-playbook -i inventory playbooks/site.yml -vvv

# Check Proxmox host logs
ssh root@192.168.1.3 journalctl -f
```

## Next Steps

1. **Review Architecture** - [Network Topology](architecture/network-topology.md)
2. **Deploy Services** - [Deployment Guide](deployment/)
3. **Learn Operations** - [Operations Guide](operations/)
4. **Understand Decisions** - [Architecture Decision Records](adr/)

## Additional Resources

- **Ansible Documentation**: https://docs.ansible.com/
- **Proxmox VE Documentation**: https://pve.proxmox.com/pve-docs/
- **Project Constitution**: `../.specify/memory/constitution.md`
- **Feature Specs**: `../specs/`

---

**Questions?** Check [docs/README.md](README.md) for more documentation links.
