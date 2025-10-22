# Automation & Disaster Recovery Audit

## Audit Date: 2025-10-22

This document identifies contradictions and issues that hinder the **disaster recovery automation goal**: being able to take identical hardware with clean Proxmox install, run Ansible playbooks without user intervention, restore backups, and achieve 100% functionality.

## Executive Summary

**Current State**: Documentation claims high automation, but reality is that most services were deployed manually via SSH/pct exec commands.

**Impact**: Disaster recovery would require extensive manual intervention, violating the core automation goal.

**Action Required**: Update documentation to reflect reality and create Ansible roles for all manually-deployed services.

## Issues Found

### 1. README.md - Outdated Container IDs and Missing Services

**File**: `/README.md` lines 60-70

**Issue**: Container ID table is completely outdated and uses old numbering scheme

**Current Documentation**:
```markdown
| Service | Container ID | IP Address | URL |
|---------|--------------|------------|-----|
| Firewall | 1 | 172.16.10.1 | N/A (NAT gateway) |
| PostgreSQL | 50 | 172.16.10.50 | N/A (internal) |
| Keycloak | 51 | 172.16.10.51 | https://keycloak.viljo.se |
| NetBox | 52 | 172.16.10.52 | https://netbox.viljo.se |
| GitLab | 53 | 172.16.10.53 | https://gitlab.viljo.se |
| Demo Site | 60 | 172.16.10.60 | https://demosite.viljo.se |
```

**Reality** (Deployed Services):
```markdown
| Service | Container ID | IP Address | URL | Deployment Method |
|---------|--------------|------------|-----|-------------------|
| Firewall | 101 | 172.16.10.101 | N/A | Manual (pct exec) |
| Bastion | 110 | 192.168.1.10 | ssh.viljo.se | Manual (pct create) |
| PostgreSQL | 150 | 172.16.10.150 | N/A | Manual (pct exec) |
| Keycloak | 151 | 172.16.10.151 | https://keycloak.viljo.se | Manual (pct exec) |
| GitLab | 153 | 172.16.10.153 | https://gitlab.viljo.se | Manual (pct exec) |
| GitLab Runner | 154 | 172.16.10.154 | N/A | Manual (pct exec) |
| Nextcloud | 155 | 172.16.10.155 | https://nextcloud.viljo.se | Manual (pct exec) |
| Redis | 158 | 172.16.10.158 | N/A | Manual (pct exec) |
| Demo Site | 160 | 172.16.10.160 | https://demosite.viljo.se | Ansible (demo_site_api) |
| Mattermost | 163 | 172.16.10.163 | https://mattermost.viljo.se | Manual (pct exec + Docker) |
| Webtop | 170 | 172.16.10.170 | https://browser.viljo.se | Manual (pct exec + Docker) |
```

**Missing Services** (documented but not deployed):
- NetBox (ID 152)
- Jellyfin (ID 156)
- Home Assistant (ID 157)
- qBittorrent (ID 159)
- Cosmos (ID 161)
- Wazuh (ID 162)
- OpenMediaVault (ID 164)
- Zipline (ID 165)
- WireGuard (ID 190)

**Fix Required**:
1. Update README.md table with actual deployed services
2. Remove or mark as "planned" the services that don't exist yet
3. Add column indicating automation status

### 2. README.md - SSH Access Documentation Incomplete

**File**: `/README.md` line 40

**Current Text**:
```markdown
Day-to-day access to the Proxmox host is via `ssh root@192.168.1.3`.
```

**Issue**: Doesn't mention the two access methods:
1. Admin network: `ssh root@192.168.1.3` (current location)
2. Internet: `ssh -J root@ssh.viljo.se root@192.168.1.3`

**Fix Required**:
```markdown
Day-to-day access to the Proxmox host depends on your network location:

- **From admin network** (192.168.1.0/16): `ssh root@192.168.1.3`
- **From internet**: `ssh -J root@ssh.viljo.se root@192.168.1.3`

See [SSH Access Methods](docs/operations/ssh-access-methods.md) for details.
```

