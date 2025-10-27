# OAuth2-Proxy Audience Claim Fix

## Problem Statement

The Mattermost SSO authentication via oauth2-proxy was failing with the following error:
```
Error creating session during OAuth2 callback:
audience from claim aud with value [master-realm account] does not match with any of allowed audiences map[oauth2-proxy:{}]
```

## Root Cause Analysis

The issue occurred because:
1. Keycloak (when using the master realm) issues JWT tokens with default audiences: `master-realm` and `account`
2. oauth2-proxy expected the audience to contain `oauth2-proxy` (its client ID)
3. The mismatch caused authentication to fail at the token validation stage

## Solution Implemented

The fix involved a two-pronged approach to ensure compatibility:

### 1. Keycloak Configuration
Created a custom client scope with an audience mapper to include `oauth2-proxy` in the JWT audience claim:

```bash
# Create client scope
kcadm.sh create client-scopes -r master \
  -s name=oauth2-proxy-audience \
  -s protocol=openid-connect

# Add audience mapper
kcadm.sh create client-scopes/{scope-id}/protocol-mappers/models -r master \
  -s name=oauth2-proxy-audience \
  -s protocolMapper=oidc-audience-mapper \
  -s 'config."included.client.audience"=oauth2-proxy'

# Assign to oauth2-proxy client
kcadm.sh update clients/{client-id}/default-client-scopes/{scope-id} -r master
```

### 2. OAuth2-Proxy Configuration
Added extra audiences to accept Keycloak's default audience claims:

```yaml
OAUTH2_PROXY_OIDC_EXTRA_AUDIENCES: "master-realm,account"
```

## Files Modified

### Ansible Templates and Variables

1. **roles/oauth2_proxy_api/templates/docker-compose.yml.j2**
   - Added conditional inclusion of `OAUTH2_PROXY_OIDC_EXTRA_AUDIENCES` environment variable

2. **inventory/group_vars/all/oauth2_proxy.yml**
   - Added `oauth2_proxy_oidc_extra_audiences: "master-realm,account"`

3. **roles/keycloak_api/tasks/configure_oauth2_proxy_client.yml** (NEW)
   - Automated task to configure oauth2-proxy client in Keycloak with proper audience mapping

4. **roles/keycloak_api/tasks/configure_gitlab_oauth.yml**
   - Updated GitLab OAuth configuration (uncommitted changes for username claim mapping)

5. **roles/traefik/files/middlewares.yml**
   - Configured forward auth middleware for oauth2-proxy integration

## Authentication Flow

The complete SSO flow now works as follows:

1. **User Access**: User visits `https://mattermost.viljo.se/`
2. **Auth Check**: Traefik middleware forwards to `http://172.16.10.167:4180/oauth2/auth`
3. **Login Redirect**: oauth2-proxy redirects to Keycloak login at `https://keycloak.viljo.se/realms/master/protocol/openid-connect/auth`
4. **Identity Provider**: User can authenticate via:
   - Direct Keycloak credentials
   - GitLab.com OAuth (federated through Keycloak)
5. **Token Exchange**: After successful authentication, Keycloak redirects to `https://auth.viljo.se/oauth2/callback`
6. **Token Validation**: oauth2-proxy validates the JWT token with audiences: `[oauth2-proxy, master-realm, account]`
7. **Session Creation**: oauth2-proxy sets a secure cookie and redirects to Mattermost
8. **Access Granted**: User accesses Mattermost with valid session

## Verification Steps

To verify the fix is working:

```bash
# 1. Check oauth2-proxy health
curl -sf http://172.16.10.167:4180/ping

# 2. Verify Keycloak OIDC endpoint
curl -sf https://keycloak.viljo.se/realms/master/.well-known/openid-configuration

# 3. Test authentication redirect
curl -I https://mattermost.viljo.se/
# Should return HTTP 403 (authentication required)

# 4. Check for authentication errors
ssh root@192.168.1.3 "pct exec 167 -- docker logs oauth2-proxy 2>&1 | tail -20"
# Should NOT show audience mismatch errors

# 5. Browser test
# Visit https://mattermost.viljo.se/ and complete the login flow
```

## Deployment

To deploy these changes via Ansible:

```bash
# Deploy oauth2-proxy with updated configuration
ansible-playbook playbooks/oauth2-proxy-deploy.yml

# Configure Keycloak client (if needed)
ansible-playbook playbooks/keycloak-deploy.yml --tags configure_oauth2_proxy_client
```

## Troubleshooting

If authentication issues persist:

1. **Check oauth2-proxy logs**:
   ```bash
   pct exec 167 -- docker logs oauth2-proxy --tail 50
   ```

2. **Verify Keycloak client configuration**:
   ```bash
   pct exec 151 -- docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients/{client-id} -r master
   ```

3. **Test token validation**:
   - Decode a JWT token from the authentication flow
   - Verify the `aud` claim contains expected values

4. **Clear browser cookies**:
   - Authentication issues may be caused by stale cookies
   - Clear cookies for `*.viljo.se` domain

## Security Considerations

- JWT tokens are validated using JWKS from Keycloak
- Cookies are set with `Secure`, `HttpOnly`, and `SameSite=lax` flags
- Internal communication uses private network (172.16.10.0/24)
- External URLs use HTTPS with valid certificates
- GitLab.com OAuth users inherit Keycloak's session policies

## Future Improvements

1. Consider moving from master realm to a dedicated realm for applications
2. Implement group-based access control using OIDC groups claim
3. Add monitoring for authentication failures
4. Configure session timeout policies in Keycloak
5. Implement automated testing for the authentication flow