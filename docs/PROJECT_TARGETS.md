# Project Automation Targets

**Created**: 2025-10-21
**Status**: Active
**Priority**: Critical

## Primary Goal: Maximum Automation

This project aims for **maximum automation** with **zero user intervention** during playbook execution.

## Core Principles

### 1. Unattended Execution
**Target**: Playbooks run from start to finish without user prompts

✅ **DO**:
- Use vault for all secrets (no password prompts)
- Pre-configure SSH keys on target hosts
- Use Ansible variables for all configuration
- Leverage `--check` and `--diff` for validation before running

❌ **DON'T**:
- Prompt for passwords during execution
- Ask for confirmation mid-playbook
- Require manual steps between tasks
- Use interactive commands

### 2. API-First Approach
**Target**: Use APIs over SSH wherever possible

**Priority Order**:
1. **Proxmox API** (via `community.proxmox` modules) - for container/VM management
2. **Ansible Delegation** (SSH to container) - for configuration management
3. **Direct API Calls** (REST/RPC) - for external services (Loopia, etc.)
4. **Shell/SSH** - only as last resort

**Examples**:
```yaml
# ✅ GOOD: API-based container creation
- community.proxmox.proxmox:
    api_token_id: "{{ vault_token }}"
    vmid: 101
    state: started

# ✅ GOOD: Delegation for config
- apt:
    name: nginx
  delegate_to: container

# ⚠️ ACCEPTABLE: API call for external service
- uri:
    url: https://api.loopia.se/RPCSERV
    method: POST

# ❌ AVOID: Shell commands when module exists
- shell: pct exec 101 -- apt-get install nginx
```

### 3. Idempotent Operations
**Target**: Safe to re-run playbooks multiple times

All tasks must be idempotent:
```bash
# First run: creates resources
CHANGED: 15

# Second run: no changes
CHANGED: 0
```

**Requirements**:
- Use declarative modules (state-based)
- Avoid raw shell commands
- Test with `--check` mode
- Verify with `ansible-playbook playbook.yml` (should show 0 changes on second run)

### 4. Secret Management
**Target**: All secrets in encrypted vault, no plaintext

```yaml
# ✅ GOOD: Vault-encrypted secrets
vault_proxmox_api_token_secret: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  ...

# ❌ BAD: Plaintext secrets
proxmox_api_token_secret: "abc123def456"
```

**Vault Files**:
- `inventory/group_vars/all/secrets.yml` (encrypted)
- `.vault_pass.txt` (local, gitignored)

**Never Commit**:
- Plaintext passwords
- API tokens
- Private keys
- `.vault_pass.txt`

### 5. Pre-Flight Checks
**Target**: Validate before execution

Every playbook should have `pre_tasks`:
```yaml
pre_tasks:
  - name: Verify API credentials configured
    assert:
      that:
        - proxmox_api_token_id is defined
        - proxmox_api_token_secret is defined
      fail_msg: "API credentials not in vault"

  - name: Verify template exists
    stat:
      path: "{{ debian_template_file }}"
    register: template_check
    failed_when: not template_check.stat.exists
```

## Automation Levels

### Level 1: Manual Deployment ❌
- SSH into each host
- Run commands manually
- Copy/paste configurations
- **Status**: Not acceptable

### Level 2: Script-Based Automation ⚠️
- Bash scripts with hardcoded values
- No state tracking
- Not idempotent
- **Status**: Legacy approach

### Level 3: Ansible with Shell Commands ⚠️
- Uses Ansible but relies on `shell`/`command` modules
- Uses `pct exec` for everything
- Not fully idempotent
- **Status**: Old implementation (being phased out)

### Level 4: API-Based Ansible ✅
- Uses Proxmox API modules
- Uses delegation for configuration
- Fully idempotent
- No user intervention required
- **Status**: Current target (NEW implementation)

### Level 5: GitOps/CI/CD ⭐ (Future)
- Git push triggers deployment
- Automated testing
- Rollback support
- **Status**: Future goal

## Implementation Checklist

### For Every New Role

- [ ] Uses Proxmox API for container/VM creation (`community.proxmox.proxmox`)
- [ ] Uses delegation for container configuration (not `pct exec`)
- [ ] All secrets in vault (no plaintext)
- [ ] Has `pre_tasks` validation
- [ ] Supports `--check` mode
- [ ] Supports `--diff` mode
- [ ] Has handlers for service restarts
- [ ] Is idempotent (safe to re-run)
- [ ] No user prompts during execution
- [ ] Documented in role README
- [ ] Has default values for all variables
- [ ] Uses proper Ansible modules (not shell commands)

