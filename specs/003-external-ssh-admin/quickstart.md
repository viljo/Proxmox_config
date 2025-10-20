# Quickstart Guide: External SSH Access via viljo.se

**Feature**: External SSH Access via viljo.se
**Date**: 2025-10-20
**Purpose**: Step-by-step guide for implementing external SSH access

## Overview

This guide will help you configure external SSH access to your Proxmox host (mother @ 192.168.1.3) via the viljo.se domain. After completion, you'll be able to connect using:

```bash
ssh root@viljo.se
```

**Estimated Time**: 30-60 minutes (depending on router automation capability)

**Prerequisites**:
- Proxmox host running and accessible at 192.168.1.3
- viljo.se domain registered and DNS configurable
- Router/firewall with port forwarding capability
- Ansible installed on control machine
- Access to Loopia account for DNS/DDNS configuration
- SSH key pair generated (ed25519 recommended)

## Quick Reference

| Component | Configuration | Location |
|-----------|--------------|----------|
| Proxmox Host | 192.168.1.3 | Internal network |
| External Domain | viljo.se | Loopia DNS |
| SSH Port (internal) | 22 | Proxmox |
| SSH Port (external) | 2222 (recommended) | Router |
| DNS TTL | 300 seconds | Loopia |
| Ansible Playbook | `playbooks/external-ssh-access.yml` | Repository |

## Implementation Steps

### Phase 1: Preparation (5-10 minutes)

#### 1.1 Generate SSH Key Pair (if not already done)

```bash
# Generate ed25519 key (recommended)
ssh-keygen -t ed25519 -C "admin@workstation" -f ~/.ssh/proxmox_external

# Verify key was created
ls -l ~/.ssh/proxmox_external*
# Should show: proxmox_external (private) and proxmox_external.pub (public)
```

**Important**: Never commit private keys to git. Only the public key will be deployed.

#### 1.2 Copy Public Key

```bash
# Display public key
cat ~/.ssh/proxmox_external.pub

# Copy output to clipboard for next step
```

#### 1.3 Store Public Key in Ansible Vault

```bash
# Edit vault file (create if doesn't exist)
ansible-vault edit group_vars/all/secrets.yml

# Add your public key (paste from clipboard):
vault_admin_ssh_public_key: "ssh-ed25519 AAAAC3Nza... admin@workstation"

# Save and exit (ESC :wq in vim)
```

#### 1.4 Verify Prerequisites Checklist

- [ ] Proxmox host reachable: `ping 192.168.1.3`
- [ ] Ansible installed: `ansible --version`
- [ ] Vault password known or in password file
- [ ] SSH key pair generated
- [ ] Public key added to vault

### Phase 2: DNS Configuration (10-15 minutes)

#### 2.1 Configure Loopia DNS A Record

**Option A: Via Loopia Web UI** (Manual)