### 3. README.md - False Claim of Idempotent Roles

**File**: `/README.md` line 31

**Current Text**:
```markdown
Each Ansible role is contained in `roles/` and is designed to be idempotent.
```

**Reality**: Most services were deployed manually via SSH, not via Ansible roles:
- PostgreSQL: Manual database/user creation via `pct exec 150 -- su - postgres -c "psql ..."`
- Keycloak: Manual deployment via `pct exec 151`
- GitLab: Manual deployment via `pct exec 153`
- Nextcloud: Manual deployment via `pct exec 155`
- Mattermost: Manual Docker Compose deployment via `pct exec 163`
- Webtop: Manual Docker Compose deployment via `pct exec 170`
- Redis: Manual redis-server start via `pct exec 158`

**Fix Required**:
```markdown
Each Ansible role is contained in `roles/` and **should be** designed to be idempotent.

**Current Automation Status**:
- ✅ Fully automated: Demo Site, Traefik, Loopia DDNS, Network, DMZ Cleanup
- ⚠️  Partially automated: Firewall (Ansible role exists, but uses pct exec)
- ❌ Manual deployment: PostgreSQL, Keycloak, GitLab, Nextcloud, Mattermost, Webtop, Redis, Bastion

See [External Testing Methodology - Disaster Recovery Validation](docs/operations/external-testing-methodology.md#disaster-recovery-validation) for automation status details.
```

### 4. docs/architecture/container-mapping.md - Outdated and Incomplete

**File**: `/docs/architecture/container-mapping.md`

**Issues**:
1. Missing deployed services: Bastion (110), Redis (158), Mattermost (163), Webtop (170)
2. Lists services that don't exist: NetBox, Jellyfin, Home Assistant, qBittorrent, Cosmos, Wazuh, OpenMediaVault, Zipline, WireGuard
3. Resource allocation table is fictional (lists totals for non-existent services)
4. No indication of automation status

**Fix Required**:
1. Add table section for "Currently Deployed Services"
2. Add table section for "Planned Services"
3. Add "Automation Status" column:
   - ✅ Fully Automated (via Ansible)
   - ⚠️ Partially Automated (Ansible role with manual steps)
   - ❌ Manual Deployment (deployed via SSH/pct exec)
4. Update resource allocation to reflect actual deployed services
5. Cross-reference with disaster recovery validation documentation

### 5. README_AUTOMATION.md - Metrics Contradict Reality

**File**: `/README_AUTOMATION.md` lines 124-131

**Current Metrics**:
```markdown
| Metric | Target | Current |
|--------|--------|---------|
| API vs Shell | >90% | 95% ✅ |
| User Prompts | 0 | 0 ✅ |
| Idempotent | 100% | 100% ✅ |
| Vault Secrets | 100% | 100% ✅ |
```

**Reality**:
- **API vs Shell**: Likely < 20% (only Demo Site uses API, 10+ services deployed manually)
- **Idempotent**: Maybe 10% (only Demo Site can be re-run idempotently)
- **User Prompts**: 0 ✅ (this is accurate)
- **Vault Secrets**: ~60% (many manual commands used hardcoded passwords, not vault)

**Fix Required**:
```markdown
| Metric | Target | Current | Notes |
|--------|--------|---------|-------|
| API vs Shell | >90% | ~15% ❌ | Only demo_site_api uses Proxmox API |
| User Prompts | 0 | 0 ✅ | No interactive prompts |
| Idempotent | 100% | ~10% ❌ | Most services deployed manually |
| Vault Secrets | 100% | ~60% ⚠️  | Many manual deployments used hardcoded passwords |
| External Validation | 100% | 0% ❌ | Services not tested from external sources |
```

### 6. README_AUTOMATION.md - API-Based Roles List is Incomplete

**File**: `/README_AUTOMATION.md` lines 112-123