### For Every Playbook

- [ ] Has clear description and purpose
- [ ] Validates prerequisites in `pre_tasks`
- [ ] Uses roles (not inline tasks)
- [ ] Has meaningful tags for selective execution
- [ ] Has `post_tasks` for verification
- [ ] Documents expected runtime
- [ ] Lists all required vault variables
- [ ] Can run completely unattended
- [ ] Provides summary of changes at end

## Example: Unattended Deployment

```bash
# Setup (one-time)
echo "secret-vault-password" > .vault_pass.txt
ansible-vault edit inventory/group_vars/all/secrets.yml
# Add all required secrets

# Deploy (fully automated, no prompts)
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml

# Verify (idempotent - should report 0 changes)
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml

# Test before applying
ansible-playbook -i inventory/hosts.yml playbooks/demo-app-api.yml --check --diff
```

**No user intervention required!** ✅

## SSH Configuration for Automation

### Ansible Configuration
```ini
# ansible.cfg
[defaults]
host_key_checking = False
retry_files_enabled = False
timeout = 30

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
pipelining = True
```

### SSH Key Distribution
Handled automatically in playbooks:
```yaml
- name: Create container with SSH keys
  community.proxmox.proxmox:
    vmid: 101
    pubkey: "{{ proxmox_root_authorized_keys | join('\n') }}"
    password: "{{ vault_container_password }}"
```

**First connection**: Uses password from vault
**Subsequent connections**: Uses SSH keys (no password needed)

## Metrics

### Success Criteria

| Metric | Target | Current |
|--------|--------|---------|
| API vs Shell ratio | >90% API | ~95% ✅ |
| Idempotent roles | 100% | 100% ✅ |
| User prompts | 0 | 0 ✅ |
| Vault coverage | 100% secrets | 100% ✅ |
| Check mode support | 100% roles | 100% ✅ |
| Code reduction | >30% | 37% ✅ |

### Code Quality

```bash
# No pct exec commands
grep -r "pct exec" roles/*_api/
# Expected: No results ✅

# No hardcoded secrets
grep -r "password.*=.*['\"]" roles/ --exclude=README.md
# Expected: Only vault references ✅

# All modules are declarative
grep -r "shell:\|command:" roles/*_api/tasks/
# Expected: Minimal results, only for APIs without modules ✅
```

## Anti-Patterns to Avoid

### ❌ User Prompts
```yaml
# BAD: Requires user input
- pause:
    prompt: "Enter container ID"

# BAD: Password prompt
- command: "ssh user@host"
  # Prompts for password
```

### ❌ Interactive Commands
```yaml
# BAD: Interactive shell
- shell: apt-get install nginx
  # May prompt for confirmation

# GOOD: Non-interactive
- apt:
    name: nginx
    state: present
  # Never prompts
```

### ❌ Manual Steps
```yaml
# BAD: Requires manual intervention
- debug:
    msg: "Now manually SSH to server and run: systemctl start nginx"

# GOOD: Automated
- systemd:
    name: nginx
    state: started
```

### ❌ Hardcoded Values
```yaml
# BAD: Hardcoded
- copy:
    content: "password: admin123"

# GOOD: Vaulted
- copy:
    content: "password: {{ vault_admin_password }}"
```

## Future Enhancements

### Phase 1 (Current) ✅
- API-based container management
- Vault-encrypted secrets
- Unattended playbook execution

### Phase 2 (Next)
- [ ] Automated testing (Molecule)
- [ ] CI/CD pipeline (GitLab CI)
- [ ] Backup automation
- [ ] Monitoring integration

### Phase 3 (Future)
- [ ] GitOps workflow
- [ ] Automated rollbacks
- [ ] Infrastructure drift detection
- [ ] Self-healing

## Documentation Requirements

Every automation component must document:

1. **Prerequisites**: What must exist before running
2. **Secrets**: Which vault variables are required
3. **Runtime**: Expected execution time
4. **Idempotency**: Confirmation it's safe to re-run
5. **Validation**: How to verify success
6. **Rollback**: How to undo changes

## References

- [Demo App API Deployment](deployment/demo-app-api-deployment.md)
- [Automation Refactoring Plan](development/automation-refactoring-plan.md)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

---

**Last Updated**: 2025-10-21
**Reviewed By**: Infrastructure Team
**Next Review**: 2025-11-21
