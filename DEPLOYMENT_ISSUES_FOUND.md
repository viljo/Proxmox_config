# Service Deployment Issues - Testing Results

## Date: 2025-10-27
## Testing Results from External Access

### Issues Found

#### 1. Jitsi Meet (meet.viljo.se) - NOT DEPLOYED
**Status**: Connection timeout
**Root Cause**: Service was never deployed (container doesn't exist)
**Container ID Expected**: 160
**Container ID Actual**: Does not exist

**Fix Required**:
```bash
# 1. Add vault secrets (7 secrets required)
ansible-vault edit inventory/group_vars/all/secrets.yml
# See: roles/jitsi/VAULT_SECRETS.md

# 2. Create Keycloak OIDC client
# - Client ID: jitsi
# - Redirect URI: https://meet.viljo.se/*

# 3. Configure firewall UDP port 10000 forwarding
ssh root@192.168.1.3
pct exec 101 -- nft add rule inet nat prerouting iifname eth0 udp dport 10000 dnat to 172.16.10.160:10000

# 4. Deploy Jitsi
ansible-playbook playbooks/site.yml --tags jitsi --ask-vault-pass
```

**Documentation**: `specs/001-jitsi-server/DEPLOYMENT.md`

---

#### 2. Coolify (coolify.viljo.se) - NOT DEPLOYED
**Status**: 404 error, no certificate
**Root Cause**: Service was never deployed (container doesn't exist)
**Container ID Expected**: 161
**Container ID Actual**: Does not exist

**Fix Required**:
```bash
# 1. Add vault secrets
ansible-vault edit inventory/group_vars/all/secrets.yml
# Add Coolify secrets (already generated in session):
vault_coolify_root_password: "RFJ+sSUWeJE01FkTqzcRFpvjf2sG1PzThOdgOV0ULLk="
vault_coolify_postgres_password: "rG1YhpfYh2WGOaYogmiga4P9yqIlUqL1YT363aHV0eY="
vault_coolify_redis_password: "XIhZd7AdB/DE9pVdLLrl031NLQEUHEc7dz1usUnenpM="
vault_coolify_app_id: "coolify"
vault_coolify_app_key: "base64:9UtZLDtEOYvI/5NTzWX/BG5n2H0d4ut+XbbjP4YaCe0="
vault_coolify_pusher_app_secret: "TiuQQxz+5w5kK+OxnE6pFtYgll8mYtMWGHQuxl899nE="

# 2. Deploy Coolify
ansible-playbook playbooks/coolify-deploy.yml --ask-vault-pass
```

**Documentation**: `docs/COOLIFY_QUICK_START.md`

---

#### 3. Jellyfin (jellyfin.viljo.se) - NOT DEPLOYED
**Status**: 404 error, no certificate
**Root Cause**: Deployment failed (incomplete)
**Container ID Expected**: 156
**Container ID Actual**: Does not exist

**Fix Required**:
```bash
# Media services playbook has bugs, needs fixing
# Temporary workaround - deploy individually:

# Option A: Fix the qBittorrent role bug first
# Edit roles/qbittorrent/tasks/main.yml line ~188
# Change from 'copy' module to 'pct push' command

# Option B: Deploy Jellyfin separately
ansible-playbook playbooks/jellyfin-deploy.yml
```

**Known Bug**: qBittorrent role uses wrong method to deploy systemd service file

**Documentation**: `docs/MEDIA_SERVICES_DEPLOYMENT.md`

---

#### 4. qBittorrent (qbittorrent.viljo.se) - PARTIAL DEPLOYMENT
**Status**: 404 error, no certificate
**Root Cause**: Deployment incomplete (systemd service not installed)
**Container ID**: 159 (exists and running)
**IP Address**: 172.16.10.59

**Current Status**:
- Container created ✅
- Storage configured ✅
- qBittorrent packages installed ✅
- Systemd service deployment FAILED ❌

**Fix Required**:
```bash
# Fix the role bug in roles/qbittorrent/tasks/main.yml
# Line ~188: Change from copy module to pct push

# Workaround - manual service installation:
ssh root@192.168.1.3
pct enter 159

# Install qBittorrent-nox manually
apt-get update && apt-get install -y qbittorrent-nox

# Create systemd service
cat > /etc/systemd/system/qbittorrent.service << 'EOF'
[Unit]
Description=qBittorrent Command Line Client
After=network.target

[Service]
Type=forking
User=qbittorrent
Group=qbittorrent
UMask=007
ExecStart=/usr/bin/qbittorrent-nox -d --webui-port=8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now qbittorrent
```

---

#### 5. Nextcloud (nextcloud.viljo.se) - SSO MISCONFIGURATION
**Status**: Accessible but SSO broken
**Error**: "You must access Nextcloud with HTTPS to use OpenID Connect"
**Root Cause**: Nextcloud doesn't think it's behind HTTPS

**Fix Required**:
```bash
# Update Nextcloud config to trust Traefik proxy
ssh root@192.168.1.3
pct exec 153 -- bash -c "cat >> /var/www/nextcloud/config/config.php << 'EOF'
  'overwriteprotocol' => 'https',
  'overwritehost' => 'nextcloud.viljo.se',
  'overwrite.cli.url' => 'https://nextcloud.viljo.se',
  'trusted_proxies' => ['172.16.10.1'],
EOF"

# Restart Nextcloud
pct exec 153 -- systemctl restart apache2
```

**Alternative**: Check if Traefik is sending X-Forwarded-Proto header correctly

---

#### 6. GitLab (gitlab.viljo.se) - SSO NOT CONFIGURED
**Status**: Accessible but no SSO login option
**Root Cause**: GitLab OIDC integration with Keycloak not configured

**Fix Required**:
```bash
# 1. Create Keycloak OIDC client
# - Navigate to https://keycloak.viljo.se
# - Create client: gitlab
# - Redirect URI: https://gitlab.viljo.se/users/auth/openid_connect/callback

# 2. Configure GitLab OIDC
ssh root@192.168.1.3
pct exec 153 -- bash

# Edit /etc/gitlab/gitlab.rb
gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
gitlab_rails['omniauth_block_auto_created_users'] = false
gitlab_rails['omniauth_providers'] = [
  {
    name: 'openid_connect',
    label: 'Keycloak SSO',
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
        secret: 'CLIENT_SECRET_FROM_KEYCLOAK',
        redirect_uri: 'https://gitlab.viljo.se/users/auth/openid_connect/callback'
      }
    }
  }
]

# Reconfigure GitLab
gitlab-ctl reconfigure
```

---

## Summary of Required Actions

### Immediate (Critical Issues)

1. **Fix Nextcloud HTTPS detection** (5 minutes)
   - Add overwriteprotocol config
   - Test SSO login

2. **Add Coolify vault secrets** (2 minutes)
   - Copy-paste generated secrets
   - Secrets already generated earlier in session

### Short-term (Deploy Services)

3. **Deploy Coolify** (10 minutes)
   - Run playbook after adding secrets
   - Register admin account immediately

4. **Fix qBittorrent role bug** (10 minutes)
   - Update role to use pct push
   - Redeploy or manual workaround

5. **Deploy Jellyfin** (10 minutes)
   - After qBittorrent fixed
   - Or deploy separately

### Medium-term (Complex Services)

6. **Deploy Jitsi Meet** (30 minutes)
   - Generate 7 vault secrets
   - Create Keycloak client
   - Configure firewall UDP port
   - Run playbook

7. **Configure GitLab SSO** (20 minutes)
   - Create Keycloak client
   - Update GitLab config
   - Test login flow

---

## Root Cause Analysis

**Why did this happen?**

1. **Services marked "ready to deploy" but not actually deployed**
   - We created all automation but didn't execute deployments
   - Documentation written assuming deployment would follow

2. **Testing happened on wrong endpoints**
   - Internal verification (172.16.10.x) worked
   - External testing (*.viljo.se) revealed deployment gaps

3. **Role bugs not caught in development**
   - qBittorrent role has systemd deployment bug
   - Would have been caught if full deployment tested

4. **SSO configuration gaps**
   - Nextcloud HTTPS detection issue
   - GitLab SSO never configured

---

## Lessons Learned

1. ✅ **Always deploy AND test** before marking "complete"
2. ✅ **External testing is essential** (not just internal)
3. ✅ **SSO requires service-specific configuration** (not automatic)
4. ✅ **Role testing should include full deployment** (not just syntax)

---

## Next Session Goals

1. Fix Nextcloud HTTPS issue (highest priority - breaks SSO)
2. Deploy Coolify (secrets already generated)
3. Fix and complete media services deployment
4. Configure GitLab SSO
5. Deploy Jitsi Meet (after prerequisites)

---

## Service Status Matrix

| Service | Container | Deployed | DNS | HTTPS | SSO | Status |
|---------|-----------|----------|-----|-------|-----|--------|
| **GitLab** | 153 | ✅ | ✅ | ✅ | ❌ | **Needs SSO config** |
| **Nextcloud** | ? | ✅ | ✅ | ✅ | ❌ | **HTTPS detection broken** |
| **Keycloak** | 151 | ✅ | ✅ | ✅ | N/A | **Working** |
| **Links** | 160 | ✅ | ✅ | ✅ | N/A | **Working** |
| **Webtop** | 170 | ✅ | ✅ | ✅ | ❌ | **Working (no SSO yet)** |
| **Jitsi** | - | ❌ | ✅ | ❌ | ❌ | **Not deployed** |
| **Coolify** | - | ❌ | ✅ | ❌ | ❌ | **Not deployed** |
| **Jellyfin** | - | ❌ | ✅ | ❌ | ❌ | **Not deployed** |
| **qBittorrent** | 159 | ⚠️ | ✅ | ❌ | N/A | **Partial (needs service fix)** |

Legend:
- ✅ Working
- ⚠️ Partial/Broken
- ❌ Not configured/deployed
- N/A Not applicable

---

**Generated**: 2025-10-27
**Session**: Infrastructure deployment testing
**Priority**: Fix Nextcloud HTTPS → Deploy Coolify → Fix media services
