# GitLab Backup Investigation Procedure

**Purpose**: Investigate and resolve 100% GitLab backup corruption discovered in DR test

**Created**: 2025-10-24
**Priority**: CRITICAL
**Status**: Investigation Required

## Problem Statement

From [DR Test Report (2025-10-23)](DR_TEST_REPORT_2025-10-23.md):

**Issue**: All GitLab container backups (3 attempts) failed with checksum errors during restore

**Evidence**:
```
# Backup 1 (23:36:39)
pct restore 153 local:backup/vzdump-lxc-153-2025_10_23-23_36_39.tar.zst
ERROR: error at entry "etc/gitlab/": crc error

# Backup 2 (23:43:18)
pct restore 153 local:backup/vzdump-lxc-153-2025_10_23-23_43_18.tar.zst
ERROR: error at entry "etc/gitlab/": crc error

# Backup 3 (23:44:56)
pct restore 153 local:backup/vzdump-lxc-153-2025_10_23-23_44_56.tar.zst
ERROR: error at entry "etc/gitlab/": crc error
```

**Impact**:
- ❌ GitLab cannot be restored from backups
- ❌ Critical service for DevOps workflows
- ❌ Source code, CI/CD pipelines at risk
- ❌ Blocks 100% DR success rate

**Success Rate**: 0% (0/3 backups restorable)

## Root Cause Hypotheses

### Hypothesis 1: GitLab Running During Backup
**Theory**: GitLab Docker container is writing to disk during backup, causing inconsistent state

**Evidence**:
- CRC errors at `etc/gitlab/` suggest files changing during archive creation
- GitLab has many active processes (Sidekiq, Gitaly, PostgreSQL, Redis, etc.)
- Large repository may be receiving commits during backup

**Likelihood**: HIGH (80%)

**Test**: Stop GitLab before backup

---

### Hypothesis 2: Compression Method (zstd)
**Theory**: zstd compression may have issues with specific file types or sizes

**Evidence**:
- Backups use `.tar.zst` (zstd compression)
- Other services with zstd backups succeeded (but smaller sizes)
- GitLab backup size: 3.5GB (largest container)

**Likelihood**: MEDIUM (40%)

**Test**: Try gzip compression instead

---

### Hypothesis 3: Docker Overlay Filesystem Issues
**Theory**: Docker's overlay filesystem may create issues during backup

**Evidence**:
- GitLab uses Docker with overlay2 storage driver
- Overlay filesystems have multiple layers
- Backup may not handle overlay metadata correctly

**Likelihood**: MEDIUM (50%)

**Test**: Use GitLab's built-in backup tools instead of container snapshots

---

### Hypothesis 4: Large File or Sparse File Handling
**Theory**: Large Git repositories or sparse files cause backup tool issues

**Evidence**:
- Git repositories can have large files
- Some files may be sparse (holes in filesystem)
- tar may have issues with large/sparse files

**Likelihood**: LOW (20%)

**Test**: Exclude large files or use different backup approach

---

### Hypothesis 5: Filesystem Corruption
**Theory**: GitLab container filesystem is already corrupted

**Evidence**:
- CRC errors could indicate existing corruption
- However, GitLab was running normally before backup

**Likelihood**: LOW (10%)

**Test**: Run filesystem check on container

---

## Investigation Procedure

### Phase 1: Validate Current State (5 minutes)

**Goal**: Ensure GitLab is healthy before investigation

```bash
# 1. Check GitLab container status
ssh root@192.168.1.3 "pct status 153"

# 2. Verify GitLab Docker is running
ssh root@192.168.1.3 "pct exec 153 -- docker ps | grep gitlab"

# 3. Check GitLab health via API
curl -I https://gitlab.viljo.se/api/v4/projects

# 4. Check container filesystem
ssh root@192.168.1.3 "pct exec 153 -- df -h"
ssh root@192.168.1.3 "pct exec 153 -- du -sh /opt/gitlab/*"
```