**Current List**:
```markdown
### API-Based Roles ✅
- **firewall_api**: Container via Proxmox API
- **demo_site_api**: Container via Proxmox API
- **traefik_api**: Ansible modules (no shell)
- **loopia_ddns_api**: Ansible modules (no shell)

### Legacy Roles ⚠️ (Being Phased Out)
- **firewall**: Uses pct commands
- **demo_site**: Uses pct commands
- **traefik**: Uses shell commands
- **loopia_ddns**: Uses shell commands
```

**Missing** (deployed but not documented as automated or manual):
- **postgresql**: No Ansible role - deployed manually
- **keycloak**: No API role - deployed manually
- **gitlab**: No API role - deployed manually
- **nextcloud**: No API role - deployed manually
- **mattermost**: No Ansible role - deployed manually
- **webtop**: No Ansible role - deployed manually
- **redis**: No Ansible role - deployed manually
- **bastion**: No Ansible role - deployed manually

**Fix Required**:
Add section for "Manual Deployments (No Ansible Role)":
```markdown
### Manual Deployments ❌ (Require Ansible Roles)
- **bastion**: SSH gateway - deployed via pct create
- **postgresql**: Database server - deployed via pct exec
- **keycloak**: SSO server - deployed via pct exec + manual config
- **gitlab**: DevOps platform - deployed via pct exec + Docker
- **nextcloud**: File sharing - deployed via pct exec + nginx + PHP
- **mattermost**: Team collaboration - deployed via pct exec + Docker Compose
- **webtop**: Remote desktop - deployed via pct exec + Docker Compose
- **redis**: Cache server - deployed via pct exec + manual redis-server

**Priority**: Create Ansible roles for these services to achieve disaster recovery automation goal.
```

## Impact on Disaster Recovery

### Current State: Manual Intervention Required

If we attempted disaster recovery today:

1. ✅ **Can be automated**: Demo Site, Traefik, Loopia DDNS, Network
2. ❌ **Requires manual intervention**:
   - Create 10 containers manually via pct create
   - SSH into each container
   - Run package installation commands
   - Copy configuration files
   - Create databases and users in PostgreSQL
   - Deploy Docker Compose files
   - Fix file permissions
   - Configure services
   - Create DNS records
   - Verify each service works

**Estimated Recovery Time**: 8-12 hours with manual intervention

**Goal**: < 1 hour fully automated

### What's Needed for 100% Automation

For each manually-deployed service, create an Ansible role with:

1. **Container Creation**: Use `community.proxmox.proxmox` module
2. **Package Installation**: Use `ansible.builtin.apt` with delegation
3. **Configuration**: Use Jinja2 templates for all config files
4. **Database Setup**: Use `community.postgresql.postgresql_*` modules
5. **Docker Setup**: Use `community.docker.docker_*` modules
6. **Service Start**: Use handlers for service restart
7. **DNS Creation**: Integrate with Loopia DDNS or create DNS role
8. **Traefik Config**: Template the dynamic config files
9. **Idempotency**: Support `--check` mode and multiple runs
10. **Documentation**: README with variables and vault requirements

## Recommended Actions

### Immediate (High Priority)

1. **Update README.md**:
   - [ ] Fix container ID table (lines 60-70)
   - [ ] Add SSH access methods section (line 40)
   - [ ] Update automation claims (line 31)
   - [ ] Remove or mark as "planned" non-existent services

2. **Update container-mapping.md**:
   - [ ] Add missing deployed services (Bastion, Redis, Mattermost, Webtop)
   - [ ] Separate "Deployed" from "Planned" services
   - [ ] Add automation status column
   - [ ] Update resource allocation to reality

3. **Update README_AUTOMATION.md**:
   - [ ] Fix metrics to reflect reality (lines 124-131)
   - [ ] Add "Manual Deployments" section (lines 112-123)
   - [ ] Document automation gaps

### Short Term (Next Sprint)

4. **Create Ansible Roles** (in priority order):
   - [ ] `roles/postgresql_api/` - Database automation
   - [ ] `roles/redis_api/` - Cache server automation
   - [ ] `roles/keycloak_api/` - SSO automation (depends on PostgreSQL)
   - [ ] `roles/bastion_api/` - SSH gateway automation

