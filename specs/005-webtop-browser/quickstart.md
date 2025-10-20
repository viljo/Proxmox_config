# Quickstart: Webtop Browser Instance Deployment

**Feature**: Browser-accessible Linux desktop environment
**Deployment Time**: ~15-20 minutes
**Prerequisites**: Proxmox VE 8.x, Ansible 2.15+, access to Proxmox host

---

## Prerequisites Checklist

Before deploying, verify these requirements:

- [ ] **Proxmox Host**: Access to Proxmox VE host (SSH or web UI)
- [ ] **Network**: DMZ network (vmbr3) configured with 172.16.10.0/24
- [ ] **DNS**: A record for `browser.viljo.se` pointing to firewall/Traefik IP
- [ ] **Traefik**: Reverse proxy deployed and operational
- [ ] **Storage**: At least 25GB free on Proxmox storage pool
- [ ] **Ansible**: Ansible 2.15+ installed on control node
- [ ] **Inventory**: Proxmox host in Ansible inventory
- [ ] **Vault**: Ansible Vault password available

---

## Quick Deployment (5 Steps)

### Step 1: Clone Repository and Navigate to Project

```bash
cd /path/to/Proxmox_config
git checkout 005-webtop-browser  # Or main after merge
```

### Step 2: Configure Secrets in Ansible Vault

Create or edit the vault file for webtop credentials:

```bash
ansible-vault edit group_vars/all/secrets.yml
```

Add these variables:

```yaml
# Webtop Admin Credentials
vault_webtop_admin_user: "admin"
vault_webtop_admin_password: "YOUR_SECURE_PASSWORD_HERE"  # Min 12 characters

# LDAP Credentials (Phase 2 - optional for now)
# vault_ldap_bind_dn: "cn=webtop,ou=services,dc=infra,dc=local"
# vault_ldap_bind_password: "LDAP_SERVICE_ACCOUNT_PASSWORD"
```

**Security Note**: Generate a strong password using `openssl rand -base64 24`

### Step 3: Configure Deployment Variables

Edit `group_vars/all/webtop.yml` (or create if missing):

```yaml
---
# Webtop Deployment Configuration

# LXC Container
webtop_container_id: 2400
webtop_hostname: webtop
webtop_domain: browser.viljo.se

# Network (DMZ)
webtop_ip_address: 172.16.10.70
webtop_netmask: 24
webtop_gateway: 172.16.10.1
webtop_bridge: vmbr3

# Resources
webtop_memory_mb: 4096
webtop_cpu_cores: 2
webtop_disk_gb: 20
webtop_swap_mb: 2048
webtop_storage_pool: local-zfs

# Authentication (Phase 1: Built-in)
webtop_auth_mode: builtin
webtop_admin_user: "{{ vault_webtop_admin_user }}"
webtop_admin_password: "{{ vault_webtop_admin_password }}"

# Desktop Settings
webtop_timezone: Europe/Stockholm
webtop_keyboard_layout: sv-se-qwerty
webtop_title: "Webtop - browser.viljo.se"

# Integration Flags
webtop_enable_traefik: true
webtop_enable_netbox: true
webtop_enable_monitoring: true
webtop_enable_backup: true
```

### Step 4: Run Deployment Playbook

Execute the webtop deployment:

```bash
# Dry-run first (check mode)
ansible-playbook playbooks/webtop-deploy.yml --check --diff

# Actual deployment
ansible-playbook playbooks/webtop-deploy.yml --ask-vault-pass
```

**Expected Output**:
```
PLAY [Deploy Webtop Browser Instance] *****************************

TASK [webtop : Create LXC container] *****************************
changed: [proxmox-host]

TASK [webtop : Install Docker in container] **********************
changed: [proxmox-host]

TASK [webtop : Deploy webtop Docker container] *******************
changed: [proxmox-host]

TASK [webtop : Configure Traefik routing] ************************
changed: [proxmox-host]

TASK [webtop : Register in NetBox] *******************************
changed: [proxmox-host]

PLAY RECAP ********************************************************
proxmox-host : ok=15   changed=10   unreachable=0    failed=0
```

### Step 5: Verify Deployment

**Test Access**:

1. Navigate to `https://browser.viljo.se` in your web browser
2. You should see a login page (built-in auth) or desktop (if auto-login configured)
3. Enter credentials: `admin` / `[your vault password]`
4. XFCE desktop should load within 10 seconds

**Verify Container**:

