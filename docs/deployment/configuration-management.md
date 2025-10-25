# Configuration Management

This guide explains what configuration files should be tracked in git and how to properly separate secrets from infrastructure topology.

## Overview

**Key Principle**: Track infrastructure topology in git, keep secrets in Ansible Vault.

- **Infrastructure Topology** = Container IDs, IP addresses, ports, network layout → **COMMIT TO GIT**
- **Secrets** = Passwords, API keys, tokens, certificates → **ANSIBLE VAULT ONLY**

## What Should Be Tracked in Git

### ✅ Always Track These Files

All files in `inventory/group_vars/all/*.yml` that define infrastructure topology:

- `main.yml` - Core infrastructure settings (domain, DNS, Traefik services)
- `network.yml` - Network bridges, interfaces, IP addressing
- `dmz.yml` - DMZ subnet configuration
- `firewall.yml` - Firewall rules and port forwarding
- `postgresql.yml` - Database server topology (not passwords!)
- Service definition files: `gitlab.yml`, `nextcloud.yml`, `keycloak.yml`, etc.

**Proxmox Configuration:**
- `inventory/group_vars/proxmox_hosts/proxmox_api.yml` - API settings (references vault)
- `inventory/hosts.yml` - Ansible inventory (hostnames and IPs only)

**Why track these?**
- Provides audit trail for infrastructure changes
- Enables rollback to previous configurations
- Documents infrastructure as code
- Facilitates disaster recovery
- Enables team collaboration via pull requests

### ❌ Never Track These

- `.vault_pass.txt` - Vault password file
- `**/dr_test_vars.yml` - May contain unencrypted test passwords
- Any file with hardcoded passwords, API keys, or tokens

### 🔐 Special Case: secrets.yml

`inventory/group_vars/all/secrets.yml` **IS tracked** but only because it's encrypted with Ansible Vault.

## How to Identify if a File Should Be Tracked

### Safe to Track (Topology)

```yaml
# ✅ This is topology - safe to track
gitlab_container_id: 153
gitlab_ip_address: 172.16.10.153
gitlab_external_url: "https://gitlab.example.com"
gitlab_root_password: "{{ vault_gitlab_root_password }}"  # References vault
```

**Characteristics:**
- Contains container IDs, IP addresses, ports, hostnames
- All sensitive values reference `{{ vault_* }}` variables
- Defines "what" and "where", not "how to authenticate"

### Never Track (Contains Secrets)

```yaml
# ❌ This contains secrets - DO NOT TRACK
gitlab_root_password: "MyActualPassword123!"
api_token: "ghp_abc123def456"
database_password: "SuperSecret2024"
```

**Characteristics:**
- Contains plaintext passwords, tokens, or keys
- Hardcoded credentials
- Private keys or certificates

## Adding a New Service

When adding a new service configuration file (e.g., `mattermost.yml`):

### 1. Create the Service Configuration

```yaml
---
# inventory/group_vars/all/mattermost.yml
mattermost_container_id: 163
mattermost_hostname: mattermost
mattermost_ip_address: 172.16.10.163
mattermost_bridge: "{{ public_bridge }}"
mattermost_gateway: "{{ dmz_gateway }}"
mattermost_root_password: "{{ vault_mattermost_root_password }}"  # ✅ Uses vault
mattermost_db_password: "{{ vault_mattermost_db_password }}"      # ✅ Uses vault
```

### 2. Add Secrets to Vault

```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Add the vault variables:
```yaml
vault_mattermost_root_password: "actual_secure_password"
vault_mattermost_db_password: "actual_db_password"
```

### 3. Commit the Service Configuration

```bash
git add inventory/group_vars/all/mattermost.yml
git commit -m "Add Mattermost service configuration"
git push
```

**The service configuration is now tracked, but secrets remain encrypted in Vault.**

## Verifying Before Commit

Before committing any YAML file, verify it contains no secrets:

```bash
# Check for hardcoded passwords
grep -E "(password|secret|api_key|token):" inventory/group_vars/all/yourfile.yml | grep -v "vault_"

# If this returns anything, review those lines carefully!
```

**Safe pattern:** All sensitive values should reference vault variables:
```yaml
some_password: "{{ vault_some_password }}"  # ✅ Good
some_password: "MyPassword123"              # ❌ Bad - DO NOT COMMIT
```

## Current .gitignore Strategy

The `.gitignore` is configured to:

1. **Ignore all YAML files by default** (defensive approach)
2. **Explicitly allow** known-safe topology files:
   - `!inventory/group_vars/all/*.yml` - All service definitions
   - `!inventory/group_vars/proxmox_hosts/*.yml` - Proxmox API config
   - `!inventory/hosts.yml` - Ansible inventory

This means:
- New service configuration files are automatically visible to git
- You must consciously add them (preventing accidental secret commits)
- Protected against accidentally committing test files with secrets

## Migration History

**2025-10-25**: Migrated from "ignore everything" to "track topology, vault secrets"
- Previously: All `*.yml` files in `inventory/group_vars/` were ignored
- Now: Service topology files are tracked, only `.vault_pass.txt` and test files ignored
- Benefit: Full audit trail, rollback capability, disaster recovery

## Best Practices

### DO:
- ✅ Reference all secrets via `{{ vault_* }}` variables
- ✅ Track infrastructure topology (IPs, ports, container IDs)
- ✅ Use `ansible-vault edit` to manage secrets
- ✅ Review diffs before committing to verify no secrets present
- ✅ Use descriptive commit messages for infrastructure changes

### DON'T:
- ❌ Hardcode passwords, tokens, or keys in tracked files
- ❌ Commit `.vault_pass.txt`
- ❌ Track test files with unencrypted passwords
- ❌ Use `_open` fallback variables (deprecated for security)
- ❌ Share vault passwords via insecure channels

## Troubleshooting

### "I accidentally committed a secret!"

**If not yet pushed:**
```bash
# Remove the file from staging
git reset HEAD path/to/file.yml

# Edit the file to use vault references
vim path/to/file.yml

# Re-add and commit properly
git add path/to/file.yml
git commit --amend
```

**If already pushed:**
1. Remove the secret from the file immediately
2. Rotate the compromised credential
3. Consider the secret compromised permanently
4. Use `git filter-branch` or BFG Repo-Cleaner to remove from history (advanced)

### "How do I know if a file should be tracked?"

Ask yourself:
1. Does this file contain plaintext passwords/tokens/keys? → **Don't track**
2. Does this file define infrastructure layout (IPs, ports, container IDs)? → **Track it**
3. Do all sensitive values reference `{{ vault_* }}`? → **Track it**

When in doubt, ask a team member or review this guide.

## Related Documentation

- [Secrets Management](secrets-management.md) - How to use Ansible Vault
- [Getting Started](../getting-started.md) - Initial setup guide
- [New Service Workflow](../NEW_SERVICE_WORKFLOW.md) - Adding services step-by-step

## Summary

**Simple Rule**: If it defines "what" and "where" (topology), track it in git. If it defines "how to authenticate" (secrets), put it in Vault.

This approach provides:
- 🔒 Security: Secrets encrypted and separate from topology
- 📋 Audit Trail: All infrastructure changes tracked
- ↩️ Rollback: Can revert to any previous state
- 🚀 Collaboration: Team can review infrastructure changes
- 💾 DR: Clone repo + Vault = full infrastructure restore
