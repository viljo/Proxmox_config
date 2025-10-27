# Jitsi Meet Deployment Guide

**Feature**: 001-jitsi-server
**Status**: Ready for Deployment
**Created**: 2025-10-27

## Overview

This guide provides step-by-step instructions for deploying the Jitsi Meet video conferencing server to the Proxmox infrastructure.

## Prerequisites

Before deploying, ensure the following are in place:

### Infrastructure Requirements

- [x] Proxmox host accessible at 192.168.1.3
- [x] vmbr3 (DMZ) network configured (172.16.10.0/24)
- [x] Traefik reverse proxy running
- [x] Keycloak SSO instance operational at keycloak.viljo.se
- [x] Firewall container (LXC 101) running with nftables configured
- [x] DNS managed by Loopia with API access configured

### Storage Requirements

- [x] `/mnt/storage/jitsi-recordings` directory on Proxmox host (will be created by Ansible)
- [x] At least 100GB free space for recordings (recommended)

### Secrets Configuration

All secrets must be defined in `inventory/group_vars/all/secrets.yml` (see [VAULT_SECRETS.md](../../roles/jitsi/VAULT_SECRETS.md)):

- [ ] `vault_jitsi_root_password`
- [ ] `vault_jitsi_jicofo_component_secret`
- [ ] `vault_jitsi_jicofo_auth_password`
- [ ] `vault_jitsi_jvb_auth_password`
- [ ] `vault_jitsi_jibri_recorder_password`
- [ ] `vault_jitsi_jibri_xmpp_password`
- [ ] `vault_jitsi_oidc_client_secret` (after Keycloak client creation)

## Deployment Steps

### Step 1: Configure Ansible Vault Secrets

Generate required secrets:

```bash
# Generate component secrets
for i in {1..5}; do
  echo "$(openssl rand -hex 32)"
done
```

Edit the encrypted vault file:

```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Add the Jitsi secrets (see VAULT_SECRETS.md for complete list).

### Step 2: Configure Keycloak OIDC Client

1. Access Keycloak admin console: https://keycloak.viljo.se
2. Select **master** realm
3. Navigate to **Clients** → **Create Client**
4. Configure client:
   ```
   Client ID: jitsi
   Client Type: OpenID Connect
   Client authentication: ON
   ```
5. Set **Valid redirect URIs**:
   ```
   https://meet.viljo.se/*
   ```
6. Set **Web origins**:
   ```
   https://meet.viljo.se
   ```
7. Save and go to **Credentials** tab
8. Copy **Client Secret** and add to vault:
   ```bash
   ansible-vault edit inventory/group_vars/all/secrets.yml
   # Add: vault_jitsi_oidc_client_secret: "copied_secret"
   ```

### Step 3: Configure Firewall Port Forwarding

The Jitsi JVB component requires UDP port 10000 for WebRTC media streams.

**Option A: Manual Configuration** (if firewall role doesn't support this yet)

SSH to firewall container:
```bash
ssh root@192.168.1.3 "pct exec 101 -- bash"
```

Edit nftables configuration:
```bash
nano /etc/nftables.conf
```

Add UDP DNAT rule in the `prerouting` chain:
```nft
# Jitsi JVB UDP port for WebRTC media
iifname "eth0" udp dport 10000 dnat to 172.16.10.160:10000
```

Reload nftables:
```bash
nft -f /etc/nftables.conf
systemctl reload nftables
```

Verify rule:
```bash
nft list ruleset | grep 10000
```

**Option B: Update Firewall Ansible Role** (recommended)

Add to firewall role configuration and re-run firewall playbook.

### Step 4: Run Ansible Playbook

Deploy the Jitsi role:

```bash
# From repository root
cd /Users/anders/git/Proxmox_config

# Dry run first (check mode)
ansible-playbook -i inventory/proxmox.ini site.yml \
  --tags jitsi \
  --ask-vault-pass \
  --check

# Actual deployment
ansible-playbook -i inventory/proxmox.ini site.yml \
  --tags jitsi \
  --ask-vault-pass
