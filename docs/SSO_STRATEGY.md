# SSO Strategy - GitLab.com OAuth via Keycloak

## Overview

This infrastructure uses **GitLab.com OAuth** as the primary identity provider, with **Keycloak** acting as an OAuth broker and **oauth2-proxy** providing forward authentication for services that don't natively support OAuth.

## Architecture

```
User → Service → Traefik → Authentication Layer → Backend
                              ↓
                         oauth2-proxy (Forward Auth)
                              ↓
                         Keycloak (OAuth Broker)
                              ↓
                         GitLab.com OAuth
```

## Current Services

### Services Removed
- **Mattermost** - Removed from infrastructure (Team Edition SSO limitations made it impractical)

### Active Services

#### 1. **GitLab** (gitlab.viljo.se)
- **Container**: LXC 153
- **URL**: http://172.16.10.153:80
- **Authentication**: Native GitLab authentication (self-contained)
- **SSO**: Not applicable (GitLab is the identity source)
- **Status**: ✅ Running, no SSO needed

#### 2. **Nextcloud** (nextcloud.viljo.se)
- **Container**: LXC 155
- **URL**: http://172.16.10.155:80
- **Authentication**: Keycloak OIDC via user_oidc app
- **SSO Implementation**: ✅ COMPLETED (2025-10-27)
  - Using official user_oidc app for OIDC integration
  - Connected to Keycloak master realm
  - Auto-provisioning enabled for new users
  - Admin access configured for anders@viljo.se
- **Current Status**: ✅ SSO Enabled (GitLab.com → Keycloak → Nextcloud)
- **Documentation**: See [NEXTCLOUD_SSO_IMPLEMENTATION.md](./NEXTCLOUD_SSO_IMPLEMENTATION.md)

#### 3. **Webtop** (browser.viljo.se)
- **Container**: LXC 170
- **URL**: http://172.16.10.170:3000
- **Authentication**: Native Webtop authentication
- **SSO Options**:
  - Could use oauth2-proxy forward auth (protect the URL)
  - Limited native OAuth support
- **Current Status**: ✅ Accessible (native authentication, no SSO)
- **HTTPS Access**: Configured via Traefik (2025-10-27)
- **Note**: oauth2-proxy forward auth available but not enabled (would create double authentication)

## SSO Components

### Keycloak (keycloak.viljo.se)
- **Container**: LXC 151
- **URL**: http://172.16.10.151:8080
- **Realm**: master
- **Identity Provider**: GitLab.com OAuth
- **Purpose**: Acts as OAuth broker, provides OIDC/SAML for services
- **Status**: ✅ Running

### oauth2-proxy
- **Container**: LXC 167
- **Port**: 4180
- **Purpose**: Forward authentication for services without native OAuth
- **Authentication**: Keycloak OIDC (which uses GitLab.com)
- **Status**: ✅ Running
- **Configuration**: `/opt/oauth2-proxy/docker-compose.yml`

## Implementation Recommendations

### ✅ Completed: Nextcloud SSO (2025-10-27)
Nextcloud SSO has been successfully implemented:

1. **Installed user_oidc App** - Official OIDC support app
2. **Configured Keycloak OIDC Client**:
   - Client ID: `nextcloud`
   - Redirect URIs configured for user_oidc app
   - User attribute mappers configured
3. **Nextcloud OIDC Provider Configuration**:
   - Discovery URL: `https://keycloak.viljo.se/realms/master/.well-known/openid-configuration`
   - Auto-provisioning enabled
   - Seamless user creation on first login
4. **Automation Created**:
   - Ansible role: `roles/nextcloud_sso/`
   - Playbook: `playbooks/nextcloud_sso.yml`
5. **Full Documentation**: [NEXTCLOUD_SSO_IMPLEMENTATION.md](./NEXTCLOUD_SSO_IMPLEMENTATION.md)

### Priority 2: Webtop Protection (Optional)
If access control is needed:

