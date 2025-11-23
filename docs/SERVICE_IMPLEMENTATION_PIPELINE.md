> **⚠️ OUTDATED**: This document references Keycloak SSO which is no longer used. Current SSO uses OAuth2-Proxy + GitLab. Current architecture uses Docker containers in LXC 200 with Traefik reverse proxy. See docs/oauth2-proxy-automation.md and docs/getting-started.md
# Service Implementation Pipeline

## Critical: Mandatory Requirements for All Services

**This document establishes the REQUIRED security and accessibility standards for all services deployed in the infrastructure.**

### Non-Negotiable Requirements

Every service implementation MUST include:

1. **Single Sign-On (SSO) via Keycloak** with GitLab.com OAuth backend
2. **DNS entry at Loopia** (automated via loopia_dns role)
3. **HTTPS certificate** (automated via Traefik + Let's Encrypt)

**These requirements are NOT OPTIONAL.** They ensure:
- Security: Centralized authentication, no weak passwords
- Discoverability: Services accessible via friendly domain names
- Trust: Valid HTTPS certificates, no browser warnings
- Maintainability: Consistent authentication and access patterns

---

## Section A: Mandatory Requirements

### 1. SSO via Keycloak (GitLab.com OAuth Backend)

**Status**: MANDATORY for all services with web interfaces

#### Why This is Mandatory

**Security Benefits:**
- Single point of authentication management
- No service-specific passwords to manage or forget
- Centralized user provisioning and de-provisioning
- Audit trail of all authentication events
- Strong OAuth 2.0 / OpenID Connect security

**User Experience Benefits:**
- One login for all infrastructure services
- No password fatigue or reuse
- Familiar GitLab.com login flow
- Automatic session management across services

**Operational Benefits:**
- Consistent authentication patterns across all services
- Easy to add/remove user access
- Integration with existing developer workflows (GitLab)
- Reduces attack surface (fewer password databases)

#### Consequences of Skipping SSO

**DO NOT deploy a service without SSO integration.** Skipping this requirement creates:

1. **Security Risks**:
   - Service-specific passwords (weak, reused, forgotten)
   - No centralized access control
   - Difficult to audit who has access
   - Hard to revoke access when needed

2. **User Experience Problems**:
   - Users must remember multiple passwords
   - Password reset burden on administrators
   - Friction accessing services

3. **Technical Debt**:
   - Retrofitting SSO later is more complex
   - Inconsistent authentication patterns
   - Migration challenges with existing users

#### Exception Handling

**Rare exceptions may exist** for services that:
- Have no web interface (pure CLI/API services)
- Are internal infrastructure (databases, caches)
- Cannot technically support OIDC/OAuth (legacy systems)

**Exception Process:**
1. Document why SSO cannot be implemented
2. Propose alternative authentication (mTLS, API keys with rotation)
3. Document security compensating controls
4. Get explicit approval before proceeding
5. Add to technical debt register for future remediation

**Example Exception**: PostgreSQL database (no web interface, uses password authentication or mTLS)

### 2. DNS Entry at Loopia

**Status**: MANDATORY for all externally-accessible services

#### Why This is Mandatory

**User Experience:**
- Friendly URLs: `https://servicename.viljo.se` instead of `http://172.16.10.155:8080`
- Memorable: Users can find services easily
- Professional: No IP addresses or port numbers

**Technical Benefits:**
- Enables HTTPS certificate automation (requires DNS)
- Allows service relocation without URL changes
- Supports load balancing and failover
- Required for Traefik routing

**Operational Benefits:**
- Centralized DNS management
- Automated provisioning via Ansible
- Consistent naming conventions
- Documentation through DNS records

#### Consequences of Skipping DNS

**DO NOT deploy without DNS entry.** Without DNS:

1. **HTTPS Impossible**: Let's Encrypt requires DNS for validation
2. **Poor UX**: Users must remember IP:PORT combinations
3. **Brittle**: Changing IP/port breaks all existing links
4. **Unprofessional**: Internal IP addresses in production

#### DNS Entry Format

Standard format for all services:

```yaml
# inventory/group_vars/all/main.yml
loopia_dns_records:
  - host: servicename  # Results in servicename.viljo.se
    ttl: 600          # 10 minutes (standard)
```

**Naming Conventions:**
- Use lowercase
- Use hyphens for multi-word names (preferred) or single words
- Keep names short and descriptive
- Examples: `gitlab`, `nextcloud`, `meet` (Jitsi), `qbittorrent`

#### Exception Handling

**Services that don't need DNS:**
- Internal infrastructure (PostgreSQL, Redis)
- Services without network exposure
- Services only accessed via VPN

**Exception Process:**
1. Document why service is internal-only
2. Ensure firewall blocks external access
3. Document internal access method
4. Still consider internal DNS for convenience

### 3. HTTPS Certificate (Traefik + Let's Encrypt)

**Status**: MANDATORY for all web-accessible services

#### Why This is Mandatory

**Security:**
- Encrypted traffic (no eavesdropping)
- Man-in-the-middle attack prevention
- Trust and authenticity verification
- Required for modern web features (HTTP/2, service workers)

**User Experience:**
- No browser security warnings
- Trust indicators (padlock icon)
- Modern browser features work correctly
- Professional appearance

**Technical:**
- Required for many OAuth/OIDC flows
- Enables HTTP/2 and HTTP/3
- Cookie security attributes (Secure flag)
- Content security policies work correctly

**Compliance:**
- Industry best practice
- Required by many standards (PCI-DSS, etc.)
- Expected by users

#### Consequences of Skipping HTTPS

**DO NOT deploy without HTTPS.** Without valid certificates:

1. **Security Risks**:
   - Credentials sent in plaintext
   - Session hijacking possible
   - No authenticity guarantee

2. **User Experience**:
   - Browser warnings scare users
   - Users may not trust service
   - Features may not work (camera, microphone access)

3. **Technical Problems**:
   - OAuth/OIDC redirects may fail
   - Mixed content errors
   - Service workers disabled

#### How Certificates Work

**Automatic Process:**
1. DNS entry exists (requirement #2)
2. Traefik service configuration added
3. Traefik requests certificate from Let's Encrypt
4. Let's Encrypt validates via DNS challenge
5. Certificate issued automatically
6. Traefik serves certificate
7. Auto-renewal before expiration

**No manual intervention required** if DNS and Traefik config are correct.

#### Exception Handling

**No exceptions.** All web services MUST have HTTPS.

Internal services can use:
- Internal CA certificates (more complex)
- Self-signed with proper trust anchors
- **Preferred**: Just use Let's Encrypt (it's free and automated)

---

## Section B: Implementation Steps (In Order)

### Implementation Timeline

These requirements should be implemented at specific stages:

```
Service Development Lifecycle:
1. Initial Development      → [Infrastructure planning]
2. Container Deployment     → [DNS entry added]
3. Service Configuration    → [Basic functionality]
4. Security Configuration   → [SSO integration - DO HERE]
5. Testing                  → [Verify all 3 requirements]
6. Production Deployment    → [All requirements MUST be met]
```

**IMPORTANT**: Do not proceed to production without all 3 requirements implemented and tested.

---

### Step 1: DNS Entry Provisioning

**When**: During initial service planning, before deployment

**Duration**: ~2 minutes

#### 1.1 Add DNS Entry to Inventory

Edit `inventory/group_vars/all/main.yml`:

```yaml
loopia_dns_records:
  # ... existing entries ...
  - host: servicename  # Add your service here
    ttl: 600          # Optional: default is 600 (10 minutes)
```

**Naming Guidelines:**
- Choose a clear, descriptive name
- Use lowercase only
- Prefer single words, use hyphens if needed
- Verify name is not already used: `grep -i "host: servicename" inventory/group_vars/all/main.yml`

#### 1.2 Provision DNS Entry

```bash
# Deploy DNS configuration to Loopia
ansible-playbook -i inventory/hosts.yml playbooks/loopia-dns-deploy.yml --ask-vault-pass

# Expected output: DNS record created/updated
```

#### 1.3 Verify DNS Entry

```bash
# Wait 1-2 minutes for DNS propagation
sleep 120

# Verify DNS resolves correctly
dig +short servicename.viljo.se @1.1.1.1

# Expected output: Your firewall's public IP address
# Example: 85.24.XXX.XXX
```

**Troubleshooting:**
- If no result: Check for typos in main.yml
- If wrong IP: Verify loopia_ddns is running on Proxmox host
- If error: Check Loopia API credentials in vault

#### 1.4 Commit Configuration

```bash
git add inventory/group_vars/all/main.yml
git commit -m "Add DNS entry for servicename.viljo.se"
git push
```

**Success Criteria:**
- DNS record appears in Loopia control panel
- `dig` command returns correct IP
- No errors in Ansible playbook run

---

### Step 2: Traefik Service Configuration (HTTPS Certificate)

**When**: After DNS entry is provisioned and container is deployed

**Duration**: ~5 minutes (certificate issuance takes 1-3 minutes)

**Prerequisites:**
- DNS entry exists and resolves correctly (Step 1 complete)
- Service container is running
- Service is accessible internally (test with `curl http://INTERNAL_IP:PORT`)

#### 2.1 Add Traefik Service Entry

Edit `inventory/group_vars/all/main.yml`:

```yaml
traefik_services:
  # ... existing entries ...
  - name: servicename
    host: "servicename.{{ public_domain }}"
    container_id: "{{ servicename_container_id }}"
    port: 8080  # Internal port where service listens
    # Optional settings:
    # scheme: https              # If service uses HTTPS internally
    # insecure_skip_verify: true # If service has self-signed cert
```

**Configuration Notes:**

**Port**: The internal port where the service listens
- Find with: `pct exec CONTAINER_ID -- netstat -tlnp`
- Common ports: 80 (HTTP), 8080, 3000, 8000, 8096

**Container ID Variable**: Use a variable reference
- Must match variable in service's own config file
- Example: `jellyfin_container_id` defined in `inventory/group_vars/all/jellyfin.yml`

**Scheme**: Usually `http` (default), use `https` only if service has its own certificate

#### 2.2 Deploy Traefik Configuration

```bash
# Deploy Traefik with new service configuration
ansible-playbook -i inventory/hosts.yml playbooks/traefik-deploy.yml --ask-vault-pass

# Expected: Traefik restarts with new configuration
```

#### 2.3 Monitor Certificate Issuance

```bash
# Watch Traefik logs for certificate request
pct exec 167 -- docker logs -f traefik

# Look for lines like:
# time="..." level=info msg="Obtained certificate for servicename.viljo.se"
```

**Certificate Issuance Process:**
1. Traefik detects new service configuration
2. Requests certificate from Let's Encrypt
3. Let's Encrypt performs DNS-01 challenge
4. Traefik responds with DNS TXT record
5. Let's Encrypt validates and issues certificate
6. Traefik stores certificate and serves it

**Typical duration**: 1-3 minutes

#### 2.4 Verify HTTPS Access

```bash
# Test HTTPS access
curl -I https://servicename.viljo.se

# Expected output:
# HTTP/2 200
# server: nginx (or your service)
# (certificate valid, no warnings)

# Verify certificate details
echo | openssl s_client -connect servicename.viljo.se:443 -servername servicename.viljo.se 2>/dev/null | openssl x509 -noout -dates -subject

# Expected:
# subject=CN = servicename.viljo.se
# notBefore=... (recent date)
# notAfter=... (90 days from now)
```

**Browser Test:**
1. Open: `https://servicename.viljo.se`
2. Check for padlock icon in address bar
3. Click padlock → Certificate should be valid
4. Issuer: Let's Encrypt Authority X3 (or newer)

#### 2.5 Commit Configuration

```bash
git add inventory/group_vars/all/main.yml
git commit -m "Add Traefik configuration for servicename with HTTPS"
git push
```

**Success Criteria:**
- Service accessible via HTTPS
- Valid Let's Encrypt certificate
- No browser security warnings
- Certificate auto-renews (check in 60-80 days)

**Troubleshooting:**

**Problem**: "502 Bad Gateway"
- **Cause**: Service not running or wrong port
- **Fix**: Verify service is accessible internally: `curl http://INTERNAL_IP:PORT`

**Problem**: Certificate not issued after 5 minutes
- **Cause**: DNS not resolving or Loopia API issue
- **Fix**: Check `dig servicename.viljo.se`, verify Loopia credentials

**Problem**: "NET::ERR_CERT_AUTHORITY_INVALID"
- **Cause**: Certificate issuance failed, Traefik using self-signed
- **Fix**: Check Traefik logs for errors, ensure DNS resolves correctly

---

### Step 3: Keycloak SSO Integration

**When**: After service is functional (can access via HTTPS)

**Duration**: ~15-30 minutes (varies by service)

**Prerequisites:**
- DNS entry provisioned (Step 1 complete)
- HTTPS working (Step 2 complete)
- Service deployed and accessible
- Service admin credentials available

#### Two Approaches to SSO Integration

**Approach A: Native OIDC Support** (PREFERRED)
- Service has built-in Keycloak/OIDC integration
- Direct integration, best user experience
- Examples: Nextcloud, GitLab, Jellyfin, Coolify
- **Use this if available**

**Approach B: oauth2-proxy Forward Auth**
- Service lacks native SSO support
- Use oauth2-proxy as authentication gateway
- Transparent to service
- Examples: Services without OIDC support
- **Fallback when Approach A not possible**

---

#### Approach A: Native OIDC Integration

**When to Use**: Service has built-in OIDC/OAuth support

##### A.1 Create Keycloak Client

Access Keycloak admin console:

```bash
# Open in browser
open https://keycloak.viljo.se

# Login with admin credentials
# Username: admin
# Password: (from vault_keycloak_admin_password)
```

Create new client:

1. **Navigate**: Clients → Create client
2. **Client type**: OpenID Connect
3. **Client ID**: `servicename` (match your service name)
4. **Name**: "ServiceName OIDC Client" (descriptive)
5. Click "Next"

Configure capability:

6. **Client authentication**: ON (confidential client)
7. **Authorization**: OFF (not needed for SSO)
8. **Authentication flow**:
   - ✅ Standard flow (OAuth authorization code)
   - ❌ Direct access grants (disable)
   - ❌ Implicit flow (disable - insecure)
   - ❌ Service accounts roles (not needed)
9. Click "Next"

Configure login settings:

10. **Root URL**: `https://servicename.viljo.se`
11. **Valid redirect URIs**:
    - Add service-specific callback URLs
    - Common patterns:
      - `https://servicename.viljo.se/oauth2/callback`
      - `https://servicename.viljo.se/auth/callback`
      - `https://servicename.viljo.se/login/oauth/callback`
      - Check service documentation for exact URL
    - **IMPORTANT**: Include trailing wildcards if needed: `https://servicename.viljo.se/*`
12. **Valid post logout redirect URIs**: `https://servicename.viljo.se/*`
13. **Web origins**: `https://servicename.viljo.se`
14. Click "Save"

Get client credentials:

15. Go to "Credentials" tab
16. **Client secret**: Copy this value
17. Store securely in Ansible vault (Step A.2)

##### A.2 Store Client Secret in Vault

```bash
# Edit vault file
ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt

# Add entry:
vault_servicename_oidc_client_secret: "paste-secret-here"

# Save and exit
```

**Vault Variable Naming Convention:**
- Format: `vault_servicename_oidc_client_secret`
- Use lowercase, underscores
- Must start with `vault_` prefix

##### A.3 Configure Client Mappers (Important!)

Mappers ensure user attributes are sent correctly to the service.

Go to client → "Client scopes" tab → Click "servicename-dedicated" → "Add mapper" → "By configuration"

**Required Mapper 1: Username**
- Mapper type: User Property
- Name: `username`
- Property: `username`
- Token Claim Name: `preferred_username`
- Claim JSON Type: String
- Add to ID token: ON
- Add to access token: ON
- Add to userinfo: ON

**Required Mapper 2: Email Verified**
- Mapper type: User Property
- Name: `email verified`
- Property: `emailVerified`
- Token Claim Name: `email_verified`
- Claim JSON Type: boolean
- Add to ID token: ON
- Add to access token: ON
- Add to userinfo: ON

**Optional Mapper 3: Groups** (if service supports group mapping)
- Mapper type: Group Membership
- Name: `groups`
- Token Claim Name: `groups`
- Full group path: OFF
- Add to ID token: ON
- Add to userinfo: ON

##### A.4 Configure Service for OIDC

**Configuration varies by service.** Common patterns:

**Discovery Endpoint Method** (preferred):
```yaml
# Most services support OIDC discovery
OIDC_DISCOVERY_URL: "https://keycloak.viljo.se/realms/master/.well-known/openid-configuration"
OIDC_CLIENT_ID: "servicename"
OIDC_CLIENT_SECRET: "{{ vault_servicename_oidc_client_secret }}"
OIDC_REDIRECT_URI: "https://servicename.viljo.se/oauth2/callback"
```

**Manual Endpoint Method**:
```yaml
# If service doesn't support discovery
OIDC_ISSUER: "https://keycloak.viljo.se/realms/master"
OIDC_AUTH_URL: "https://keycloak.viljo.se/realms/master/protocol/openid-connect/auth"
OIDC_TOKEN_URL: "https://keycloak.viljo.se/realms/master/protocol/openid-connect/token"
OIDC_USERINFO_URL: "https://keycloak.viljo.se/realms/master/protocol/openid-connect/userinfo"
OIDC_CLIENT_ID: "servicename"
OIDC_CLIENT_SECRET: "{{ vault_servicename_oidc_client_secret }}"
```

**Service-Specific Examples:**

**Nextcloud** (using user_oidc app):
```bash
# Install app
docker exec -u www-data nextcloud php occ app:install user_oidc
docker exec -u www-data nextcloud php occ app:enable user_oidc

# Configure via OCC
docker exec -u www-data nextcloud php occ config:app:set user_oidc providers --value '{
  "1": {
    "identifier": "keycloak",
    "name": "Sign in with GitLab SSO",
    "clientId": "nextcloud",
    "clientSecret": "SECRET_HERE",
    "discoveryEndpoint": "https://keycloak.viljo.se/realms/master/.well-known/openid-configuration",
    "scope": "openid profile email",
    "autoProvision": true
  }
}'
```

**GitLab** (using OmniAuth):
```yaml
# config/gitlab.rb
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
        secret: 'SECRET_HERE',
        redirect_uri: 'https://gitlab.viljo.se/users/auth/openid_connect/callback'
      }
    }
  }
]
```

**Jellyfin** (using SSO-Plugin):
```yaml
# Install SSO plugin from repository
# Configure in Jellyfin admin panel
{
  "OIDProvider": "Keycloak",
  "OIDEndpoint": "https://keycloak.viljo.se/realms/master",
  "OIDClientId": "jellyfin",
  "OIDSecret": "SECRET_HERE",
  "EnableAuthorization": true
}
```

##### A.5 Test SSO Login Flow

**Test Procedure:**

1. **Clear Session**: Use incognito/private browsing mode
2. **Navigate**: Go to `https://servicename.viljo.se`
3. **Click SSO**: Look for "Sign in with SSO" / "Sign in with GitLab" button
4. **Redirect to Keycloak**: Should redirect to `keycloak.viljo.se`
5. **Keycloak Session Check**:
   - If no session: Redirects to GitLab.com
   - If existing session: Auto-logs in
6. **GitLab Authentication**: Login with GitLab.com credentials
7. **Return to Service**: Should redirect back, logged in
8. **Verify User**: Check username matches GitLab username

**Verification Commands:**

```bash
# Check Keycloak logs for authentication
pct exec 151 -- docker logs keycloak 2>&1 | grep -i "code_to_token"

# Check service logs for OIDC token exchange
pct exec CONTAINER_ID -- docker logs SERVICE 2>&1 | grep -i oidc

# Verify user created in service
# (Service-specific commands)
```

##### A.6 Configure Auto-Provisioning

**Important**: Enable automatic user creation on first login.

Most services support these settings:
- `autoProvision: true` - Create user on first SSO login
- `autoUpdate: true` - Update user attributes on subsequent logins
- `defaultGroup: users` - Add new users to default group
- `roleMapping: groups` - Map Keycloak groups to service roles (optional)

**Example (Nextcloud)**:
```json
{
  "autoProvision": true,
  "autoUpdate": true
}
```

This eliminates manual user management.

##### A.7 Grant Admin Access (If Needed)

After first login, promote user to admin if needed:

```bash
# Service-specific commands
# Nextcloud example:
pct exec 155 -- docker exec -u www-data nextcloud php occ group:adduser admin anders

# GitLab example:
pct exec 154 -- docker exec -it gitlab gitlab-rails runner "user = User.find_by(username: 'anders'); user.admin = true; user.save!"

# Jellyfin: Admin UI → Users → Edit user → Check "Administrator"
```

##### A.8 Document Configuration

Add to service README or documentation:

```markdown
## Authentication

This service uses SSO via Keycloak (GitLab.com OAuth backend).

- **Keycloak Client**: servicename
- **Login URL**: https://servicename.viljo.se
- **Click**: "Sign in with GitLab SSO"
- **Auto-provisioning**: Enabled (users created on first login)
- **Admin users**: Must be granted after first login

### Adding Admin Users

After user's first login:
```bash
pct exec CONTAINER_ID -- docker exec SERVICE <command-to-grant-admin>
```
```

**Success Criteria - Approach A:**
- Keycloak client created and configured
- Client secret stored in vault
- Service configured for OIDC
- SSO login flow works end-to-end
- User auto-provisioned on first login
- User attributes (username, email) populated correctly

---

#### Approach B: oauth2-proxy Forward Auth

**When to Use**: Service lacks native OIDC support or has poor OIDC implementation

**How It Works:**
```
User → Traefik → oauth2-proxy (auth check) → Service
                      ↓ (if not authenticated)
                  Keycloak → GitLab.com
```

oauth2-proxy sits in front of service and handles all authentication.

##### B.1 Create Keycloak Client for oauth2-proxy

Follow same process as Approach A.1, but with specific redirect URIs:

**Client ID**: `servicename-proxy` (distinguish from service itself)

**Valid redirect URIs**:
- `https://servicename.viljo.se/oauth2/callback`
- `https://auth.viljo.se/oauth2/callback` (if using shared oauth2-proxy)

**Store client secret in vault** (Step A.2 pattern)

##### B.2 Deploy oauth2-proxy Container (If Not Exists)

Check if oauth2-proxy already deployed:

```bash
pct list | grep oauth2

# If not deployed, use existing oauth2-proxy container role
ansible-playbook -i inventory/hosts.yml playbooks/oauth2-proxy-container-deploy.yml --ask-vault-pass
```

##### B.3 Configure oauth2-proxy for Service

Add configuration for service:

```yaml
# inventory/group_vars/all/oauth2_proxy.yml or service-specific file
oauth2_proxy_upstreams:
  - service: servicename
    upstream: "http://172.16.10.XXX:PORT"
    client_id: "servicename-proxy"
    client_secret: "{{ vault_servicename_proxy_oidc_client_secret }}"
    cookie_name: "_oauth2_proxy_servicename"
```

##### B.4 Configure Traefik Middleware

Update Traefik service configuration:

```yaml
# inventory/group_vars/all/main.yml
traefik_services:
  - name: servicename
    host: "servicename.{{ public_domain }}"
    container_id: "{{ servicename_container_id }}"
    port: 8080
    middlewares:
      - "oauth2-proxy-servicename@file"  # Add this line
```

Create middleware configuration:

```yaml
# Traefik dynamic config (handled by traefik role)
http:
  middlewares:
    oauth2-proxy-servicename:
      forwardAuth:
        address: "http://172.16.10.XXX:4180/oauth2/auth"
        trustForwardHeader: true
        authResponseHeaders:
          - X-Auth-Request-User
          - X-Auth-Request-Email
          - X-Auth-Request-Access-Token
```

##### B.5 Deploy Configuration

```bash
# Deploy oauth2-proxy with new service config
ansible-playbook -i inventory/hosts.yml playbooks/oauth2-proxy-deploy.yml --ask-vault-pass

# Deploy Traefik with updated middleware
ansible-playbook -i inventory/hosts.yml playbooks/traefik-deploy.yml --ask-vault-pass
```

##### B.6 Test oauth2-proxy Flow

**Test Procedure:**

1. **Clear Session**: Use incognito mode
2. **Navigate**: Go to `https://servicename.viljo.se`
3. **Auto-Redirect**: Should auto-redirect to oauth2-proxy
4. **Keycloak Auth**: oauth2-proxy redirects to Keycloak
5. **GitLab Auth**: Keycloak redirects to GitLab.com
6. **Return**: Should return to service, authenticated
7. **Verify**: Service receives auth headers

**Verification:**

```bash
# Check oauth2-proxy logs
pct exec OAUTH2_CONTAINER -- docker logs oauth2-proxy 2>&1 | grep servicename

# Check for successful authentication
pct exec OAUTH2_CONTAINER -- docker logs oauth2-proxy 2>&1 | grep "authentication via OAuth2"

# Verify auth headers sent to service
pct exec CONTAINER_ID -- docker logs SERVICE | grep -i "X-Auth-Request"
```

##### B.7 Handle Service-Side Authorization (If Needed)

Some services can read oauth2-proxy headers for authorization:

```yaml
# Example: Service reads headers
X-Auth-Request-User: anders
X-Auth-Request-Email: anders@viljo.se
X-Auth-Request-Groups: admin,developers
```

Configure service to:
- Trust these headers (only when behind oauth2-proxy)
- Map email/username to internal users
- Use groups for role-based access control

**Security Note**: Service must ONLY trust headers when oauth2-proxy is in path. Use internal networking to ensure service not accessible directly.

**Success Criteria - Approach B:**
- oauth2-proxy client created in Keycloak
- oauth2-proxy configured for service
- Traefik middleware configured
- SSO login flow works via oauth2-proxy
- Service receives authentication headers
- Access denied when not authenticated

---

#### SSO Implementation Troubleshooting

**Problem**: "invalid_redirect_uri" error

**Cause**: Redirect URI mismatch between service and Keycloak

**Fix**:
1. Check exact redirect URI service is using (check browser network tab)
2. Add exact URI to Keycloak client's "Valid redirect URIs"
3. Include wildcards if needed: `https://service.viljo.se/*`

---

**Problem**: "invalid_client" error

**Cause**: Client ID or secret mismatch

**Fix**:
1. Verify client ID in service config matches Keycloak
2. Verify client secret is correct (check vault)
3. Ensure client is enabled in Keycloak

---

**Problem**: User authenticated but no username/email

**Cause**: Missing client mappers or wrong token claims

**Fix**:
1. Add username mapper (Step A.3)
2. Add email verified mapper
3. Verify scopes include `profile` and `email`
4. Check token contents: JWT.io to decode tokens

---

**Problem**: "OIDC provider not found" or "discovery failed"

**Cause**: Discovery endpoint unreachable or misconfigured

**Fix**:
1. Test discovery endpoint manually:
   ```bash
   curl https://keycloak.viljo.se/realms/master/.well-known/openid-configuration
   ```
2. Verify Keycloak is accessible from service container
3. Check for certificate validation errors
4. Ensure service can resolve DNS

---

**Problem**: Authentication works but service shows "access denied"

**Cause**: Service-side authorization issue

**Fix**:
1. Check service logs for authorization errors
2. Verify user exists in service (auto-provisioning enabled?)
3. Grant necessary permissions/roles
4. Check group mappings if service uses groups

---

**Problem**: Redirect loop (keeps redirecting to Keycloak)

**Cause**: Cookie issues or session storage problems

**Fix**:
1. Clear browser cookies
2. Check cookie domain settings in service
3. Ensure service session storage is working
4. Verify oauth2-proxy cookie configuration (if using)

---

#### SSO Testing Checklist

Use this checklist to verify SSO implementation:

```markdown
## SSO Implementation Test

Service: _______________________
Date: _______________________
Tester: _______________________

### Keycloak Configuration
- [ ] Client created with correct ID
- [ ] Client type: OpenID Connect
- [ ] Client authentication: ON (confidential)
- [ ] Valid redirect URIs configured
- [ ] Client secret generated and stored in vault
- [ ] Username mapper configured
- [ ] Email verified mapper configured
- [ ] Client enabled and not in locked state

### Service Configuration
- [ ] OIDC discovery URL or manual endpoints configured
- [ ] Client ID matches Keycloak
- [ ] Client secret reference from vault
- [ ] Redirect URI matches Keycloak config
- [ ] Scopes include: openid, profile, email
- [ ] Auto-provisioning enabled (if supported)

### Authentication Flow
- [ ] Service shows SSO login button
- [ ] Clicking button redirects to Keycloak
- [ ] Keycloak redirects to GitLab.com (if no session)
- [ ] Can authenticate with GitLab.com credentials
- [ ] Redirects back to service after auth
- [ ] User logged into service
- [ ] No error messages in flow

### User Provisioning
- [ ] User created automatically on first login
- [ ] Username populated correctly
- [ ] Email populated correctly
- [ ] Display name populated (if applicable)
- [ ] User can access service features

### Session Management
- [ ] Session persists across browser refreshes
- [ ] Logout works (if service has logout)
- [ ] Re-login works after logout
- [ ] Session timeout works (if configured)

### Security Validation
- [ ] Client secret not exposed in logs
- [ ] HTTPS used for all OAuth redirects
- [ ] No tokens visible in URLs
- [ ] Cookies have Secure flag
- [ ] Cannot access service without authentication

### Cross-Service SSO (if multiple services configured)
- [ ] Login to service A
- [ ] Access service B
- [ ] Service B auto-logs in (SSO working)
- [ ] No re-authentication needed

### Documentation
- [ ] SSO configuration documented
- [ ] Admin user grant procedure documented
- [ ] Troubleshooting notes added
- [ ] Client secret location documented

### Approval
- [ ] All tests passed
- [ ] Service approved for production
- [ ] SSO requirement satisfied

Signature: _________________ Date: _________
```

---

## Section C: Verification Checklist

Use this comprehensive checklist to verify all 3 requirements are met:

### Pre-Deployment Verification

**Run before declaring service production-ready.**

#### 1. DNS Verification

```bash
# Check DNS resolves correctly
dig +short servicename.viljo.se @1.1.1.1
# Expected: Your public IP (e.g., 85.24.XXX.XXX)

# Check DNS from multiple resolvers
dig +short servicename.viljo.se @8.8.8.8
dig +short servicename.viljo.se @1.0.0.1

# Check DNS propagation globally (optional)
# https://dnschecker.org - enter servicename.viljo.se
```

**Success Criteria:**
- DNS resolves to correct IP address
- Resolution works from multiple DNS servers
- No NXDOMAIN errors

**If Failed:**
- Verify entry in `inventory/group_vars/all/main.yml`
- Re-run `playbooks/loopia-dns-deploy.yml`
- Wait 5-10 minutes for propagation
- Check Loopia control panel for record

---

#### 2. HTTPS Certificate Verification

```bash
# Test HTTPS access
curl -I https://servicename.viljo.se
# Expected: HTTP/2 200 (or HTTP/1.1 200)

# Check certificate details
echo | openssl s_client -connect servicename.viljo.se:443 -servername servicename.viljo.se 2>/dev/null | openssl x509 -noout -text | grep -E "(Issuer|Subject|Not Before|Not After)"

# Expected:
# Issuer: C=US, O=Let's Encrypt, CN=R3 (or similar)
# Subject: CN=servicename.viljo.se
# Not Before: <recent date>
# Not After: <~90 days from issue date>

# Verify certificate with SSL Labs (production only)
# https://www.ssllabs.com/ssltest/analyze.html?d=servicename.viljo.se
```

**Success Criteria:**
- HTTPS connection succeeds
- Certificate issued by Let's Encrypt
- Certificate valid (not expired)
- No browser security warnings
- Certificate covers correct domain

**If Failed:**
- Check Traefik logs: `pct exec 167 -- docker logs traefik`
- Verify DNS is resolving correctly (requirement #1)
- Check Traefik service configuration in main.yml
- Verify Let's Encrypt rate limits not exceeded
- Check Loopia API credentials for DNS challenge

---

#### 3. SSO Integration Verification

```bash
# Method 1: Manual browser test
# Open https://servicename.viljo.se in incognito mode
# Should show SSO login option
# Complete login flow and verify success

# Method 2: Check Keycloak client exists
curl -s "https://keycloak.viljo.se/realms/master/.well-known/openid-configuration" | jq .

# Method 3: Check service configuration (service-specific)
# Nextcloud example:
pct exec 155 -- docker exec -u www-data nextcloud php occ config:app:get user_oidc providers

# Method 4: Check oauth2-proxy configuration (if using Approach B)
pct exec OAUTH2_CONTAINER -- cat /etc/oauth2-proxy/oauth2-proxy.cfg | grep servicename
```

**Success Criteria:**
- SSO login button appears on service
- Login flow redirects to Keycloak
- Keycloak redirects to GitLab.com
- Authentication completes successfully
- User auto-provisioned in service
- Username and email populated correctly

**If Failed:**
- Verify Keycloak client created and enabled
- Check client secret in vault matches Keycloak
- Verify redirect URIs match exactly
- Check client mappers configured correctly
- Review service logs for OIDC errors
- Test discovery endpoint accessibility

---

### Complete Verification Script

Save as `scripts/verify-service-requirements.sh`:

```bash
#!/bin/bash
# Comprehensive service requirements verification
# Usage: ./scripts/verify-service-requirements.sh servicename

set -e

SERVICE_NAME="$1"
PUBLIC_DOMAIN="viljo.se"
FQDN="${SERVICE_NAME}.${PUBLIC_DOMAIN}"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <servicename>"
    exit 1
fi

echo "========================================"
echo "Service Requirements Verification"
echo "========================================"
echo "Service: $SERVICE_NAME"
echo "FQDN: $FQDN"
echo "Date: $(date)"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Requirement 1: DNS Entry
echo "========================================"
echo "Requirement 1: DNS Entry"
echo "========================================"

DNS_IP=$(dig +short "$FQDN" @1.1.1.1 | head -1)
if [ -n "$DNS_IP" ]; then
    echo -e "${GREEN}✓ DNS resolves${NC}"
    echo "  IP Address: $DNS_IP"

    # Check if IP is public
    if echo "$DNS_IP" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)'; then
        echo -e "${YELLOW}⚠ Warning: IP appears to be private${NC}"
    fi
else
    echo -e "${RED}✗ DNS does not resolve${NC}"
    echo "  Action: Add DNS entry to inventory/group_vars/all/main.yml"
    exit 1
fi

# Requirement 2: HTTPS Certificate
echo ""
echo "========================================"
echo "Requirement 2: HTTPS Certificate"
echo "========================================"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$FQDN" --max-time 10 || echo "000")
if [ "$HTTP_STATUS" == "000" ]; then
    echo -e "${RED}✗ HTTPS connection failed${NC}"
    echo "  Action: Check Traefik configuration and certificate"
    exit 1
elif [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 400 ]; then
    echo -e "${GREEN}✓ HTTPS accessible${NC}"
    echo "  HTTP Status: $HTTP_STATUS"
else
    echo -e "${YELLOW}⚠ HTTPS connection returned non-success status${NC}"
    echo "  HTTP Status: $HTTP_STATUS"
fi

# Check certificate
CERT_INFO=$(echo | openssl s_client -connect "$FQDN:443" -servername "$FQDN" 2>/dev/null | openssl x509 -noout -issuer -subject -dates 2>/dev/null || echo "")

if echo "$CERT_INFO" | grep -q "Let's Encrypt"; then
    echo -e "${GREEN}✓ Valid Let's Encrypt certificate${NC}"

    # Extract and display expiry
    NOT_AFTER=$(echo "$CERT_INFO" | grep "notAfter" | cut -d= -f2)
    echo "  Expires: $NOT_AFTER"

    # Check if expiring soon (< 30 days)
    EXPIRY_EPOCH=$(date -d "$NOT_AFTER" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$NOT_AFTER" +%s 2>/dev/null)
    NOW_EPOCH=$(date +%s)
    DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

    if [ "$DAYS_UNTIL_EXPIRY" -lt 30 ]; then
        echo -e "${YELLOW}⚠ Certificate expires in $DAYS_UNTIL_EXPIRY days${NC}"
    fi
else
    echo -e "${RED}✗ Certificate not from Let's Encrypt or invalid${NC}"
    echo "  Action: Check Traefik logs for certificate issuance errors"
    exit 1
fi

# Requirement 3: SSO Integration
echo ""
echo "========================================"
echo "Requirement 3: SSO Integration"
echo "========================================"

# Check if Keycloak client exists by attempting to fetch discovery
DISCOVERY_URL="https://keycloak.${PUBLIC_DOMAIN}/realms/master/.well-known/openid-configuration"
DISCOVERY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DISCOVERY_URL")

if [ "$DISCOVERY_STATUS" == "200" ]; then
    echo -e "${GREEN}✓ Keycloak discovery endpoint accessible${NC}"
else
    echo -e "${RED}✗ Keycloak discovery endpoint not accessible${NC}"
    echo "  Status: $DISCOVERY_STATUS"
    echo "  Action: Verify Keycloak is running"
    exit 1
fi

# Check for SSO login (HTML page check)
echo "  Checking for SSO integration..."
PAGE_CONTENT=$(curl -s "https://$FQDN" --max-time 10 || echo "")

if echo "$PAGE_CONTENT" | grep -qi "sso\|sign in with\|oauth\|keycloak\|gitlab"; then
    echo -e "${GREEN}✓ SSO integration appears to be present${NC}"
    echo "  (Found SSO/OAuth references in HTML)"
elif echo "$PAGE_CONTENT" | grep -qi "login\|sign in"; then
    echo -e "${YELLOW}⚠ Login page found but SSO unclear${NC}"
    echo "  Action: Manually verify SSO login flow"
else
    echo -e "${YELLOW}⚠ Cannot automatically verify SSO integration${NC}"
    echo "  Action: Manually test SSO login flow"
fi

# Check inventory configuration
echo ""
echo "========================================"
echo "Configuration Checks"
echo "========================================"

INVENTORY_FILE="inventory/group_vars/all/main.yml"
if [ -f "$INVENTORY_FILE" ]; then
    # Check DNS entry
    if grep -q "host: $SERVICE_NAME" "$INVENTORY_FILE"; then
        echo -e "${GREEN}✓ DNS entry found in inventory${NC}"
    else
        echo -e "${YELLOW}⚠ DNS entry not found in inventory${NC}"
        echo "  Action: Add to loopia_dns_records in $INVENTORY_FILE"
    fi

    # Check Traefik service entry
    if grep -q "name: $SERVICE_NAME" "$INVENTORY_FILE"; then
        echo -e "${GREEN}✓ Traefik service entry found in inventory${NC}"
    else
        echo -e "${YELLOW}⚠ Traefik service entry not found in inventory${NC}"
        echo "  Action: Add to traefik_services in $INVENTORY_FILE"
    fi
else
    echo -e "${RED}✗ Inventory file not found${NC}"
    echo "  Expected: $INVENTORY_FILE"
fi

# Final summary
echo ""
echo "========================================"
echo "Summary"
echo "========================================"

echo ""
echo "Core Requirements:"
echo "  [1] DNS Entry:          $([  -n \"$DNS_IP\" ] && echo -e \"${GREEN}PASS${NC}\" || echo -e \"${RED}FAIL${NC}\")"
echo "  [2] HTTPS Certificate:  $(echo \"$CERT_INFO\" | grep -q \"Let's Encrypt\" && echo -e \"${GREEN}PASS${NC}\" || echo -e \"${RED}FAIL${NC}\")"
echo "  [3] SSO Integration:    ${YELLOW}MANUAL VERIFICATION REQUIRED${NC}"

echo ""
echo "Next Steps:"
echo "  1. Manually test SSO login flow at https://$FQDN"
echo "  2. Verify user auto-provisioning works"
echo "  3. Test logout and re-login"
echo "  4. Update service documentation"
echo ""

if [ -n "$DNS_IP" ] && echo "$CERT_INFO" | grep -q "Let's Encrypt"; then
    echo -e "${GREEN}Automated checks: PASSED${NC}"
    echo "Complete manual SSO testing before production deployment."
    exit 0
else
    echo -e "${RED}Automated checks: FAILED${NC}"
    echo "Fix issues before proceeding."
    exit 1
fi
```

**Make script executable:**
```bash
chmod +x scripts/verify-service-requirements.sh
```

**Usage:**
```bash
# Verify all requirements for a service
./scripts/verify-service-requirements.sh servicename

# Example output:
# ========================================
# Service Requirements Verification
# ========================================
# Service: jellyfin
# FQDN: jellyfin.viljo.se
# Date: Mon Oct 28 10:30:00 UTC 2025
#
# ========================================
# Requirement 1: DNS Entry
# ========================================
# ✓ DNS resolves
#   IP Address: 85.24.XXX.XXX
#
# ========================================
# Requirement 2: HTTPS Certificate
# ========================================
# ✓ HTTPS accessible
#   HTTP Status: 200
# ✓ Valid Let's Encrypt certificate
#   Expires: Jan 26 09:15:43 2026 GMT
#
# ========================================
# Requirement 3: SSO Integration
# ========================================
# ✓ Keycloak discovery endpoint accessible
# ✓ SSO integration appears to be present
#   (Found SSO/OAuth references in HTML)
#
# ========================================
# Summary
# ========================================
# Core Requirements:
#   [1] DNS Entry:          PASS
#   [2] HTTPS Certificate:  PASS
#   [3] SSO Integration:    MANUAL VERIFICATION REQUIRED
#
# Automated checks: PASSED
# Complete manual SSO testing before production deployment.
```

---

## Section D: Templates and Examples

### Template 1: Keycloak Client Creation (JSON Export)

For automation or backup, use this JSON template:

```json
{
  "clientId": "servicename",
  "name": "ServiceName OIDC Client",
  "description": "OIDC client for ServiceName SSO integration",
  "enabled": true,
  "protocol": "openid-connect",
  "publicClient": false,
  "bearerOnly": false,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": false,
  "authorizationServicesEnabled": false,
  "redirectUris": [
    "https://servicename.viljo.se/*"
  ],
  "webOrigins": [
    "https://servicename.viljo.se"
  ],
  "attributes": {
    "pkce.code.challenge.method": "S256"
  },
  "protocolMappers": [
    {
      "name": "username",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "username",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "preferred_username",
        "jsonType.label": "String"
      }
    },
    {
      "name": "email verified",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-usermodel-property-mapper",
      "consentRequired": false,
      "config": {
        "userinfo.token.claim": "true",
        "user.attribute": "emailVerified",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "email_verified",
        "jsonType.label": "boolean"
      }
    }
  ]
}
```

**How to Use:**
1. Copy template to `keycloak-client-servicename.json`
2. Replace `servicename` with actual service name
3. Update redirect URIs to match service requirements
4. Import via Keycloak admin UI or API

### Template 2: Inventory DNS Entry

```yaml
# Add to inventory/group_vars/all/main.yml

loopia_dns_records:
  # ... existing entries ...

  # ServiceName - Brief description
  - host: servicename
    ttl: 600  # 10 minutes (standard for all services)
```

### Template 3: Inventory Traefik Service

```yaml
# Add to inventory/group_vars/all/main.yml

traefik_services:
  # ... existing entries ...

  # ServiceName
  - name: servicename
    host: "servicename.{{ public_domain }}"
    container_id: "{{ servicename_container_id }}"
    port: 8080  # Internal service port
    # Optional: uncomment if needed
    # scheme: https
    # insecure_skip_verify: true
    # middlewares:
    #   - "oauth2-proxy@file"
```

### Template 4: Service README SSO Section

Add this section to service role README:

```markdown
## Authentication & SSO

This service uses Single Sign-On (SSO) via Keycloak with GitLab.com OAuth backend.

### Configuration

**Keycloak Client:**
- Client ID: `servicename`
- Client Type: Confidential (OpenID Connect)
- Realm: master
- Discovery Endpoint: `https://keycloak.viljo.se/realms/master/.well-known/openid-configuration`

**Client Secret:**
- Stored in: `inventory/group_vars/all/secrets.yml`
- Variable: `vault_servicename_oidc_client_secret`

### User Login

1. Navigate to: `https://servicename.viljo.se`
2. Click: "Sign in with GitLab SSO" (or similar)
3. Authenticate with GitLab.com credentials
4. First login creates user automatically (auto-provisioning)

### Admin User Setup

After first login, grant admin access:

```bash
# Replace with service-specific command
pct exec CONTAINER_ID -- docker exec SERVICE <grant-admin-command> USERNAME
```

### Troubleshooting

**"Invalid redirect URI" error:**
- Verify Keycloak client redirect URIs match service callback URL
- Check service logs for exact URI being used

**User authenticated but access denied:**
- Grant user appropriate permissions/roles
- Check service logs for authorization errors

**Cannot login:**
- Verify Keycloak is accessible: https://keycloak.viljo.se
- Check service can resolve keycloak.viljo.se
- Verify client secret matches in vault and Keycloak
```

### Template 5: Vault Secrets Entry

```yaml
# Add to inventory/group_vars/all/secrets.yml (ansible-vault encrypted)

# ServiceName OIDC Integration
vault_servicename_oidc_client_secret: "paste-secret-from-keycloak-here"

# Optional: if using oauth2-proxy
vault_servicename_proxy_oidc_client_secret: "paste-proxy-secret-here"

# Service admin credentials (if needed)
vault_servicename_admin_password: "generate-strong-password"
```

**Encrypt/edit vault:**
```bash
ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt
```

### Complete Working Example: Nextcloud

**Real implementation demonstrating all 3 requirements.**

#### 1. DNS Entry (main.yml)

```yaml
loopia_dns_records:
  - host: nextcloud
    ttl: 600
```

**Deployed with:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/loopia-dns-deploy.yml --ask-vault-pass
```

**Verification:**
```bash
$ dig +short nextcloud.viljo.se @1.1.1.1
85.24.XXX.XXX
```

#### 2. HTTPS Certificate (main.yml)

```yaml
traefik_services:
  - name: nextcloud
    host: "nextcloud.{{ public_domain }}"
    container_id: "{{ nextcloud_container_id }}"
    port: 80
```

**Deployed with:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/traefik-deploy.yml --ask-vault-pass
```

**Verification:**
```bash
$ curl -I https://nextcloud.viljo.se
HTTP/2 200
server: nginx/1.24.0
...

$ echo | openssl s_client -connect nextcloud.viljo.se:443 2>/dev/null | openssl x509 -noout -issuer
issuer=C = US, O = Let's Encrypt, CN = R3
```

#### 3. SSO Integration

**Keycloak Client Configuration:**

Created via Keycloak admin UI:
- Client ID: `nextcloud`
- Name: "Nextcloud File Storage OIDC Client"
- Client authentication: ON
- Valid redirect URIs:
  - `https://nextcloud.viljo.se/apps/user_oidc/code`
  - `https://nextcloud.viljo.se/index.php/apps/user_oidc/code`

**Client Mappers:**
1. Username mapper (preferred_username → username)
2. Email verified mapper (email_verified → emailVerified)

**Client Secret:** Stored in vault as `vault_nextcloud_oidc_client_secret`

**Nextcloud Configuration** (via role: roles/nextcloud_sso):

```yaml
# tasks/configure_nextcloud_oidc.yml
- name: Install user_oidc app
  ansible.builtin.shell:
    cmd: docker exec -u www-data nextcloud php occ app:install user_oidc
  delegate_to: nextcloud_container

- name: Enable user_oidc app
  ansible.builtin.shell:
    cmd: docker exec -u www-data nextcloud php occ app:enable user_oidc
  delegate_to: nextcloud_container

- name: Configure OIDC provider
  ansible.builtin.shell:
    cmd: |
      docker exec -u www-data nextcloud php occ config:app:set user_oidc providers --value '{
        "1": {
          "identifier": "keycloak",
          "name": "Sign in with GitLab SSO",
          "clientId": "nextcloud",
          "clientSecret": "{{ vault_nextcloud_oidc_client_secret }}",
          "discoveryEndpoint": "https://keycloak.viljo.se/realms/master/.well-known/openid-configuration",
          "scope": "openid profile email",
          "autoProvision": true,
          "autoUpdate": true
        }
      }'
  delegate_to: nextcloud_container
  no_log: true  # Don't log client secret
```

**Deployed with:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/nextcloud-sso-deploy.yml --ask-vault-pass
```

**Verification:**

1. **Configuration Check:**
```bash
$ pct exec 155 -- docker exec -u www-data nextcloud php occ config:app:get user_oidc providers | jq .
{
  "1": {
    "identifier": "keycloak",
    "name": "Sign in with GitLab SSO",
    ...
  }
}
```

2. **Login Flow Test:**
- Navigate to: https://nextcloud.viljo.se
- See "Sign in with GitLab SSO" button
- Click button → Redirects to keycloak.viljo.se
- Keycloak → Redirects to gitlab.com
- Authenticate with GitLab
- Returns to Nextcloud, logged in

3. **Auto-Provisioning Test:**
```bash
$ pct exec 155 -- docker exec -u www-data nextcloud php occ user:list
  - anders: Anders Viljo (anders@viljo.se)
```

4. **Admin Grant:**
```bash
$ pct exec 155 -- docker exec -u www-data nextcloud php occ group:adduser admin anders
User "anders" added to group "admin"
```

**Result:** Nextcloud meets all 3 requirements:
- ✅ DNS: nextcloud.viljo.se resolves
- ✅ HTTPS: Valid Let's Encrypt certificate
- ✅ SSO: Keycloak OIDC with auto-provisioning

**Documentation:** See `/docs/NEXTCLOUD_SSO_IMPLEMENTATION.md` for full details.

---

## Section E: Integration with Existing Workflows

### Adding Requirements to Test-Driven Service Workflow

The existing workflow (NEW_SERVICE_WORKFLOW.md) has 9 steps. The 3 mandatory requirements fit into these steps:

**Step 1: Implement Service**
- Add DNS entry to inventory
- Add Traefik service to inventory
- Deploy DNS and Traefik configurations
- Service becomes accessible via HTTPS

**Step 2: Test with External Tools**
- Verify DNS resolves
- Verify HTTPS certificate valid
- Test external access

**Between Step 3 and 4: SSO Integration** (NEW STEP)
- Create Keycloak client
- Configure service for OIDC
- Test SSO login flow
- Verify user auto-provisioning

**Step 4-9: Continue as normal**
- Backup, restore, verification

### Updated Step Sequence

```
1. Implement Service (includes DNS + HTTPS)
2. Test with External Tools (verify DNS + HTTPS)
3. Delete and Recreate (verify automation)
3.5. SSO Integration (NEW - mandatory before backup planning)
4. Implement Data Backup Plan
5. Populate with Test Data
6. Test Backup Script
7. Execute Backup
8. Wipe Service
9. Restore and Verify

FINAL: All 3 requirements verified, service production-ready
```

### Pre-Deployment Gate

**Before Step 1 starts:**
```yaml
pre_deployment_checklist:
  - [ ] Service name chosen (for DNS)
  - [ ] Subdomain available (not already used)
  - [ ] Service supports OIDC or can use oauth2-proxy
  - [ ] Container ID allocated
  - [ ] Port mapping planned
```

**Before marking service "production ready" (after Step 9):**
```yaml
production_readiness_checklist:
  - [ ] DNS entry provisioned and resolves
  - [ ] HTTPS certificate valid
  - [ ] SSO login flow tested and working
  - [ ] User auto-provisioning tested
  - [ ] Admin user access granted
  - [ ] All 9 workflow steps completed
  - [ ] Verification script passes: ./scripts/verify-service-requirements.sh servicename
  - [ ] Service added to links portal
  - [ ] Documentation updated
```

**Gate:** Service cannot be deployed to production without passing verification script and manual SSO test.

---

## Section F: Automation Integration

### CI/CD Pipeline Integration

If using GitLab CI or similar, add validation stage:

```yaml
# .gitlab-ci.yml (example)

stages:
  - validate
  - deploy
  - test

validate-service-requirements:
  stage: validate
  script:
    - ./scripts/verify-service-requirements.sh $SERVICE_NAME
  only:
    - merge_requests
  variables:
    SERVICE_NAME: "servicename"  # Override per service

deploy-service:
  stage: deploy
  script:
    - ansible-playbook -i inventory/hosts.yml playbooks/${SERVICE_NAME}-deploy.yml
  dependencies:
    - validate-service-requirements
  only:
    - main

test-sso:
  stage: test
  script:
    - curl -I https://${SERVICE_NAME}.viljo.se
    - ./scripts/test-sso-login.sh ${SERVICE_NAME}
  dependencies:
    - deploy-service
```

### Ansible Pre-Flight Checks

Add to service deployment playbooks:

```yaml
# playbooks/servicename-deploy.yml

- name: Pre-deployment validation
  hosts: localhost
  tasks:
    - name: Check DNS entry exists in inventory
      ansible.builtin.assert:
        that:
          - loopia_dns_records | selectattr('host', 'equalto', 'servicename') | list | length > 0
        fail_msg: "DNS entry for servicename not found in inventory. Add to main.yml first."
        success_msg: "DNS entry found in inventory"

    - name: Check Traefik service entry exists in inventory
      ansible.builtin.assert:
        that:
          - traefik_services | selectattr('name', 'equalto', 'servicename') | list | length > 0
        fail_msg: "Traefik service entry for servicename not found. Add to main.yml first."
        success_msg: "Traefik service entry found in inventory"

    - name: Check client secret exists in vault
      ansible.builtin.assert:
        that:
          - vault_servicename_oidc_client_secret is defined
          - vault_servicename_oidc_client_secret | length > 0
        fail_msg: "OIDC client secret not found in vault. Add vault_servicename_oidc_client_secret first."
        success_msg: "Client secret found in vault"

- name: Deploy service
  hosts: proxmox_admin
  roles:
    - servicename_api
```

### Post-Deployment Verification

Add to service roles:

```yaml
# roles/servicename/tasks/main.yml

# ... service deployment tasks ...

- name: Wait for service to be ready
  ansible.builtin.uri:
    url: "http://{{ servicename_ip }}:{{ servicename_port }}/health"
    status_code: 200
  retries: 30
  delay: 10
  register: health_check

- name: Verify DNS resolves correctly
  ansible.builtin.command:
    cmd: "dig +short {{ servicename_subdomain }}.{{ public_domain }} @1.1.1.1"
  register: dns_check
  changed_when: false
  failed_when: dns_check.stdout | trim | length == 0

- name: Verify HTTPS certificate exists
  ansible.builtin.uri:
    url: "https://{{ servicename_subdomain }}.{{ public_domain }}"
    method: HEAD
    validate_certs: yes
  register: https_check
  retries: 10
  delay: 30  # Certificate issuance can take time

- name: Display deployment summary
  ansible.builtin.debug:
    msg:
      - "Service deployed successfully:"
      - "  URL: https://{{ servicename_subdomain }}.{{ public_domain }}"
      - "  DNS: {{ dns_check.stdout | trim }}"
      - "  HTTPS: {{ 'Valid' if https_check.status == 200 else 'Invalid' }}"
      - "  Next: Configure SSO integration (see docs/SERVICE_IMPLEMENTATION_PIPELINE.md)"
```

---

## Section G: Documentation Standards

Every service must document how it meets the 3 requirements.

### Service README Template

```markdown
# ServiceName

## Overview
Brief description of service and its purpose.

## Deployment

**Ansible Role**: `roles/servicename/`
**Playbook**: `playbooks/servicename-deploy.yml`
**Container ID**: {{ servicename_container_id }}

## Access

**URL**: https://servicename.viljo.se
**Authentication**: GitLab SSO via Keycloak

## Mandatory Requirements Compliance

### ✅ 1. DNS Entry

**Subdomain**: servicename
**FQDN**: servicename.viljo.se
**Configuration**: `inventory/group_vars/all/main.yml`

```yaml
loopia_dns_records:
  - host: servicename
```

**Verification**:
```bash
dig +short servicename.viljo.se @1.1.1.1
```

### ✅ 2. HTTPS Certificate

**Provider**: Let's Encrypt (via Traefik)
**Configuration**: `inventory/group_vars/all/main.yml`

```yaml
traefik_services:
  - name: servicename
    host: "servicename.{{ public_domain }}"
    container_id: "{{ servicename_container_id }}"
    port: 8080
```

**Verification**:
```bash
curl -I https://servicename.viljo.se
```

### ✅ 3. SSO Integration

**Method**: [Native OIDC / oauth2-proxy Forward Auth]

**Keycloak Client**:
- Client ID: `servicename`
- Realm: master
- Discovery: `https://keycloak.viljo.se/realms/master/.well-known/openid-configuration`

**Configuration**: [Location of OIDC config files/commands]

**Verification**:
- Navigate to https://servicename.viljo.se
- Click "Sign in with GitLab SSO"
- Authenticate with GitLab.com
- User auto-provisioned on first login

## Admin Access

After first SSO login, grant admin privileges:

```bash
pct exec CONTAINER_ID -- docker exec servicename <command>
```

## Variables

See `roles/servicename/defaults/main.yml` for all configurable options.

**Key Variables**:
- `servicename_container_id`: LXC container ID
- `servicename_port`: Internal service port

**Vault Variables**:
- `vault_servicename_oidc_client_secret`: Keycloak client secret

## Troubleshooting

### Cannot access via HTTPS
- Verify DNS: `dig +short servicename.viljo.se`
- Check certificate: `curl -I https://servicename.viljo.se`
- Review Traefik logs: `pct exec 167 -- docker logs traefik`

### SSO login fails
- Verify Keycloak accessible: https://keycloak.viljo.se
- Check client secret in vault matches Keycloak
- Review service logs for OIDC errors

## References

- Documentation: [link to detailed docs]
- Specification: [link to spec if exists]
- Implementation Pipeline: docs/SERVICE_IMPLEMENTATION_PIPELINE.md
```

---

## Section H: Maintenance and Updates

### Rotating Client Secrets

**When to Rotate:**
- Annually (security best practice)
- After security incident
- When employee leaves with access
- If secret accidentally exposed

**Procedure:**

1. **Generate New Secret in Keycloak**:
   - Login to Keycloak admin
   - Clients → servicename → Credentials tab
   - Click "Regenerate Secret"
   - Copy new secret

2. **Update Vault**:
   ```bash
   ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt
   # Update vault_servicename_oidc_client_secret with new value
   ```

3. **Redeploy Service Configuration**:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/servicename-deploy.yml --ask-vault-pass --tags config
   ```

4. **Test Login Flow**:
   - Clear browser session
   - Login via SSO
   - Verify successful authentication

5. **Revoke Old Secret** (optional):
   - Keycloak doesn't store old secrets
   - Old secret automatically invalid after regeneration

### Certificate Renewal

**Automatic Renewal:**
- Let's Encrypt certificates valid for 90 days
- Traefik auto-renews at 60 days
- No manual intervention required

**Monitoring Renewal:**
```bash
# Check certificate expiry
echo | openssl s_client -connect servicename.viljo.se:443 -servername servicename.viljo.se 2>/dev/null | openssl x509 -noout -dates

# Check Traefik renewal logs
pct exec 167 -- docker logs traefik 2>&1 | grep -i "renew"
```

**Manual Renewal** (if automatic fails):
```bash
# Restart Traefik to trigger renewal check
pct exec 167 -- docker restart traefik

# Monitor logs for renewal
pct exec 167 -- docker logs -f traefik
```

**Troubleshooting Renewal Failures:**
- Verify DNS still resolves correctly
- Check Loopia API credentials valid
- Ensure no rate limits hit (5 renewals per week per domain)
- Review Traefik logs for specific errors

### DNS Changes

**Changing Subdomain:**

1. Update inventory:
   ```yaml
   loopia_dns_records:
     - host: new-servicename  # Changed from old-servicename
   ```

2. Update Traefik:
   ```yaml
   traefik_services:
     - name: servicename
       host: "new-servicename.{{ public_domain }}"  # Changed
   ```

3. Update Keycloak client redirect URIs
4. Update service configuration
5. Deploy changes
6. Delete old DNS record (manual in Loopia if needed)

**Adding New Services:**
- Follow Section B implementation steps
- Always add DNS before deploying service
- DNS first, then Traefik, then SSO

### Keycloak Upgrades

**Backup Before Upgrade:**
```bash
# Backup Keycloak database
pg_dump -h 172.16.10.150 -U postgres keycloak > keycloak-backup.sql
```

**Test Client Compatibility:**
- After upgrade, test login flow for each service
- Verify client configurations intact
- Check mappers still work
- Validate discovery endpoint

**Rollback Procedure:**
- Restore previous Keycloak container
- Restore database backup
- Verify all services can authenticate

---

## Section I: Training and Onboarding

### New Engineer Checklist

When onboarding new infrastructure engineers, ensure they understand:

- [ ] Read this document (SERVICE_IMPLEMENTATION_PIPELINE.md)
- [ ] Understand why SSO/DNS/HTTPS are mandatory
- [ ] Know how to add DNS entries
- [ ] Know how to configure Traefik services
- [ ] Know how to create Keycloak clients
- [ ] Can execute verification script
- [ ] Have completed hands-on service deployment
- [ ] Know how to troubleshoot common issues

### Hands-On Exercise

**Exercise**: Deploy a test service meeting all 3 requirements.

**Service**: nginx-test (simple web server)

**Tasks**:
1. Add DNS entry for `nginx-test`
2. Deploy nginx container
3. Add Traefik configuration
4. Create Keycloak client
5. Configure oauth2-proxy for nginx-test
6. Test complete SSO flow
7. Run verification script
8. Document results

**Expected Duration**: 45-60 minutes

**Success Criteria**:
- Service accessible via https://nginx-test.viljo.se
- Valid HTTPS certificate
- SSO login works
- Verification script passes
- Clean up test service after completion

---

## Section J: Audit and Compliance

### Regular Audits

**Monthly:**
- Review list of services
- Verify all have SSO enabled
- Check certificate expiry dates
- Validate DNS entries resolve

**Quarterly:**
- Rotate Keycloak client secrets
- Review Keycloak access logs
- Audit user provisioning
- Test disaster recovery

**Annually:**
- Full security audit
- Review and update documentation
- Verify compliance with requirements
- Update procedures based on lessons learned

### Audit Procedure

```bash
#!/bin/bash
# scripts/audit-service-requirements.sh
# Audit all services for compliance

SERVICES=$(grep -E "^\s+- host: " inventory/group_vars/all/main.yml | awk '{print $3}' | grep -v "@")

echo "Service Requirements Audit"
echo "Date: $(date)"
echo "================================"
echo ""

for SERVICE in $SERVICES; do
    echo "Service: $SERVICE"

    # Check DNS
    DNS=$(dig +short "${SERVICE}.viljo.se" @1.1.1.1 | head -1)
    if [ -n "$DNS" ]; then
        echo "  DNS: ✓ ($DNS)"
    else
        echo "  DNS: ✗ (not resolving)"
    fi

    # Check HTTPS
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${SERVICE}.viljo.se" --max-time 5)
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
        echo "  HTTPS: ✓ ($HTTP_CODE)"
    else
        echo "  HTTPS: ✗ ($HTTP_CODE)"
    fi

    # SSO check (manual verification required)
    echo "  SSO: (manual check required)"

    echo ""
done

echo "================================"
echo "Audit Complete"
echo ""
echo "Next Steps:"
echo "  1. Manually verify SSO for each service"
echo "  2. Address any failed checks"
echo "  3. Update documentation"
```

### Compliance Report Template

```markdown
# Infrastructure Service Compliance Report

**Report Date**: YYYY-MM-DD
**Auditor**: Name
**Period Covered**: YYYY-MM-DD to YYYY-MM-DD

## Executive Summary

Total Services: X
Compliant: Y
Non-Compliant: Z
Compliance Rate: XX%

## Service Status

| Service | DNS | HTTPS | SSO | Status |
|---------|-----|-------|-----|--------|
| service1 | ✓ | ✓ | ✓ | Compliant |
| service2 | ✓ | ✓ | ✗ | Non-Compliant |
| ... | ... | ... | ... | ... |

## Non-Compliant Services

### Service Name

**Issue**: SSO not configured
**Risk**: Users using local passwords, security risk
**Remediation**: Configure OIDC client in Keycloak
**Timeline**: Within 7 days
**Owner**: Engineer Name

## Recommendations

1. Recommendation 1
2. Recommendation 2
3. Recommendation 3

## Sign-Off

**Auditor Signature**: __________________
**Date**: __________________

**Infrastructure Lead Approval**: __________________
**Date**: __________________
```

---

## Appendix A: Common Service OIDC Endpoints

Reference for configuring various services:

### Nextcloud
- **Method**: user_oidc app
- **Discovery**: Yes
- **Callback**: `https://nextcloud.viljo.se/apps/user_oidc/code`
- **Scopes**: `openid profile email`

### GitLab
- **Method**: OmniAuth openid_connect
- **Discovery**: Yes
- **Callback**: `https://gitlab.viljo.se/users/auth/openid_connect/callback`
- **Scopes**: `openid profile email`

### Jellyfin
- **Method**: SSO-Plugin
- **Discovery**: Yes (partial)
- **Callback**: `https://jellyfin.viljo.se/sso/OID/r/keycloak`
- **Scopes**: `openid profile email`

### Coolify
- **Method**: Built-in OAuth
- **Discovery**: Yes
- **Callback**: `https://coolify.viljo.se/auth/oauth/callback`
- **Scopes**: `openid profile email`

### Grafana
- **Method**: Built-in generic_oauth
- **Discovery**: Yes
- **Callback**: `https://grafana.viljo.se/login/generic_oauth`
- **Scopes**: `openid profile email`

### Wekan
- **Method**: Environment variables
- **Discovery**: No (manual endpoints)
- **Callback**: `https://wekan.viljo.se/_oauth/oidc`
- **Scopes**: `openid profile email`

### oauth2-proxy (Generic)
- **Method**: Forward authentication
- **Discovery**: Yes
- **Callback**: `https://servicename.viljo.se/oauth2/callback`
- **Scopes**: `openid profile email`

---

## Appendix B: Decision Tree

Use this decision tree when implementing SSO:

```
Does service have web UI?
├─ NO → SSO not required (internal service)
└─ YES → Continue

Does service support OIDC/OAuth natively?
├─ YES → Use Approach A (Native OIDC)
│   └─ Configure service for Keycloak OIDC
└─ NO → Continue

Does service support LDAP/SAML?
├─ YES → Consider Keycloak LDAP/SAML adapter (advanced)
└─ NO → Use Approach B (oauth2-proxy)
    └─ Configure oauth2-proxy forward auth

Can service run behind reverse proxy?
├─ YES → oauth2-proxy will work
└─ NO → Document exception, use API keys/mTLS
    └─ Add to technical debt register
```

---

## Appendix C: Frequently Asked Questions

**Q: Can I deploy a service without SSO for testing?**

A: Yes, during development. But SSO must be implemented before production deployment. Use test instances without DNS entries for experimentation.

---

**Q: What if a service already has users with local passwords?**

A: Migrate users:
1. Configure SSO alongside existing auth
2. Communicate migration plan to users
3. Encourage users to login via SSO
4. After 30 days, disable local auth
5. Optionally provide migration script

---

**Q: How do I handle API-only services?**

A: API authentication typically uses:
- API keys (with rotation policy)
- Service accounts in Keycloak
- mTLS certificates
- OAuth 2.0 client credentials flow

SSO requirement applies to web UIs, not APIs.

---

**Q: Can users still access services if Keycloak is down?**

A: No, SSO is a single point of failure. Mitigation:
- High availability Keycloak deployment (future)
- Backup authentication method (break-glass admin account)
- Keycloak monitoring and alerting
- Rapid Keycloak recovery procedures

---

**Q: How do I handle emergency access if SSO is broken?**

A: Most services support break-glass admin accounts:
- Nextcloud: Local admin account
- GitLab: Root account
- Jellyfin: Local admin user

Keep these credentials in secure location (vault) for emergencies only.

---

**Q: What about services on isolated networks?**

A: If service cannot reach Keycloak:
- Use oauth2-proxy on same network
- Configure network routing to allow OIDC traffic
- Document exception if truly isolated
- Consider if service needs SSO

---

**Q: Do internal infrastructure services need HTTPS?**

A: Depends:
- **Public-facing**: Yes, mandatory
- **Internal DMZ**: Yes, strongly recommended
- **Management network**: Can use HTTP internally, but HTTPS preferred
- **Database/cache**: No HTTP at all (different protocols)

When in doubt, use HTTPS.

---

**Q: Can I use a different identity provider than GitLab.com?**

A: Architecturally yes, but:
- Keycloak supports multiple IdPs
- Current standard is GitLab.com
- Changing requires updating Keycloak IdP configuration
- All services continue working (they only know Keycloak)

To add alternative IdP: Configure in Keycloak, users choose at login.

---

**Q: How long does SSO integration take per service?**

A: Typical timelines:
- **Native OIDC**: 15-30 minutes
- **oauth2-proxy**: 30-45 minutes
- **Custom integration**: 1-4 hours
- **Legacy system**: 4-8 hours (or exception)

First time takes longer; subsequent services faster with templates.

---

**Q: Can I automate Keycloak client creation?**

A: Yes, Keycloak has REST API:
```bash
# Get admin token
TOKEN=$(curl -X POST "https://keycloak.viljo.se/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=SECRET" \
  -d "grant_type=password" | jq -r .access_token)

# Create client
curl -X POST "https://keycloak.viljo.se/admin/realms/master/clients" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @keycloak-client.json
```

Consider Ansible module or role for automation.

---

## Appendix D: Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-27 | Infrastructure Team | Initial version |

---

## Appendix E: Related Documentation

- [NEW_SERVICE_WORKFLOW.md](NEW_SERVICE_WORKFLOW.md) - Test-driven service deployment workflow
- [SERVICE_CHECKLIST_TEMPLATE.md](SERVICE_CHECKLIST_TEMPLATE.md) - Service deployment checklist
- [NEXTCLOUD_SSO_IMPLEMENTATION.md](NEXTCLOUD_SSO_IMPLEMENTATION.md) - Nextcloud SSO example
- [AUTHENTICATION_FINAL_REPORT.md](AUTHENTICATION_FINAL_REPORT.md) - Authentication architecture
- [SSO_DNS_HTTPS_QUICKREF.md](SSO_DNS_HTTPS_QUICKREF.md) - Quick reference card

---

**Document Status**: AUTHORITATIVE

This document establishes the mandatory requirements for all service deployments. All services must comply with these requirements before production deployment.

**Questions or Exceptions**: Contact Infrastructure Team
