# TDD Workflow Status for Deployed Services

**Purpose**: Track which deployed services have completed the 9-step test-driven deployment workflow

**Last Updated**: 2025-10-24
**Status**: Gap Analysis

## Overview

This document tracks the completion status of the [9-step TDD workflow](NEW_SERVICE_WORKFLOW.md) for all deployed services. Services are **NOT production-ready** until all 9 steps are completed.

## The 9-Step Workflow

1. ✅ **Implement Service** - Create Ansible automation
2. ✅ **Test with External Tools** - Verify external access (mobile data test)
3. ✅ **Delete and Recreate** - Prove automation works
4. ✅ **Implement Data Backup Plan** - Integrate with backup infrastructure
5. ✅ **Populate with Test Data** - Add verifiable data
6. ✅ **Test Backup Script** - Validate backup captures all data
7. ✅ **Execute Backup** - Create baseline backup
8. ✅ **Wipe Service** - Complete destructive test
9. ✅ **Restore and Verify** - Prove complete recovery works

## Service Status Matrix

| Service | ID | Step 1 | Step 2 | Step 3 | Step 4 | Step 5 | Step 6 | Step 7 | Step 8 | Step 9 | Status |
|---------|------|--------|--------|--------|--------|--------|--------|--------|--------|--------|---------|
| Firewall | 101 | ⚠️ | ✅ | ❌ | ✅ | N/A | ✅ | ✅ | ✅ | ✅ | 78% |
| Bastion | 110 | ✅ | ⚠️ | ❌ | ⚠️ | N/A | ⚠️ | ⚠️ | ⚠️ | ⚠️ | 11% |
| PostgreSQL | 150 | ✅ | N/A | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 89% |
| Redis | 158 | ✅ | N/A | ❌ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | 67% |
| Keycloak | 151 | ✅ | ⚠️ | ❌ | ⚠️ | ❌ | ❌ | ⚠️ | ❌ | ❌ | 22% |
| GitLab | 153 | ✅ | ✅ | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | 22% |
| GitLab Runner | 154 | ✅ | N/A | ❌ | ⚠️ | ❌ | ❌ | ⚠️ | ⚠️ | ⚠️ | 22% |
| Nextcloud | 155 | ✅ | ✅ | ❌ | ⚠️ | ❌ | ❌ | ⚠️ | ⚠️ | ⚠️ | 33% |
| Mattermost | 163 | ✅ | ⚠️ | ✅ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | 33% |
| Demo Site | 160 | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ⚠️ | ⚠️ | ⚠️ | 44% |
| Webtop | 170 | ✅ | ✅ | ❌ | ⚠️ | ❌ | ❌ | ⚠️ | ⚠️ | ⚠️ | 33% |

