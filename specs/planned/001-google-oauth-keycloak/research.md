# Research Report: Google OAuth Integration with Keycloak

**Feature**: Google OAuth Integration with Keycloak
**Date**: 2025-10-20
**Status**: Complete

## Overview

This research report documents technical decisions for implementing Google OAuth 2.0 as the primary authentication method through Keycloak, with one-way synchronization to OpenLDAP and OIDC/SAML integration for infrastructure services.

---

## 1. Keycloak Google OAuth Identity Provider

### Decision: Use Native Google Social Identity Provider

**Rationale**: Keycloak has built-in Google provider support that simplifies configuration compared to generic OIDC provider. Pre-configured with correct endpoints and scopes.

### Google Cloud Console Configuration

**OAuth Client Setup**:
- Application type: **Web Application**
- Authorized redirect URI: `https://keycloak.{{ public_domain }}/realms/{REALM_NAME}/broker/google/endpoint`
- Authorized JavaScript origins: `https://keycloak.{{ public_domain }}`

**Required Credentials**:
- Client ID: Format `XXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.apps.googleusercontent.com`
- Client Secret: Store in Ansible Vault (`vault_google_oauth_client_id`, `vault_google_oauth_client_secret`)

### Keycloak Configuration

**Identity Provider Settings**:
```yaml
Alias: google
Provider ID: google
Enabled: true
Trust Email: true
Store Token: false
Scopes: openid profile email
Sync Mode: IMPORT
```

**Attribute Mappers**:
1. **Email Mapper** (FORCE sync):
   - Claim: `email`
   - User Attribute: `email`
   - Sync Mode: FORCE

2. **Name Mappers** (INHERIT sync):
   - First Name: `given_name` → `firstName`
   - Last Name: `family_name` → `lastName`
   - Picture: `picture` → `picture` (FORCE)

**Security Settings**:
- Use JWKS URL: true (validates token signature)
- HTTPS Required: Yes (via `proxy=edge`)
- Session Timeout: 30 min idle, 10 hours max

**Hosted Domain** (Optional):
- Leave empty for consumer Google accounts
- Set to `example.com` for Google Workspace domain restriction

### Implementation Pattern

**Ansible Configuration**:
```yaml
- name: Configure Google Identity Provider
  community.general.keycloak_identity_provider:
    auth_keycloak_url: "{{ keycloak_url }}"
    realm: "{{ keycloak_realm }}"
    alias: google
    provider_id: google
    enabled: true
    trust_email: true
    store_token: false
    config:
      clientId: "{{ vault_google_oauth_client_id }}"
      clientSecret: "{{ vault_google_oauth_client_secret }}"
      defaultScope: "openid profile email"
      syncMode: "IMPORT"
```

---

## 2. Keycloak → OpenLDAP Synchronization

### Decision: REST API + External Sync Script

**Rationale**: Keycloak's native LDAP federation is designed for LDAP→Keycloak sync (opposite direction). For Keycloak→LDAP, a custom solution is required.

### Approach Comparison

| Approach | Real-Time | Complexity | Maintainability | Recommendation |
|----------|-----------|------------|-----------------|----------------|
| WRITABLE Mode | ✅ | Low | Medium | ❌ Designed for opposite direction |
| Event Listener SPI | ✅ | High | Medium | ⚠️ Complex, requires Java |
| REST API + Script | ❌ (15-min lag) | Low | High | ✅ **RECOMMENDED** |
| User Storage SPI | ✅ | Very High | Low | ❌ Overkill |

### Implementation: Python Sync Script

**Architecture**:
```
Systemd Timer (15 min) → Python Script → Keycloak REST API (read) → LDAP (write)
```

**Key Components**:

1. **LDAP Schema Setup**:
   - Object Classes: `inetOrgPerson`, `posixAccount`
   - UID Number Allocation: Counter object at `cn=uidNext,ou=services,dc=infra,dc=local`
   - Default GID: 10000 (users group)

