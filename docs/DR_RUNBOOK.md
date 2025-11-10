# Disaster Recovery Runbook

**Version**: 1.0
**Last Updated**: 2025-11-10
**Next Review**: 2025-12-10

---

## ⚠️ CRITICAL WARNING: OUTDATED DOCUMENTATION

**This DR runbook is OUTDATED and describes a fictional infrastructure that was never deployed.**

**Documented (but never existed)**:
- 10+ individual service LXC containers
- Firewall LXC container (101)
- DMZ network on vmbr3 (172.16.10.0/24)
- Individual container backups for each service

**Actual current architecture** (as of 2025-11-10):
- **Single LXC container**: Coolify (ID: 200)
- **All services**: Run as Docker containers inside Coolify
- **No firewall container**: Direct internet access via vmbr2
- **No DMZ network**: vmbr3 created but unused

## Current DR Procedures (Simplified)

### Quick Recovery for Coolify Architecture

**If you need to recover NOW, follow these steps instead**:

1. **Verify Coolify LXC backup exists**:
   ```bash
   ssh root@192.168.1.3
   pvesm list local | grep "vzdump-lxc-200"
   ```

2. **Restore Coolify LXC container**:
   ```bash
   BACKUP=$(pvesm list local | grep "vzdump-lxc-200" | tail -1 | awk '{print $1}')
   pct restore 200 "$BACKUP" --storage local-lvm
   pct start 200
   ```

3. **Verify Coolify is running**:
   ```bash
   pct status 200
   curl -s http://192.168.1.200:8000/health
   ```

4. **Check Docker containers**:
   ```bash
   pct exec 200 -- docker ps
   ```

5. **Access Coolify dashboard**: https://paas.viljo.se

For complete current architecture details, see:
- [Network Topology](architecture/network-topology.md)
- [Container Mapping](architecture/container-mapping.md)
- [ADR-001: Network Architecture Decision](adr/001-network-topology-change.md)

---

## Historical Documentation (Outdated)

The procedures below describe recovering a multi-container infrastructure that was **never actually deployed**. This is retained for historical reference only.

## Purpose (Historical)

This runbook provides step-by-step procedures for recovering the Proxmox infrastructure from backups after a disaster. Follow these procedures in order for the fastest recovery.

**Target RTO**: < 1 hour
**Target RPO**: < 24 hours (daily backups)

## Prerequisites

### Required Access

- [ ] Physical or remote access to Proxmox host (192.168.1.3)
- [ ] Root credentials for Proxmox host
- [ ] Vault password file (`.vault_pass.txt`) or knowledge of vault password
- [ ] Network connectivity (admin network 192.168.1.0/16 or internet via bastion)

### Required Resources

- [ ] Proxmox VE 9 installed and running
- [ ] Storage available: ~100GB for container restores + data
- [ ] Network bridges configured (vmbr0, vmbr2, vmbr3)
- [ ] Backups accessible in `/var/lib/vz/dump/` or mounted backup storage

### Required Files

- [ ] This git repository cloned: `git clone https://github.com/viljo/Proxmox_config.git`
- [ ] Ansible installed (on control machine)
- [ ] SSH keys configured for Proxmox access

## Disaster Recovery Scenarios

### Scenario A: Complete Infrastructure Loss
**Use Case**: Entire Proxmox host rebuilt, all containers lost
**Recovery Method**: Restore from backups (this runbook)
**Estimated Time**: 30-60 minutes

