# Demo App API-Based Deployment Guide

**Created**: 2025-10-21
**Status**: Production Ready
**Method**: Proxmox API + Ansible Delegation (No SSH/pct commands)

## Overview

This guide documents the **fully refactored** demo app deployment using Proxmox API modules and proper Ansible delegation instead of SSH/pct commands.

### What's Deployed

1. **Firewall Container** (ID: 101, IP: 172.16.10.101)
   - Manages WAN/DMZ routing
   - nftables with NAT/SNAT rules
   - DHCP on WAN interface

2. **Demo Site Container** (ID: 160, IP: 172.16.10.160)
   - Nginx web server
   - Serves demo HTML pages
   - Accessible via Traefik reverse proxy

3. **Traefik** (Proxmox host, IP: 172.16.10.102)
   - Reverse proxy with automatic HTTPS
   - Let's Encrypt DNS challenge (Loopia)
   - Routes traffic to demo site

4. **Loopia DDNS** (Proxmox host)
   - Updates DNS records automatically
   - Monitors firewall WAN IP changes
   - Runs every 15 minutes

## Prerequisites

### 1. Proxmox API Token

Must be configured in vault:

```yaml
# inventory/group_vars/all/secrets.yml (encrypted)
vault_proxmox_api_token_id: "ansible"
vault_proxmox_api_token_secret: "22ff826b-786f-42f3-b8b1-5a23601cb010"
```

**Note**: Token credentials are in `/tmp/proxmox_api_creds.txt`

### 2. Loopia API Credentials

```yaml
# inventory/group_vars/all/secrets.yml (encrypted)
vault_loopia_api_user: "your-username@loopiaapi"
vault_loopia_api_password: "your-api-password"
```

### 3. Root Passwords

```yaml
# inventory/group_vars/all/secrets.yml (encrypted)
vault_firewall_root_password: "secure-password"
vault_demo_site_root_password: "secure-password"
```

### 4. Collections Installed

```bash
ansible-galaxy collection install -r requirements.yml
```

## Deployment Steps

### Step 1: Verify Configuration

Check that API credentials are set:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml --check
```

Expected: Should fail if API credentials are missing.

### Step 2: Deploy Infrastructure

Deploy the complete stack:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml
```

This will:
1. ✅ Configure network bridges
2. ✅ Create firewall container (API)
3. ✅ Configure firewall (delegation, not pct exec)
4. ✅ Create demo site container (API)
5. ✅ Configure demo site (delegation)
6. ✅ Install and configure Traefik
7. ✅ Configure Loopia DDNS
8. ✅ Update DNS records

### Step 3: Verify Deployment

Check container status:

```bash
ssh root@192.168.1.3 "pct list"
```

Expected output:
```
VMID       Status     Name
101        running    firewall
160        running    demosite
```

Check services:

```bash
# Firewall WAN IP
ssh root@192.168.1.3 "pct exec 101 -- ip -4 addr show eth0 | grep inet"

# Demo site
curl -I http://172.16.10.160/

# Traefik
ssh root@192.168.1.3 "systemctl status traefik"
```

### Step 4: Wait for DNS Propagation

DNS updates may take 5-10 minutes:

```bash
# Check DNS
dig +short demosite.viljo.se @1.1.1.1

# Should return the firewall WAN IP
```

### Step 5: Test External Access

```bash
curl -I https://demosite.viljo.se/
```

Expected: `HTTP/2 200` with valid TLS certificate.

## Deployment Tags

Deploy specific components:

```bash
# Only network configuration
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml --tags network

# Only firewall
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml --tags firewall

# Only demo site
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml --tags demo_site

# Only Traefik
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml --tags traefik

# Only DNS
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml --tags loopia_ddns
```

## Architecture

```
Internet
  |
  | WAN (DHCP)
  |
┌─────────────────────┐
│ Firewall (101)      │
│ .101 DMZ            │
│ - nftables NAT      │
│ - DNAT 80/443→.102  │
│ - SNAT WAN↔DMZ      │
└─────────────────────┘
  |
  | DMZ (172.16.10.0/24)
  |
  ├─── Traefik (Proxmox Host .102)
  │      - Reverse proxy
  │      - TLS termination
  │      - Let's Encrypt
  │
  └─── Demo Site (160, .160)
         - Nginx
         - Demo HTML pages
```

## Key Differences from Old Method

### Container Creation

**OLD (SSH-based)**:
```yaml
- name: Create container
  ansible.builtin.shell: |
    pct create 160 /var/lib/vz/template/cache/debian.tar.zst \
      --hostname demosite \
      --cores 1 \
      # ... many more flags ...
  args:
    creates: "/etc/pve/lxc/160.conf"
```

