# GitLab SSO Role

Configure GitLab Single Sign-On (SSO) integration with Keycloak using OpenID Connect (OIDC).

## Overview

This role automates the complete configuration of GitLab SSO with Keycloak:
1. Creates and configures a Keycloak OIDC client for GitLab
2. Configures GitLab OmniAuth to use Keycloak as OIDC provider
3. Verifies the SSO configuration and login flow

## Requirements

- Ansible 2.9 or higher
- GitLab Omnibus installation
- Keycloak running with admin access
- Both services accessible via HTTPS

## Role Variables

### GitLab Configuration
- `gitlab_sso_container_id`: GitLab container ID (default: 153)
- `gitlab_sso_ip_address`: GitLab IP address (default: 172.16.10.153)
- `gitlab_sso_public_url`: Public GitLab URL (default: https://gitlab.viljo.se)
- `gitlab_config_file`: GitLab config file path (default: /etc/gitlab/gitlab.rb)

### Keycloak Configuration
- `gitlab_sso_keycloak_container_id`: Keycloak container ID (default: 151)
- `gitlab_sso_keycloak_ip_address`: Keycloak IP address (default: 172.16.10.151)
- `gitlab_sso_keycloak_port`: Keycloak port (default: 8080)
- `gitlab_sso_keycloak_realm`: Keycloak realm (default: master)
- `gitlab_sso_keycloak_public_url`: Public Keycloak URL (default: https://keycloak.viljo.se)

### OIDC Client Settings
- `gitlab_sso_client_id`: OIDC client ID (default: gitlab)
- `gitlab_sso_client_secret`: OIDC client secret (default: generated_at_runtime)
- `gitlab_sso_provider_label`: SSO button label (default: Keycloak SSO)

### Authentication Settings
- `gitlab_sso_allow_single_sign_on`: Allow SSO login (default: true)
- `gitlab_sso_block_auto_created_users`: Block auto-created users (default: false)
- `gitlab_sso_uid_field`: User ID field mapping (default: preferred_username)

### Required Vault Variables
- `vault_keycloak_admin_password`: Keycloak admin password
- `vault_keycloak_root_password`: Keycloak container root password
- `vault_gitlab_root_password`: GitLab container root password
- `vault_gitlab_oidc_client_secret`: (optional) Pre-defined OIDC client secret

## Dependencies

None

## Example Playbook

```yaml
---
- name: Configure GitLab SSO with Keycloak
  hosts: proxmox_admin
  gather_facts: true
  become: false

  roles:
    - role: gitlab_sso
      vars:
        gitlab_sso_provider_label: "Sign in with Keycloak"
        gitlab_sso_block_auto_created_users: false
```

## Testing

After running the playbook:

1. Visit https://gitlab.viljo.se
2. Verify "Keycloak SSO" button appears on login page
3. Click the SSO button
4. Authenticate with GitLab.com (via Keycloak identity provider)
5. Verify successful login to GitLab

## Architecture

```
User Browser
    |
    v
GitLab (OIDC Client)
    |
    v
Keycloak (OIDC Provider)
    |
    v
GitLab.com (Identity Provider)
```

## Files Modified

- `/etc/gitlab/gitlab.rb` - GitLab OmniAuth configuration
- Backup created: `/etc/gitlab/gitlab.rb.backup.<timestamp>`

## Keycloak Client Configuration

The role creates/updates a Keycloak OIDC client with:
- Client ID: gitlab
- Protocol: openid-connect
- Access Type: confidential
- Standard Flow: enabled
- Redirect URI: https://gitlab.viljo.se/users/auth/openid_connect/callback
- Mappers: username, email_verified

## Troubleshooting

### SSO button not appearing
- Check GitLab logs: `gitlab-ctl tail`
- Verify configuration: `grep -A 30 omniauth /etc/gitlab/gitlab.rb`
- Reconfigure GitLab: `gitlab-ctl reconfigure`

### Authentication fails
- Verify Keycloak client secret matches GitLab configuration
- Check Keycloak logs for authentication attempts
- Verify redirect URI in Keycloak client matches GitLab callback URL

### User auto-creation blocked
- Set `gitlab_sso_block_auto_created_users: false` in role variables
- Or manually approve users in GitLab admin panel

## License

MIT

## Author

Anders Viljo