```

**Expected output**:
- Container 160 created
- Docker installed in container
- Docker Compose stack deployed
- Recording storage bind-mounted
- Services started

### Step 5: Verify Deployment

#### Check Container Status

```bash
ssh root@192.168.1.3 "pct status 160"
# Expected: status: running
```

#### Check Docker Containers

```bash
ssh root@192.168.1.3 "pct exec 160 -- docker ps"
```

Expected containers:
- jitsi-web
- jitsi-prosody
- jitsi-jicofo
- jitsi-jvb
- jitsi-jibri (if recording enabled)

#### Verify Network Connectivity

```bash
# Container can reach internet
ssh root@192.168.1.3 "pct exec 160 -- ping -c 2 1.1.1.1"

# Container can reach Keycloak
ssh root@192.168.1.3 "pct exec 160 -- curl -I https://keycloak.viljo.se"

# Web service is responding
curl -I https://meet.viljo.se
# Expected: HTTP/2 200
```

#### Check DNS Resolution

```bash
dig meet.viljo.se +short
# Should return public IP from vmbr2
```

#### Verify Traefik Routing

```bash
ssh root@192.168.1.3 "cat /etc/traefik/dynamic/services.yml | grep -A 5 jitsi"
```

Should show route configuration for meet.viljo.se.

### Step 6: Test Basic Functionality

#### Create Test Meeting

1. Open browser to https://meet.viljo.se
2. Enter meeting name: "test-deployment"
3. Should load Jitsi interface
4. Allow camera/microphone access
5. Verify video/audio working

#### Test Anonymous Access

1. Open incognito/private window
2. Navigate to https://meet.viljo.se/test-deployment
3. Should join as guest
4. Verify limited permissions (cannot mute others, etc.)

#### Test SSO Authentication

1. Create new meeting: https://meet.viljo.se/secure-meeting
2. Click "I am the host" or similar moderator prompt
3. Should redirect to Keycloak → GitLab OAuth
4. Authenticate with GitLab credentials
5. Return to Jitsi with moderator privileges
6. Verify moderator controls available

#### Test Screen Sharing

1. Join meeting as moderator
2. Click "Share screen" button
3. Select window/screen
4. Verify screen sharing works

#### Test Recording (if enabled)

1. Join meeting as moderator
2. Click "Start recording"
3. Record for 30 seconds
4. Stop recording
5. Verify file saved to `/mnt/storage/jitsi-recordings` on Proxmox host:
   ```bash
   ssh root@192.168.1.3 "ls -lh /mnt/storage/jitsi-recordings/"
   ```

### Step 7: Performance Validation

#### Load Test (optional)

1. Open multiple browser tabs/windows
2. Join same meeting from 5-10 clients
3. Monitor resource usage:
   ```bash
   ssh root@192.168.1.3 "pct exec 160 -- docker stats"
   ```
4. Verify acceptable performance (no lag, dropped frames)

#### Network Test

Test UDP connectivity from external network:
```bash
# From external host
nc -zuv <public_ip> 10000
```

Should show "Connection to <ip> 10000 port [udp/*] succeeded!"

## Post-Deployment

### Monitoring Setup

Add to monitoring system (Zabbix/Prometheus):
- Container CPU/memory usage
- Docker container health
- Disk space for recordings
- Network traffic on UDP 10000

### Backup Configuration

Ensure backups include:
- Container configuration: `/etc/pve/lxc/160.conf`
- Docker volumes: Jitsi configuration persisted in Docker volumes
- Recordings: `/mnt/storage/jitsi-recordings` on host

### Documentation Updates

- [ ] Update service inventory documentation
- [ ] Add monitoring dashboards
- [ ] Document backup/restore procedures
- [ ] Create runbook for common operations

### User Communication

Notify users about new service:
- Service URL: https://meet.viljo.se
- Authentication: GitLab SSO for moderators
- Anonymous access: Supported for guests
- Features: Screen sharing, recording, chat

## Rollback Procedure

If deployment fails or issues arise:

### Stop Services

```bash
ssh root@192.168.1.3 "pct exec 160 -- docker compose -f /opt/jitsi/docker-compose.yml down"
```

### Stop Container

```bash
ssh root@192.168.1.3 "pct stop 160"
```

### Remove Container (if needed)

```bash
ssh root@192.168.1.3 "pct destroy 160"
```

### Remove DNS Record

Edit `inventory/group_vars/all/main.yml` and remove:
```yaml
- host: meet
```

Re-run DNS update playbook.

### Remove Traefik Route

Edit `inventory/group_vars/all/main.yml` and remove Jitsi service entry.

Re-run Traefik playbook.

## Troubleshooting

### Container Won't Start

**Check logs**:
```bash
ssh root@192.168.1.3 "pct status 160"
ssh root@192.168.1.3 "journalctl -xe | grep lxc"
```

**Common issues**:
- Insufficient resources: Increase memory/CPU
- Network misconfiguration: Verify vmbr3 settings
- Feature flags: Ensure nesting=1

### Docker Containers Crash Loop

**Check logs**:
```bash
ssh root@192.168.1.3 "pct exec 160 -- docker compose -f /opt/jitsi/docker-compose.yml logs"
```

**Common issues**:
- Incorrect secrets: Verify all environment variables
- Port conflicts: Ensure ports 8000, 10000 available
- Missing volumes: Check Docker volume creation

### Cannot Connect to Meeting

**Check network path**:
```bash
# DNS resolution
dig meet.viljo.se

