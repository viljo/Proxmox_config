# Coolify Vault Secrets

This document describes the vault secrets required for the Coolify role deployment.

## Required Vault Variables

Add the following variables to `inventory/group_vars/all/secrets.yml`:

```yaml
# Container root password
vault_coolify_root_password: "secure-random-password"

# PostgreSQL database password
vault_coolify_postgres_password: "secure-db-password"

# Redis cache password
vault_coolify_redis_password: "secure-redis-password"

# Application ID for Coolify authentication
vault_coolify_app_id: "coolify"

# Laravel application key (generate with: php artisan key:generate)
# Format: base64:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
vault_coolify_app_key: "base64:generated-key-here"

# Pusher/Soketi secret for real-time features
vault_coolify_pusher_app_secret: "random-pusher-secret"
```

## Generating Secrets

### Application Key

The Coolify application key is a Laravel application key. Generate it using one of these methods:

**Method 1: Using openssl**
```bash
echo "base64:$(openssl rand -base64 32)"
```

**Method 2: Using PHP (if available)**
```bash
php -r "echo 'base64:' . base64_encode(random_bytes(32)) . PHP_EOL;"
```

**Method 3: Using Python**
```bash
python3 -c "import os, base64; print('base64:' + base64.b64encode(os.urandom(32)).decode())"
```

### Other Secrets

Generate secure random passwords for other secrets:

```bash
# PostgreSQL password
openssl rand -base64 32

# Redis password
openssl rand -base64 32

# Pusher secret
openssl rand -base64 32
```

## Editing Vault Secrets

To add or update these secrets in the encrypted vault file:

```bash
# Edit the vault file
ansible-vault edit inventory/group_vars/all/secrets.yml

# Or if using a vault password file
ansible-vault edit --vault-password-file .vault_pass.txt inventory/group_vars/all/secrets.yml
```

## Security Recommendations

1. **Strong Passwords**: Use at least 32 characters for all secrets
2. **Unique Secrets**: Generate unique values for each secret (don't reuse)
3. **Secure Storage**: Keep vault password file (`.vault_pass.txt`) outside the repository
4. **Regular Rotation**: Consider rotating secrets periodically
5. **Access Control**: Limit who has access to the vault password

## Post-Deployment Security

After deploying Coolify:

1. **Immediately** access the Coolify web interface at https://coolify.viljo.se
2. **Register your admin account** before anyone else can
3. Configure additional security settings in Coolify UI
4. Set up SSH keys for Git repository access
5. Configure 2FA if available in Coolify settings

## Example Vault Entry

Complete example of Coolify secrets in vault file:

```yaml
---
# Coolify secrets
vault_coolify_root_password: "Xk9mN2pQvT4sR8wL3zH6yB5nC1dF0gE"
vault_coolify_postgres_password: "aB3xY9mW2kL5qR8tN1vC7zD4pS6jH0f"
vault_coolify_redis_password: "pQ2nM5kL8vR1xT4yC9zB3aS7wD0jF6h"
vault_coolify_app_id: "coolify"
vault_coolify_app_key: "base64:YourGeneratedBase64KeyHere123456789=="
vault_coolify_pusher_app_secret: "wT1mB5kN8vL3xR6yC2zQ9aP4sD7jF0h"
```

## Troubleshooting

### Invalid Application Key

If Coolify fails to start with an encryption key error:

1. Ensure the `APP_KEY` is properly formatted with `base64:` prefix
2. Verify the key is exactly 32 bytes (44 characters after base64 encoding)
3. Regenerate the key if necessary

### Database Connection Issues

If Coolify cannot connect to PostgreSQL:

1. Verify `vault_coolify_postgres_password` matches in all locations
2. Check Docker Compose logs: `pct exec 66 -- docker compose logs postgres`
3. Ensure PostgreSQL container is healthy

### Redis Authentication Issues

If Redis authentication fails:

1. Verify `vault_coolify_redis_password` is correctly set
2. Check Redis container logs: `pct exec 66 -- docker compose logs redis`
3. Ensure Redis container is running with `--requirepass` option

## See Also

- [Coolify Role README](README.md) - Full role documentation
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html) - Official Ansible Vault guide
- [Coolify Documentation](https://coolify.io/docs) - Official Coolify documentation