2. **Attribute Mapping**:
   ```
   Keycloak username → LDAP uid
   Keycloak email → LDAP mail
   Keycloak firstName → LDAP givenName
   Keycloak lastName → LDAP sn
   Auto-generated → LDAP uidNumber (from counter)
   Default 10000 → LDAP gidNumber
   /home/{username} → LDAP homeDirectory
   ```

3. **Sync Script** (`/usr/local/bin/keycloak-to-ldap-sync.py`):
   - Authenticate to Keycloak admin API
   - Fetch all users via `/admin/realms/{realm}/users`
   - For each user:
     - Check if exists in LDAP
     - If new: Allocate uidNumber, create LDAP entry
     - If existing: Update modified attributes
   - Sync groups to posixGroup entries

4. **Systemd Timer**:
   - Interval: Every 15 minutes
   - Service type: oneshot
   - Logs to systemd journal

**LDAP Counter Management**:
```python
def allocate_uid_number(ldap_conn):
    """Atomically allocate next uidNumber"""
    current_uid = ldap_conn.search('cn=uidNext,...', 'uidNumber')
    next_uid = current_uid + 1
    ldap_conn.modify('cn=uidNext,...',
                     delete=[current_uid],
                     add=[next_uid])
    return current_uid
```

**Alternative for Real-Time**: Keycloak Event Listener SPI can provide real-time sync but requires Java development and maintenance.

---

## 3. Service OIDC/SAML Integration

### 3.1 GitLab - OIDC Integration

**Configuration Method**: File-based via `/etc/gitlab/gitlab.rb`

**Keycloak Client**:
```
Client ID: gitlab
Protocol: openid-connect
Access Type: Confidential
Valid Redirect URI: https://gitlab.{{ public_domain }}/users/auth/openid_connect/callback
Scopes: openid, profile, email, groups
```

**GitLab Configuration**:
```ruby
gitlab_rails['omniauth_providers'] = [
  {
    name: "openid_connect",
    label: "Keycloak SSO",
    args: {
      name: "openid_connect",
      scope: ["openid", "profile", "email"],
      response_type: "code",
      issuer: "https://keycloak.{{ public_domain }}/realms/{realm}",
      discovery: true,
      client_options: {
        identifier: "gitlab",
        secret: "{{ vault_gitlab_oidc_secret }}",
        redirect_uri: "https://gitlab.{{ public_domain }}/users/auth/openid_connect/callback"
      }
    }
  }
]
```

**Role Mapping**: Use `admin_groups`, `external_groups` for role assignment.

---

### 3.2 Nextcloud - OIDC Integration

**Configuration Method**: App-based (user_oidc) + config.php

**Required App**: "OpenID Connect user backend" from App Store

**Keycloak Client**:
```
Client ID: nextcloud
Valid Redirect URI: https://nextcloud.{{ public_domain }}/apps/user_oidc/code
```

**Nextcloud config.php**:
```php
'oidc_login_provider_url' => 'https://keycloak.{{ public_domain }}/realms/{realm}',
'oidc_login_client_id' => 'nextcloud',
'oidc_login_client_secret' => '{{ vault_nextcloud_oidc_secret }}',
'oidc_login_attributes' => [
    'id' => 'preferred_username',
    'name' => 'name',
    'mail' => 'email',
    'groups' => 'groups',
],
'oidc_login_default_group' => 'oidc_users',
```

**Important**: Set `allow_local_remote_servers => true` for localhost Keycloak.

---

### 3.3 Grafana - OIDC Integration

**Configuration Method**: File-based via `grafana.ini`

**Keycloak Client**:
```
Client ID: grafana
Valid Redirect URI: https://grafana.{{ public_domain }}/login/generic_oauth
Required Scopes: openid, email, profile, roles
```

**Grafana grafana.ini**:
```ini
[auth.generic_oauth]
enabled = true
name = Keycloak
client_id = grafana
client_secret = {{ vault_grafana_oidc_secret }}
scopes = openid email profile roles
auth_url = https://keycloak.{{ public_domain }}/realms/{realm}/protocol/openid-connect/auth
token_url = https://keycloak.{{ public_domain }}/realms/{realm}/protocol/openid-connect/token
api_url = https://keycloak.{{ public_domain }}/realms/{realm}/protocol/openid-connect/userinfo

# Role mapping (critical for permissions)
role_attribute_path = contains(realm_access.roles[*], 'grafana-admin') && 'Admin' || contains(realm_access.roles[*], 'grafana-editor') && 'Editor' || 'Viewer'
```