**NEW (API-based)**:
```yaml
- name: Create/update container
  community.proxmox.proxmox:
    api_host: "{{ proxmox_api_host }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    vmid: 160
    hostname: demosite
    ostemplate: "local:vztmpl/debian.tar.zst"
    cores: 1
    state: started
```

### Package Installation

**OLD (pct exec)**:
```yaml
- name: Install nginx
  ansible.builtin.command:
    cmd: pct exec 160 -- bash -lc "apt-get install -y nginx"
```

**NEW (delegation)**:
```yaml
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present
  delegate_to: demo_site_container
```

### File Management

**OLD (pct push)**:
```yaml
- name: Render file locally
  ansible.builtin.template:
    src: index.html.j2
    dest: /tmp/index.html

- name: Push file to container
  ansible.builtin.command:
    cmd: pct push 160 /tmp/index.html /var/www/html/index.html

- name: Clean up temp file
  ansible.builtin.file:
    path: /tmp/index.html
    state: absent
```

**NEW (direct template)**:
```yaml
- name: Configure index page
  ansible.builtin.template:
    src: index.html.j2
    dest: /var/www/html/index.html
    owner: www-data
    group: www-data
    mode: '0644'
  delegate_to: demo_site_container
```

## Benefits

### 1. Idempotency

```bash
# First run: creates containers
PLAY RECAP *****
proxmox_admin: ok=42 changed=30

# Second run: no changes
PLAY RECAP *****
proxmox_admin: ok=42 changed=0
```

### 2. Check Mode

```bash
# See what would change without applying
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml --check --diff
```

### 3. Less Code

- **OLD firewall role**: ~150 lines with shell commands
- **NEW firewall_api role**: ~95 lines with modules
- **Reduction**: 37% less code

### 4. Better Error Handling

Ansible modules include:
- Automatic retries
- State tracking
- Detailed error messages
- Rollback support

## Troubleshooting

### API Authentication Failed

```
Error: API authentication failed
```

**Solution**: Verify API token in vault:
```bash
ansible-vault view inventory/group_vars/all/secrets.yml | grep proxmox_api
```

### Container Creation Failed

```
Error: VM 101 already exists
```

**Solution**: Destroy existing container first:
```bash
ssh root@192.168.1.3 "pct stop 101 && pct destroy 101"
```

### DNS Not Updating

**Check**: Firewall WAN IP:
```bash
ssh root@192.168.1.3 "pct exec 101 -- ip addr show eth0 | grep 'inet '"
```

**Force update**:
```bash
ssh root@192.168.1.3 "/usr/local/bin/loopia-ddns"
```

### Demo Site Not Accessible

1. **Check container**: `ssh root@192.168.1.3 "pct status 160"`
2. **Check nginx**: `ssh root@172.16.10.160 "systemctl status nginx"`
3. **Check Traefik**: `ssh root@192.168.1.3 "systemctl status traefik"`
4. **Check firewall NAT**: `ssh root@192.168.1.3 "pct exec 101 -- nft list ruleset"`

## Files Created

```
playbooks/
  demo-app-api.yml                  # Main playbook (API-based)

roles/firewall_api/
  defaults/main.yml                 # Variables
  tasks/main.yml                    # API-based deployment
  templates/nftables.conf.j2        # Firewall rules
  handlers/main.yml                 # Service handlers

roles/demo_site_api/
  defaults/main.yml                 # Variables
  tasks/main.yml                    # API-based deployment
  templates/index.html.j2           # Demo page
  templates/hello.html.j2           # Demo page
  handlers/main.yml                 # Service handlers

roles/traefik_api/
  defaults/main.yml                 # Variables
  tasks/main.yml                    # Traefik deployment
  templates/traefik.yml.j2          # Main config
  templates/demosite.yml.j2         # Dynamic routing
  handlers/main.yml                 # Service handlers

roles/loopia_ddns_api/
  defaults/main.yml                 # Variables
  tasks/main.yml                    # DDNS deployment
  templates/update.py.j2            # Update script
  templates/loopia-ddns.service.j2  # Systemd service
  templates/loopia-ddns.timer.j2    # Systemd timer
  handlers/main.yml                 # Service handlers
```

## Next Steps

1. **Add More Services**: Follow the same pattern for other roles
2. **Implement Backups**: Use `community.proxmox.proxmox_snap`
3. **Add Monitoring**: Deploy monitoring stack with API
4. **CI/CD Integration**: Run playbook in GitLab CI

## References

- [Automation Refactoring Plan](../development/automation-refactoring-plan.md)
- [community.proxmox Collection](https://docs.ansible.com/ansible/latest/collections/community/proxmox/)
- [Ansible Delegation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_delegation.html)

---

**Last Updated**: 2025-10-21
**Tested**: Proxmox VE 9.0, Ansible 2.18
