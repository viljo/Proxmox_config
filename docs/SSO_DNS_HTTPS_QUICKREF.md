# SSO/DNS/HTTPS Quick Reference Card

**One-page quick reference for mandatory service requirements**

---

## 1. DNS Entry (5 minutes)

### Add Entry
```yaml
# inventory/group_vars/all/main.yml
loopia_dns_records:
  - host: servicename
    ttl: 600
```

### Deploy
```bash
ansible-playbook -i inventory/hosts.yml playbooks/loopia-dns-deploy.yml --ask-vault-pass
```

### Verify
```bash
dig +short servicename.viljo.se @1.1.1.1
# Should return: 85.24.XXX.XXX (your public IP)
```

---

## 2. HTTPS Certificate (5 minutes)

### Add Traefik Service
```yaml
# inventory/group_vars/all/main.yml
traefik_services:
  - name: servicename
    host: "servicename.{{ public_domain }}"
    container_id: "{{ servicename_container_id }}"
    port: 8080  # Internal port
```

### Deploy
```bash
ansible-playbook -i inventory/hosts.yml playbooks/traefik-deploy.yml --ask-vault-pass
```

### Monitor Certificate Issuance
```bash
pct exec 167 -- docker logs -f traefik
# Look for: "Obtained certificate for servicename.viljo.se"
```

### Verify
```bash
curl -I https://servicename.viljo.se
# Should return: HTTP/2 200

echo | openssl s_client -connect servicename.viljo.se:443 -servername servicename.viljo.se 2>/dev/null | openssl x509 -noout -issuer
# Should show: Let's Encrypt
```

---

## 3. SSO Integration (20-30 minutes)

### Step 1: Create Keycloak Client

1. **Open**: https://keycloak.viljo.se
2. **Login**: admin / (vault_keycloak_admin_password)
3. **Navigate**: Clients → Create client
4. **Configure**:
   - Client ID: `servicename`
   - Client Type: OpenID Connect
   - Client authentication: ON (confidential)
5. **Set URLs**:
   - Root URL: `https://servicename.viljo.se`
   - Valid redirect URIs: `https://servicename.viljo.se/*`
   - Web origins: `https://servicename.viljo.se`
6. **Save** and go to **Credentials** tab
7. **Copy** Client Secret

### Step 2: Configure Client Mappers

**Go to**: Client → Client scopes → servicename-dedicated → Add mapper → By configuration

**Mapper 1: Username**
- Mapper type: User Property
- Name: `username`
- Property: `username`
- Token Claim Name: `preferred_username`
- Add to ID token: ON
- Add to access token: ON
- Add to userinfo: ON

**Mapper 2: Email Verified**
- Mapper type: User Property
- Name: `email verified`
- Property: `emailVerified`
- Token Claim Name: `email_verified`
- Claim JSON Type: boolean
- Add to ID token: ON
- Add to access token: ON
- Add to userinfo: ON

### Step 3: Store Client Secret
```bash
ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt

# Add this line:
vault_servicename_oidc_client_secret: "PASTE_SECRET_HERE"
```

### Step 4: Configure Service for OIDC

**Discovery endpoint method** (preferred):
```yaml
OIDC_DISCOVERY_URL: "https://keycloak.viljo.se/realms/master/.well-known/openid-configuration"
OIDC_CLIENT_ID: "servicename"
OIDC_CLIENT_SECRET: "{{ vault_servicename_oidc_client_secret }}"
OIDC_REDIRECT_URI: "https://servicename.viljo.se/oauth2/callback"
OIDC_SCOPE: "openid profile email"
```

### Step 5: Test SSO
```bash
# Open in incognito mode
open https://servicename.viljo.se

# Expected flow:
# 1. Click "Sign in with SSO"
# 2. Redirect to keycloak.viljo.se
# 3. Redirect to gitlab.com
# 4. Login with GitLab credentials
# 5. Return to service, logged in
```

---

## Service-Specific OIDC Examples