**Expected Results**:
- Container running
- GitLab Docker container healthy
- API returns 200 OK
- No disk space issues

---

### Phase 2: Test Hypothesis 1 - Stop GitLab During Backup (15 minutes)

**Goal**: Test if stopping GitLab prevents corruption

```bash
# 1. Access Proxmox host
ssh root@192.168.1.3

# 2. Stop GitLab Docker container
pct exec 153 -- docker stop gitlab
sleep 10

# 3. Create backup with GitLab stopped
vzdump 153 --mode snapshot --compress zstd --storage local

# 4. Record backup filename
BACKUP=$(pvesm list local | grep "vzdump-lxc-153" | tail -1 | awk '{print $1}')
echo "Backup created: $BACKUP"

# 5. Restart GitLab
pct exec 153 -- docker start gitlab
sleep 30

# 6. Test restore to temporary container (999)
pct restore 999 $BACKUP --storage local-lvm

# 7. Verify restore success
if pct status 999 | grep -q running; then
    echo "✅ SUCCESS: Backup restored without errors"
    pct stop 999 && pct destroy 999
    exit 0
else
    echo "❌ FAILED: Backup still corrupted"
    exit 1
fi
```

**If Successful**:
- Update backup playbook to stop GitLab before backup
- Document downtime requirement (estimate 5-10 minutes)
- Proceed to Phase 5 (Implementation)

**If Failed**:
- Proceed to Phase 3

---

### Phase 3: Test Hypothesis 2 - Use gzip Compression (15 minutes)

**Goal**: Test if compression method is the issue

```bash
# 1. Stop GitLab (from Phase 2)
pct exec 153 -- docker stop gitlab

# 2. Create backup with gzip compression
vzdump 153 --mode snapshot --compress gzip --storage local

# 3. Record backup filename
BACKUP=$(pvesm list local | grep "vzdump-lxc-153.*\.tar\.gz" | tail -1 | awk '{print $1}')
echo "Backup created: $BACKUP"

# 4. Restart GitLab
pct exec 153 -- docker start gitlab

# 5. Test restore
pct restore 999 $BACKUP --storage local-lvm

# 6. Verify
if pct status 999 | grep -q running; then
    echo "✅ SUCCESS: gzip compression works"
    pct stop 999 && pct destroy 999
    exit 0
else
    echo "❌ FAILED: Still corrupted with gzip"
    exit 1
fi
```

**If Successful**:
- Update backup playbook to use gzip for GitLab
- Document compression method change
- Proceed to Phase 5

**If Failed**:
- Proceed to Phase 4

---

### Phase 4: Test Hypothesis 3 - Use GitLab Built-in Backup (30 minutes)

**Goal**: Use GitLab's native backup instead of container snapshots

```bash
# 1. Access GitLab container
ssh root@192.168.1.3
pct enter 153

# 2. Create GitLab backup using built-in tool
docker exec gitlab gitlab-backup create

# 3. Exit container
exit

# 4. Copy backup file to Proxmox host
pct exec 153 -- ls -lh /opt/gitlab/data/backups/
GITLAB_BACKUP=$(pct exec 153 -- ls -1 /opt/gitlab/data/backups/ | tail -1)
echo "GitLab backup: $GITLAB_BACKUP"

# 5. Copy to backup location
pct exec 153 -- cp /opt/gitlab/data/backups/$GITLAB_BACKUP /var/backups/

# 6. Test restore (requires recreating container first)
pct stop 153
pct destroy 153

# 7. Recreate container via Ansible
cd /path/to/Proxmox_config
ansible-playbook -i inventory/hosts.yml playbooks/gitlab-deploy.yml

# 8. Wait for GitLab to start
sleep 60

# 9. Restore GitLab data
pct exec 153 -- docker exec gitlab gitlab-backup restore BACKUP=$GITLAB_BACKUP

# 10. Verify GitLab health
curl -I https://gitlab.viljo.se/api/v4/projects
```