**Keycloak Role Mapper**: Create realm roles `grafana-admin`, `grafana-editor`, `grafana-viewer` and configure role mapper to include in tokens.

---

### 3.4 Mattermost - OIDC Integration

**Edition Dependency**:
- **Team Edition**: Use GitLab OAuth workaround
- **Enterprise**: Native OIDC support

**Keycloak Client**:
```
Client ID: mattermost
Valid Redirect URI: https://mattermost.{{ public_domain }}/signup/gitlab/complete
```

**Critical Requirement (Team Edition)**: Each user needs `mattermostId` attribute (numeric, unique) in Keycloak.

**Keycloak Mapper** (Team Edition):
```
Name: mattermostId
Mapper Type: User Attribute
User Attribute: mattermostId
Token Claim Name: id
Claim JSON Type: long (MUST be numeric)
```

**Mattermost config.json** (Team Edition):
```json
{
  "GitLabSettings": {
    "Enable": true,
    "Id": "mattermost",
    "Secret": "{{ vault_mattermost_oidc_secret }}",
    "AuthEndpoint": "https://keycloak.{{ public_domain }}/realms/{realm}/protocol/openid-connect/auth",
    "TokenEndpoint": "https://keycloak.{{ public_domain }}/realms/{realm}/protocol/openid-connect/token",
    "UserApiEndpoint": "https://keycloak.{{ public_domain }}/realms/{realm}/protocol/openid-connect/userinfo"
  }
}
```

---

### 3.5 NetBox - OIDC Integration

**Configuration Method**: File-based via `configuration.py`

**Backend**: `social_core.backends.keycloak.KeycloakOAuth2`

**Keycloak Client**:
```
Client ID: netbox
Valid Redirect URI: https://netbox.{{ public_domain }}/oauth/complete/keycloak/
```

**NetBox configuration.py**:
```python
REMOTE_AUTH_ENABLED = True
REMOTE_AUTH_BACKEND = 'social_core.backends.keycloak.KeycloakOAuth2'

SOCIAL_AUTH_KEYCLOAK_KEY = 'netbox'
SOCIAL_AUTH_KEYCLOAK_SECRET = '{{ vault_netbox_oidc_secret }}'
SOCIAL_AUTH_KEYCLOAK_PUBLIC_KEY = '''-----BEGIN PUBLIC KEY-----
...
-----END PUBLIC KEY-----'''

SOCIAL_AUTH_KEYCLOAK_AUTHORIZATION_URL = 'https://keycloak.{{ public_domain }}/realms/{realm}/protocol/openid-connect/auth'
SOCIAL_AUTH_KEYCLOAK_ACCESS_TOKEN_URL = 'https://keycloak.{{ public_domain }}/realms/{realm}/protocol/openid-connect/token'
```

**Group Sync**: Requires custom pipeline functions (not native). Example provided in research.

---

### 3.6 Zabbix - SAML Integration

**Protocol**: SAML 2.0 (NOT OIDC - Zabbix 7.0+ uses SAML)

**Keycloak Client**:
```
Client Type: SAML
Client ID: zabbix
Valid Redirect URI: https://zabbix.{{ public_domain }}/index_sso.php?acs
Sign Documents: ON
```

**Zabbix Web UI Configuration** (Administration → Authentication → SAML):
```
IdP entity ID: https://keycloak.{{ public_domain }}/realms/{realm}
SSO service URL: https://keycloak.{{ public_domain }}/realms/{realm}/protocol/saml
Username attribute: username
SP entity ID: zabbix
JIT provisioning: Enabled
User group: Default group for new users
```

**Keycloak SAML Mappers**:
1. Username: User Property → username
2. Email: User Property → email
3. Groups: Group list → member

**Certificate**: Copy X.509 certificate from Keycloak → Realm Settings → Keys → RS256 Algorithm → Certificate

---

