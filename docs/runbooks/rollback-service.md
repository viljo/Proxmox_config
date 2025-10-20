# Rollback Service Deployment

**Category**: Deployment / Incident Response
**Estimated Time**: 5-15 minutes
**Risk Level**: Medium
**Prerequisites**: Root SSH access to Proxmox host, backup snapshot exists

## Symptoms / Indicators

Rollback is needed when:
- Service fails to start after deployment
- Service starts but is non-functional
- Performance degradation after update
- Security issue discovered in new version

## Prerequisites

- Root SSH access to Proxmox host (`ssh root@192.168.1.3`)
- Knowledge of LXC container ID (check `pct list`)
- Recent backup snapshot (created before deployment)
- Access to Ansible vault password (if configuration rollback needed)

## Procedure

### Step 1: Identify Container and Snapshot

```bash
# List all containers
pct list

# List snapshots for specific container (example: GitLab = 53)
pct listsnapshot <VMID>

# Example:
pct listsnapshot 53
```

**Expected Result**: List of snapshots with timestamps
**If no snapshots exist**: Proceed to Step 5 (manual rollback)

### Step 2: Stop the Container

```bash
# Stop the container gracefully
pct stop <VMID>

# Example:
pct stop 2050

# Verify stopped
pct status <VMID>
```

**Expected Result**: Container status shows "stopped"
**If it fails**: Force stop with `pct stop <VMID> --force`

### Step 3: Rollback to Snapshot

```bash
# Rollback to most recent snapshot
pct rollback <VMID> <SNAPSHOT_NAME>

# Example:
pct rollback 53 pre-upgrade-20251020

# Alternative: List snapshots first to choose
pct listsnapshot 53
pct rollback 53 <chosen-snapshot>
```

**Expected Result**: "rollback snapshot successful" message
**If it fails**: Check snapshot exists and disk space available

### Step 4: Start Container

```bash
# Start the container
pct start <VMID>

# Wait for boot
sleep 10

# Verify running
pct status <VMID>
```

**Expected Result**: Container status shows "running"
**If it fails**: Check logs with `pct enter <VMID>` then `journalctl -xe`

### Step 5: Manual Rollback (if no snapshot)

If no snapshot exists, manual rollback is required:

```bash
# Enter container
pct enter <VMID>

# For GitLab: Check installed version
gitlab-rake gitlab:env:info | grep GitLab

# Downgrade package (example for GitLab)
apt-get install gitlab-ce=<previous-version>

# Reconfigure
gitlab-ctl reconfigure

# Restart services
gitlab-ctl restart

# Exit container
exit
```

### Step 6: Verify Service Functionality

Check service-specific health:

**GitLab:**
```bash
curl -k https://gitlab.example.com/-/health
pct exec 2050 -- gitlab-rake gitlab:check
```

**Nextcloud:**
```bash
curl -k https://nextcloud.example.com/status.php
pct exec <VMID> -- sudo -u www-data php occ status
```

**Traefik:**
```bash
systemctl status traefik
curl http://localhost:8080/api/overview  # Dashboard API
```

**Expected Result**: Service responds with healthy status
**If it fails**: Check service logs (proceed to Common Issues)

### Step 7: Revert Ansible Configuration (if needed)

If Ansible configuration was updated:

```bash
# Check out previous version of role
cd /path/to/ansible/repo
git log --oneline roles/<service>/  # Find previous commit
git checkout <commit-hash> -- roles/<service>/

# Re-run playbook with old configuration
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags <service>

# Commit the revert
git commit -m "Rollback <service> to previous version"
```

### Step 8: Document Incident

Create incident report:

```bash
# In docs/incidents/ directory
cat > docs/incidents/$(date +%Y%m%d)-<service>-rollback.md << EOF
# <Service> Rollback - $(date +%Y-%m-%d)

## Summary
Service rolled back due to [reason]

## Timeline
- [Time]: Deployment started
- [Time]: Issue detected
- [Time]: Rollback initiated
- [Time]: Service restored

## Root Cause
[Why the deployment failed]

## Resolution
Rolled back to snapshot: [snapshot name]

## Follow-Up Actions
- [ ] Investigate root cause
- [ ] Fix deployment issue
- [ ] Test in staging
- [ ] Re-deploy with fix
EOF
```

## Verification

After rollback, verify:

- [ ] Service is responding (check HTTPS URL)
- [ ] Service health check passes
- [ ] No error logs in service output
- [ ] Monitoring shows service as healthy (Zabbix, Grafana)
- [ ] Users can access service normally
- [ ] Incident documented

## Rollback of Rollback (Re-deployment)

If you need to try the upgrade again:

1. Investigate and fix the issue that caused rollback
2. Test fix in staging environment
3. Create new snapshot: `pct snapshot <VMID> pre-retry-$(date +%Y%m%d-%H%M)`
4. Re-run deployment procedure
5. Monitor closely for same issue

## Common Issues

### Issue 1: Snapshot Rollback Fails - Disk Full

**Symptoms**: "No space left on device" error during rollback

**Solution**:
```bash
# Check disk space
df -h
pvs
lvs

# Free up space
vzdump --remove <old-backup-id>

# Retry rollback
pct rollback <VMID> <SNAPSHOT>
```

### Issue 2: Service Won't Start After Rollback

**Symptoms**: Container starts but service fails to start

**Solution**:
```bash
# Enter container
pct enter <VMID>

# Check service status
systemctl status <service>

# View logs
journalctl -u <service> -n 100 --no-pager

# Check for configuration issues
<service-specific-check-command>

# Try manual service restart
systemctl restart <service>
```

### Issue 3: Database Schema Mismatch

**Symptoms**: "Database schema version mismatch" errors

**Solution**:
```bash
# For GitLab:
pct exec <VMID> -- gitlab-rake db:migrate:status
pct exec <VMID> -- gitlab-rake db:migrate:down VERSION=<version>

# For other services: Restore database from backup
# See: docs/runbooks/backup-restore.md
```

## Related Runbooks

- `backup-restore.md` - Full backup restoration
- `service-down.md` - General service troubleshooting
- `deploy-new-service.md` - Deployment best practices

## References

- Proxmox pct documentation: https://pve.proxmox.com/pve-docs/pct.1.html
- Proxmox snapshots: https://pve.proxmox.com/wiki/Linux_Container#pct_snapshots
- GitLab backup/restore: https://docs.gitlab.com/ee/administration/backup_restore/

## Constitution Compliance

This runbook ensures **Idempotent Operations** principle:
> "Destructive operations require explicit confirmation flags or separate teardown playbooks"

Always create snapshots before deployments to enable safe rollbacks.
