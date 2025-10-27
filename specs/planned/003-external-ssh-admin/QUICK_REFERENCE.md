# External SSH Access - Quick Reference Guide

**Feature**: 003-external-ssh-admin
**Status**: Ready for Deployment
**Last Updated**: 2025-10-27

## Network Flow Diagram

```
Internet User
    ↓
ssh root@viljo.se (DNS resolves to Firewall WAN IP)
    ↓
Firewall Container (LXC 101) - vmbr2 WAN
    ↓ DNAT: tcp port 22 → 172.16.10.102:22
    ↓
Proxmox Host - 172.16.10.102 (vmbr3 DMZ)
    ↓ SSH Authentication (key-based)
    ↓
Shell Access Granted
```

## Quick Commands

### Deployment

```bash
# Deploy SSH hardening and fail2ban
cd /Users/anders/git/Proxmox_config
ansible-playbook playbooks/external-ssh-access.yml --ask-vault-pass

# Deploy SSH only
ansible-playbook playbooks/external-ssh-access.yml --tags ssh

# Deploy fail2ban only (requires proxmox_fail2ban_enabled: true)
ansible-playbook playbooks/external-ssh-access.yml --tags fail2ban
```

### Testing

```bash
# Run comprehensive test suite
ansible-playbook playbooks/external-ssh-test.yml

# Test internal access (from local network)
ssh root@172.16.10.102

# Test external access (from internet)
ssh root@viljo.se
```

### Verification

```bash
# On Proxmox host:

# Check SSH configuration
sshd -T | grep -E 'passwordauthentication|permitrootlogin|pubkeyauthentication'

# Expected output:
# permitrootlogin without-password
# passwordauthentication no
# pubkeyauthentication yes

# Check SSH service status
systemctl status sshd

# Verify fail2ban (if enabled)
fail2ban-client status sshd

# Monitor SSH logs
journalctl -u sshd -f
tail -f /var/log/auth.log

# Check firewall DNAT rules
pct exec 101 -- nft list ruleset | grep -A2 "dnat to 172.16.10.102"
```

### Troubleshooting

```bash
# Validate SSH configuration syntax
sshd -t

# Check authorized keys
cat /root/.ssh/authorized_keys
ls -la /root/.ssh/

# Restart SSH service
systemctl restart sshd

# Restart fail2ban
systemctl restart fail2ban

# Unban IP from fail2ban
fail2ban-client set sshd unbanip <IP_ADDRESS>

# Check DNS resolution
dig viljo.se +short

# Test firewall connectivity
pct exec 101 -- ip addr show eth0
pct exec 101 -- ip addr show eth1
```

## Key Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| SSH Config | Hardened SSH daemon configuration | `/etc/ssh/sshd_config` |
| Authorized Keys | SSH public keys for authentication | `/root/.ssh/authorized_keys` |
| Fail2ban Local | Global fail2ban settings | `/etc/fail2ban/jail.d/local.conf` |
| Fail2ban SSH | SSH-specific jail configuration | `/etc/fail2ban/jail.d/sshd.conf` |
| Auth Logs | SSH authentication logs | `/var/log/auth.log` |
| Fail2ban Logs | Ban/unban events | `/var/log/fail2ban.log` |
| Firewall Config | nftables rules (DNAT) | `/etc/nftables.conf` (in LXC 101) |

## Important Variables

```yaml
# Network Configuration
dmz_host_ip: 172.16.10.102              # Proxmox host IP on DMZ
wan_bridge: vmbr2                        # WAN bridge
public_bridge: vmbr3                     # DMZ bridge
firewall_container_id: 101               # Firewall LXC ID
public_domain: viljo.se                  # External domain

# SSH Configuration
proxmox_ssh_port: 22                     # SSH port
proxmox_ssh_password_auth: false         # Disable password auth externally
proxmox_ssh_permit_root_login: without-password  # Key-only root login
proxmox_ssh_internal_network_rules: true # Allow password from internal nets

# Fail2ban Configuration
proxmox_fail2ban_enabled: false          # Enable for production
proxmox_fail2ban_maxretry: 5             # Failures before ban
proxmox_fail2ban_findtime: 600           # 10 minute window
proxmox_fail2ban_bantime: 3600           # 1 hour ban
```