**If Successful**:
- Document GitLab-specific backup procedure
- Update backup_infrastructure role with GitLab backup
- Add to restore_infrastructure role
- Proceed to Phase 5

**If Failed**:
- Escalate to GitLab support
- Consider alternative VCS (GitHub, Gitea)

---

### Phase 5: Implementation (Variable Time)

**Goal**: Implement working backup solution in automation

#### Option A: Stop GitLab During Backup

Update `roles/backup_infrastructure/tasks/main.yml`:

```yaml
# Before GitLab container backup
- name: Stop GitLab Docker container for clean backup
  ansible.builtin.shell:
    cmd: "pct exec 153 -- docker stop gitlab"
  when: backup_containers_enabled

- name: Wait for GitLab to stop
  ansible.builtin.pause:
    seconds: 30

# ... existing vzdump task ...

- name: Restart GitLab Docker container after backup
  ansible.builtin.shell:
    cmd: "pct exec 153 -- docker start gitlab"
  when: backup_containers_enabled
```

#### Option B: Use gzip Compression for GitLab

Update `roles/backup_infrastructure/defaults/main.yml`:

```yaml
backup_container_compression:
  default: "zstd"
  gitlab: "gzip"  # Use gzip for GitLab due to corruption with zstd
```

#### Option C: Use GitLab Built-in Backup

Update `roles/backup_infrastructure/tasks/main.yml`:

```yaml
- name: Create GitLab native backup
  ansible.builtin.shell:
    cmd: "pct exec 153 -- docker exec gitlab gitlab-backup create"
  register: gitlab_backup_result

- name: Get GitLab backup filename
  ansible.builtin.shell:
    cmd: "pct exec 153 -- ls -1 /opt/gitlab/data/backups/ | tail -1"
  register: gitlab_backup_file

- name: Copy GitLab backup to Proxmox host
  ansible.builtin.shell:
    cmd: "pct exec 153 -- cp /opt/gitlab/data/backups/{{ gitlab_backup_file.stdout }} {{ backup_base_dir }}/{{ backup_timestamp }}/gitlab/"
```

Update `roles/restore_infrastructure/tasks/main.yml`:

```yaml
- name: Restore GitLab native backup
  ansible.builtin.shell:
    cmd: "pct exec 153 -- docker exec gitlab gitlab-backup restore BACKUP={{ gitlab_backup_filename }}"
  vars:
    gitlab_backup_filename: "{{ item }}"
  loop: "{{ lookup('fileglob', backup_base_dir + '/' + restore_backup_timestamp + '/gitlab/*.tar') }}"
```

---

### Phase 6: Validation (30 minutes)

**Goal**: Prove backup solution works end-to-end

```bash
# 1. Run backup playbook
ansible-playbook -i inventory/hosts.yml playbooks/backup-infrastructure.yml

# 2. Verify backup created
ssh root@192.168.1.3 "ls -lh /var/backups/infrastructure/$(date +%Y%m%dT%H%M%S)/containers/ | grep gitlab"

# 3. Test backup verification script
bash scripts/verify-backup.sh 153

# 4. If successful, wipe and restore GitLab
pct stop 153
pct destroy 153

# 5. Restore from backup
# For container backup:
BACKUP=$(pvesm list local | grep "vzdump-lxc-153" | tail -1 | awk '{print $1}')
pct restore 153 $BACKUP --storage local-lvm
pct start 153

# For GitLab native backup:
ansible-playbook -i inventory/hosts.yml playbooks/gitlab-deploy.yml
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=$(ls -1 /var/backups/infrastructure/ | tail -1)

# 6. Verify GitLab health
sleep 60
curl -I https://gitlab.viljo.se/api/v4/projects

# 7. Verify repositories present
# Login to GitLab web UI and check projects
```

