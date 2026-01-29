# Service Deployment Checklist

**Service Name**: _______________
**Container ID**: _______________
**Started**: _______________
**Completed**: _______________

---

## MANDATORY REQUIREMENTS (Must Complete Before Production)

**These 3 requirements are NON-NEGOTIABLE for all services:**

### Requirement 1: DNS Entry ✅ REQUIRED
- [ ] **DNS entry added** to `inventory/group_vars/all/main.yml`
  ```yaml
  loopia_dns_records:
    - host: servicename
      ttl: 600
  ```
- [ ] **DNS deployed**: `ansible-playbook playbooks/loopia-dns-deploy.yml --ask-vault-pass`
- [ ] **DNS verification**: `dig +short servicename.viljo.se @1.1.1.1` returns public IP

### Requirement 2: HTTPS Certificate ✅ REQUIRED
- [ ] **Traefik service added** to `inventory/group_vars/all/main.yml`
  ```yaml
  traefik_services:
    - name: servicename
      host: "servicename.{{ public_domain }}"
      container_id: "{{ servicename_container_id }}"
      port: 8080
  ```
- [ ] **Traefik deployed**: `ansible-playbook playbooks/traefik-deploy.yml --ask-vault-pass`
- [ ] **Certificate issued**: Monitor Traefik logs for "Obtained certificate"
- [ ] **HTTPS access works**: `curl -I https://servicename.viljo.se` returns HTTP/2 200
- [ ] **No browser warnings**: Valid Let's Encrypt certificate
- [ ] **Certificate expiry**: Check expires ~90 days from issue

### Requirement 3: SSO Integration ✅ REQUIRED
- [ ] **Keycloak client created**:
  - Client ID: `servicename`
  - Type: OpenID Connect (confidential)
  - Valid redirect URIs configured
  - Web origins configured
- [ ] **Client mappers configured**:
  - [ ] Username mapper (`preferred_username`)
  - [ ] Email verified mapper (`email_verified`)
- [ ] **Client secret stored in vault**:
  ```yaml
  vault_servicename_oidc_client_secret: "SECRET"
  ```
- [ ] **Service OIDC configured**:
  - [ ] Discovery endpoint OR manual endpoints set
  - [ ] Client ID and secret configured
  - [ ] Auto-provisioning enabled
  - [ ] Scopes include: `openid profile email`
- [ ] **SSO login tested**:
  - [ ] Service shows SSO login button
  - [ ] Redirects to Keycloak work
  - [ ] GitLab.com authentication works
  - [ ] Returns to service successfully
  - [ ] User auto-provisioned
  - [ ] Username and email populated correctly
- [ ] **Admin access granted** (if needed): Document command
- [ ] **SSO documentation added** to service README

**Verification Command**:
```bash
./scripts/verify-service-requirements.sh servicename
```

**Reference**: See [SERVICE_IMPLEMENTATION_PIPELINE.md](SERVICE_IMPLEMENTATION_PIPELINE.md) for detailed implementation guide.

---

## Step 1: Implement Service ✅ Initial Deployment

**Objective**: Create working Ansible automation

### Prerequisites (Complete BEFORE Step 1)
- [ ] **DNS entry added** (Requirement 1 above)
- [ ] **Traefik service entry added** (Requirement 2 above)
- [ ] **Service name chosen** and verified not in use

### Ansible Automation
- [ ] Ansible role created (`roles/<service>_api/`)
- [ ] Deployment playbook created (`playbooks/<service>-deploy.yml`)
- [ ] Uses Proxmox API (not pct exec)
- [ ] SSH delegation for config
- [ ] Health checks added
- [ ] Role README.md created
- [ ] Vault variables documented

### Deployment and Verification
- [ ] **DNS deployed and verified** (Requirement 1 completed)
- [ ] Initial deployment successful
- [ ] **Traefik deployed and certificate issued** (Requirement 2 completed)
- [ ] **HTTPS access verified**: Service accessible via https://servicename.viljo.se
- [ ] **Service added to `services.yml`** (if public-facing)
- [ ] **Links portal regenerated**: `ansible-playbook playbooks/links-portal-deploy.yml`

