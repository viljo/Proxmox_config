# OAuth2-Proxy SSO Automation

## Overview

This automation deploys GitLab.com SSO authentication for public services using oauth2-proxy in reverse proxy mode.

## Architecture

```
Browser → Traefik → oauth2-proxy-{service} → Backend Service
                          ↓
                    GitLab OAuth
```

Each protected service gets its own oauth2-proxy instance to avoid complex routing issues.

## Files

### Configuration
- `inventory/group_vars/all/oauth2_proxy.yml` - Service definitions and settings
- `inventory/group_vars/all/vault.yml` - Encrypted secrets (GitLab OAuth credentials)

### Playbooks
- `playbooks/oauth2-proxy-deploy.yml` - Main deployment playbook

### Roles
- `roles/oauth2_proxy/` - Reusable role for oauth2-proxy deployment
  - `tasks/main.yml` - Deployment tasks
  - `templates/docker-compose.yml.j2` - Docker Compose template

## Usage

### Deploy OAuth2-Proxy

```bash
ansible-playbook playbooks/oauth2-proxy-deploy.yml
```

### Add a New Protected Service

1. Edit `inventory/group_vars/all/oauth2_proxy.yml`:

```yaml
oauth2_proxy_services:
  # ... existing services ...

  - name: myservice
    subdomain: myservice
    upstream: "http://myservice:8080"
    description: "My Service description"
```

2. Add DNS record to `inventory/group_vars/all/main.yml`:

```yaml
loopia_dns_records:
  # ... existing records ...
  - host: myservice
    ttl: 600
```

3. Deploy DNS:

```bash
ansible-playbook playbooks/loopia-dns-deploy.yml
```

4. Deploy oauth2-proxy:

```bash
ansible-playbook playbooks/oauth2-proxy-deploy.yml
```

5. Disable direct Traefik access to backend service:

```bash
ssh root@192.168.1.3 'pct exec 200 -- bash -c "
  cd /opt/docker-stack/myservice
  sed -i \"s/traefik.enable=true/traefik.enable=false/\" docker-compose.yml
  docker compose up -d
"'
```

## Variables

### Required Secrets (in vault.yml)
- `vault_gitlab_oauth_client_id` - GitLab OAuth Application ID
- `vault_gitlab_oauth_client_secret` - GitLab OAuth Application Secret
- `vault_oauth2_proxy_cookie_secret` - Random 32-byte base64 string

### Service Configuration
Each service in `oauth2_proxy_services` requires:
- `name` - Internal identifier (used for container name)
- `subdomain` - DNS subdomain (e.g., "meet" for meet.viljo.se)
- `upstream` - Backend service URL (e.g., "http://jitsi:80")
- `description` - Human-readable description

### Global Settings
- `oauth2_proxy_container_id: 200` - Coolify LXC container ID
- `oauth2_proxy_cookie_domains: ".viljo.se"` - Shared cookie domain
- `oauth2_proxy_email_domains: "viljo.se"` - Restrict to @viljo.se emails
- `oauth2_proxy_redirect_url` - OAuth callback URL (https://auth.viljo.se/oauth2/callback)

## GitLab OAuth Application Setup

1. Visit https://gitlab.com/-/profile/applications
2. Create new application:
   - **Name**: `oauth2-proxy SSO`
   - **Redirect URI**: `https://auth.viljo.se/oauth2/callback`
   - **Confidential**: Yes
   - **Scopes**: `openid`, `profile`, `email`
3. Copy Client ID and Secret
4. Update vault:

```bash
ansible-vault edit inventory/group_vars/all/vault.yml --vault-password-file=.vault_pass.txt
```

## Session Sharing

All oauth2-proxy instances share:
- Same cookie domain (`.viljo.se`)
- Same cookie secret
- Same GitLab OAuth credentials
- Same redirect URL

**Result**: Users log in once, session works across all services!

## Troubleshooting

### Check oauth2-proxy logs
```bash
ssh root@192.168.1.3 'pct exec 200 -- docker logs oauth2-proxy-meet'
ssh root@192.168.1.3 'pct exec 200 -- docker logs oauth2-proxy-media'
ssh root@192.168.1.3 'pct exec 200 -- docker logs oauth2-proxy-torrent'
```

### Check container status
```bash
ssh root@192.168.1.3 'pct exec 200 -- docker ps | grep oauth2-proxy'
```

### Test SSO redirect
```bash
curl -sI https://meet.viljo.se/
# Should return HTTP 302 redirect to gitlab.com
```

### Verify health endpoints
```bash
curl -sI https://auth.viljo.se/ping
# Should return HTTP 200
```

## Security

- ✅ All cookies are `Secure` (HTTPS only)
- ✅ All cookies are `HttpOnly` (no JavaScript access)
- ✅ Email domain restricted to `@viljo.se`
- ✅ SameSite=lax prevents CSRF attacks
- ✅ Session valid for 168 hours (7 days)
- ✅ TLS/HTTPS enforced on all routes

## Currently Protected Services

- **meet.viljo.se** - Jitsi Meet video conferencing
- **media.viljo.se** - Jellyfin media streaming
- **torrent.viljo.se** - qBittorrent torrent management

## Services NOT Protected

- **links.viljo.se** - Public landing page (no auth needed)
- **cloud.viljo.se** - Nextcloud (has its own authentication)
