# Required Vault Variables

This document lists all required variables that must be defined in the encrypted `inventory/group_vars/all/secrets.yml` vault file.

## Usage

Encrypt the vault file:
```bash
ansible-vault encrypt inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt
```

Edit the vault:
```bash
ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt
```

## Required Variables

### Proxmox API Authentication

```yaml
vault_proxmox_root_password: "SecurePassword123!"
```

Used by: All deployment roles for Proxmox API authentication

### Database Passwords

#### PostgreSQL
```yaml
vault_postgres_root_password: "SecurePostgresPassword!"
vault_postgres_keycloak_password: "SecureKeycloakDBPassword!"
vault_postgres_nextcloud_password: "SecureNextcloudDBPassword!"
vault_postgres_mattermost_password: "SecureMattermostDBPassword!"
vault_postgres_gitlab_password: "SecureGitLabDBPassword!"
```

Used by:
- `backup_infrastructure` role (for PostgreSQL database backups)
- `restore_infrastructure` role (for database restoration)
- Service roles that configure database connections

### Container Root Passwords

```yaml
vault_firewall_root_password: "SecureFirewallPassword!"
vault_bastion_root_password: "SecureBastionPassword!"
vault_postgresql_root_password: "SecurePostgreSQLPassword!"
vault_redis_root_password: "SecureRedisPassword!"
vault_keycloak_root_password: "SecureKeycloakPassword!"
vault_gitlab_root_password: "SecureGitLabPassword!"
vault_gitlab_runner_root_password: "SecureRunnerPassword!"
vault_nextcloud_root_password: "SecureNextcloudPassword!"
vault_mattermost_root_password: "SecureMattermostPassword!"
vault_webtop_root_password: "SecureWebtopPassword!"
vault_demo_site_root_password: "SecureDemoSitePassword!"
```

Used by: Deployment roles for setting container root passwords via Proxmox API

### Service-Specific Passwords

#### Keycloak
```yaml
vault_keycloak_admin_password: "SecureKeycloakAdminPassword!"
vault_keycloak_db_password: "SecureKeycloakDBPassword!"
```

#### LDAP (if used)
```yaml
vault_ldap_admin_password: "SecureLDAPPassword!"
vault_ldap_users:
  - uid: admin
    password: "SecureUserPassword!"
    # ... other user fields
```

## Missing Variables

If you see errors like:
```
'vault_postgres_root_password' is undefined
```

This means the variable is not defined in your vault. Add it using:
```bash
ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt
```

## Security Notes

1. **Never commit unencrypted passwords** to git
2. **Always use strong passwords** (minimum 16 characters, mix of upper/lower/digits/symbols)
3. **Rotate passwords regularly** (at least every 90 days)
4. **Store vault password securely** (`.vault_pass.txt` should be in `.gitignore`)
5. **Use different passwords** for each service (never reuse)

## Temporary Test Variables

During testing, temporary unencrypted variables may be used in `inventory/group_vars/all/dr_test_vars.yml`.

**⚠️ WARNING**: This file should NEVER be committed to git and should be deleted after testing:
```bash
rm inventory/group_vars/all/dr_test_vars.yml
```

## Validation

To validate that all required variables are defined, run:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/full-deployment.yml --syntax-check --vault-password-file=.vault_pass.txt
```

Any missing variables will cause errors during the syntax check.
