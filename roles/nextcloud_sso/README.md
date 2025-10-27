# Nextcloud SSO Role

This Ansible role configures Single Sign-On (SSO) for Nextcloud using Keycloak as an OpenID Connect (OIDC) provider, which in turn uses GitLab.com as the identity source.

## Requirements

- Nextcloud container (LXC 155) running with Docker
- Keycloak container (LXC 151) running with Docker
- GitLab.com OAuth already configured in Keycloak
- Ansible 2.9 or higher
- Access to Proxmox host via SSH

## Role Variables

Key variables that can be customized:

```yaml
# Nextcloud configuration
nextcloud_sso_container_id: 155
nextcloud_sso_public_url: "https://nextcloud.viljo.se"

# Keycloak configuration
nextcloud_sso_keycloak_container_id: 151
nextcloud_sso_keycloak_public_url: "https://keycloak.viljo.se"
nextcloud_sso_keycloak_realm: "master"

# OIDC client settings
nextcloud_sso_client_id: "nextcloud"
nextcloud_sso_provider_identifier: "keycloak"
nextcloud_sso_button_text: "Sign in with GitLab SSO"

# User provisioning
nextcloud_sso_auto_provision: true
nextcloud_sso_auto_update: true

# Admin user
nextcloud_sso_admin_email: "anders@viljo.se"
nextcloud_sso_admin_username: "anders"
```

## Dependencies

Required vault variables:
- `vault_keycloak_admin_password` - Keycloak admin password
- `vault_keycloak_root_password` - Keycloak container root password
- `vault_nextcloud_root_password` - Nextcloud container root password
- `vault_nextcloud_admin_password` - Nextcloud admin password

## Example Playbook

```yaml
- hosts: proxmox_admin
  roles:
    - nextcloud_sso
  vars:
    nextcloud_sso_button_text: "Sign in with GitLab SSO"
    nextcloud_sso_admin_email: "anders@viljo.se"
```

## Usage

Run the complete SSO configuration:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/nextcloud_sso.yml --ask-vault-pass
```

Verify configuration only:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/nextcloud_sso.yml --tags verify --ask-vault-pass
```

## What This Role Does

1. **Configures Keycloak Client**:
   - Creates or updates OIDC client for Nextcloud
   - Configures redirect URIs
   - Sets up user attribute mappers

2. **Installs Nextcloud OIDC App**:
   - Installs user_oidc app if not present
   - Enables the app if disabled
   - Configures OIDC provider settings

3. **Sets Up User Provisioning**:
   - Enables automatic user creation on first login
   - Maps OIDC claims to Nextcloud user attributes
   - Configures user profile updates

4. **Configures Admin Access**:
   - Prepares admin group
   - Sets up admin user configuration
   - Provides instructions for post-login admin grant

5. **Verifies Configuration**:
   - Checks app installation
   - Validates provider configuration
   - Tests Keycloak connectivity
   - Provides manual test instructions

## Testing

After running the role:

1. Visit https://nextcloud.viljo.se
2. Click "Sign in with GitLab SSO"
3. Authenticate via GitLab.com
4. Verify automatic login to Nextcloud

For admin access, after first login:
```bash
ssh root@192.168.1.3 "pct exec 155 -- docker exec -u www-data nextcloud php occ group:adduser admin anders"
```

## Troubleshooting

Check logs:
```bash
# Nextcloud logs
pct exec 155 -- docker logs nextcloud

# Keycloak logs
pct exec 151 -- docker logs keycloak
```

Verify configuration:
```bash
# Check OIDC app
pct exec 155 -- docker exec -u www-data nextcloud php occ app:list | grep user_oidc

# Check provider config
pct exec 155 -- docker exec -u www-data nextcloud php occ config:app:get user_oidc providers
```

## License

MIT

## Author Information

Created for the Proxmox infrastructure automation project.