**Deployment Time**: _____ minutes

---

## Step 2: Test with External Tools ✅ External Validation

**Objective**: Verify external accessibility

- [ ] HTTPS access works: `curl -I https://<service>.viljo.se`
- [ ] External testing service passed (HTTPie/Uptime Robot)
- [ ] Mobile data test passed (not admin network!)
- [ ] SSL certificate valid
- [ ] DNS resolves: `dig +short <service>.viljo.se @1.1.1.1`

**External Test Results**:
```
HTTPS Status: _____
External Service: _____
Mobile Test: _____
SSL Valid: _____
DNS: _____
```

---

## Step 3: Delete and Recreate ✅ Automation Validation

**Objective**: Prove automation works

```bash
# Delete
pct stop <id> && pct destroy <id>

# Recreate
ansible-playbook -i inventory/hosts.yml playbooks/<service>-deploy.yml
```

- [ ] Container deleted successfully
- [ ] Playbook recreated service without errors
- [ ] Service fully functional after recreation
- [ ] Second run is idempotent (changed=0 or 1)
- [ ] External access still works

**Deployment Time (2nd run)**: _____ minutes
**Idempotency**: changed=_____

---

## Step 3.5: SSO Integration ✅ MANDATORY

**Objective**: Configure Single Sign-On via Keycloak

**CRITICAL**: This step is MANDATORY before proceeding to backup planning.

**Approach Used**: [ ] Native OIDC [ ] oauth2-proxy Forward Auth

### SSO Configuration Checklist

See "Requirement 3: SSO Integration" section at top of checklist for complete checklist.

**Quick Verification**:
- [ ] Keycloak client created and configured
- [ ] Client secret in vault
- [ ] Service OIDC configuration complete
- [ ] SSO login flow tested end-to-end
- [ ] User auto-provisioned successfully
- [ ] Admin access granted (if needed)
- [ ] Documentation updated

**Time Spent**: _____ minutes

**Reference**: [SERVICE_IMPLEMENTATION_PIPELINE.md](SERVICE_IMPLEMENTATION_PIPELINE.md) - Section B, Step 3

---

## Step 4: Implement Data Backup Plan ✅ Backup Integration

**Objective**: Integrate data backups

**Backup Type**: [ ] Database [ ] Files [ ] Key-Value [ ] Other: _____

- [ ] Backup strategy defined
- [ ] Updated `backup_infrastructure` role defaults
- [ ] Updated `backup_infrastructure` role tasks
- [ ] Updated `restore_infrastructure` role defaults
- [ ] Updated `restore_infrastructure` role tasks
- [ ] Backup toggle works (enabled/disabled)

**Backup Files Location**:
```
/var/backups/infrastructure/<timestamp>/<type>/<service>_<timestamp>.<ext>
```

---

## Step 5: Populate with Test Data ✅ Data Creation

**Objective**: Add test data

- [ ] Test data script created: `scripts/populate-<service>-testdata.sh`
- [ ] At least 3 types of test data
- [ ] Data includes relationships/dependencies
- [ ] Data is verifiable (can count)
- [ ] Test data size > 1MB

**Test Data Summary**:
```
Type 1: _____ (count: _____)
Type 2: _____ (count: _____)
Type 3: _____ (count: _____)
Total Size: _____ MB
```

---

## Step 6: Test Backup Script ✅ Backup Verification

**Objective**: Verify backup works

```bash
ansible-playbook -i inventory/hosts.yml playbooks/backup-infrastructure.yml
```

- [ ] Backup script ran without errors
- [ ] Service data captured in backup
- [ ] Backup files have size > 0 bytes
- [ ] Backup files are valid (not corrupted)
- [ ] Backup includes all test data

**Backup Results**:
```
Backup Timestamp: _____
Backup Size: _____ MB
Backup Time: _____ minutes
Files Created: _____
```

---

## Step 7: Execute Backup ✅ Baseline Creation

**Objective**: Create baseline backup