### Scenario B: Partial Container Loss
**Use Case**: Some containers corrupted, Proxmox host intact
**Recovery Method**: Selective restore (see [Selective Recovery](#selective-recovery))
**Estimated Time**: 10-20 minutes

### Scenario C: Data Corruption Only
**Use Case**: Containers intact, data corrupted (databases, files)
**Recovery Method**: Data-level restore (see [Data-Only Restore](#data-only-restore))
**Estimated Time**: 15-30 minutes

---

## Complete Infrastructure Recovery

Use this procedure when recovering from complete infrastructure loss.

### Phase 1: Verify Backups (5 minutes)

**Objective**: Confirm backups exist and are accessible

```bash
# Connect to Proxmox host
ssh root@192.168.1.3

# List available backups
pvesm list local | grep vzdump-lxc | head -20

# Check backup dates
pvesm list local | grep vzdump-lxc | awk '{print $1}' | grep -oP '\d{4}_\d{2}_\d{2}' | sort -u | tail -5

# Verify backup sizes (should not be 0)
pvesm list local | grep vzdump-lxc | awk '{print $1, $4}' | head -10
```

**Expected Output**:
- Backups exist for containers: 101, 110, 150, 151, 153, 154, 155, 158, 160, 170
- Latest backup date within last 24 hours
- Backup sizes reasonable (> 100MB for most)

**⚠️ If backups missing or old**:
- Check backup storage mount
- Restore from off-site backup (if available)
- Escalate: Backups older than RPO

### Phase 2: Restore Firewall First (2 minutes)

**Objective**: Restore firewall to provide NAT for DMZ containers

**Why First**: DMZ containers need internet access during deployment. The firewall provides NAT routing.

```bash
# Method 1: Use quick-restore script
cd /root/Proxmox_config
bash scripts/restore-firewall.sh

# Method 2: Manual restore
BACKUP=$(pvesm list local | grep "vzdump-lxc-101" | tail -1 | awk '{print $1}')
pct restore 101 "$BACKUP" --storage local-lvm
pct start 101
sleep 10
```

**Verification**:
```bash
# Check firewall is running
pct status 101

# Verify NAT rules loaded (should see MASQUERADE)
pct exec 101 -- iptables -t nat -L POSTROUTING | grep MASQUERADE
```

**⚠️ If firewall fails**:
- Check for conflicting container IDs
- Try alternative backup timestamp
- Check network bridge configuration (`ip link show vmbr2`)

### Phase 3: Restore Remaining Containers (10 minutes)

**Objective**: Restore all infrastructure containers from backups

```bash
# Restore all containers (excluding firewall 101, already restored)
for id in 110 150 151 154 155 158 160 170; do
  echo "=== Restoring container $id ==="
  BACKUP=$(pvesm list local | grep "vzdump-lxc-$id" | tail -1 | awk '{print $1}')

  if [ -n "$BACKUP" ]; then
    echo "Using backup: $BACKUP"
    pct restore $id "$BACKUP" --storage local-lvm
    pct start $id
    echo "✓ Container $id restored"
  else
    echo "✗ No backup found for container $id"
  fi
  echo ""
done

# Check status
pct list
```

**Expected Result**: 9 containers restored (101, 110, 150, 151, 154, 155, 158, 160, 170)

**Note**: Container 153 (GitLab) may fail due to backup corruption (known issue). Skip if necessary.

**⚠️ If container restore fails**:
- Check error message (checksum error = corrupted backup)
- Try earlier backup: `pvesm list local | grep "vzdump-lxc-$id" | head -3`
- Skip container and continue (can restore later)

### Phase 4: Restore Data (Optional, 15-30 minutes)

**Objective**: Restore databases, Redis, and Docker volumes if needed

**When to Skip**: If container backups are recent (< 1 hour old) and no data changes since backup

**When Required**: If containers restored from old backup or data-only recovery needed

```bash
# Navigate to Ansible directory
cd /root/Proxmox_config

# Find latest data backup timestamp
ssh root@192.168.1.3 "ls -1 /var/backups/infrastructure/ | tail -1"
# Example output: 20251023T234308

# Run data restoration playbook
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  --vault-password-file=.vault_pass.txt \
  -e restore_backup_timestamp=20251023T234308

# Or test first with dry-run
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  --vault-password-file=.vault_pass.txt \
  -e restore_backup_timestamp=20251023T234308 \
  -e restore_dry_run=true
```

**What This Restores**:
- PostgreSQL databases (keycloak, gitlab, nextcloud, mattermost)
- Redis persistence data
- Docker volumes (Keycloak, GitLab, Nextcloud, Mattermost, Webtop)

**⚠️ If data restore fails**:
- Check database connectivity: `pct exec 150 -- su - postgres -c 'psql -l'`
- Check Redis: `pct exec 158 -- systemctl status redis-server`
- Review restore playbook logs
- Try manual restoration (see [Manual Data Restore](#manual-data-restore))

### Phase 5: Verify Services (10 minutes)

**Objective**: Confirm all critical services are operational

```bash
# 1. PostgreSQL
echo "=== PostgreSQL ==="
pct exec 150 -- su - postgres -c 'psql -l' | grep -E 'keycloak|gitlab|nextcloud|mattermost'

# 2. Redis
echo "=== Redis ==="
pct exec 158 -- systemctl status redis-server | head -5
pct exec 158 -- redis-cli ping

# 3. Docker Services
echo "=== Keycloak ==="
pct exec 151 -- docker ps | grep keycloak

echo "=== GitLab ==="
pct exec 153 -- docker ps | grep gitlab  # May fail if container 153 not restored

echo "=== Nextcloud ==="
pct exec 155 -- docker ps | grep nextcloud

echo "=== Mattermost ==="
pct exec 163 -- docker ps | grep mattermost

echo "=== Webtop ==="
pct exec 170 -- docker ps | grep webtop

echo "=== Demo Site ==="
pct exec 160 -- docker ps | grep -E 'links|matrix'

# 4. External Access (from control machine)
echo "=== External Access ==="
curl -I https://keycloak.viljo.se
curl -I https://gitlab.viljo.se
curl -I https://nextcloud.viljo.se
curl -I https://mattermost.viljo.se
curl -I https://browser.viljo.se
curl -I https://demosite.viljo.se
```

**Success Criteria**:
- [ ] PostgreSQL responding with all 4 databases
- [ ] Redis responding with PONG
- [ ] At least 5 out of 6 Docker services running
- [ ] External HTTPS access working (200 or 302 responses)

**⚠️ If services not running**:
- Check service logs: `pct exec <id> -- docker logs <service>`
- Restart services: `pct exec <id> -- systemctl restart docker`
- Check Traefik routing: `systemctl status traefik`

### Phase 6: Update External DNS (5 minutes)

**Objective**: Ensure external domains point to correct IP

```bash
# Check current public IP
curl -4 ifconfig.me

# Update Loopia DDNS (should auto-update every 15 minutes)
systemctl status loopia-ddns | head -10

# Or manually trigger
systemctl restart loopia-ddns

# Verify DNS resolution
for domain in keycloak gitlab nextcloud mattermost browser demosite ssh; do
  echo "$domain.viljo.se -> $(dig +short $domain.viljo.se A @1.1.1.1)"
done
```

**Expected**: All domains resolve to current public IP (usually 85.24.186.100)

---

## Selective Recovery

Use when only specific containers need restoration.

### Single Container Restore

```bash
# Replace 150 with desired container ID
CONTAINER_ID=150

# Stop container if running
pct stop $CONTAINER_ID || true

# Destroy container
pct destroy $CONTAINER_ID

# Find latest backup
BACKUP=$(pvesm list local | grep "vzdump-lxc-$CONTAINER_ID" | tail -1 | awk '{print $1}')

# Restore
pct restore $CONTAINER_ID "$BACKUP" --storage local-lvm

# Start
pct start $CONTAINER_ID

# Verify
pct status $CONTAINER_ID
```

### Multiple Container Restore

```bash
# List containers to restore
CONTAINERS="150 151 155"

for id in $CONTAINERS; do
  echo "Restoring container $id..."
  pct stop $id || true
  pct destroy $id || true
  BACKUP=$(pvesm list local | grep "vzdump-lxc-$id" | tail -1 | awk '{print $1}')
  pct restore $id "$BACKUP" --storage local-lvm
  pct start $id
done
```

---

## Data-Only Restore

Use when containers are intact but data is corrupted.

### Prerequisites

- [ ] Containers running
- [ ] Backup timestamp identified
- [ ] Vault password available

### Procedure

```bash
cd /root/Proxmox_config

# Test with dry-run first
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  --vault-password-file=.vault_pass.txt \
  -e restore_backup_timestamp=20251023T234308 \
  -e restore_dry_run=true

# Review output, then run actual restore
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  --vault-password-file=.vault_pass.txt \
  -e restore_backup_timestamp=20251023T234308
```

### Selective Data Restore

```bash
# PostgreSQL only
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  --vault-password-file=.vault_pass.txt \
  -e restore_backup_timestamp=20251023T234308 \
  -e restore_redis_enabled=false \
  -e restore_docker_volumes_enabled=false

# Redis only
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  --vault-password-file=.vault_pass.txt \
  -e restore_backup_timestamp=20251023T234308 \
  -e restore_postgresql_enabled=false \
  -e restore_docker_volumes_enabled=false

# Docker volumes only
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  --vault-password-file=.vault_pass.txt \
  -e restore_backup_timestamp=20251023T234308 \
  -e restore_postgresql_enabled=false \
  -e restore_redis_enabled=false
```

---

## Manual Data Restore

Use if automated restoration fails.

### PostgreSQL Manual Restore

```bash
# Copy backup to PostgreSQL container
TIMESTAMP="20251023T234308"
pct push 150 /var/backups/infrastructure/$TIMESTAMP/postgresql/keycloak_$TIMESTAMP.dump /tmp/keycloak.dump

# Restore database (inside container)
pct exec 150 -- su - postgres -c "pg_restore -d keycloak --clean --if-exists --no-owner --no-acl /tmp/keycloak.dump"

# Cleanup
pct exec 150 -- rm /tmp/keycloak.dump
```

### Redis Manual Restore

```bash
# Stop Redis
pct exec 158 -- systemctl stop redis-server

# Copy dump.rdb
TIMESTAMP="20251023T234308"
pct push 158 /var/backups/infrastructure/$TIMESTAMP/redis_$TIMESTAMP.rdb /var/lib/redis/dump.rdb

# Fix ownership
pct exec 158 -- chown redis:redis /var/lib/redis/dump.rdb
pct exec 158 -- chmod 640 /var/lib/redis/dump.rdb

# Start Redis
pct exec 158 -- systemctl start redis-server
```

### Docker Volume Manual Restore

```bash
# Example: Restore Nextcloud data
TIMESTAMP="20251023T234308"
CONTAINER=155

# Stop Docker service
pct exec $CONTAINER -- systemctl stop docker

# Copy and extract
pct push $CONTAINER /var/backups/infrastructure/$TIMESTAMP/docker-volumes/nextcloud_opt-nextcloud_$TIMESTAMP.tar.gz /tmp/restore.tar.gz
pct exec $CONTAINER -- tar xzf /tmp/restore.tar.gz -C /opt/nextcloud
pct exec $CONTAINER -- rm /tmp/restore.tar.gz

# Start Docker service
pct exec $CONTAINER -- systemctl start docker
```

---

## Troubleshooting

### Container Won't Start

**Symptoms**: `pct start` fails or container immediately stops

**Causes**:
- Configuration error in `/etc/pve/lxc/<id>.conf`
- Storage not accessible
- Network bridge missing
- Resource conflict (memory, CPU)

**Resolution**:
```bash
# Check configuration
pct config <id>

# Check logs
journalctl -u pve-container@<id> | tail -50

# Try starting with debug
pct start <id> --debug

# Check storage
pvesm status

# Check network bridges
ip link show | grep vmbr
```

### Service Won't Start Inside Container

**Symptoms**: Container running but service failed

**Causes**:
- Service configuration error
- Dependencies not met
- Port already in use
- Permission issues

**Resolution**:
```bash
# Check service status
pct exec <id> -- systemctl status <service>

# Check service logs
pct exec <id> -- journalctl -u <service> -n 50

# Check for port conflicts
pct exec <id> -- netstat -tulpn | grep <port>

# Try manual start
pct exec <id> -- systemctl restart <service>
```

### Backup Corrupted

**Symptoms**: Restore fails with checksum error

**Known Issue**: GitLab backups may be corrupted (all timestamps)

**Resolution**:
1. Try earlier backup timestamps
2. Deploy container from automation instead:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/<service>-deploy.yml
   ```
3. Restore data only (skip container restore)

### Network Issues

**Symptoms**: Containers can't reach internet or each other

**Causes**:
- Firewall not running
- Network bridges down
- Routing configuration missing

**Resolution**:
```bash
# Check firewall
pct status 101
pct exec 101 -- iptables -t nat -L POSTROUTING

# Restart firewall
./scripts/restore-firewall.sh

# Check bridges
ip link show | grep vmbr
brctl show

# Test connectivity from DMZ
pct exec 150 -- ping -c 2 8.8.8.8
```

### External Access Fails

**Symptoms**: Services internal but not reachable from internet

**Causes**:
- Traefik not running
- DNS not updated
- Firewall port forwarding missing
- Certificate issues

**Resolution**:
```bash
# Check Traefik
systemctl status traefik
journalctl -u traefik -f

# Check DNS
dig +short <service>.viljo.se A @1.1.1.1

# Restart Traefik
systemctl restart traefik

# Check certificates
ls -lh /etc/traefik/acme/acme.json
```

---

## Post-Recovery Checklist

After recovery is complete, verify:

- [ ] All containers running (`pct list`)
- [ ] All services responding (see [Phase 5](#phase-5-verify-services-10-minutes))
- [ ] External HTTPS access working
- [ ] SSH access via bastion working
- [ ] Backups scheduled and running
- [ ] Monitoring alerts cleared
- [ ] Incident report created
- [ ] Post-mortem scheduled
- [ ] DR test results updated

---

## Recovery Time Tracking

Record actual times for future RTO planning:

| Phase | Target | Actual | Notes |
|-------|--------|--------|-------|
| Backup verification | 5 min | _____ | |
| Firewall restore | 2 min | _____ | |
| Container restore | 10 min | _____ | |
| Data restore | 30 min | _____ | |
| Service verification | 10 min | _____ | |
| DNS update | 5 min | _____ | |
| **Total RTO** | **62 min** | **_____** | |

---

## Escalation

If recovery cannot be completed within RTO or critical issues encountered:

1. **Level 1**: Check this runbook and troubleshooting section
2. **Level 2**: Review DR test reports in `docs/DR_TEST_*`
3. **Level 3**: Contact infrastructure team
4. **Level 4**: Engage external support (Proxmox, vendors)

---

## Related Documents

- [DR Test Report (2025-10-23)](DR_TEST_REPORT_2025-10-23.md)
- [DR Test Lessons Learned](DR_TEST_LESSONS_LEARNED.md)
- [Vault Variables Documentation](VAULT_VARIABLES.md)
- [Backup Infrastructure Role](../roles/backup_infrastructure/README.md)
- [Restore Infrastructure Role](../roles/restore_infrastructure/README.md)

---

**Document Owner**: Infrastructure Team
**Review Frequency**: After each DR test (monthly)
**Last DR Test**: 2025-10-23
**Next DR Test**: 2025-11-23