## 4. Traefik Forward Authentication

### Decision: OAuth2 Proxy

**Rationale**: Best balance of features, maintenance, and Keycloak integration for Proxmox LXC infrastructure.

### Solution Comparison

| Solution | Keycloak Integration | Complexity | Maintenance | Recommendation |
|----------|---------------------|------------|-------------|----------------|
| **OAuth2 Proxy** | ⭐⭐⭐⭐⭐ Native | Low | Active (2025) | ✅ **RECOMMENDED** |
| **Authelia** | ⭐⭐⭐ Via backend | High | Active (2025) | ⚠️ Alternative if MFA needed |
| **Keycloak Gatekeeper** | ⭐⭐⭐⭐⭐ Native | Low | ❌ Deprecated 2020 | ❌ Do not use |
| **Traefik-Forward-Auth** | ⭐⭐⭐ Generic OIDC | Medium | ⚠️ Limited (2023) | ❌ Not recommended |
| **Custom Service** | ⭐⭐⭐⭐ DIY | High | ⚠️ You maintain | ❌ Unnecessary complexity |

### OAuth2 Proxy Implementation

**Deployment**:
- Container ID: 54 (recommended)
- IP: 172.16.10.54
- Memory: 512MB
- Deployment Method: Binary with systemd (LXC-friendly)

**Configuration**:
```yaml
provider: keycloak-oidc
oidc_issuer_url: https://keycloak.{{ public_domain }}/realms/{realm}
client_id: oauth2-proxy
client_secret: {{ vault_oauth2_proxy_client_secret }}
cookie_secret: {{ vault_oauth2_proxy_cookie_secret }}
redirect_url: https://auth.{{ public_domain }}/oauth2/callback
```

**Traefik Middleware**:
```yaml
http:
  middlewares:
    oauth2-auth:
      forwardAuth:
        address: "http://172.16.10.54:4180/oauth2/auth"
        trustForwardHeader: true
        authResponseHeaders:
          - X-Auth-Request-User
          - X-Auth-Request-Email
          - X-Auth-Request-Groups
          - Authorization
```

**Features**:
- Group-based access control via `--allowed-role`, `--allowed-group`
- Header injection (username, email, groups, JWT token)
- Redis session storage for HA
- Prometheus metrics endpoint
- Ansible roles available for automation

**Alternative: Authelia** - Consider if you need:
- Built-in MFA/2FA (TOTP, WebAuthn)
- Ultra-low resource usage (<30MB)
- Self-service user portal
- Per-URL authorization policies

---

## 5. Account Linking and Migration

### First Login Flow Configuration

**Decision**: Enhanced flow with Review Profile + Manual Linking

**Flow Structure**:
```
First Broker Login
├─ Review Profile (REQUIRED) - User reviews Google profile data
└─ User Creation Or Linking (ALTERNATIVE)
    ├─ Create User If Unique
    ├─ Automatically Set Existing User (if trust email)
    └─ Handle Existing Account
        ├─ Confirm Link Existing Account (REQUIRED)
        └─ Verify Existing Account By Email
```

**Settings**:
- Update Profile On First Login: `on` (compliance, user review)
- Account Linking: Manual confirmation (security over convenience)
- Trust Email: `true` (Google verified emails)

### Migration Strategy

**Phased Rollout**:

**Phase A - Foundation**:
1. Deploy Keycloak with Google OAuth IdP
2. Configure LDAP sync from Keycloak to OpenLDAP
3. Test new user creation via Google → Keycloak → LDAP flow

**Phase B - Service Integration**:
4. Configure OIDC for pilot service (Grafana - simple config)
5. Test SSO with pilot service
6. Roll out OIDC to remaining services (GitLab, Nextcloud, Mattermost, NetBox)
7. Configure SAML for Zabbix

**Phase C - Custom Services**:
8. Deploy OAuth2 Proxy for Traefik forward auth
9. Protect custom websites/services
10. Test SSO across all protected endpoints

**Phase D - User Migration**:
11. Enable Google authentication for end users
12. Migrate existing LDAP users (manual linking as needed)
13. Monitor and validate zero disruption