## Security Checklist

- [ ] SSH password authentication disabled for external access
- [ ] SSH key-based authentication configured
- [ ] At least one authorized key added to Proxmox host
- [ ] Fail2ban enabled and running (optional but recommended)
- [ ] Firewall DNAT rule configured (port 22 → 172.16.10.102)
- [ ] DNS points to firewall WAN IP
- [ ] Tested internal SSH access
- [ ] Tested external SSH access
- [ ] Verified logging to /var/log/auth.log
- [ ] Monitored fail2ban bans (if enabled)

## Common Issues

### Issue: "Permission denied (publickey)"

**Cause**: SSH key not in authorized_keys or wrong key being used

**Solution**:
```bash
# Verify authorized_keys exists and has correct permissions
ssh root@172.16.10.102
ls -la /root/.ssh/authorized_keys
cat /root/.ssh/authorized_keys

# Should show:
# -rw------- 1 root root <size> <date> /root/.ssh/authorized_keys

# Fix permissions if needed:
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
```

### Issue: "Connection refused" from external network

**Cause**: DNS not resolving or firewall DNAT not configured

**Solution**:
```bash
# Check DNS resolution
dig viljo.se +short

# Should return firewall WAN IP

# Check DNAT rules
ssh root@172.16.10.102
pct exec 101 -- nft list ruleset | grep dnat

# Should show: dnat to 172.16.10.102
```

### Issue: Accidentally locked out

**Cause**: SSH configuration error or all keys removed

**Solution**:
```bash
# Access via Proxmox console (not SSH)
# From Proxmox web UI: Container → Console

# Restore SSH config from backup
cp /etc/ssh/sshd_config.backup-* /etc/ssh/sshd_config
systemctl restart sshd

# Or temporarily enable password auth
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
systemctl restart sshd
```

### Issue: Fail2ban banning legitimate IPs

**Cause**: Too aggressive ban settings or legitimate IP not whitelisted

**Solution**:
```bash
# Unban IP immediately
fail2ban-client set sshd unbanip <IP>

# Add to whitelist (edit /etc/fail2ban/jail.d/local.conf)
ignoreip = 127.0.0.1/8 192.168.0.0/16 172.16.0.0/12 10.0.0.0/8 <YOUR_IP>

# Restart fail2ban
systemctl restart fail2ban
```

## Important Network Topology Notes

**CRITICAL**: The Proxmox host has TWO network interfaces:

1. **Management Network** (vmbr0):
   - IP: 192.168.1.3
   - ISP: Starlink (CGNAT)
   - Purpose: Local management ONLY
   - Internet: NO ACCESS (by design)

2. **DMZ Network** (vmbr3):
   - IP: 172.16.10.102
   - Gateway: 172.16.10.101 (Firewall)
   - Purpose: Production services
   - Internet: Via firewall NAT

**External SSH access uses the DMZ IP (172.16.10.102), NOT the management IP (192.168.1.3).**

## Monitoring Recommendations

### Daily
- Check fail2ban bans: `fail2ban-client status sshd`
- Review recent SSH connections: `journalctl -u sshd --since today | grep Accepted`

### Weekly
- Review authentication failures: `grep "Failed password" /var/log/auth.log | tail -50`
- Check disk space used by logs: `du -sh /var/log/`

### Monthly
- Review all SSH access patterns
- Verify DNS still resolves correctly
- Test external access from different locations

### Annually
- Rotate SSH keys
- Review and update fail2ban configuration
- Test disaster recovery procedures

## Support Documentation

- Full implementation: `specs/planned/003-external-ssh-admin/IMPLEMENTATION_REPORT.md`
- Detailed guide: `specs/planned/003-external-ssh-admin/quickstart.md`
- Network architecture: `docs/NETWORK_ARCHITECTURE.md`
- Data model: `specs/planned/003-external-ssh-admin/data-model.md`

---

**Quick Reference Version**: 1.0
**For Production Use**
**Last Updated**: 2025-10-27
