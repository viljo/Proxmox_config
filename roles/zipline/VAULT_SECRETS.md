# Zipline Vault Secrets

This document lists the vault-encrypted variables required for the Zipline role.

## Required Vault Variables

Add these variables to `inventory/group_vars/all/secrets.yml`:

```yaml
---
# Zipline LXC Container
vault_zipline_root_password: "your_secure_root_password_here"

# Zipline Application
vault_zipline_core_secret: "your_random_secret_key_here"  # Generate with: openssl rand -hex 32

# PostgreSQL Database for Zipline
vault_postgres_zipline_user: "zipline"
vault_postgres_zipline_password: "your_secure_db_password_here"
vault_postgres_zipline_db: "zipline"
```

## Generating Secrets

### Core Secret
Generate a secure random secret for `vault_zipline_core_secret`:
```bash
openssl rand -hex 32
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

Before deploying Zipline, ensure the PostgreSQL database and user are created on the shared PostgreSQL container (ID 50).

This can be done manually:
```bash
pct exec 50 -- psql -U postgres <<EOF
CREATE DATABASE zipline;
CREATE USER zipline WITH PASSWORD 'your_secure_db_password_here';
GRANT ALL PRIVILEGES ON DATABASE zipline TO zipline;
\c zipline
GRANT ALL ON SCHEMA public TO zipline;
EOF
```

Or add database provisioning tasks to the PostgreSQL role for automated setup.

## Security Notes

- **Never commit unencrypted secrets** to version control
- Use `ansible-vault` for all sensitive data
- Rotate secrets periodically
- Use different passwords for each service
- Store vault password securely (not in the repository)

---

**Last Updated**: 2025-10-22