---

## 6. Security and Production Considerations

### Token and Session Management

**Access Token Lifespan**: 15 minutes (balance security/performance)
**Session Settings**:
- Idle timeout: 30 minutes
- Max session: 10 hours (workday coverage)
- Refresh tokens: Enabled with revocation

**Token Validation**:
- JWKS URL validation: Enabled
- Signature algorithm: RSA256
- Token storage: Not stored (minimizes exposure)

### Secrets Management

**Ansible Vault Storage**:
```yaml
# inventory/group_vars/all/secrets.yml (encrypted)
vault_google_oauth_client_id: "..."
vault_google_oauth_client_secret: "..."
vault_keycloak_admin_password: "..."
vault_gitlab_oidc_secret: "..."
vault_nextcloud_oidc_secret: "..."
vault_grafana_oidc_secret: "..."
vault_mattermost_oidc_secret: "..."
vault_netbox_oidc_secret: "..."
vault_oauth2_proxy_client_secret: "..."
vault_oauth2_proxy_cookie_secret: "..."
```

### High Availability

**Keycloak**:
- PostgreSQL backend with replication
- Multiple Keycloak instances with distributed cache
- Load balancer in front

**OAuth2 Proxy**:
- Redis session storage for shared sessions
- Multiple proxy instances behind load balancer

### Monitoring and Logging

**Metrics**:
- Keycloak: Prometheus metrics enabled
- OAuth2 Proxy: Metrics endpoint at :9090
- Monitor: Login success rate, token refresh rate, session count

**Logging**:
- Keycloak events: LOGIN, LOGIN_ERROR, IDENTITY_PROVIDER_LOGIN
- OAuth2 Proxy: JSON logging for aggregation
- Centralized: Loki for log collection

**Alerting**:
- High Google login failure rate (>10% failed)
- LDAP sync failures
- OAuth2 Proxy service down
- Certificate expiration warnings

---

## 7. Implementation Artifacts

### Required Ansible Roles

**New Roles**:
- `keycloak_google_oauth` - Configure Google IdP in Keycloak
- `keycloak_ldap_sync` - Deploy Python sync script
- `oauth2_proxy` - Deploy OAuth2 Proxy for forward auth

**Updated Roles**:
- `keycloak` - Increase resources if needed
- `ldap` - Add posixAccount schema, counter objects
- `traefik` - Add forward auth middleware configuration
- `gitlab`, `nextcloud`, `grafana`, `mattermost`, `netbox`, `zabbix` - Add OIDC/SAML configuration

### Required Playbooks

**New Playbooks**:
- `playbooks/keycloak-google-oauth.yml` - Configure Google IdP
- `playbooks/service-oidc-integration.yml` - Configure all services
- `playbooks/verify-sso.yml` - Integration test playbook

**Updated Playbooks**:
- `playbooks/site.yml` - Include new roles

### Configuration Files

**Keycloak**:
- Identity provider configuration (via Ansible module)
- Client configurations for each service
- Attribute mappers
- Realm settings

**Services**:
- GitLab: `/etc/gitlab/gitlab.rb`
- Nextcloud: `/var/www/nextcloud/config/config.php`
- Grafana: `/etc/grafana/grafana.ini`
- Mattermost: `/opt/mattermost/config/config.json`
- NetBox: `/opt/netbox/netbox/netbox/configuration.py`
- Zabbix: Web UI configuration (saved to database)

**OAuth2 Proxy**:
- `/etc/oauth2-proxy/oauth2-proxy.cfg`
- `/etc/oauth2-proxy/oauth2-proxy.env` (secrets)
- `/etc/systemd/system/oauth2-proxy.service`

**Traefik**:
- `/etc/traefik/dynamic/oauth2-proxy.yml` (middleware definition)
- `/etc/traefik/dynamic/protected-services.yml` (apply middleware to routes)

---

## 8. Testing Strategy

### Unit Tests

**Keycloak Google IdP**:
- Test Google OAuth flow with real Google account
- Verify attribute mapping (email, name, picture)
- Test account linking scenarios
- Verify trust email setting

