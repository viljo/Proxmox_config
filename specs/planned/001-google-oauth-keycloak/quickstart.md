# Quickstart Guide: Google OAuth Integration with Keycloak

**Feature**: Google OAuth Integration with Keycloak
**Date**: 2025-10-20
**Estimated Time**: 4-6 hours for complete setup

## Overview

This guide provides step-by-step instructions for implementing Google OAuth authentication through Keycloak with LDAP synchronization and service integration.

---

## Prerequisites

Before starting, ensure you have:

- [ ] Access to Google Cloud Console (admin rights to create OAuth credentials)
- [ ] Keycloak installed and accessible (version 20.0+)
- [ ] OpenLDAP installed and configured
- [ ] Ansible environment set up with vault configured
- [ ] Traefik reverse proxy configured with HTTPS
- [ ] Admin access to infrastructure services (GitLab, Nextcloud, Grafana, etc.)

---

## Phase 1: Google Cloud Console Setup (30 minutes)

### Step 1.1: Create Google OAuth 2.0 Credentials

1. **Navigate to Google Cloud Console**:
   ```
   https://console.developers.google.com/apis/credentials
   ```

2. **Create or Select Project**:
   - Click "Select a project" → "New Project"
   - Project name: "Proxmox Infrastructure SSO"
   - Click "Create"

3. **Configure OAuth Consent Screen**:
   - Click "OAuth consent screen" in left menu
   - User Type: **External** (or Internal for Google Workspace)
   - App name: `Proxmox Infrastructure`
   - User support email: `admin@{{ public_domain }}`
   - Authorized domains: `{{ public_domain }}`
   - Developer contact: `admin@{{ public_domain }}`
   - Click "Save and Continue"
   - Scopes: Leave default (openid, profile, email) - Click "Save and Continue"
   - Test users: Add your Google account - Click "Save and Continue"

4. **Create OAuth Client**:
   - Click "Credentials" → "Create Credentials" → "OAuth client ID"
   - Application type: **Web application**
   - Name: `Keycloak Production`
   - Authorized JavaScript origins: `https://keycloak.{{ public_domain }}`
   - Authorized redirect URIs: `https://keycloak.{{ public_domain }}/realms/master/broker/google/endpoint`
   - Click "Create"

5. **Save Credentials**:
   - Copy **Client ID** (format: `123456-xyz.apps.googleusercontent.com`)
   - Copy **Client Secret**
   - Store securely (will add to Ansible Vault)

---

## Phase 2: Ansible Vault Setup (15 minutes)

### Step 2.1: Add Secrets to Vault

```bash
# Edit vault file
ansible-vault edit inventory/group_vars/all/secrets.yml

# Add these entries:
vault_google_oauth_client_id: "<paste-client-id-from-google>"
vault_google_oauth_client_secret: "<paste-client-secret-from-google>"

# Generate OAuth2 Proxy cookie secret (32-byte random)
vault_oauth2_proxy_cookie_secret: "<run: python -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'>"

# Save and exit (:wq in vim)
```

### Step 2.2: Verify Vault Encryption

```bash
# Vault should be encrypted
cat inventory/group_vars/all/secrets.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256...

# Test decryption
ansible-vault view inventory/group_vars/all/secrets.yml --ask-vault-pass
# Should show plaintext secrets
```

---

## Phase 3: Keycloak Google IdP Configuration (30 minutes)

### Step 3.1: Configure Google Identity Provider via Ansible

```bash
# Run Keycloak Google OAuth playbook
ansible-playbook playbooks/keycloak-google-oauth.yml --ask-vault-pass
```

**Manual Alternative** (if playbook not ready):

1. **Login to Keycloak Admin Console**:
   ```
   https://keycloak.{{ public_domain }}/admin
   ```

2. **Add Google Identity Provider**:
   - Navigate to: Identity Providers → Add provider → Google
   - **Alias**: `google`
   - **Display Name**: `Sign in with Google`
   - **Enabled**: ON
   - **Trust Email**: ON
   - **Store Tokens**: OFF
   - **Client ID**: `{{ vault_google_oauth_client_id }}`
   - **Client Secret**: `{{ vault_google_oauth_client_secret }}`
   - **Default Scopes**: `openid profile email`
   - **Hosted Domain**: (leave empty for consumer accounts)
   - Click "Save"

3. **Copy Redirect URI**:
   - Scroll down to "Redirect URI" field
   - Copy the URI (should match what you configured in Google)
   - Verify exact match in Google Cloud Console

### Step 3.2: Configure Attribute Mappers

1. **Navigate to Mappers**:
   - Identity Providers → google → Mappers tab