1. Log in to Loopia customer portal: https://customerzone.loopia.com/
2. Navigate to DNS settings for viljo.se
3. Add/Edit A record:
   - **Type**: A
   - **Name**: @ (for apex domain) or ssh (for subdomain)
   - **TTL**: 300 seconds
   - **Value**: [Your current external IP - find at https://icanhazip.com/]
4. Save changes
5. Verify: `dig viljo.se` (should return your external IP)

**Option B: Via Loopia API** (Automated - if loopia_dns role exists)

```bash
# Edit loopia_dns role variables
ansible-playbook playbooks/loopia-dns-setup.yml \
  -e "loopia_domain=viljo.se" \
  -e "loopia_record_type=A" \
  -e "loopia_ttl=300"
```

#### 2.2 Configure Loopia DDNS (Dynamic DNS Updates)

Edit `roles/loopia_ddns/defaults/main.yml`:

```yaml
loopia_domain: "viljo.se"
loopia_dns_ttl: 300
loopia_update_interval: 300  # Check for IP changes every 5 minutes
```

Ensure Loopia API credentials are in vault:

```bash
ansible-vault edit group_vars/all/secrets.yml

# Add (if not present):
vault_loopia_api_user: "your-loopia-username"
vault_loopia_api_password: "your-loopia-api-password"
```

#### 2.3 Verify DNS Configuration

```bash
# Check DNS resolution
dig viljo.se

# Expected output should include:
# ;; ANSWER SECTION:
# viljo.se.  300  IN  A  [Your External IP]

# Verify TTL is 300 seconds
dig viljo.se | grep "^viljo.se"
```

### Phase 3: Ansible Role Configuration (10 minutes)

#### 3.1 Create/Update Proxmox Role Variables

Edit `roles/proxmox/defaults/main.yml` and add/update:

```yaml
# SSH Hardening Configuration
proxmox_ssh_hardening_enabled: true
proxmox_ssh_port: 22  # Internal port
proxmox_ssh_external_port: 2222  # External port (for documentation)
proxmox_ssh_permit_root_login: "without-password"
proxmox_ssh_password_auth: false
proxmox_ssh_pubkey_auth: true
proxmox_ssh_allowed_users:
  - root
proxmox_ssh_client_alive_interval: 300
proxmox_ssh_client_alive_count_max: 3
proxmox_ssh_max_auth_tries: 3

# Fail2ban Configuration
proxmox_fail2ban_enabled: true
proxmox_fail2ban_maxretry: 5
proxmox_fail2ban_findtime: 600
proxmox_fail2ban_bantime: 3600
proxmox_fail2ban_ignoreip:
  - "127.0.0.1/8"
  - "192.168.0.0/16"

# SSH Authorized Keys
proxmox_ssh_authorized_keys:
  - type: "ssh-ed25519"
    key: "{{ vault_admin_ssh_public_key }}"
    comment: "admin@workstation"
```

#### 3.2 Create External SSH Access Playbook

Create `playbooks/external-ssh-access.yml`:

```yaml
---
- name: Configure External SSH Access to Proxmox Host
  hosts: proxmox_admin
  become: true

  tasks:
    - name: Include proxmox role with SSH hardening
      ansible.builtin.include_role:
        name: proxmox
        tasks_from: ssh-hardening
      tags: ['ssh']

    - name: Include loopia_ddns role
      ansible.builtin.include_role:
        name: loopia_ddns
      tags: ['ddns']

    - name: Display connection instructions
      ansible.builtin.debug:
        msg: |
          ===================================
          SSH Access Configuration Complete
          ===================================

          To connect from external networks:
          ssh -p {{ proxmox_ssh_external_port }} root@viljo.se

          Note: Complete router port forwarding first (see Phase 4)

          Test internal access first:
          ssh root@192.168.1.3
```

### Phase 4: Router Port Forwarding (10-20 minutes)

**This step varies by router model. Below are general instructions.**

#### 4.1 Access Router Admin Interface

1. Navigate to your router's admin interface (common addresses):
   - http://192.168.1.1
   - http://192.168.0.1
   - http://10.0.0.1

2. Log in with admin credentials

#### 4.2 Configure Port Forwarding Rule

Navigate to Port Forwarding / NAT / Virtual Servers section (name varies by router).

Create new rule:

| Field | Value |
|-------|-------|
| **Service Name** | Proxmox SSH |
| **External Port** | 2222 (or your chosen port) |
| **Internal IP Address** | 192.168.1.3 |
| **Internal Port** | 22 |
| **Protocol** | TCP |
| **Enabled** | Yes |

**Screenshots** (router-specific - consult your router manual):
- Examples for common routers: Asus, Netgear, TP-Link, etc.

#### 4.3 Configure Static DHCP Reservation (Recommended)

Ensure 192.168.1.3 is always assigned to Proxmox host:

1. Navigate to DHCP settings
2. Find Proxmox host (MAC address: [check with `ip a` on Proxmox])
3. Create static lease:
   - **IP Address**: 192.168.1.3
   - **MAC Address**: [Proxmox MAC]
   - **Hostname**: mother (or proxmox)

#### 4.4 Save and Reboot Router

After configuring:
1. Save settings
2. Reboot router (optional but recommended)
3. Wait for router to come back online (2-5 minutes)

#### 4.5 Alternative: Automated Port Forwarding (if supported)

If your router supports UPnP or has an API:

Create `roles/firewall/tasks/port-forward.yml`:

```yaml
---
# Automated port forwarding (router-dependent)
# This is a placeholder - customize for your router model

- name: Check if UPnP is available
  ansible.builtin.command: which upnpc
  register: upnpc_check
  ignore_errors: true
  changed_when: false

- name: Add port forwarding via UPnP
  ansible.builtin.command: >
    upnpc -a {{ hostvars[inventory_hostname].ansible_default_ipv4.address }} 22 2222 TCP
  when: upnpc_check.rc == 0

# For API-enabled routers (EdgeRouter, MikroTik, etc.):
# Use appropriate Ansible modules or API calls
```

### Phase 5: Deploy Configuration (5 minutes)

#### 5.1 Run Ansible Playbook

```bash
# From repository root
cd /path/to/Proxmox_config

# Dry run first (check mode)
ansible-playbook playbooks/external-ssh-access.yml --check --diff

# Review changes, then apply
ansible-playbook playbooks/external-ssh-access.yml --ask-vault-pass

# Or if using vault password file:
ansible-playbook playbooks/external-ssh-access.yml --vault-password-file ~/.ansible_vault_pass
```

#### 5.2 Monitor Deployment

Watch for:
- SSH config changes applied
- sshd service restarted successfully
- fail2ban installed and started
- Loopia DDNS updated
- No errors in task output

Expected output:

```
PLAY [Configure External SSH Access to Proxmox Host] ***

TASK [Include proxmox role with SSH hardening] ***
changed: [proxmox_admin]

TASK [Include loopia_ddns role] ***
ok: [proxmox_admin]

PLAY RECAP ***
proxmox_admin : ok=15  changed=5  unreachable=0  failed=0
```

### Phase 6: Verification & Testing (10-15 minutes)

#### 6.1 Test Internal SSH Access (from local network)

```bash
# Test internal access with new key
ssh -i ~/.ssh/proxmox_external root@192.168.1.3

# If successful, you should see Proxmox shell
# Try some commands:
hostname  # Should show: mother
ip a      # Verify IP is 192.168.1.3
exit
```

#### 6.2 Test Password Authentication is Disabled

```bash
# This should FAIL (which is expected/correct)
ssh -o PubkeyAuthentication=no root@192.168.1.3

# Expected output:
# Permission denied (publickey).
```

If it prompts for password, SSH hardening didn't apply correctly.

#### 6.3 Verify fail2ban is Active

```bash
# SSH to Proxmox, then check fail2ban status
ssh -i ~/.ssh/proxmox_external root@192.168.1.3

# On Proxmox host:
systemctl status fail2ban
fail2ban-client status sshd

# Expected output:
# Status for the jail: sshd
# |- Filter
# |  |- Currently failed: 0
# |  |- Total failed:     0
# |  `- File list:        /var/log/auth.log
# `- Actions
#    |- Currently banned: 0
#    |- Total banned:     0
#    `- Banned IP list:
```

#### 6.4 Test External SSH Access

**Important**: This step requires you to test from an external network (not your local network).

Options:
- Use mobile phone hotspot (disable WiFi on laptop)
- Use VPN connection to different location
- Ask friend on different network to test

```bash
# From external network (e.g., mobile hotspot):
ssh -p 2222 -i ~/.ssh/proxmox_external root@viljo.se

# If successful: External access is working!
# If fails: Check troubleshooting section below
```

#### 6.5 Verify DNS Resolution

```bash
# Check DNS resolves to your external IP
dig viljo.se +short

# Compare with your actual external IP
curl -4 https://icanhazip.com/

# These should match
```

#### 6.6 Verify Audit Logging

```bash
# On Proxmox host:
tail -f /var/log/auth.log

# In another terminal, make SSH connection
# You should see log entries like:
# Oct 20 14:23:45 mother sshd[12345]: Accepted publickey for root from 1.2.3.4 port 54321 ssh2: ED25519 SHA256:...
```

### Phase 7: Security Hardening Verification (5 minutes)

#### 7.1 Trigger fail2ban Test

From external network, intentionally fail authentication 6 times:

```bash
# This will fail 6 times and trigger ban
for i in {1..6}; do
  ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@viljo.se -p 2222
done

# Check if you're banned (on Proxmox):
ssh root@192.168.1.3
sudo fail2ban-client status sshd

# Your IP should appear in "Banned IP list"
```

**Unban yourself**:

```bash
# On Proxmox:
sudo fail2ban-client set sshd unbanip YOUR_EXTERNAL_IP
```

#### 7.2 Verify SSH Configuration

```bash
# On Proxmox:
sshd -T | grep -E 'passwordauthentication|permitrootlogin|pubkeyauthentication'

# Expected output:
# permitrootlogin without-password
# passwordauthentication no
# pubkeyauthentication yes
```

## Configuration Summary

After successful deployment, your setup will be:

```
External User (anywhere)
    ↓ (resolves DNS)
viljo.se → [External IP]
    ↓ (connects to port 2222)
Router Port Forward: 2222 → 192.168.1.3:22
    ↓ (forwards traffic)
Proxmox Host SSH (192.168.1.3:22)
    ↓ (authenticates)
fail2ban (monitors) + authorized_keys (validates)
    ↓ (logs to)
/var/log/auth.log + Wazuh (optional)
```

## Troubleshooting

### Issue: Cannot connect externally, "Connection refused"

**Diagnosis**:
```bash
# Check port forwarding is active on router
# Check firewall allows inbound on port 2222
# Verify external IP matches DNS:
curl -4 https://icanhazip.com/
dig viljo.se +short
```

**Solution**:
- Verify router port forwarding rule is enabled
- Check ISP doesn't block port 2222 (try different port)
- Ensure router firewall allows inbound TCP on port 2222

### Issue: Cannot connect externally, "Connection timeout"

**Diagnosis**:
- Port forwarding not configured correctly
- External port blocked by ISP
- DNS not resolving correctly

**Solution**:
```bash
# Test external port is open (from external network):
nc -zv viljo.se 2222

# If fails, check router logs
# Try different external port (22, 443, 8022)
```

### Issue: "Permission denied (publickey)"

**Diagnosis**:
- SSH key not in authorized_keys
- Wrong private key being used
- File permissions incorrect

**Solution**:
```bash
# On Proxmox, check authorized_keys:
cat /root/.ssh/authorized_keys

# Verify your public key is present
# Check permissions:
ls -la /root/.ssh/
# Should show:
# drwx------ (700) for .ssh directory
# -rw------- (600) for authorized_keys file

# Fix permissions if needed:
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
```

### Issue: DNS not resolving / old IP address

**Diagnosis**:
```bash
# Check current DNS value
dig viljo.se +short

# Check external IP
curl -4 https://icanhazip.com/

# Check loopia_ddns logs on Proxmox
journalctl -u loopia-ddns -n 50
```

**Solution**:
```bash
# Manually trigger DDNS update (if cron-based):
ssh root@192.168.1.3
/path/to/loopia-ddns-update.sh

# Or re-run Ansible playbook with DDNS role
ansible-playbook playbooks/external-ssh-access.yml --tags ddns
```

### Issue: fail2ban not banning attackers

**Diagnosis**:
```bash
# On Proxmox:
systemctl status fail2ban
fail2ban-client status sshd

# Check fail2ban is monitoring correct log
tail /var/log/fail2ban.log
```

**Solution**:
```bash
# Restart fail2ban
systemctl restart fail2ban

# Verify jail is active
fail2ban-client status

# Check filter is matching log entries
fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf
```

## Rollback Procedure

If you need to undo these changes:

```bash
# 1. Remove port forwarding rule from router (via web UI)

# 2. Restore previous SSH config on Proxmox:
ssh root@192.168.1.3
sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
sudo systemctl restart sshd

# 3. Disable fail2ban:
sudo systemctl stop fail2ban
sudo systemctl disable fail2ban

# 4. Remove DNS A record (via Loopia web UI) or set to old IP

# 5. Re-run Ansible with hardening disabled:
ansible-playbook playbooks/external-ssh-access.yml -e "proxmox_ssh_hardening_enabled=false"
```

## Maintenance Tasks

### Rotate SSH Keys (Annually)

1. Generate new key pair
2. Add new public key to Ansible Vault
3. Deploy new key alongside old: `proxmox_ssh_authorized_keys` (append)
4. Test connection with new key
5. Remove old key from list
6. Re-run playbook

### Monitor fail2ban Bans

```bash
# Weekly check:
ssh root@192.168.1.3
fail2ban-client status sshd

# Review banned IPs
# If legitimate IP banned, unban:
fail2ban-client set sshd unbanip IP_ADDRESS
```

### Verify DDNS Updates

```bash
# Monthly check:
dig viljo.se +short
curl -4 https://icanhazip.com/

# Should match - if not, investigate loopia_ddns logs
```

## Next Steps

After successful deployment:

1. **Update documentation**: Add connection info to runbooks
2. **Set up monitoring**: Configure alerts for failed SSH attempts
3. **Team onboarding**: Distribute connection instructions to team
4. **Schedule key rotation**: Add calendar reminder for annual key rotation
5. **Consider enhancements**:
   - Multi-factor authentication (Google Authenticator)
   - SSH certificate authority
   - Bastion host for other infrastructure

## Reference Links

- [OpenSSH Security Best Practices](https://infosec.mozilla.org/guidelines/openssh)
- [fail2ban Documentation](https://www.fail2ban.org/wiki/index.php/Main_Page)
- [Loopia DNS API Docs](https://www.loopia.com/api/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- Project Constitution: `.specify/memory/constitution.md`
- Feature Specification: `specs/003-external-ssh-admin/spec.md`

## Support

For issues or questions:

1. Check troubleshooting section above
2. Review Ansible playbook logs
3. Check fail2ban and SSH logs on Proxmox
4. Consult project documentation in `docs/`