**LDAP Sync**:
- Test new user creation in LDAP
- Verify uidNumber allocation
- Test attribute updates
- Verify group synchronization
- Test sync script idempotency

### Integration Tests

**Service OIDC**:
- For each service: Test login via Google → Keycloak → Service
- Verify SSO (login to one service, access another without re-auth)
- Test role/group mapping
- Verify logout (single logout)

**OAuth2 Proxy**:
- Test unauthenticated access (redirect to Keycloak)
- Test authenticated access (headers injected)
- Test group-based authorization
- Verify session management

### Performance Tests

**Load Testing**:
- Concurrent users: 50-100
- Authentication flow latency: <10 seconds
- LDAP sync completion: <5 minutes
- OAuth2 Proxy overhead: <100ms

**Scalability**:
- Test with 1000+ users in Keycloak
- Verify LDAP sync performance
- Test session storage capacity

### Security Tests

**Authentication**:
- Test invalid credentials
- Test expired sessions
- Test token validation
- Test HTTPS enforcement

**Authorization**:
- Test group-based access control
- Test role mapping
- Test unauthorized access attempts

---

## 9. Risk Mitigation

### Identified Risks and Mitigations

**Risk: Google OAuth Outage**
- Mitigation: Maintain LDAP username/password authentication as fallback
- Impact: Users with linked accounts can use LDAP credentials
- Monitoring: Alert on Google IdP failures

**Risk: Keycloak Failure**
- Mitigation: Document emergency procedures to switch services to direct LDAP
- Impact: All OIDC-dependent services lose authentication
- Prevention: Keycloak high availability (future enhancement)

**Risk: LDAP Sync Failure**
- Mitigation: OIDC services unaffected; LDAP-only services see stale data
- Impact: New users can't access SSH/PAM services until sync resumes
- Monitoring: Zabbix monitors sync job status

**Risk: Session Conflicts**
- Mitigation: Test single logout thoroughly, document session timeout settings
- Impact: Users may remain logged in to some services after logout
- Prevention: Proper session configuration across all services

**Risk: Account Duplicates**
- Mitigation: Email-based duplicate detection, manual resolution workflow
- Impact: User confusion, potential security issue
- Prevention: First broker login flow with manual linking

**Risk: Service Misconfiguration**
- Mitigation: Automated testing in CI/CD pipeline
- Impact: Service authentication failure
- Prevention: Ansible playbook validation, smoke tests

---

## 10. Open Questions and Assumptions

### Assumptions

✅ **Confirmed Assumptions**:
- Google OAuth service availability meets 99.9% uptime (Google SLA)
- Users have or can create Google accounts
- Existing Keycloak installation is functional (version 24.0.3)
- OpenLDAP supports posixAccount/posixGroup schema
- Services support OIDC or SAML authentication
- Network allows outbound HTTPS to Google
- Administrator has Google Cloud Console access
- Traefik version supports forward authentication

### No Outstanding Questions

All technical unknowns have been resolved through research. The implementation can proceed with the documented decisions and patterns.

---

## 11. References and Documentation

### Official Documentation
- Keycloak Server Administration Guide: Identity Broker
- Google OAuth 2.0 Documentation
- OAuth2 Proxy Documentation
- Service-specific OIDC/SAML guides (GitLab, Nextcloud, etc.)

### Community Resources
- Keycloak Discourse community
- OAuth2 Proxy GitHub issues and discussions
- Service-specific integration examples

### Internal Documentation
- Proxmox Infrastructure Constitution
- Existing Ansible role documentation
- Network topology documentation

---

## Summary

All technical research is complete. Key decisions:

1. **Google OAuth**: Use native Keycloak provider with standard scopes
2. **LDAP Sync**: Python script via REST API (15-minute interval)
3. **Service Integration**: OIDC for GitLab/Nextcloud/Grafana/Mattermost/NetBox, SAML for Zabbix
4. **Forward Auth**: OAuth2 Proxy (recommended over alternatives)
5. **Account Linking**: Manual confirmation with review profile
6. **Security**: Vault secrets, HTTPS, token validation, session management

Ready to proceed to Phase 1: Design & Contracts.
