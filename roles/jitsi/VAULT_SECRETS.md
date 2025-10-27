# Jitsi Meet - Required Vault Secrets

This document lists all secrets that must be configured in `inventory/group_vars/all/secrets.yml` (encrypted with Ansible Vault) for the Jitsi Meet deployment.

## Required Secrets

Add these variables to your encrypted secrets file:

```yaml
---
# Jitsi Meet Secrets

# Container root password for SSH access
vault_jitsi_root_password: "CHANGE_ME"

# Jicofo (Conference Focus) component secret
# Used for XMPP component authentication
# Generate with: openssl rand -hex 32
vault_jitsi_jicofo_component_secret: "CHANGE_ME"

# Jicofo authentication password
# Used for Jicofo to authenticate to Prosody
# Generate with: openssl rand -hex 32
vault_jitsi_jicofo_auth_password: "CHANGE_ME"

# JVB (Videobridge) authentication password
# Used for JVB to authenticate to Prosody
# Generate with: openssl rand -hex 32
vault_jitsi_jvb_auth_password: "CHANGE_ME"

# Jibri recorder user password
# Used for recording authentication
# Generate with: openssl rand -hex 32
vault_jitsi_jibri_recorder_password: "CHANGE_ME"

# Jibri XMPP authentication password
# Used for Jibri to authenticate to Prosody
# Generate with: openssl rand -hex 32
vault_jitsi_jibri_xmpp_password: "CHANGE_ME"

# Keycloak OIDC client secret
# Obtain from Keycloak admin console after creating the 'jitsi' client
vault_jitsi_oidc_client_secret: "CHANGE_ME"
```

## Generating Secrets

### Generate Random Secrets

Use OpenSSL to generate cryptographically secure random secrets:

```bash
# Generate a single secret
openssl rand -hex 32

# Generate all secrets at once
for i in {1..6}; do
  echo "Secret $i: $(openssl rand -hex 32)"
done
```

### Keycloak OIDC Client Secret

1. **Create Keycloak Client**:
   ```
   - Navigate to Keycloak admin console: https://keycloak.viljo.se
   - Select 'master' realm
   - Go to Clients → Create Client
   - Client ID: jitsi
   - Client Protocol: openid-connect
   - Save
   ```

2. **Configure Client**:
   ```
   - Client authentication: ON
   - Valid redirect URIs: https://meet.viljo.se/*
   - Web origins: https://meet.viljo.se
   - Save
   ```

3. **Retrieve Client Secret**:
   ```
   - Go to Credentials tab
   - Copy the Client Secret value
   - This is your vault_jitsi_oidc_client_secret
   ```

## Editing Vault File

### First Time Setup

```bash
# Create encrypted secrets file
ansible-vault create inventory/group_vars/all/secrets.yml

# Add the secrets listed above
# Save and exit
```

### Updating Existing Vault

```bash
# Edit encrypted file
ansible-vault edit inventory/group_vars/all/secrets.yml

# Add new Jitsi secrets
# Save and exit
```

### Viewing Current Secrets

```bash
# View encrypted file (read-only)
ansible-vault view inventory/group_vars/all/secrets.yml
```

## Security Best Practices

1. **Never commit unencrypted secrets to git**
   - Always use `ansible-vault encrypt` before committing
   - Verify with `ansible-vault view` before pushing

2. **Use strong passwords**
   - Minimum 32 characters for component secrets
   - Use cryptographically random generation

3. **Rotate secrets periodically**
   - Update Keycloak client secret annually
   - Rotate component secrets during maintenance windows

4. **Limit vault password access**
   - Store vault password securely (password manager)
   - Don't share vault password via insecure channels

5. **Backup encrypted vault**
   - Keep encrypted backup of secrets file
   - Test recovery procedure periodically

## Vault Password Management

### Using Vault Password File

```bash
# Create password file (DO NOT COMMIT THIS)
echo "your_vault_password" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Use in playbooks
ansible-playbook --vault-password-file ~/.ansible_vault_pass site.yml
```

### Using Environment Variable

```bash
export ANSIBLE_VAULT_PASSWORD="your_vault_password"
ansible-playbook site.yml
```

### Interactive Password Prompt

```bash
# Ansible will prompt for password
ansible-playbook --ask-vault-pass site.yml
```

## Validation

After adding secrets, validate the configuration:

```bash
# Check variable substitution
ansible-playbook -i inventory/proxmox.ini site.yml --tags jitsi --check

# Verify secrets are loaded
ansible-playbook -i inventory/proxmox.ini site.yml --tags jitsi --list-tasks
```

## Troubleshooting

### "Vault password not provided"

```bash
# Solution: Provide vault password
ansible-playbook --ask-vault-pass site.yml
```

### "Secret variable not defined"

```bash
# Check variable name matches exactly
ansible-vault view inventory/group_vars/all/secrets.yml | grep jitsi

# Verify no typos in variable references
```

### "Cannot decrypt vault file"

```bash
# Wrong password - verify vault password
ansible-vault view inventory/group_vars/all/secrets.yml

# File corruption - restore from backup
```

## Migration from Unencrypted

If you have unencrypted secrets:

```bash
# 1. Backup current file
cp inventory/group_vars/all/secrets.yml secrets.yml.backup

# 2. Encrypt file
ansible-vault encrypt inventory/group_vars/all/secrets.yml

# 3. Verify encryption
ansible-vault view inventory/group_vars/all/secrets.yml

# 4. Remove backup (after verification)
rm secrets.yml.backup
```

## Reference

For more information on Ansible Vault:
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Best Practices for Variables and Vaults](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
