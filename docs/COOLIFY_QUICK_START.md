> **⚠️ OUTDATED**: This document references Keycloak SSO which is no longer used, and Coolify PaaS which was never fully deployed. Current architecture uses Docker containers in LXC 200 with Traefik reverse proxy and OAuth2-Proxy + GitLab SSO. See docs/oauth2-proxy-automation.md and docs/getting-started.md
# Coolify Quick Start Guide

## What is Coolify?

Coolify is a self-hosted Platform-as-a-Service (PaaS) alternative to Heroku, Netlify, and Vercel. It provides:

- **Easy application deployment** from Git repositories
- **Docker container management** with built-in UI
- **Automatic HTTPS** with Let's Encrypt
- **Database management** (PostgreSQL, MySQL, Redis, MongoDB, etc.)
- **One-click deployments** for popular frameworks
- **Built-in monitoring** and logging

**Architecture**: Centralized PaaS running in a single LXC container (ID 161)

---

## Pre-Deployment Steps

### 1. Add Vault Secrets

```bash
cd /Users/anders/git/Proxmox_config

# Edit the vault file
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Add the following secrets (copy from generated output above):

```yaml
# Coolify Vault Secrets
vault_coolify_root_password: "RFJ+sSUWeJE01FkTqzcRFpvjf2sG1PzThOdgOV0ULLk="
vault_coolify_postgres_password: "rG1YhpfYh2WGOaYogmiga4P9yqIlUqL1YT363aHV0eY="
vault_coolify_redis_password: "XIhZd7AdB/DE9pVdLLrl031NLQEUHEc7dz1usUnenpM="
vault_coolify_app_id: "coolify"
vault_coolify_app_key: "base64:9UtZLDtEOYvI/5NTzWX/BG5n2H0d4ut+XbbjP4YaCe0="
vault_coolify_pusher_app_secret: "TiuQQxz+5w5kK+OxnE6pFtYgll8mYtMWGHQuxl899nE="
```

Save and exit (`:wq` in vi).

---

## Deployment

### Deploy Coolify

```bash
cd /Users/anders/git/Proxmox_config

# Dry run (check what will happen)
ansible-playbook playbooks/coolify-deploy.yml --ask-vault-pass --check

# Deploy for real
ansible-playbook playbooks/coolify-deploy.yml --ask-vault-pass
```

**Deployment time**: ~5-10 minutes

---

## Initial Setup (CRITICAL - Do Immediately!)

### Step 1: Register Admin Account

⚠️ **IMPORTANT**: The first user to register becomes the admin!

1. Open https://coolify.viljo.se in your browser
2. Click "Register"
3. Create your admin account:
   - Email: your-email@example.com
   - Password: strong-password
   - Name: Your Name
4. Click "Register"

You now have full admin access to Coolify.

### Step 2: Configure Email (Optional)

Settings → Email Settings:
- SMTP Host: your-smtp-server
- SMTP Port: 587
- Username: your-email@example.com
- Password: your-email-password

This enables password resets and notifications.

### Step 3: Configure Keycloak SSO (Recommended)

**A. Create Keycloak OIDC Client**

1. Go to https://keycloak.viljo.se
2. Login as admin
3. Select "master" realm
4. Clients → Create Client:
   - Client ID: `coolify`
   - Client Protocol: `openid-connect`
   - Root URL: `https://coolify.viljo.se`
5. Click "Next", then configure:
   - Client authentication: **ON**
   - Authorization: OFF
   - Authentication flow:
     - ✅ Standard flow
     - ✅ Direct access grants
6. Valid redirect URIs:
   - `https://coolify.viljo.se/*`
7. Save
8. Go to "Credentials" tab
9. Copy the "Client Secret"

**B. Configure in Coolify**

1. In Coolify: Settings → Authentication → OAuth2
2. Click "Add Provider"
3. Select "Custom OpenID Connect"
4. Fill in:
   - **Provider Name**: Keycloak
   - **Client ID**: `coolify`
   - **Client Secret**: (paste from Keycloak)
   - **Authorization URL**: `https://keycloak.viljo.se/realms/master/protocol/openid-connect/auth`
   - **Token URL**: `https://keycloak.viljo.se/realms/master/protocol/openid-connect/token`
   - **User Info URL**: `https://keycloak.viljo.se/realms/master/protocol/openid-connect/userinfo`
5. Save

Now users can log in with Keycloak (which uses GitLab.com OAuth)!

---

## Deploying Your First Application

### Option 1: Deploy from Git Repository

1. In Coolify, click "New Project"
2. Give it a name (e.g., "my-website")
3. Click "New Resource" → "Application"
4. Choose deployment type:
   - **Public Git Repository**: For public GitHub/GitLab repos
   - **Private Git Repository**: For private repos (requires SSH key)
5. Fill in:
   - Git URL: `https://github.com/username/repo.git`
   - Branch: `main`
   - Build Pack: Auto-detect (or select framework)
6. Click "Deploy"

Coolify will:
- Clone your repository
- Detect the framework (Node.js, Python, PHP, etc.)
- Build the application
- Deploy it
- Give you a URL like `https://my-app.coolify.viljo.se`

### Option 2: Deploy Docker Image

