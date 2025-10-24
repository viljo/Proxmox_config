# Vault Completion Checklist

**Purpose**: Complete vault configuration for production-ready deployment automation

**Created**: 2025-10-24
**Status**: Action Required

## Current Status

### Variables Defined ✅

The vault file currently has 76 lines with the following variables properly defined:

#### Container Root Passwords
- ✅ `vault_firewall_root_password`
- ✅ `vault_demo_site_root_password`
- ✅ `vault_gitlab_root_password`
- ✅ `vault_gitlab_runner_root_password`
- ✅ `vault_keycloak_root_password`
- ✅ `vault_nextcloud_root_password`
- ✅ `vault_mattermost_root_password`

#### Database Passwords
- ✅ `vault_postgres_root_password` (postgres superuser)
- ✅ `vault_postgres_keycloak_password`
- ✅ `vault_postgres_nextcloud_password`
- ✅ `vault_postgres_mattermost_password`

#### Service-Specific Passwords
- ✅ `vault_keycloak_admin_password`
- ✅ `vault_keycloak_db_password`
- ✅ `vault_nextcloud_admin_password`
- ✅ `vault_nextcloud_db_password`
- ✅ `vault_ldap_admin_password`
- ✅ `vault_ldap_users` (4 users with passwords)

#### API Credentials
- ✅ `vault_loopia_api_user`
- ✅ `vault_loopia_api_password`

### Variables Missing ❌

These variables are required by deployment roles but not yet in the vault:

#### Container Root Passwords (5 missing)
- ❌ `vault_proxmox_root_password` - Proxmox host root password (for API auth)
- ❌ `vault_postgresql_root_password` - PostgreSQL container root password
- ❌ `vault_redis_root_password` - Redis container root password
- ❌ `vault_bastion_root_password` - Bastion container root password
- ❌ `vault_webtop_root_password` - Webtop container root password

#### Database Passwords (potentially missing)
- ⚠️ `vault_postgres_gitlab_password` - GitLab database user password (may be needed)

## Temporary File Status

### ⚠️ SECURITY ISSUE: Unencrypted Passwords in Repository

**File**: `inventory/group_vars/all/dr_test_vars.yml`
**Status**: EXISTS (should be deleted)
**Risk**: Contains unencrypted passwords visible in plaintext

**Contents**:
```yaml
vault_proxmox_root_password: "temp_dr_test_password_2025"
vault_postgresql_root_password: "TempPostgresPassword2025"
vault_redis_root_password: "TempRedisPassword2025"
vault_bastion_root_password: "TempBastionPassword2025"
vault_keycloak_root_password: "TempKeycloakPassword2025"
vault_gitlab_root_password: "TempGitLabPassword2025"
vault_gitlab_runner_root_password: "TempRunnerPassword2025"
vault_nextcloud_root_password: "TempNextcloudPassword2025"
vault_mattermost_root_password: "TempMattermostPassword2025"
vault_webtop_root_password: "TempWebtopPassword2025"
vault_demo_site_root_password: "TempDemoPassword2025"
```

**Impact**:
- These temporary passwords were used during the DR test
- Most are already replaced with secure passwords in the vault
- File should be deleted after missing variables are added to vault

## Action Required

### Step 1: Add Missing Variables to Vault

Edit the encrypted vault file:
```bash
ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt
```

Add these variables with **strong, unique passwords** (minimum 20 characters):

```yaml
# === Missing Container Root Passwords ===

# Proxmox host root password (for API authentication)
vault_proxmox_root_password: "GENERATE_STRONG_PASSWORD"

# PostgreSQL container (150) root password
vault_postgresql_root_password: "GENERATE_STRONG_PASSWORD"

# Redis container (158) root password
vault_redis_root_password: "GENERATE_STRONG_PASSWORD"

# Bastion container (110) root password
vault_bastion_root_password: "GENERATE_STRONG_PASSWORD"

# Webtop container (170) root password
vault_webtop_root_password: "GENERATE_STRONG_PASSWORD"

# === Optional: GitLab Database Password ===

# GitLab database user password (if not already set)
vault_postgres_gitlab_password: "GENERATE_STRONG_PASSWORD"
```

**Password Generation**:
```bash
# Generate strong passwords (20 characters, mixed case + digits + symbols)
pwgen -s 20 1
# or
openssl rand -base64 20
```

### Step 2: Verify Proxmox Root Password

The Proxmox root password is critical for API authentication. Verify it matches the actual root password:

```bash
# Test SSH login with current password
ssh root@192.168.1.3

# If successful, add the ACTUAL password to vault (not a new generated one!)
ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt
```

**⚠️ IMPORTANT**: For `vault_proxmox_root_password`, use the **existing** Proxmox root password, not a newly generated one. The other container passwords can be new since they'll be set during deployment.