```bash
# Check LXC container status
ssh proxmox-host "pct list | grep 2400"

# Check Docker container inside LXC
ssh proxmox-host "pct exec 2400 -- docker ps | grep webtop"

# Check logs
ssh proxmox-host "pct exec 2400 -- docker logs webtop"
```

**Verify Traefik Routing**:

```bash
# Check HTTP redirect
curl -I http://browser.viljo.se
# Expected: 301/302 redirect to HTTPS

# Check HTTPS access
curl -I https://browser.viljo.se
# Expected: 200 OK with valid TLS certificate

# Verify certificate
echo | openssl s_client -connect browser.viljo.se:443 -servername browser.viljo.se 2>/dev/null | openssl x509 -noout -issuer -dates
# Expected: Issuer=Let's Encrypt, valid dates
```

---

## Troubleshooting

### Issue: Container fails to create

**Symptoms**: Ansible task "Create LXC container" fails

**Diagnosis**:
```bash
# Check if container ID already exists
ssh proxmox-host "pct list | grep 2400"

# Check storage availability
ssh proxmox-host "pvesm status"
```

**Resolution**:
- If container exists: Either destroy it or choose different ID
- If storage full: Free up space or use different storage pool

---

### Issue: Webtop container won't start

**Symptoms**: Docker container not running after deployment

**Diagnosis**:
```bash
# Check Docker service status
ssh proxmox-host "pct exec 2400 -- systemctl status docker"

# Check Docker logs
ssh proxmox-host "pct exec 2400 -- journalctl -u docker -n 50"

# Check webtop container logs
ssh proxmox-host "pct exec 2400 -- docker logs webtop"
```

**Resolution**:
- Verify nesting is enabled: `pct config 2400 | grep nesting`
- Restart Docker daemon: `pct exec 2400 -- systemctl restart docker`
- Check environment variables in docker-compose.yml

---

### Issue: Cannot access browser.viljo.se

**Symptoms**: Browser shows "Connection refused" or "Site can't be reached"

**Diagnosis**:
```bash
# Check DNS resolution
dig browser.viljo.se +short
# Should return Traefik/firewall IP

# Check Traefik can reach webtop
ssh traefik-host "curl -I http://172.16.10.70:3000"
# Should return 200 OK

# Check firewall rules
ssh firewall-host "nft list ruleset | grep 443"
```

**Resolution**:
1. Verify DNS A record points to correct IP
2. Check firewall forwards port 443 to Traefik
3. Verify Traefik discovered webtop route: Check Traefik dashboard
4. Check Docker labels on webtop container are correct

---

### Issue: Authentication fails

**Symptoms**: Login page rejects credentials

**Diagnosis**:
```bash
# Check environment variables
ssh proxmox-host "pct exec 2400 -- docker exec webtop env | grep CUSTOM"

# Check vault decryption
ansible -m debug -a "var=vault_webtop_admin_password" localhost --ask-vault-pass
```

**Resolution**:
- Verify Vault password is correct
- Check `CUSTOM_USER` and `CUSTOM_PASSWORD` environment variables are set
- Restart webtop container after changing credentials

---

### Issue: Desktop loads slowly (>10 seconds)

**Symptoms**: Desktop takes long time to render after login

**Diagnosis**:
```bash
# Check container resources
ssh proxmox-host "pct config 2400 | grep -E 'memory|cores'"

# Check CPU/memory usage
ssh proxmox-host "pct exec 2400 -- top -b -n 1 | head -20"

# Check network latency
ping -c 5 browser.viljo.se
```

**Resolution**:
- Increase RAM allocation (try 6GB): `webtop_memory_mb: 6144`
- Add more CPU cores: `webtop_cpu_cores: 4`
- Check network connectivity between client and Traefik

---

## Post-Deployment Tasks

### 1. Verify Monitoring Integration

Check Zabbix has discovered the webtop container:

```bash
# Login to Zabbix web UI
# Navigate to: Configuration > Hosts
# Search for: webtop or 172.16.10.70
# Verify: Docker container template applied
```

### 2. Verify Backup Configuration

Check PBS includes webtop in backup jobs:

```bash
# Via PBS web UI:
# Datastore > Backup Jobs
# Verify: CT 2400 included in DMZ backup job

# Via CLI:
ssh pbs-host "proxmox-backup-manager backup-job list | grep 2400"
```

### 3. Test Session Persistence

1. Login to `https://browser.viljo.se`
2. Customize desktop (change wallpaper, create a file on Desktop)
3. Close browser tab
4. Re-open `https://browser.viljo.se` and login
5. Verify: Customizations persisted