2. **Add Email Mapper**:
   - Click "Create"
   - **Name**: `google-email`
   - **Sync Mode Override**: FORCE
   - **Mapper Type**: Attribute Importer
   - **Social Profile JSON Field Path**: `email`
   - **User Attribute Name**: `email`
   - Click "Save"

3. **Add Name Mappers** (repeat for each):
   - First Name: `given_name` → `firstName` (INHERIT)
   - Last Name: `family_name` → `lastName` (INHERIT)
   - Picture: `picture` → `picture` (FORCE)

### Step 3.3: Test Google Authentication

```bash
# Open Keycloak account console
https://keycloak.{{ public_domain }}/realms/master/account

# Click "Sign in with Google"
# Should redirect to Google login
# After authentication, should return to Keycloak account page
# Verify your profile shows Google data (name, email)
```

---

## Phase 4: LDAP Sync Setup (45 minutes)

### Step 4.1: Prepare LDAP Schema

```bash
# SSH to LDAP container or server
ssh root@172.16.10.51

# Create organizational units
ldapadd -x -D "cn=admin,dc=infra,dc=local" -W <<EOF
dn: ou=people,dc=infra,dc=local
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=infra,dc=local
objectClass: organizationalUnit
ou: groups

dn: ou=services,dc=infra,dc=local
objectClass: organizationalUnit
ou: services
EOF

# Create UID/GID counter objects
ldapadd -x -D "cn=admin,dc=infra,dc=local" -W <<EOF
dn: cn=uidNext,ou=services,dc=infra,dc=local
objectClass: extensibleObject
cn: uidNext
uidNumber: 10001

dn: cn=gidNext,ou=services,dc=infra,dc=local
objectClass: extensibleObject
cn: gidNext
gidNumber: 10001
EOF

# Create default groups
ldapadd -x -D "cn=admin,dc=infra,dc=local" -W <<EOF
dn: cn=users,ou=groups,dc=infra,dc=local
objectClass: posixGroup
cn: users
gidNumber: 10000

dn: cn=admins,ou=groups,dc=infra,dc=local
objectClass: posixGroup
cn: admins
gidNumber: 10001
EOF
```

### Step 4.2: Deploy LDAP Sync Script

```bash
# Run Ansible playbook to deploy sync script
ansible-playbook playbooks/keycloak-ldap-sync.yml --ask-vault-pass
```

**Manual Alternative**:

1. Create Python sync script at `/usr/local/bin/keycloak-to-ldap-sync.py`
   (see contracts/ldap-sync-mapping.json for logic)

2. Create systemd service and timer:
   ```bash
   # Create service file
   cat > /etc/systemd/system/keycloak-ldap-sync.service <<EOF
   [Unit]
   Description=Keycloak to LDAP Sync
   After=network.target

   [Service]
   Type=oneshot
   ExecStart=/usr/bin/python3 /usr/local/bin/keycloak-to-ldap-sync.py
   StandardOutput=journal
   StandardError=journal
   EOF

   # Create timer file
   cat > /etc/systemd/system/keycloak-ldap-sync.timer <<EOF
   [Unit]
   Description=Keycloak to LDAP Sync Timer

   [Timer]
   OnBootSec=5min
   OnUnitActiveSec=15min

   [Install]
   WantedBy=timers.target
   EOF

   # Enable and start
   systemctl daemon-reload
   systemctl enable keycloak-ldap-sync.timer
   systemctl start keycloak-ldap-sync.timer
   ```

### Step 4.3: Test LDAP Sync

```bash
# Trigger manual sync
systemctl start keycloak-ldap-sync.service

# Check logs
journalctl -u keycloak-ldap-sync.service -f

# Verify user in LDAP
ldapsearch -x -H ldap://172.16.10.51 \
  -D "cn=admin,dc=infra,dc=local" \
  -W \
  -b "ou=people,dc=infra,dc=local" \
  "(mail=your-google-email@gmail.com)"

# Should show posixAccount entry with uidNumber, homeDirectory, etc.
```

---

## Phase 5: Service OIDC Integration (2-3 hours)

### Step 5.1: Create OIDC Clients in Keycloak

For each service, create an OIDC client:

```bash
# Use Ansible playbook (recommended)
ansible-playbook playbooks/service-oidc-integration.yml --ask-vault-pass
```

**Manual Alternative** (example for GitLab):

1. Navigate to Keycloak Admin → Clients → Create
2. **Client ID**: `gitlab`
3. **Client Protocol**: `openid-connect`
4. **Access Type**: `confidential`
5. **Valid Redirect URIs**: `https://gitlab.{{ public_domain }}/users/auth/openid_connect/callback`
6. **Web Origins**: `https://gitlab.{{ public_domain }}`
7. Click "Save"
8. Go to "Credentials" tab → Copy "Secret" → Store in Ansible Vault as `vault_gitlab_oidc_secret`

