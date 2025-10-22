# NetBox Vault Secrets

This document lists the vault-encrypted variables required for the NetBox role.

## Required Vault Variables

Add these variables to `inventory/group_vars/all/secrets.yml`:

```yaml
---
# NetBox LXC Container
vault_netbox_root_password: "your_secure_root_password_here"

# NetBox Application
vault_netbox_secret_key: "your_random_secret_key_here"  # Generate with: openssl rand -hex 50
vault_netbox_superuser_password: "your_secure_admin_password_here"

# NetBox Database (PostgreSQL)
vault_netbox_db_password: "your_secure_db_password_here"

# NetBox Cache (Redis)
vault_netbox_redis_password: "your_secure_redis_password_here"
```

## Generating Secrets

### Django Secret Key
Generate a secure random secret for `vault_netbox_secret_key` (50+ characters recommended):
```bash
openssl rand -hex 50
```

### Passwords
Use a password manager or generate secure passwords:
```bash
openssl rand -base64 24
```

## Editing Vault

To edit the encrypted vault file:
```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Or if using a vault password file:
```bash
ansible-vault edit --vault-password-file .vault_pass.txt inventory/group_vars/all/secrets.yml
```

## Database Setup

NetBox uses an embedded PostgreSQL container within its Docker Compose stack, so **no external database setup is required**. The database is automatically initialized on first startup using the credentials provided in the vault variables.

Unlike some other services that use the shared PostgreSQL container (ID 50), NetBox runs its own isolated PostgreSQL instance within container ID 52.

## Initial Login

After deployment, access NetBox at `https://netbox.viljo.se` (or `http://172.16.10.52:8080` internally) and login with:
- **Username**: `admin`
- **Email**: `admin@viljo.se`
- **Password**: Value of `vault_netbox_superuser_password`

## Security Notes

- **Never commit unencrypted secrets** to version control
- Use `ansible-vault` for all sensitive data
- Rotate secrets periodically
- Use different passwords for each service
- Store vault password securely (not in the repository)
- The Django `SECRET_KEY` should be at least 50 characters long
- Change the default superuser password after first login

## Post-Deployment Security

After deploying NetBox:

1. Login with the initial admin credentials
2. Change the admin password in the NetBox UI
3. Consider enabling two-factor authentication
4. Create individual user accounts for team members
5. Review and configure authentication settings
6. Set up API tokens for automation

---

**Last Updated**: 2025-10-22