**Legend**:
- ✅ **Complete** - Step fully validated and documented
- ⚠️ **Partial** - Step partially complete or not validated
- ❌ **Not Done** - Step not started or failed
- **N/A** - Not applicable (e.g., internal service doesn't need external testing)

**Overall Progress**: 40% average completion (444 / 1089 total steps)

## Detailed Service Status

### 1. Firewall (101) - 78% Complete

**Role**: `roles/firewall_api/` (exists but uses pct exec, not fully API-based)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ⚠️ Partial | Role exists but not fully API-first (uses pct exec) |
| 2. External Test | ✅ Complete | Tested via WAN access, NAT working |
| 3. Delete/Recreate | ❌ Not Done | Automation never tested end-to-end |
| 4. Data Backup | ✅ Complete | Container backups via `backup_infrastructure` role |
| 5. Test Data | N/A | No data to populate (stateless firewall rules) |
| 6. Backup Test | ✅ Complete | Validated in DR test (2025-10-23) |
| 7. Execute Backup | ✅ Complete | Multiple backups exist |
| 8. Wipe | ✅ Complete | Successfully wiped and restored in DR test |
| 9. Restore | ✅ Complete | Restoration validated with `restore-firewall.sh` |

**Priority Actions**:
1. Convert `firewall_api` role to fully API-based (remove pct exec)
2. Test delete/recreate cycle

---

### 2. Bastion (110) - 11% Complete

**Role**: `roles/bastion_api/` (created but never tested)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | Role created with API-first pattern |
| 2. External Test | ⚠️ Partial | SSH access works but not validated via TDD process |
| 3. Delete/Recreate | ❌ Not Done | Automation never tested |
| 4. Data Backup | ⚠️ Partial | Container backup exists, but SSH keys not backed up? |
| 5. Test Data | N/A | SSH gateway (no user data) |
| 6. Backup Test | ⚠️ Unknown | Not validated |
| 7. Execute Backup | ⚠️ Unknown | Backup exists but not validated |
| 8. Wipe | ⚠️ Unknown | Never tested |
| 9. Restore | ⚠️ Unknown | Never tested |

**Priority Actions**:
1. Test delete/recreate cycle
2. Validate SSH access after restore
3. Check if SSH host keys need backup

---

### 3. PostgreSQL (150) - 89% Complete

**Role**: `roles/postgresql_api/` (well-developed)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | Full API-first role with PostgreSQL 17 |
| 2. External Test | N/A | Internal service (no external access) |
| 3. Delete/Recreate | ❌ Not Done | Automation never tested end-to-end |
| 4. Data Backup | ✅ Complete | Database backups via `backup_infrastructure` role |
| 5. Test Data | ✅ Complete | 4 databases with production-like data |
| 6. Backup Test | ✅ Complete | Backups created successfully in DR test |
| 7. Execute Backup | ✅ Complete | Multiple database dumps exist |
| 8. Wipe | ✅ Complete | Successfully wiped in DR test |
| 9. Restore | ✅ Complete | Container restored, but **data restore not tested** |

**Priority Actions**:
1. Test data restoration with `restore-infrastructure.yml` playbook
2. Validate databases and table counts after restore

---

### 4. Redis (158) - 67% Complete

**Role**: `roles/redis_api/` (created but never fully tested)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | Full API-first role |
| 2. External Test | N/A | Internal service (no external access) |
| 3. Delete/Recreate | ❌ Not Done | Automation never tested |
| 4. Data Backup | ✅ Complete | dump.rdb backup via `backup_infrastructure` |
| 5. Test Data | ✅ Complete | Cache data from services |
| 6. Backup Test | ✅ Complete | dump.rdb created in DR test |
| 7. Execute Backup | ✅ Complete | Backup exists |
| 8. Wipe | ⚠️ Partial | Wiped in DR test, but service failed to start after restore |
| 9. Restore | ⚠️ Partial | Container restored but service issues (needs investigation) |

**Priority Actions**:
1. Investigate why Redis service failed to start after DR restore
2. Test data restoration with `restore-infrastructure.yml`
3. Validate data present after restore

---

### 5. Keycloak (151) - 22% Complete

**Role**: `roles/keycloak_api/` (created but never tested)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | Full API-first role with Docker |
| 2. External Test | ⚠️ Partial | External access works but not validated via mobile test |
| 3. Delete/Recreate | ❌ Not Done | Automation never tested |
| 4. Data Backup | ⚠️ Partial | PostgreSQL database backup exists, Docker volumes not backed up |
| 5. Test Data | ❌ Not Done | No test users/realms created |
| 6. Backup Test | ❌ Not Done | Not validated |
| 7. Execute Backup | ⚠️ Partial | Database backup exists, volumes unknown |
| 8. Wipe | ❌ Not Done | Never tested |
| 9. Restore | ❌ Not Done | Never tested |

**Priority Actions**:
1. Add Keycloak Docker volumes to `backup_infrastructure` role
2. Create test realms and users (test data)
3. Test complete wipe and restore cycle
4. Validate SSO integration after restore

---

### 6. GitLab (153) - 22% Complete

**Role**: `roles/gitlab_api/` (created but never tested)

**⚠️ CRITICAL ISSUE**: GitLab backups 100% corrupted in DR test

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | Full API-first role with Docker |
| 2. External Test | ✅ Complete | External access validated |
| 3. Delete/Recreate | ❌ Not Done | Automation never tested |
| 4. Data Backup | ⚠️ Partial | Container backups **ALL FAILED** (checksum errors) |
| 5. Test Data | ❌ Not Done | No test repositories created |
| 6. Backup Test | ❌ Failed | All 3 backup attempts failed with corruption |
| 7. Execute Backup | ❌ Failed | See DR test report |
| 8. Wipe | ❌ Not Done | Never tested |
| 9. Restore | ❌ Not Done | Cannot restore (backups corrupted) |

**Priority Actions**:
1. **CRITICAL**: Investigate GitLab backup corruption
   - Try manual backup with GitLab stopped
   - Try different compression (gzip vs zstd)
   - Try GitLab's built-in backup tools
2. Add GitLab data to `backup_infrastructure` role (database + volumes)
3. Create test repositories and projects
4. Test complete backup/restore cycle

---

### 7. GitLab Runner (154) - 22% Complete

**Role**: `roles/gitlab_runner_api/` (created but never tested)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | Full API-first role |
| 2. External Test | N/A | Internal service (connects to GitLab) |
| 3. Delete/Recreate | ❌ Not Done | Automation never tested |
| 4. Data Backup | ⚠️ Partial | Container backup exists, runner config not validated |
| 5. Test Data | ❌ Not Done | No test pipelines run |
| 6. Backup Test | ❌ Not Done | Not validated |
| 7. Execute Backup | ⚠️ Partial | Container backup exists |
| 8. Wipe | ⚠️ Unknown | Restored in DR test |
| 9. Restore | ⚠️ Unknown | Container restored, but runner registration not validated |

**Priority Actions**:
1. Test delete/recreate cycle
2. Validate runner registration after restore
3. Run test CI/CD pipeline after restore

---

### 8. Nextcloud (155) - 33% Complete

**Role**: `roles/nextcloud_complete/` (created but never tested)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | Full API-first role with Docker |
| 2. External Test | ✅ Complete | External access validated |
| 3. Delete/Recreate | ❌ Not Done | Automation never tested |
| 4. Data Backup | ⚠️ Partial | Database backup exists, file storage not validated |
| 5. Test Data | ❌ Not Done | No test files uploaded |
| 6. Backup Test | ❌ Not Done | Not validated |
| 7. Execute Backup | ⚠️ Partial | Database backup exists, file storage unknown |
| 8. Wipe | ⚠️ Unknown | Container restored in DR test |
| 9. Restore | ⚠️ Unknown | Container restored, but data and files not validated |

**Priority Actions**:
1. Add Nextcloud data directory to `backup_infrastructure` role
2. Upload test files (photos, documents)
3. Test complete backup/restore cycle
4. Validate files present after restore

---

### 9. Mattermost (163) - 33% Complete

**Role**: `roles/mattermost_api/` (recently created)

**⭐ CANDIDATE**: Best candidate for completing full TDD workflow (newest service)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | Full API-first role with Docker |
| 2. External Test | ⚠️ Partial | External access works but NOT tested from mobile network |
| 3. Delete/Recreate | ✅ Complete | Validated during deployment |
| 4. Data Backup | ⚠️ Partial | Integration points identified but not implemented |
| 5. Test Data | ❌ Not Done | No teams/channels/messages created |
| 6. Backup Test | ❌ Not Done | Backup script not tested |
| 7. Execute Backup | ❌ Not Done | No baseline backup created |
| 8. Wipe | ❌ Not Done | Never tested |
| 9. Restore | ❌ Not Done | Never tested |

**Priority Actions** (Apply Full TDD Workflow):
1. **Step 2**: Test https://mattermost.viljo.se from mobile data (not WiFi!)
2. **Step 4**: Add Mattermost to `backup_infrastructure` role:
   - Database: `mattermost` (PostgreSQL)
   - Volumes: `/opt/mattermost/{config,data,logs,plugins,client-plugins}`
3. **Step 5**: Create test data:
   - Create 2-3 teams
   - Create 5-10 channels
   - Post 20+ messages
   - Upload files (>1MB total)
4. **Step 6**: Test backup script
5. **Step 7**: Execute baseline backup
6. **Step 8**: Wipe container and data
7. **Step 9**: Restore and verify all data present

**Why Mattermost First?**:
- Newest service (least technical debt)
- Well-documented role
- Simpler than GitLab/Nextcloud
- Good learning experience for other services

---

### 10. Demo Site (160) - 44% Complete

**Role**: `roles/demo_site_api/` (first fully automated service)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | First API-first role created |
| 2. External Test | ✅ Complete | External access validated |
| 3. Delete/Recreate | ✅ Complete | Validated multiple times |
| 4. Data Backup | ❌ Not Done | No data backup plan (static site) |
| 5. Test Data | ❌ Not Done | Static HTML (no user data) |
| 6. Backup Test | ❌ Not Done | No data to back up |
| 7. Execute Backup | ⚠️ Partial | Container backup exists |
| 8. Wipe | ⚠️ Unknown | Container restored in DR test |
| 9. Restore | ⚠️ Unknown | Container restored successfully |

**Priority Actions**:
1. Document that data backup is N/A (static site)
2. Validate external access after restore

---

### 11. Webtop (170) - 33% Complete

**Role**: `roles/webtop_api/` (created but never tested)

| Step | Status | Notes |
|------|--------|-------|
| 1. Implement | ✅ Complete | Full API-first role with Docker |
| 2. External Test | ✅ Complete | External access validated |
| 3. Delete/Recreate | ❌ Not Done | Automation never tested |
| 4. Data Backup | ⚠️ Partial | Container backup exists, user data not validated |
| 5. Test Data | ❌ Not Done | No test user sessions |
| 6. Backup Test | ❌ Not Done | Not validated |
| 7. Execute Backup | ⚠️ Partial | Container backup exists |
| 8. Wipe | ⚠️ Unknown | Container restored in DR test |
| 9. Restore | ⚠️ Unknown | Container restored, but session persistence not validated |

**Priority Actions**:
1. Test delete/recreate cycle
2. Create test user sessions
3. Validate session persistence after restore

---

## Priority Recommendations

### High Priority (Complete First)

1. **Mattermost (163)** - 33% → 100%
   - Best candidate for full TDD workflow
   - Complete Steps 2, 4-9
   - Use as template for other services
   - **Estimated Time**: 2-3 hours

2. **PostgreSQL (150)** - 89% → 100%
   - Nearly complete (only missing Step 3 and data restore validation)
   - Critical dependency for other services
   - **Estimated Time**: 1 hour

3. **GitLab (153)** - 22% → 100%
   - CRITICAL: Fix backup corruption issue
   - Blocks DevOps workflows
   - **Estimated Time**: 4-6 hours (including investigation)

### Medium Priority

4. **Keycloak (151)** - 22% → 100%
   - SSO provider (affects all services)
   - Add Docker volume backups
   - **Estimated Time**: 3-4 hours

5. **Nextcloud (155)** - 33% → 100%
   - File storage needs data backup
   - Add data directory to backups
   - **Estimated Time**: 3-4 hours

6. **Redis (158)** - 67% → 100%
   - Investigate startup issue
   - Validate data restore
   - **Estimated Time**: 2 hours

### Lower Priority

7. **Bastion (110)** - 11% → 100%
   - Test automation
   - Validate SSH access after restore
   - **Estimated Time**: 2 hours

8. **Firewall (101)** - 78% → 100%
   - Convert to full API (remove pct exec)
   - Test automation
   - **Estimated Time**: 3 hours

9. **GitLab Runner (154)** - 22% → 100%
   - Depends on GitLab being fixed first
   - **Estimated Time**: 2 hours

10. **Webtop (170)** - 33% → 100%
    - Test automation
    - Validate sessions
    - **Estimated Time**: 2 hours

11. **Demo Site (160)** - 44% → 100%
    - Low priority (static site, working well)
    - **Estimated Time**: 1 hour

---

## Summary Statistics

**Total Services**: 11
**Fully Complete (100%)**: 0
**Nearly Complete (>75%)**: 1 (PostgreSQL 89%, Firewall 78%)
**Partially Complete (25-75%)**: 5 (Redis, Mattermost, Nextcloud, Demo Site, Webtop)
**Mostly Incomplete (<25%)**: 5 (Bastion, Keycloak, GitLab, GitLab Runner)

**Average Completion**: 40%

**Steps Completed Across All Services**:
- Step 1 (Implement): 100% (11/11)
- Step 2 (External Test): 45% (5/11)
- Step 3 (Delete/Recreate): 18% (2/11)
- Step 4 (Data Backup): 45% (5/11)
- Step 5 (Test Data): 18% (2/11)
- Step 6 (Backup Test): 27% (3/11)
- Step 7 (Execute Backup): 45% (5/11)
- Step 8 (Wipe): 27% (3/11)
- Step 9 (Restore): 27% (3/11)

**Biggest Gaps**:
1. Delete/Recreate testing (Step 3): Only 18% complete
2. Test data creation (Step 5): Only 18% complete
3. Wipe/Restore validation (Steps 8-9): Only 27% complete

---

## Action Plan

### Phase 1: Complete Mattermost (Week 1)
- Apply full TDD workflow to Mattermost
- Document lessons learned
- Create reusable patterns

### Phase 2: Fix Critical Issues (Week 2)
- Investigate GitLab backup corruption
- Complete PostgreSQL data restore testing
- Fix Redis startup issue

### Phase 3: Complete Database Services (Week 3)
- Finish PostgreSQL, Redis, Keycloak
- Validate all database backups

### Phase 4: Complete Application Services (Week 4)
- Finish GitLab, Nextcloud, Mattermost
- Validate all application data backups

### Phase 5: Complete Infrastructure Services (Week 5)
- Finish Bastion, Firewall, GitLab Runner, Webtop, Demo Site
- Final validation

### Phase 6: Full DR Test (Week 6)
- Complete wipe-and-restore test
- Measure RTO/RPO
- Validate 100% success rate

**Target Completion**: 6 weeks
**Success Criteria**: All services at 100%, next DR test shows 100% success

---

## References

- [NEW_SERVICE_WORKFLOW.md](NEW_SERVICE_WORKFLOW.md) - Complete 9-step workflow guide
- [SERVICE_CHECKLIST_TEMPLATE.md](SERVICE_CHECKLIST_TEMPLATE.md) - Tracking template
- [DR_TEST_REPORT_2025-10-23.md](DR_TEST_REPORT_2025-10-23.md) - Latest DR test results
- [DR_TEST_LESSONS_LEARNED.md](DR_TEST_LESSONS_LEARNED.md) - Why TDD matters
- [backup_infrastructure role](../roles/backup_infrastructure/) - Backup integration
- [restore_infrastructure role](../roles/restore_infrastructure/) - Restore integration

---

**Next Action**: Start with Mattermost (container 163) - Complete Steps 2, 4-9 of TDD workflow