### Nextcloud (user_oidc app)
```bash
docker exec -u www-data nextcloud php occ app:install user_oidc
docker exec -u www-data nextcloud php occ app:enable user_oidc

docker exec -u www-data nextcloud php occ config:app:set user_oidc providers --value '{
  "1": {
    "identifier": "keycloak",
    "name": "Sign in with GitLab SSO",
    "clientId": "nextcloud",
    "clientSecret": "SECRET",
    "discoveryEndpoint": "https://keycloak.viljo.se/realms/master/.well-known/openid-configuration",
    "scope": "openid profile email",
    "autoProvision": true
  }
}'
```

### GitLab (config/gitlab.rb)
```ruby
gitlab_rails['omniauth_providers'] = [
  {
    name: 'openid_connect',
    label: 'GitLab SSO',
    args: {
      name: 'openid_connect',
      scope: ['openid', 'profile', 'email'],
      response_type: 'code',
      issuer: 'https://keycloak.viljo.se/realms/master',
      discovery: true,
      client_auth_method: 'query',
      uid_field: 'preferred_username',
      client_options: {
        identifier: 'gitlab',
        secret: 'SECRET',
        redirect_uri: 'https://gitlab.viljo.se/users/auth/openid_connect/callback'
      }
    }
  }
]
```

### oauth2-proxy (Forward Auth)

**Update inventory**:
```yaml
# inventory/group_vars/all/main.yml
traefik_services:
  - name: servicename
    # ... existing config ...
    middlewares:
      - "oauth2-proxy-servicename@file"
```

**Deploy**:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/oauth2-proxy-deploy.yml --ask-vault-pass
ansible-playbook -i inventory/hosts.yml playbooks/traefik-deploy.yml --ask-vault-pass
```

---

## Troubleshooting

### DNS Not Resolving
```bash
# Check DNS entry in inventory
grep -A2 "host: servicename" inventory/group_vars/all/main.yml

# Redeploy DNS
ansible-playbook -i inventory/hosts.yml playbooks/loopia-dns-deploy.yml --ask-vault-pass

# Wait and retry
sleep 120
dig +short servicename.viljo.se @1.1.1.1
```

### Certificate Not Issuing
```bash
# Check Traefik logs
pct exec 167 -- docker logs traefik 2>&1 | grep -i error

# Verify DNS resolves first
dig +short servicename.viljo.se @1.1.1.1

# Restart Traefik if needed
pct exec 167 -- docker restart traefik
```

### SSO "invalid_redirect_uri"
```bash
# Check exact redirect URI service is using
# (View browser network tab during login attempt)

# Add to Keycloak client "Valid redirect URIs"
# Include wildcards: https://servicename.viljo.se/*
```

### SSO "invalid_client"
```bash
# Verify client ID matches
# Check client secret is correct in vault

ansible-vault view inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt | grep servicename
```

### SSO User Not Created
```bash
# Check auto-provisioning enabled in service config

# Check service logs for OIDC errors
pct exec CONTAINER_ID -- docker logs SERVICE 2>&1 | grep -i oidc

# Check Keycloak logs
pct exec 151 -- docker logs keycloak 2>&1 | grep -i error
```

---

## Verification Script

```bash
#!/bin/bash
# Quick verification of all 3 requirements

SERVICE="$1"
DOMAIN="viljo.se"

echo "Verifying: $SERVICE.$DOMAIN"

# DNS
DNS=$(dig +short "$SERVICE.$DOMAIN" @1.1.1.1 | head -1)
[ -n "$DNS" ] && echo "✓ DNS: $DNS" || echo "✗ DNS: Failed"

# HTTPS
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "https://$SERVICE.$DOMAIN" --max-time 10)
[ "$HTTP" -ge 200 ] && [ "$HTTP" -lt 400 ] && echo "✓ HTTPS: $HTTP" || echo "✗ HTTPS: $HTTP"

# Certificate
CERT=$(echo | openssl s_client -connect "$SERVICE.$DOMAIN:443" -servername "$SERVICE.$DOMAIN" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)
echo "$CERT" | grep -q "Let's Encrypt" && echo "✓ Certificate: Let's Encrypt" || echo "✗ Certificate: Invalid"