```bash
ansible-playbook -i inventory/hosts.yml playbooks/backup-infrastructure.yml
TIMESTAMP=$(ls -1 /var/backups/infrastructure/ | tail -1)
echo $TIMESTAMP > /tmp/<service>-backup-timestamp.txt
```

- [ ] Baseline backup created
- [ ] Backup timestamp recorded
- [ ] Backup report created
- [ ] Service still running after backup

**Baseline Backup**:
```
Timestamp: _____
Size: _____ MB
Location: /var/backups/infrastructure/_____
```

---

## Step 8: Wipe Service ✅ Destructive Test

**Objective**: Completely remove service

**⚠️ WARNING**: Destructive operation!

```bash
# Verify backup exists first!
TIMESTAMP=$(cat /tmp/<service>-backup-timestamp.txt)
ls -lh /var/backups/infrastructure/$TIMESTAMP/ | grep <service>

# Wipe
pct stop <id>
pct destroy <id>
```

- [ ] Backup verified before wipe
- [ ] Container deleted
- [ ] Service inaccessible: `curl -I https://<service>.viljo.se` fails
- [ ] Data removed (if complete wipe)
- [ ] Backup still exists

**Wipe Type**: [ ] Container Only [ ] Container + Data

---

## Step 9: Restore and Verify ✅ DR Validation

**Objective**: Prove restoration works

```bash
# Restore container
ansible-playbook -i inventory/hosts.yml playbooks/<service>-deploy.yml

# Restore data
TIMESTAMP=$(cat /tmp/<service>-backup-timestamp.txt)
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=$TIMESTAMP
```

- [ ] Container restored successfully
- [ ] Data restored successfully
- [ ] Service accessible: `curl -I https://<service>.viljo.se`
- [ ] Test data matches original
- [ ] External test passes (repeat Step 2)
- [ ] Completion report created

**Recovery Metrics**:
```
RTO (Recovery Time): _____ minutes
RPO (Data Loss): _____ minutes
Data Verification: [ ] Pass [ ] Fail
```

---

## Final Verification

### MANDATORY Requirements (Gate for Production)
- [ ] ✅ **DNS entry configured and resolves**
- [ ] ✅ **HTTPS certificate valid** (Let's Encrypt)
- [ ] ✅ **SSO integration working** (tested login flow)
- [ ] ✅ **Verification script passes**: `./scripts/verify-service-requirements.sh servicename`

### Workflow Completion
- [ ] ✅ All 9.5 steps completed successfully (including Step 3.5 SSO)
- [ ] ✅ Service declared PRODUCTION READY
- [ ] Documentation updated (README.md, container-mapping.md)
- [ ] Service added to full-deployment.yml
- [ ] Backup schedule confirmed
- [ ] Monitoring added (if applicable)

**PRODUCTION GATE**: Service CANNOT be deployed to production without all 3 mandatory requirements verified.

---

## Success Metrics

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Deployment Time | < 10 min | _____ min | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| RTO | < 30 min | _____ min | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| RPO | < 24 hours | _____ | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Backup Size | < 5 GB | _____ GB | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Idempotency | 0-1 changes | _____ | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| External Tests | 100% | _____% | [ ] ✅ [ ] ⚠️ [ ] ❌ |

---

## Notes and Issues

### Issues Encountered
```
<Document any problems and how they were resolved>
```

### Improvements Identified
```
<Note any improvements for future services>
```

### Special Considerations
```
<Any unique aspects of this service>
```

---

## Sign-off

**Implemented by**: _______________
**Reviewed by**: _______________
**Date Completed**: _______________
**Production Deploy Date**: _______________

---

## Files Created

- [ ] `roles/<service>_api/` (Ansible role)
- [ ] `playbooks/<service>-deploy.yml` (Playbook)
- [ ] `scripts/populate-<service>-testdata.sh` (Test data script)
- [ ] `/tmp/<service>-backup-report.txt` (Backup report)
- [ ] `/tmp/<service>-wipe-report.txt` (Wipe report)
- [ ] `/tmp/<service>-completion-report.txt` (Completion report)

---

**Reference**: See [NEW_SERVICE_WORKFLOW.md](NEW_SERVICE_WORKFLOW.md) for detailed procedures.