### 4. Test Clipboard Functionality

1. Copy text on your local machine
2. Paste into webtop desktop (terminal, text editor)
3. Copy text inside webtop desktop
4. Paste on your local machine
5. Verify: Clipboard sync works bidirectionally

### 5. Performance Testing

Run these tests inside the webtop desktop:

```bash
# Open terminal in webtop
# Test disk I/O
dd if=/dev/zero of=~/testfile bs=1M count=100 conv=fdatasync
# Should complete in < 10 seconds

# Test network bandwidth
curl -o /dev/null https://speed.cloudflare.com/__down?bytes=10000000
# Should achieve reasonable throughput

# Test application launch time
time firefox &
# Should launch in < 5 seconds
```

---

## Scaling and Multi-User Setup

### Enable Multi-User Sessions

Webtop supports multiple concurrent users. For >5 users, consider:

**Option 1: Scale Vertically**
```yaml
webtop_memory_mb: 8192  # Increase RAM
webtop_cpu_cores: 4     # Add more CPU cores
```

**Option 2: Deploy Additional Instances**
```yaml
# Second webtop instance
webtop_container_id: 2401
webtop_ip_address: 172.16.10.71
webtop_domain: browser2.viljo.se
```

**Option 3: LDAP Integration (Phase 2)**

Switch to LDAP authentication for centralized user management:

```yaml
webtop_auth_mode: ldap
webtop_ldap_uri: ldap://ldap.infra.local:389
webtop_ldap_base_dn: dc=infra,dc=local
webtop_ldap_bind_dn: "{{ vault_ldap_bind_dn }}"
webtop_ldap_bind_password: "{{ vault_ldap_bind_password }}"
```

---

## Updating Webtop

To update the webtop Docker image:

```bash
# Edit group_vars/all/webtop.yml
webtop_docker_image: lscr.io/linuxserver/webtop:debian-xfce-latest

# Re-run playbook (idempotent - will pull new image and recreate container)
ansible-playbook playbooks/webtop-deploy.yml --ask-vault-pass --tags webtop

# Or manually inside LXC:
ssh proxmox-host "pct exec 2400 -- docker-compose -f /opt/webtop/docker-compose.yml pull"
ssh proxmox-host "pct exec 2400 -- docker-compose -f /opt/webtop/docker-compose.yml up -d"
```

User data persists across updates (stored in `/var/lib/webtop/config` and `/var/lib/webtop/data`).

---

## Uninstalling Webtop

To remove the webtop deployment:

```bash
# Run teardown playbook
ansible-playbook playbooks/webtop-teardown.yml --ask-vault-pass

# This will:
# 1. Stop webtop Docker container
# 2. Stop LXC container
# 3. Remove NetBox entry
# 4. Remove Zabbix monitoring
# 5. (Optional) Destroy LXC container
```

**Warning**: This will delete all user data unless you manually backup `/var/lib/webtop/` first.

---

## Next Steps

After successful deployment:

1. **Phase 2**: Integrate LDAP authentication for centralized user management
2. **Phase 3**: Implement Traefik ForwardAuth with Keycloak for SSO
3. **Customization**: Install additional desktop applications (LibreOffice, GIMP, VSCode)
4. **Monitoring**: Set up custom Zabbix triggers for webtop-specific metrics
5. **Documentation**: Add webtop architecture to `docs/webtop-architecture.md`

---

## Support and Resources

- **LinuxServer.io Webtop Docs**: https://docs.linuxserver.io/images/docker-webtop/
- **KasmVNC Performance Tuning**: https://kasmweb.com/docs/latest/guide/performance.html
- **Traefik Docker Provider**: https://doc.traefik.io/traefik/providers/docker/
- **Internal Documentation**: `docs/webtop-architecture.md` (after creation)

---

## Success Criteria Verification

After deployment, verify these success criteria from the specification:

- [x] **SC-001**: Users can access desktop within 10 seconds of authentication
- [x] **SC-002**: Input latency <100ms (test mouse and keyboard)
- [x] **SC-003**: Supports 5 concurrent users (test with multiple browser sessions)
- [x] **SC-004**: Desktop maintains 30fps (observe smooth window dragging)
- [x] **SC-005**: File upload/download works for 100MB files
- [x] **SC-006**: Session data persists across reconnections
- [x] **SC-007**: 99% uptime (monitor over evaluation period)
- [x] **SC-008**: 3 application types work (terminal, file manager, browser)

If all criteria pass, deployment is successful and ready for production use.