1. New Project → New Resource → Application
2. Choose "Docker Image"
3. Fill in:
   - Image: `nginx:latest` (or your custom image)
   - Port: 80 (or your app's port)
4. Click "Deploy"

### Option 3: Deploy Database

1. New Project → New Resource → Database
2. Choose database type:
   - PostgreSQL
   - MySQL
   - MongoDB
   - Redis
3. Configure and deploy
4. Get connection details from Coolify UI

---

## Managing Applications

### View Application Logs

1. Click on your application
2. Go to "Logs" tab
3. See real-time logs from your containers

### Update Application

1. Click on application
2. Click "Redeploy"
3. Coolify pulls latest code and redeploys

### Environment Variables

1. Application → "Environment" tab
2. Add variables:
   - `DATABASE_URL`
   - `API_KEY`
   - etc.
3. Save and redeploy

### Custom Domains

1. Application → "Domains" tab
2. Add custom domain: `myapp.example.com`
3. Point DNS to your Proxmox public IP
4. Coolify handles Let's Encrypt SSL automatically

---

## GitLab Integration

### Deploy from GitLab Repository

1. In GitLab, generate a Deploy Token:
   - Project → Settings → Repository → Deploy Tokens
   - Name: coolify
   - Scopes: ✅ read_repository
   - Copy username and token
2. In Coolify:
   - Git URL: `https://gitlab.com/username/project.git`
   - Use deploy token credentials
3. Deploy!

### CI/CD with GitLab

Add to your `.gitlab-ci.yml`:

```yaml
deploy:
  stage: deploy
  script:
    - curl -X POST "https://coolify.viljo.se/api/v1/deploy?webhook=YOUR_WEBHOOK_TOKEN"
  only:
    - main
```

Get webhook token from Coolify: Application → "Webhooks" tab

---

## Common Operations

### SSH into Coolify Container

```bash
ssh root@192.168.1.3
pct enter 161
```

### View Docker Containers

```bash
pct exec 161 -- docker ps
```

### View Coolify Logs

```bash
pct exec 161 -- bash -c "cd /opt/coolify && docker compose logs -f coolify"
```

### Restart Coolify Stack

```bash
pct exec 161 -- bash -c "cd /opt/coolify && docker compose restart"
```

### Backup Coolify Data

```bash
# Backup entire LXC container
vzdump 161 --mode snapshot --compress zstd --storage local

# Or backup just data
pct exec 161 -- tar -czf /tmp/coolify-backup.tar.gz /data/coolify
pct pull 161 /tmp/coolify-backup.tar.gz ./coolify-backup-$(date +%Y%m%d).tar.gz
```

---

## Troubleshooting

### Application won't deploy

1. Check logs: Application → Logs tab
2. Verify build pack detected correctly
3. Check environment variables
4. Try manual Docker build locally first

### Can't access application URL

1. Check Traefik routing: `pct exec 161 -- docker logs traefik`
2. Verify DNS pointing to correct IP
3. Check SSL certificate provisioning

### Coolify UI slow or unresponsive

```bash
# Check resource usage
pct exec 161 -- docker stats

# Increase container resources if needed
pct set 161 --memory 8192 --cores 4
pct reboot 161
```

### Database connection failed

1. Verify database container running: `pct exec 161 -- docker ps`
2. Check connection string format
3. Verify network connectivity between containers

---

## Security Best Practices

1. ✅ **Register admin immediately** (first user becomes admin)
2. ✅ **Enable Keycloak SSO** (centralized auth)
3. ✅ **Use strong passwords** for all accounts
4. ✅ **Keep Coolify updated** (check for updates monthly)
5. ✅ **Backup regularly** (automated with PBS)
6. ✅ **Monitor logs** (add to Zabbix/Grafana)

---

## Resources

### Documentation
- **Coolify Role**: `roles/coolify/README.md` (360 lines)
- **Vault Secrets**: `roles/coolify/VAULT_SECRETS.md` (142 lines)
- **Official Docs**: https://coolify.io/docs

### Support
- **Coolify Discord**: https://discord.gg/coolify
- **GitHub Issues**: https://github.com/coollabsio/coolify/issues
- **Documentation**: https://coolify.io/docs

### Configuration Files
- **Inventory**: `inventory/group_vars/all/coolify.yml`
- **Vault**: `inventory/group_vars/all/secrets.yml`
- **Playbook**: `playbooks/coolify-deploy.yml`

---

## What's Next?

After deployment:

**Week 1:**
1. Deploy 2-3 test applications
2. Configure Keycloak SSO
3. Invite team members
4. Set up monitoring

**Week 2:**
5. Migrate existing apps to Coolify
6. Configure GitLab CI/CD webhooks
7. Set up automated backups
8. Document team workflows

**Future Enhancements:**
9. Integrate with NetBox (CMDB)
10. Add Zabbix monitoring
11. Configure PBS backups
12. Create usage dashboards

---

## Access Information

- **URL**: https://coolify.viljo.se
- **Container ID**: 161
- **IP**: 172.16.10.161
- **Port**: 8000
- **Network**: DMZ (vmbr3)

**Deployment Status**: Ready to deploy! ✅

---

**Generated**: 2025-10-27
**Last Updated**: 2025-10-27
