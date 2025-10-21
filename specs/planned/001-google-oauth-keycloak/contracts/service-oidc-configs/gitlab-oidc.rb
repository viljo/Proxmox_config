# GitLab OIDC Configuration
# File: /etc/gitlab/gitlab.rb
# Apply with: gitlab-ctl reconfigure

gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
gitlab_rails['omniauth_block_auto_created_users'] = false
gitlab_rails['omniauth_auto_link_user'] = ['openid_connect']

gitlab_rails['omniauth_providers'] = [
  {
    name: "openid_connect",
    label: "Keycloak SSO",
    args: {
      name: "openid_connect",
      scope: ["openid", "profile", "email", "groups"],
      response_type: "code",
      issuer: "https://keycloak.{{ public_domain }}/realms/master",
      client_auth_method: "query",
      discovery: true,
      uid_field: "preferred_username",
      pkce: true,
      client_options: {
        identifier: "gitlab",
        secret: "{{ vault_gitlab_oidc_secret }}",
        redirect_uri: "https://gitlab.{{ public_domain }}/users/auth/openid_connect/callback"
      }
    }
  }
]

# Optional: Role mapping
# gitlab_rails['omniauth_providers'][0][:args][:admin_groups] = ["gitlab-admins"]
# gitlab_rails['omniauth_providers'][0][:args][:external_groups] = ["external-users"]