Repeat for: `nextcloud`, `grafana`, `mattermost`, `netbox`, `oauth2-proxy`

### Step 5.2: Configure Services

**GitLab**:
```bash
# Edit /etc/gitlab/gitlab.rb (see contracts/service-oidc-configs/gitlab-oidc.rb)
# Run: gitlab-ctl reconfigure
```

**Nextcloud**:
```bash
# Install user_oidc app via App Store
# Edit /var/www/nextcloud/config/config.php (see contracts/service-oidc-configs/nextcloud-oidc.php)
```

**Grafana**:
```bash
# Edit /etc/grafana/grafana.ini (see contracts/service-oidc-configs/grafana-oidc.ini)
# Run: systemctl restart grafana-server
```

### Step 5.3: Test Service Authentication

For each service:
1. Access service URL (e.g., `https://gitlab.{{ public_domain }}`)
2. Click "Sign in with Keycloak" or similar
3. Should redirect to Keycloak
4. Select "Sign in with Google"
5. Authenticate with Google
6. Should redirect back to service with active session

---

## Phase 6: OAuth2 Proxy Deployment (1 hour)

### Step 6.1: Deploy OAuth2 Proxy Container

```bash
# Run Ansible playbook
ansible-playbook playbooks/oauth2-proxy-deploy.yml --ask-vault-pass
```

### Step 6.2: Configure Traefik Middleware

```bash
# Copy dynamic configuration
# (see contracts/traefik-forwardauth-config.yml)

# Add to Traefik dynamic config directory
cp contracts/traefik-forwardauth-config.yml /etc/traefik/dynamic/

# Reload Traefik
systemctl reload traefik
```

### Step 6.3: Protect a Service

Example: Protect demo site

```yaml
# /etc/traefik/dynamic/demo-site-protected.yml
http:
  routers:
    demo-site:
      rule: "Host(`demosite.{{ public_domain }}`)"
      service: demo-site-svc
      middlewares:
        - oauth2-auth  # Add this line
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

  services:
    demo-site-svc:
      loadBalancer:
        servers:
          - url: "http://172.16.10.60:80"
```

### Step 6.4: Test Protected Service

```bash
# Access demo site
curl -I https://demosite.{{ public_domain }}

# Should see 302 redirect to https://auth.{{ public_domain }}/oauth2/start?...
# Click through authentication
# Should reach demo site with headers:
#   X-Auth-Request-User: your-username
#   X-Auth-Request-Email: your-email@gmail.com
```

---

## Phase 7: Verification and Testing (1 hour)

### Verification Checklist

#### Google OAuth
- [ ] Google login works in Keycloak
- [ ] User profile populated from Google (name, email, picture)
- [ ] Email is trusted/verified automatically
- [ ] User can logout and login again

#### LDAP Sync
- [ ] User appears in LDAP within 15 minutes
- [ ] LDAP entry has posixAccount attributes
- [ ] uidNumber is unique and auto-allocated
- [ ] homeDirectory is set correctly
- [ ] Groups sync to posixGroup entries

#### Service Integration
- [ ] GitLab: Login via Keycloak → Google works
- [ ] Nextcloud: Login via Keycloak → Google works
- [ ] Grafana: Login via Keycloak → Google works
- [ ] Role mapping works (admin vs viewer in Grafana)
- [ ] SSO works (login to one service, access another without re-auth)

#### OAuth2 Proxy
- [ ] Unauthenticated requests redirect to Keycloak
- [ ] Authenticated requests pass through with headers
- [ ] Group-based access control works (if configured)
- [ ] Session persists across requests

#### Security
- [ ] All connections use HTTPS
- [ ] Secrets are encrypted in Ansible Vault
- [ ] Keycloak validates token signatures
- [ ] Session timeouts work as configured

---

## Troubleshooting

### Issue: "redirect_uri_mismatch" in Google

**Cause**: Redirect URI in Google doesn't match Keycloak's URI

**Fix**:
1. Get exact URI from Keycloak: Identity Providers → google → Redirect URI field
2. Copy to Google Cloud Console → Credentials → Edit OAuth client → Authorized redirect URIs
3. Ensure exact match (case-sensitive, no trailing slashes)
4. Wait 5 minutes for Google propagation

### Issue: LDAP sync not working

**Cause**: Multiple possible causes

