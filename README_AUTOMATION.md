# Automation Principles - Quick Reference

**Project Goal**: Maximum automation with zero user intervention during playbook execution.

## Core Principles

### 1. API-First Approach
**Prefer APIs over SSH/shell commands**

```
Priority Order:
1. Proxmox API (community.proxmox modules)     ✅ BEST
2. Ansible Delegation (SSH to containers)      ✅ GOOD
3. REST/RPC APIs (external services)           ✅ ACCEPTABLE
4. Shell/SSH commands                          ⚠️  LAST RESORT
```

### 2. Unattended Execution
**Playbooks run from start to finish without prompts**

✅ **Achieved by**:
- All secrets in Ansible Vault
- SSH keys pre-configured in containers
- `host_key_checking = False` in ansible.cfg
- Passwords from vault (never prompted)

❌ **Avoid**:
- Password prompts
- Manual confirmations
- Interactive commands
- Mid-playbook user input

### 3. Idempotent Operations
**Safe to re-run playbooks multiple times**

```bash
# First run: creates infrastructure
ansible-playbook playbooks/demo-app-api.yml
# CHANGED: 15

# Second run: no changes
ansible-playbook playbooks/demo-app-api.yml
# CHANGED: 0  ✅
```

## Quick Start

### One-Time Setup
```bash
# 1. Create vault password file
echo "your-vault-password" > .vault_pass.txt

# 2. Add secrets to vault
ansible-vault edit inventory/group_vars/all/secrets.yml
# Add:
#   vault_proxmox_api_token_id: "ansible"
#   vault_proxmox_api_token_secret: "your-token"
#   vault_loopia_api_user: "user@loopiaapi"
#   vault_loopia_api_password: "your-password"
#   vault_firewall_root_password: "secure-password"
#   vault_demo_site_root_password: "secure-password"
```

### Deploy Demo App (Fully Automated)
```bash
# Test deployment (dry run)
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml --check --diff

# Deploy (no prompts, fully automated)
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml

# Verify idempotency (should show 0 changes)
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml
```

**No user intervention required!** ✅

## Code Examples

### ✅ GOOD: API-Based Container Creation
```yaml
- name: Create firewall container
  community.proxmox.proxmox:
    api_host: "{{ proxmox_api_host }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    vmid: 101
    hostname: firewall
    state: started
    password: "{{ vault_firewall_root_password }}"
    pubkey: "{{ proxmox_root_authorized_keys | join('\n') }}"
```

### ✅ GOOD: Configuration via Delegation
```yaml
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present
  delegate_to: demo_site_container
```

### ❌ BAD: Shell Commands with pct exec
```yaml
- name: Install nginx
  ansible.builtin.command:
    cmd: pct exec 160 -- apt-get install -y nginx
```

## Current Implementation

### API-Based Roles ✅
- **firewall_api**: Container via Proxmox API
- **demo_site_api**: Container via Proxmox API
- **traefik_api**: Ansible modules (no shell)
- **loopia_ddns_api**: Ansible modules (no shell)

### Legacy Roles ⚠️ (Being Phased Out)
- **firewall**: Uses pct commands
- **demo_site**: Uses pct commands
- **traefik**: Uses shell commands
- **loopia_ddns**: Uses shell commands

### Manual Deployments ❌ (Require Ansible Roles)

**These services are currently deployed but lack Ansible automation, blocking disaster recovery goals:**

| Service | Container ID | Deployment Method | Impact | Priority |
|---------|--------------|-------------------|--------|----------|
| **bastion** | 110 | `pct create` + manual config | SSH gateway unavailable after DR | High |
| **postgresql** | 150 | `pct exec` + manual SQL | All DB-dependent services fail | **Critical** |
| **redis** | 158 | `pct exec` + manual redis-server | Cache/queue unavailable | High |
| **keycloak** | 151 | `pct exec` + manual build | SSO unavailable | High |
| **gitlab** | 153 | `pct exec` + Docker | DevOps platform unavailable | Medium |
| **gitlab_runner** | 154 | `pct exec` + manual registration | CI/CD pipelines fail | Medium |
| **nextcloud** | 155 | `pct exec` + nginx + PHP config | File sharing unavailable | Medium |
| **mattermost** | 163 | `pct exec` + Docker Compose | Team communication unavailable | Medium |
| **webtop** | 170 | `pct exec` + Docker Compose | Remote browser unavailable | Low |

**Disaster Recovery Impact**: Current DR time estimate is **8-12 hours** due to manual steps. Goal: **<1 hour fully automated**.

**Action Required**: Create Ansible roles for these services. See [Automation Audit](docs/AUTOMATION_AUDIT.md) for detailed roadmap with milestones and target dates.

## Metrics

| Metric | Target | Current | Status | Notes |
|--------|--------|---------|--------|-------|
| API vs Shell | >90% | ~15% | ❌ | Only demo_site_api uses Proxmox API fully |
| User Prompts | 0 | 0 | ✅ | No interactive prompts in any playbook |
| Idempotent | 100% | ~10% | ❌ | Most services deployed manually via SSH |
| Vault Secrets | 100% | ~60% | ⚠️ | Many manual deployments used hardcoded passwords |
| External Validation | 100% | ~9% | ❌ | Only 1 of 11 services tested externally |
| Disaster Recovery Ready | 100% | ~9% | ❌ | Only demo site can be rebuilt automatically |

**Reality Check**: While the automation *architecture* is sound, most services were deployed manually via SSH/pct exec commands. See [Automation Audit](docs/AUTOMATION_AUDIT.md) for detailed gap analysis and roadmap.

## Configuration

### ansible.cfg (Unattended Execution)
```ini
[defaults]
host_key_checking = False      # No SSH host key prompts
vault_identity_list = default@.vault_pass.txt  # Auto-load vault password

[ssh_connection]
ssh_args = -o StrictHostKeyChecking=no  # Skip host key verification
pipelining = True              # Faster execution
```

### SSH Key Distribution
Containers automatically get SSH keys:
```yaml
# In Proxmox API call
pubkey: "{{ proxmox_root_authorized_keys | join('\n') }}"
```

**First connection**: Uses password from vault
**Subsequent connections**: Uses SSH keys (passwordless)

## Documentation

- **Full Details**: [docs/PROJECT_TARGETS.md](docs/PROJECT_TARGETS.md)
- **Deployment Guide**: [docs/deployment/demo-app-api-deployment.md](docs/deployment/demo-app-api-deployment.md)
- **Refactoring Plan**: [docs/development/automation-refactoring-plan.md](docs/development/automation-refactoring-plan.md)

## Role Checklist

Every new role must:
- [ ] Use Proxmox API for containers (`community.proxmox.proxmox`)
- [ ] Use delegation for config (not `pct exec`)
- [ ] All secrets in vault
- [ ] Support `--check` mode
- [ ] Be idempotent
- [ ] No user prompts
- [ ] Document required vault variables

---

**Maximum Automation** | **Zero User Intervention** | **API-First** ✅