# Traefik routing
curl -I https://meet.viljo.se

# Service availability
ssh root@192.168.1.3 "pct exec 160 -- curl -I http://localhost:8000"
```

**Common issues**:
- DNS not updated: Wait for propagation or clear cache
- Traefik not reloaded: Restart Traefik service
- Firewall blocking: Check nftables rules

### No Audio/Video

**Check browser console** for WebRTC errors.

**Verify UDP port**:
```bash
# From external network
nc -zuv <public_ip> 10000
```

**Common issues**:
- UDP port blocked: Verify firewall DNAT rule
- STUN servers unreachable: Check JVB_STUN_SERVERS
- Browser permissions: Ensure camera/mic access granted

### SSO Not Working

**Check Keycloak integration**:
```bash
# Verify Keycloak accessible
curl -I https://keycloak.viljo.se

# Check OIDC endpoint
curl https://keycloak.viljo.se/realms/master/.well-known/openid-configuration
```

**Common issues**:
- Wrong client secret: Verify vault_jitsi_oidc_client_secret
- Invalid redirect URI: Check Keycloak client configuration
- TOKEN_AUTH_URL incorrect: Verify environment variable

## Success Criteria

Deployment is successful when:

- [x] Container running: `pct status 160` shows "running"
- [x] All Docker containers healthy: `docker ps` shows 5 containers up
- [x] Web interface accessible: https://meet.viljo.se returns 200
- [x] Anonymous users can join meetings
- [x] SSO authentication working (moderator flow)
- [x] Screen sharing functional
- [x] Recording saves files to host storage
- [x] Multiple participants can join (5+ simultaneous)
- [x] Audio/video quality acceptable
- [x] No errors in container logs

## Maintenance

### Regular Updates

Update Jitsi Docker images:
```bash
ssh root@192.168.1.3 "pct exec 160 -- bash"
cd /opt/jitsi
docker compose pull
docker compose up -d
```

### Clean Old Recordings

```bash
# Find recordings older than 30 days
find /mnt/storage/jitsi-recordings -type f -mtime +30

# Delete old recordings
find /mnt/storage/jitsi-recordings -type f -mtime +30 -delete
```

### Monitor Disk Usage

```bash
ssh root@192.168.1.3 "df -h /mnt/storage/jitsi-recordings"
```

## Related Documentation

- [Specification](spec.md)
- [Role README](../../roles/jitsi/README.md)
- [Vault Secrets](../../roles/jitsi/VAULT_SECRETS.md)
- [Network Architecture](../../docs/NETWORK_ARCHITECTURE.md)

## Support

For issues:
1. Check logs: `pct exec 160 -- docker compose logs -f`
2. Review troubleshooting section above
3. Consult Jitsi documentation: https://jitsi.github.io/handbook/
4. Check Keycloak integration guide

---

**Deployment Date**: _To be filled after deployment_
**Deployed By**: _To be filled after deployment_
**Deployment Notes**: _To be filled after deployment_