**Success Criteria**:
- ✅ Backup completes without errors
- ✅ Backup file size > 0
- ✅ Verify script passes
- ✅ Restore completes without CRC errors
- ✅ GitLab API returns 200 OK
- ✅ Repositories and projects intact
- ✅ CI/CD pipelines work

---

## Documentation Requirements

After successful resolution, create these documents:

### 1. GitLab Backup Best Practices

Document in `docs/operations/gitlab-backup-restore.md`:
- Working backup method
- Required downtime (if any)
- Restore procedure
- Verification steps
- Troubleshooting guide

### 2. Update Backup Role Documentation

Update `roles/backup_infrastructure/README.md`:
- GitLab-specific considerations
- Compression method recommendations
- Service stop/start requirements

### 3. Update DR Runbook

Update [docs/DR_RUNBOOK.md](DR_RUNBOOK.md):
- GitLab restore procedure
- Special handling requirements
- RTO estimate for GitLab

### 4. Update TDD Workflow Status

Update [docs/TDD_WORKFLOW_STATUS.md](TDD_WORKFLOW_STATUS.md):
- Mark GitLab backup steps as complete
- Update completion percentage
- Document lessons learned

---

## Timeline Estimate

| Phase | Duration | Status |
|-------|----------|--------|
| 1. Validate Current State | 5 min | Pending |
| 2. Test Stop During Backup | 15 min | Pending |
| 3. Test gzip Compression | 15 min | Pending (if Phase 2 fails) |
| 4. Test GitLab Native Backup | 30 min | Pending (if Phase 3 fails) |
| 5. Implementation | 1-2 hours | Pending |
| 6. Validation | 30 min | Pending |
| 7. Documentation | 1 hour | Pending |
| **Total** | **3-4 hours** | |

---

## Success Metrics

**Before Investigation**:
- Backup success rate: 0% (0/3)
- RTO: Unknown (cannot restore)
- RPO: Unknown (backups unusable)
- DR test success: 90% (9/10 containers)

**After Resolution**:
- Backup success rate: 100% (validated)
- RTO: < 30 minutes
- RPO: < 24 hours (daily backups)
- DR test success: 100% (11/11 containers)

---

## Escalation Path

If all phases fail:

### Level 1: Internal Investigation (Complete Phases 1-4)
**Time Limit**: 4 hours
**Owner**: Infrastructure Admin

### Level 2: Community Support
**Action**: Post to Proxmox and GitLab forums
- Proxmox Forum: https://forum.proxmox.com/
- GitLab Forum: https://forum.gitlab.com/
**Time Limit**: 48 hours

### Level 3: Professional Support
**Action**: Open support tickets
- Proxmox Support: https://www.proxmox.com/en/support
- GitLab Support: https://about.gitlab.com/support/
**Cost**: Requires support subscription

### Level 4: Alternative Solution
**Action**: Consider alternatives:
- Migrate to GitHub (cloud)
- Deploy Gitea (lighter alternative)
- Use GitLab SaaS instead of self-hosted
**Timeline**: 1-2 weeks

---

## References

- [DR Test Report (2025-10-23)](DR_TEST_REPORT_2025-10-23.md) - Original issue discovery
- [DR Test Lessons Learned](DR_TEST_LESSONS_LEARNED.md) - Impact analysis
- [GitLab Backup Documentation](https://docs.gitlab.com/ee/raketasks/backup_restore.html) - Official backup guide
- [Proxmox VZDump Documentation](https://pve.proxmox.com/wiki/Backup_and_Restore) - Container backup guide
- [TDD Workflow Status](TDD_WORKFLOW_STATUS.md) - GitLab workflow completion tracking

---

**Next Action**: Schedule investigation when infrastructure is accessible (requires admin network or VPN)

**Prerequisites**:
- Access to Proxmox host (192.168.1.3)
- GitLab running and healthy
- At least 10GB free disk space for test backups
- 3-4 hour time window
- Maintenance window notification sent to users