1. **Route through oauth2-proxy**: Change Traefik config to use oauth2-proxy forward auth
2. **Users authenticate once** via GitLab.com → Keycloak → oauth2-proxy
3. **Webtop session** still requires separate login (limitation of Webtop)

Note: This provides URL protection but not true SSO due to Webtop limitations.

## Authentication Flow

### Current Flow (GitLab.com → Keycloak → oauth2-proxy)

1. User accesses protected resource
2. oauth2-proxy intercepts request
3. Redirects to Keycloak for authentication
4. Keycloak redirects to GitLab.com OAuth
5. User authenticates with GitLab.com account
6. GitLab.com returns to Keycloak with user info
7. Keycloak creates session and returns to oauth2-proxy
8. oauth2-proxy sets cookie and forwards request to backend

### Benefits
- ✅ Single identity source (GitLab.com)
- ✅ Centralized user management
- ✅ Consistent authentication experience
- ✅ Easy to add/remove users (via GitLab.com)
- ✅ No password management needed

### Limitations
- ⚠️ Services need native OAuth/OIDC support for true SSO
- ⚠️ Forward auth provides URL protection but may require separate login
- ⚠️ Some services (like Mattermost Team Edition) have limited free-tier SSO

## Credentials Management

All OAuth credentials are stored in Ansible Vault:
- `inventory/group_vars/all/secrets.yml`

Credential structure:
```yaml
# Keycloak → GitLab.com OAuth
vault_keycloak_gitlab_oauth_client_id: <GitLab App ID>
vault_keycloak_gitlab_oauth_client_secret: <GitLab Secret>

# oauth2-proxy → Keycloak OIDC
vault_oauth2_proxy_client_id: oauth2-proxy
vault_oauth2_proxy_client_secret: <Keycloak Client Secret>
vault_oauth2_proxy_cookie_secret: <Random Secret>
```

## Service-Specific SSO Capabilities

| Service | Native OAuth | Forward Auth | True SSO | Status |
|---------|-------------|--------------|----------|---------|
| GitLab | N/A (IdP) | N/A | N/A | N/A |
| Nextcloud | ✅ Yes (user_oidc) | ✅ Yes | ✅ Yes | ✅ Implemented |
| Webtop | ❌ No | ✅ Available | ❌ No | ✅ Accessible (native auth) |

## Next Steps

1. ✅ **COMPLETED: Nextcloud SSO** - Implemented via user_oidc app (2025-10-27)
2. ✅ **COMPLETED: Webtop HTTPS Access** - Added Traefik routing and DNS (2025-10-27)
3. **Test Nextcloud SSO** - Verify authentication flow with anders@viljo.se
4. **Test Webtop HTTPS Access** - Verify browser.viljo.se is accessible
5. **Evaluate Webtop Forward Auth** - Determine if oauth2-proxy protection is needed
6. **Monitor Keycloak** - Ensure performance and reliability
7. **Document user onboarding** - How to add new users to GitLab.com org

## Maintenance Tasks

### Adding a New User
1. Add user to GitLab.com organization
2. User can immediately access all SSO-enabled services
3. No password setup required

### Adding a New Service
1. Evaluate service's OAuth/OIDC capabilities
2. If native support: Create Keycloak client, configure service
3. If no support: Consider oauth2-proxy forward auth
4. Document in this file

### Removing a User
1. Remove from GitLab.com organization
2. Access is immediately revoked across all services

## Troubleshooting

### User Can't Login
1. Check GitLab.com organization membership
2. Verify Keycloak GitLab identity provider is working
3. Check service-specific OAuth configuration
4. Review oauth2-proxy logs: `ssh root@192.168.1.3 "pct exec 167 -- docker logs oauth2-proxy"`

### Service Won't Redirect
1. Check Traefik configuration
2. Verify redirect URIs in Keycloak client
3. Check service OAuth configuration
4. Review Traefik logs

## References

- Keycloak Admin: https://keycloak.viljo.se
- GitLab.com OAuth Apps: https://gitlab.com/-/user_settings/applications
- oauth2-proxy docs: https://oauth2-proxy.github.io/oauth2-proxy/