### Step 3: Delete Temporary Test File

After adding missing variables to the vault:

```bash
# Verify all variables are in vault
ansible-vault view inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt | grep -E 'vault_(proxmox|postgresql|redis|bastion|webtop)_'

# If all variables present, delete temporary file
rm inventory/group_vars/all/dr_test_vars.yml

# Verify deletion
ls inventory/group_vars/all/dr_test_vars.yml  # should show "No such file"
```

### Step 4: Update .gitignore

Ensure temporary files are never committed:

```bash
# Check if dr_test_vars.yml is in .gitignore
grep dr_test_vars .gitignore

# If not found, add it
echo "inventory/group_vars/all/dr_test_vars.yml" >> .gitignore
```

### Step 5: Validate Vault Configuration

Test that all deployment roles can access required variables:

```bash
# Syntax check all playbooks
ansible-playbook -i inventory/hosts.yml playbooks/full-deployment.yml --syntax-check --vault-password-file=.vault_pass.txt

# Check specific variable
ansible -i inventory/hosts.yml proxmox_admin -m debug -a "var=vault_proxmox_root_password" --vault-password-file=.vault_pass.txt
```

### Step 6: Test Deployment

After completing the vault:

```bash
# Test a single service deployment (e.g., Redis)
ansible-playbook -i inventory/hosts.yml playbooks/redis-deploy.yml --vault-password-file=.vault_pass.txt --check

# If check mode passes, do actual deployment
ansible-playbook -i inventory/hosts.yml playbooks/redis-deploy.yml --vault-password-file=.vault_pass.txt
```

## Security Best Practices

### Password Requirements

All vault passwords must meet these criteria:
- ✅ Minimum 20 characters
- ✅ Mix of uppercase and lowercase letters
- ✅ Mix of digits and symbols
- ✅ Unique (never reuse passwords)
- ✅ Randomly generated (not dictionary words)

### Password Rotation

Establish a password rotation schedule:
- **Critical services** (Proxmox, PostgreSQL, Keycloak): Every 90 days
- **Standard services**: Every 180 days
- **Internal services** (Redis, GitLab Runner): Every 365 days

### Vault Access Control

- ✅ `.vault_pass.txt` must be in `.gitignore`
- ✅ Never commit unencrypted passwords
- ✅ Store vault password in secure password manager
- ✅ Use different vault password per environment (dev/staging/prod)

### Audit Trail

Document password changes:
```bash
# After rotating passwords, commit vault changes
git add inventory/group_vars/all/secrets.yml
git commit -m "Rotate vault passwords - Q1 2025 rotation"
```

## Verification Checklist

After completing all steps:

- [ ] All 5 missing container root passwords added to vault
- [ ] GitLab database password added (if needed)
- [ ] Proxmox root password verified (matches actual root password)
- [ ] Temporary `dr_test_vars.yml` file deleted
- [ ] File added to `.gitignore` to prevent future commits
- [ ] Vault syntax validated with `--syntax-check`
- [ ] Test deployment passes for at least one service
- [ ] No plaintext passwords in repository
- [ ] Vault password stored in secure location
- [ ] Password rotation schedule documented

## Files to Check

### Before Completion
```bash
$ ls -la inventory/group_vars/all/
-rw-r--r--  dr_test_vars.yml      # ⚠️ Should be deleted
-rw-------  secrets.yml            # ✅ Encrypted vault
```

### After Completion
```bash
$ ls -la inventory/group_vars/all/
-rw-------  secrets.yml            # ✅ Encrypted vault (only file)

$ grep dr_test_vars .gitignore
inventory/group_vars/all/dr_test_vars.yml  # ✅ In .gitignore
```

## Impact on DR Test Results

**Current Issue**: The DR test on 2025-10-23 used temporary unencrypted passwords from `dr_test_vars.yml`. This is acceptable for testing but not production-ready.

**After Completion**:
- ✅ All deployments use encrypted vault passwords
- ✅ No security risk from plaintext passwords
- ✅ Proper password rotation schedule established
- ✅ Production-ready authentication

## References

- [VAULT_VARIABLES.md](VAULT_VARIABLES.md) - Complete list of required variables
- [DR_TEST_LESSONS_LEARNED.md](DR_TEST_LESSONS_LEARNED.md) - Why vault completion matters
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

## Next Steps After Completion

Once vault is complete:
1. Test full-deployment.yml with proper prerequisites (firewall running)
2. Apply TDD workflow to Mattermost (Steps 4-9)
3. Investigate GitLab backup corruption
4. Schedule next DR test (2025-11-23)

---

**Status**: ⚠️ Action Required
**Priority**: High
**Owner**: Infrastructure Admin
**Due Date**: Before next service deployment