**Fix**:
```bash
# Check sync service status
systemctl status keycloak-ldap-sync.timer
systemctl status keycloak-ldap-sync.service

# Check logs
journalctl -u keycloak-ldap-sync.service -n 50

# Verify LDAP connectivity
ldapsearch -x -H ldap://172.16.10.51 -D "cn=admin,dc=infra,dc=local" -W -b "dc=infra,dc=local"

# Verify Keycloak API access
curl -X POST "https://keycloak.{{ public_domain }}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=<admin-password>" \
  -d "grant_type=password"
```

### Issue: Service OIDC not working

**Cause**: Client configuration mismatch

**Fix**:
1. Verify client exists in Keycloak: Clients → Check client ID
2. Verify redirect URI matches service configuration
3. Check client secret matches (Keycloak Credentials tab vs service config file)
4. Enable debug logging in service config
5. Check Keycloak Events tab for error details

### Issue: OAuth2 Proxy redirect loop

**Cause**: Cookie domain or redirect URL mismatch

**Fix**:
1. Verify `cookie_domains` includes service domain
2. Verify `redirect_url` in OAuth2 Proxy config matches Keycloak client
3. Check browser cookies (should see `_oauth2_proxy` cookie)
4. Verify Traefik `trustForwardHeader: true`

---

## Rollback Procedures

### Rollback Google OAuth

1. **Disable Google IdP in Keycloak**:
   ```
   Identity Providers → google → Enabled: OFF → Save
   ```

2. **Users can still login with username/password**

### Rollback Service OIDC

For each service:

1. **GitLab**:
   ```bash
   # Edit /etc/gitlab/gitlab.rb
   gitlab_rails['omniauth_enabled'] = false
   gitlab-ctl reconfigure
   ```

2. **Nextcloud**:
   ```bash
   # Disable user_oidc app via admin UI
   # Or edit config.php and remove OIDC settings
   ```

3. **Grafana**:
   ```bash
   # Edit /etc/grafana/grafana.ini
   [auth.generic_oauth]
   enabled = false
   # Restart: systemctl restart grafana-server
   ```

### Rollback LDAP Sync

```bash
# Disable timer
systemctl stop keycloak-ldap-sync.timer
systemctl disable keycloak-ldap-sync.timer

# LDAP entries remain but won't be updated
# Can manually delete LDAP entries if needed
```

### Rollback OAuth2 Proxy

```bash
# Remove Traefik middleware from services
# Edit /etc/traefik/dynamic/*.yml
# Remove or comment out: middlewares: - oauth2-auth

# Reload Traefik
systemctl reload traefik
```

---

## Monitoring and Maintenance

### Daily Checks

```bash
# Check LDAP sync status
systemctl status keycloak-ldap-sync.timer
journalctl -u keycloak-ldap-sync.service -since today

# Check OAuth2 Proxy health
curl https://auth.{{ public_domain }}/ping
# Should return: OK

# Check Keycloak events
# Navigate to: Keycloak Admin → Events → Login Events
# Look for recent LOGIN events via google provider
```

### Weekly Checks

- Review Keycloak events for failed logins
- Verify LDAP sync success rate (should be >95%)
- Check uidNumber counter (ensure not approaching max)
- Review OAuth2 Proxy logs for authorization failures

### Monthly Maintenance

- Rotate OAuth2 Proxy cookie secret
- Review and cleanup unused Keycloak sessions
- Verify all service OIDC clients still active
- Update OAuth2 Proxy to latest version
- Check Google OAuth quotas (shouldn't hit default limits)

---

## Next Steps

After successful implementation:

1. **Document** the setup for your team
2. **Train** users on Google authentication
3. **Monitor** for 2 weeks before full rollout
4. **Gradually migrate** existing LDAP users to Google OAuth
5. **Consider** enabling MFA via Google account settings
6. **Plan** for high availability (multiple Keycloak instances, Redis session storage)

---

## Support and Resources

- **Keycloak Documentation**: https://www.keycloak.org/docs/
- **OAuth2 Proxy Docs**: https://oauth2-proxy.github.io/oauth2-proxy/
- **Google OAuth Docs**: https://developers.google.com/identity/protocols/oauth2
- **Internal Docs**: `docs/deployment/google-oauth-deployment.md`
- **Research Notes**: `specs/planned/001-google-oauth-keycloak/research.md`

---

## Completion Checklist

- [ ] Google OAuth credentials created and stored in vault
- [ ] Keycloak Google IdP configured and tested
- [ ] LDAP sync script deployed and running
- [ ] At least one service (Grafana) integrated and tested
- [ ] OAuth2 Proxy deployed and protecting one service
- [ ] All security checks passed (HTTPS, vault encryption, token validation)
- [ ] Monitoring configured (systemd journal, Keycloak events)
- [ ] Documentation updated
- [ ] Team trained on new authentication flow

**Estimated Total Time**: 4-6 hours

**Status**: Ready for production deployment