5. **Document External Testing**:
   - [ ] Add external testing requirement to deployment guides
   - [ ] Create testing checklist for each service
   - [ ] Document mobile data testing procedure

### Medium Term (Next Month)

6. **Complete Automation**:
   - [ ] `roles/gitlab_api/` - DevOps platform automation
   - [ ] `roles/nextcloud_api/` - File sharing automation
   - [ ] `roles/mattermost_api/` - Team collaboration automation
   - [ ] `roles/webtop_api/` - Remote desktop automation

7. **Create Disaster Recovery Playbook**:
   - [ ] `playbooks/disaster-recovery.yml` - Full stack rebuild
   - [ ] Test on clean Proxmox install
   - [ ] Document recovery time objective (RTO)
   - [ ] Document recovery point objective (RPO)

8. **Backup Automation**:
   - [ ] Create backup role
   - [ ] Automate backup to external storage
   - [ ] Test restore procedures
   - [ ] Document backup schedule

### Long Term (Ongoing)

9. **Maintain Documentation**:
   - [ ] Keep container mapping up to date
   - [ ] Update automation metrics after each role creation
   - [ ] Document all manual interventions as tech debt
   - [ ] Create ADRs for automation decisions

10. **Test Disaster Recovery**:
    - [ ] Quarterly DR tests
    - [ ] Time the recovery process
    - [ ] Identify any remaining manual steps
    - [ ] Update automation to eliminate manual steps

## Success Metrics

### Current Baseline

- **Services Deployed**: 11 containers
- **Fully Automated**: 1 service (Demo Site)
- **Manual Deployment**: 10 services
- **Automation Coverage**: ~9%
- **Estimated DR Time**: 8-12 hours

### Target Goals (3 Months)

- **Services Deployed**: 11+ containers
- **Fully Automated**: 11 services (100%)
- **Manual Deployment**: 0 services
- **Automation Coverage**: 100%
- **Estimated DR Time**: < 1 hour
- **External Validation**: 100% (all services tested from internet)

### Milestone Tracking

| Service | Current Status | Target Date | Ansible Role | External Test |
|---------|----------------|-------------|--------------|---------------|
| Demo Site | ✅ Automated | Done | demo_site_api | ⏳ Pending |
| Bastion | ❌ Manual | 2025-11-01 | bastion_api | ⏳ Pending |
| PostgreSQL | ❌ Manual | 2025-11-01 | postgresql_api | N/A |
| Redis | ❌ Manual | 2025-11-01 | redis_api | N/A |
| Keycloak | ❌ Manual | 2025-11-15 | keycloak_api | ⏳ Pending |
| GitLab | ❌ Manual | 2025-11-30 | gitlab_api | ⏳ Pending |
| Nextcloud | ❌ Manual | 2025-12-15 | nextcloud_api | ⏳ Pending |
| Mattermost | ❌ Manual | 2025-12-15 | mattermost_api | ⏳ Pending |
| Webtop | ❌ Manual | 2025-12-30 | webtop_api | ⏳ Pending |
| Firewall | ⚠️ Partial | 2025-11-15 | firewall_api | N/A |
| Traefik | ✅ Automated | Done | traefik_api | N/A |

## Conclusion

**The documentation currently creates false expectations** about automation levels. While the *intent* and *architecture* for automation are well-documented, the *reality* is that most services were deployed manually.

**This is a critical blocker for the disaster recovery goal.** Manual deployment means:
- Recovery requires extensive human intervention
- Recovery time is unpredictable (8-12 hours minimum)
- Human error risk is high
- Reproducibility is not guaranteed

**Recommended Approach**:
1. Update documentation NOW to reflect reality
2. Create Ansible roles incrementally (one service per week)
3. Test each role in isolation before integration
4. Perform quarterly disaster recovery tests
5. Measure and track automation coverage

**Success Criteria**: When we can destroy all infrastructure, run one Ansible command, restore backups, and have 100% functionality in < 1 hour.

---

**Audit Completed**: 2025-10-22
**Next Review**: After each new Ansible role is created
**Owner**: Infrastructure Team