# SSO (manual check required)
echo "⚠ SSO: Manual test required"
echo "  Open: https://$SERVICE.$DOMAIN"
echo "  Test: SSO login flow"
```

**Save as**: `scripts/quick-verify.sh` and run: `bash scripts/quick-verify.sh servicename`

---

## Common Redirect URIs by Service Type

| Service Type | Redirect URI Pattern |
|--------------|---------------------|
| Nextcloud | `/apps/user_oidc/code` |
| GitLab | `/users/auth/openid_connect/callback` |
| Jellyfin | `/sso/OID/r/keycloak` |
| Coolify | `/auth/oauth/callback` |
| Grafana | `/login/generic_oauth` |
| oauth2-proxy | `/oauth2/callback` |
| Generic | `/auth/callback` or `/oauth/callback` |

**Always add wildcard**: `https://servicename.viljo.se/*` to Valid redirect URIs in Keycloak.

---

## Key Endpoints

| Purpose | Endpoint |
|---------|----------|
| Keycloak Admin | https://keycloak.viljo.se |
| Discovery Endpoint | https://keycloak.viljo.se/realms/master/.well-known/openid-configuration |
| Authorization Endpoint | https://keycloak.viljo.se/realms/master/protocol/openid-connect/auth |
| Token Endpoint | https://keycloak.viljo.se/realms/master/protocol/openid-connect/token |
| Userinfo Endpoint | https://keycloak.viljo.se/realms/master/protocol/openid-connect/userinfo |
| Traefik Dashboard | https://traefik.viljo.se/dashboard/ |
| Loopia Control Panel | https://customerzone.loopia.com |

---

## Time Estimates

| Task | Time |
|------|------|
| DNS Entry | 5 min |
| HTTPS Certificate | 5 min (+ 1-3 min issuance) |
| SSO (Native OIDC) | 15-30 min |
| SSO (oauth2-proxy) | 30-45 min |
| **Total (Native)** | **25-40 min** |
| **Total (oauth2-proxy)** | **40-55 min** |

**First time**: Add 15-30 minutes for learning curve.

---

## Cheat Sheet

```bash
# 1. DNS
echo "  - host: servicename\n    ttl: 600" >> inventory/group_vars/all/main.yml
ansible-playbook -i inventory/hosts.yml playbooks/loopia-dns-deploy.yml --ask-vault-pass
dig +short servicename.viljo.se @1.1.1.1

# 2. HTTPS
echo "  - name: servicename\n    host: \"servicename.{{ public_domain }}\"\n    container_id: \"{{ servicename_container_id }}\"\n    port: 8080" >> inventory/group_vars/all/main.yml
ansible-playbook -i inventory/hosts.yml playbooks/traefik-deploy.yml --ask-vault-pass
curl -I https://servicename.viljo.se

# 3. SSO
open https://keycloak.viljo.se  # Create client
ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt  # Add secret
# Configure service for OIDC
open https://servicename.viljo.se  # Test login
```

---

## Complete Verification Command

```bash
./scripts/verify-service-requirements.sh servicename
```

**Expected output**:
```
Service Requirements Verification
Service: servicename
FQDN: servicename.viljo.se

Requirement 1: DNS Entry
✓ DNS resolves
  IP Address: 85.24.XXX.XXX

Requirement 2: HTTPS Certificate
✓ HTTPS accessible
  HTTP Status: 200
✓ Valid Let's Encrypt certificate
  Expires: Jan 26 09:15:43 2026 GMT

Requirement 3: SSO Integration
✓ Keycloak discovery endpoint accessible
✓ SSO integration appears to be present

Summary
Core Requirements:
  [1] DNS Entry:          PASS
  [2] HTTPS Certificate:  PASS
  [3] SSO Integration:    MANUAL VERIFICATION REQUIRED

Automated checks: PASSED
Complete manual SSO testing before production deployment.
```

---

## Need More Help?

**Comprehensive Guide**: [SERVICE_IMPLEMENTATION_PIPELINE.md](SERVICE_IMPLEMENTATION_PIPELINE.md)

**Workflow Guide**: [NEW_SERVICE_WORKFLOW.md](NEW_SERVICE_WORKFLOW.md)

**Service Checklist**: [SERVICE_CHECKLIST_TEMPLATE.md](SERVICE_CHECKLIST_TEMPLATE.md)

**Example Implementation**: [NEXTCLOUD_SSO_IMPLEMENTATION.md](NEXTCLOUD_SSO_IMPLEMENTATION.md)

---

**Last Updated**: 2025-10-27
**Version**: 1.0
