# Test-Driven Service Deployment Workflow

**Purpose**: Forcing routine to ensure every new service is properly automated, tested, backed up, and can be restored.

**Principle**: No service is considered "complete" until it passes all 9 steps of this workflow.

---

## Overview

This workflow enforces a test-driven development approach for infrastructure services:

1. ✅ **Implement** → Create automation
2. ✅ **Test** → Verify with external tools
3. ✅ **Recreate** → Validate automation works
4. ✅ **Backup Plan** → Integrate data backups
5. ✅ **Populate** → Add test data
6. ✅ **Test Backup** → Verify backup script works
7. ✅ **Execute Backup** → Take actual backup
8. ✅ **Wipe** → Delete service completely
9. ✅ **Restore & Verify** → Prove DR works

**Goal**: Every service can be deployed from scratch and restored from backup without manual intervention.

---

## Prerequisites: Configuration Management

**IMPORTANT**: Before starting, understand how to properly manage configuration and secrets:

- 📖 **Read**: [Configuration Management Guide](deployment/configuration-management.md)
- ✅ **Track topology in git**: Container IDs, IPs, ports → commit to git
- 🔐 **Secrets in Vault**: Passwords, tokens, keys → `ansible-vault edit inventory/group_vars/all/secrets.yml`
- 🔒 **Use vault references**: Always use `{{ vault_service_password }}` pattern
- ❌ **Never commit**: Hardcoded passwords, `.vault_pass.txt`, test files with secrets

**Quick Check Before Committing:**
```bash
# Verify no hardcoded secrets
grep -E "(password|secret|api_key|token):" inventory/group_vars/all/yourservice.yml | grep -v "vault_"
# If this returns anything, those lines need vault references!
```

---

## MANDATORY REQUIREMENTS FOR ALL SERVICES

**CRITICAL**: Every service deployment MUST include these three requirements:

1. **SSO via Keycloak** (GitLab.com OAuth backend)
2. **DNS entry at Loopia** (automated via loopia_dns role)
3. **HTTPS certificate** (automated via Traefik + Let's Encrypt)

**These are NOT OPTIONAL.** They ensure security, discoverability, and usability.

**See detailed implementation guide**: [SERVICE_IMPLEMENTATION_PIPELINE.md](SERVICE_IMPLEMENTATION_PIPELINE.md)

**When implemented:**
- DNS Entry: Step 1 (before deployment)
- HTTPS Certificate: Step 1 (after container created)
- SSO Integration: Step 3.5 (after automation validation, before backup planning)

---

## Step 1: Implement Service (Initial Deployment)

**Objective**: Create working Ansible automation for the service

### MANDATORY: Add DNS and Traefik Entries First

**BEFORE creating the Ansible role**, add these mandatory entries:

1. **Add DNS entry** to `inventory/group_vars/all/main.yml`:
   ```yaml
   loopia_dns_records:
     # ... existing entries ...
     - host: servicename  # Add your service
       ttl: 600
   ```

2. **Add Traefik service** to `inventory/group_vars/all/main.yml`:
   ```yaml
   traefik_services:
     # ... existing entries ...
     - name: servicename
       host: "servicename.{{ public_domain }}"
       container_id: "{{ servicename_container_id }}"
       port: 8080  # Internal service port
   ```

3. **Deploy DNS configuration**:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/loopia-dns-deploy.yml --ask-vault-pass
   ```

4. **Verify DNS resolves**:
   ```bash
   dig +short servicename.viljo.se @1.1.1.1
   # Should return your public IP
   ```

**Why this order?** DNS must exist before Traefik can request HTTPS certificate.

### Tasks

1. **Create Ansible role** following API-first pattern:
   ```
   roles/<service>_api/
   ├── defaults/main.yml    # Configuration variables
   ├── tasks/main.yml       # Deployment logic
   ├── templates/           # Config file templates
   └── handlers/main.yml    # Service restart handlers
   ```

2. **Create deployment playbook**:
   ```yaml
   # playbooks/<service>-deploy.yml
   - name: Deploy <Service>
     hosts: proxmox_admin
     roles:
       - role: <service>_api
   ```

3. **Use Proxmox API** (not pct exec):
   ```yaml
   - name: Create container via Proxmox API
     community.proxmox.proxmox:
       api_host: "{{ proxmox_api_host }}"
       api_user: "{{ proxmox_api_user }}"
       api_password: "{{ proxmox_api_password }}"
       # ... container config
   ```

4. **Configure service via SSH delegation**:
   ```yaml
   - name: Install packages
     ansible.builtin.apt:
       name: <packages>
     delegate_to: <service>_container
   ```

5. **Add health checks**:
   ```yaml
   - name: Verify service is running
     ansible.builtin.uri:
       url: "http://{{ service_ip }}:{{ service_port }}/health"
       status_code: 200
   ```

6. **Deploy Traefik configuration** (enables HTTPS):
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/traefik-deploy.yml --ask-vault-pass
   ```

7. **Monitor certificate issuance** (~1-3 minutes):
   ```bash
   pct exec 167 -- docker logs -f traefik
   # Look for: "Obtained certificate for servicename.viljo.se"
   ```

8. **Verify HTTPS access**:
   ```bash
   curl -I https://servicename.viljo.se
   # Should return HTTP/2 200 with valid certificate
   ```

### Acceptance Criteria

**Ansible Automation:**
- [ ] Ansible role created with all required files
- [ ] Deployment playbook runs without errors
- [ ] Container created via Proxmox API
- [ ] Service starts automatically
- [ ] Health check passes
- [ ] No manual steps required

**MANDATORY REQUIREMENTS (Must be completed in Step 1):**
- [ ] **DNS entry added** to inventory/group_vars/all/main.yml
- [ ] **DNS resolves correctly**: `dig +short servicename.viljo.se` returns public IP
- [ ] **Traefik service entry added** to inventory/group_vars/all/main.yml
- [ ] **HTTPS certificate issued**: Service accessible via https://servicename.viljo.se
- [ ] **No browser security warnings**: Certificate valid and trusted
- [ ] **SSO will be configured in Step 3.5** (after automation validation)

### Documentation Required

- [ ] Role README.md with usage examples
- [ ] Required vault variables documented
- [ ] Service dependencies listed
- [ ] Port mappings documented
- [ ] **Service configuration committed to git** (`inventory/group_vars/all/<service>.yml`)
- [ ] **Secrets added to Vault** (no hardcoded credentials in tracked files)
- [ ] **Links page updated** (add service to `inventory/group_vars/all/services.yml` and redeploy)

### Links Page Update (REQUIRED for Public-Facing Services)

**⚠️ CRITICAL**: If your service is publicly accessible, you **MUST** update the links page.

**Quick Steps**:

1. **Add service to services registry**:
   ```bash
   vi inventory/group_vars/all/services.yml
   ```

2. **Add entry in deployed_working section**:
   ```yaml
   - name: Your Service
     slug: servicename
     icon: "🚀"
     description: Brief service description
     subdomain: servicename
     container_id: "{{ servicename_container_id }}"
     status: deployed_working
     spec: specs/path/to/spec
   ```

3. **Redeploy links portal**:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml
   ```

4. **Verify service appears**:
   ```bash
   open https://links.viljo.se
   ```

5. **Commit changes**:
   ```bash
   git add inventory/group_vars/all/services.yml
   git commit -m "Add [Service] to links page"
   ```

**See**: [Links Page Maintenance Guide](LINKS_PAGE_MAINTENANCE.md) for complete details.

---

## Step 2: Test with External Tools

**Objective**: Verify service is accessible and functional from outside the infrastructure

### External Testing Methods

#### Web Services
```bash
# Test HTTPS access
curl -I https://<service>.viljo.se

# Test with external service
# HTTPie: https://httpie.io/app
# Uptime Robot: https://uptimerobot.com
# SSL Labs: https://www.ssllabs.com/ssltest/
```

#### API Services
```bash
# Test API endpoint
curl -X GET https://<service>.viljo.se/api/health

# Test with Postman or Insomnia
# Import collection and run tests
```

#### Database Services
```bash
# Test from another container
pct exec <other-container> -- psql -h <service-ip> -U <user> -l

# Test connection pooling
pgbench -h <service-ip> -U <user> -d <database>
```

#### Docker Services
```bash
# Verify container is running
pct exec <container-id> -- docker ps

# Test service inside container
pct exec <container-id> -- docker exec <service> <health-check-command>
```

### Mobile Data Test (Critical!)

**Why**: Admin network access may bypass firewall/routing issues.

```bash
# Disconnect from WiFi
# Use mobile data (not connected to admin network)
curl -I https://<service>.viljo.se

# Or use external VPS
ssh user@external-vps "curl -I https://<service>.viljo.se"
```

### Acceptance Criteria

- [ ] Service accessible via HTTPS from internet
- [ ] External testing service confirms availability
- [ ] Mobile data test passes (not admin network)
- [ ] Service responds correctly to requests
- [ ] SSL certificate valid and trusted
- [ ] DNS resolves correctly from external resolvers

### Documentation Required

- [ ] External access URLs documented
- [ ] Test procedures documented
- [ ] Expected responses documented

---

## Step 3: Delete and Recreate (Automation Validation)

**Objective**: Prove automation is complete and idempotent

### Delete Service

```bash
# Stop and destroy container
pct stop <container-id>
pct destroy <container-id>

# Verify deletion
pct list | grep <container-id>  # Should return nothing
```

### Recreate Service

```bash
# Run deployment playbook
ansible-playbook -i inventory/hosts.yml playbooks/<service>-deploy.yml \
  --vault-password-file=.vault_pass.txt

# Time the deployment
time ansible-playbook -i inventory/hosts.yml playbooks/<service>-deploy.yml
```

### Verify Idempotency

```bash
# Run playbook again (should make no changes)
ansible-playbook -i inventory/hosts.yml playbooks/<service>-deploy.yml \
  --vault-password-file=.vault_pass.txt

# Check output: "changed=0" or "changed=1" (only inventory update)
```

### Acceptance Criteria

- [ ] Container deleted successfully
- [ ] Playbook recreates service without errors
- [ ] Service fully functional after recreation
- [ ] Deployment time < 10 minutes
- [ ] Second run is idempotent (no changes)
- [ ] No manual steps required
- [ ] External access still works

### Common Issues

**Problem**: Playbook fails on recreation
- **Cause**: Hard-coded values or missing cleanup
- **Fix**: Use variables, add cleanup tasks

**Problem**: Service not starting after recreation
- **Cause**: Missing dependencies or configuration
- **Fix**: Add dependency checks, verify all config files

**Problem**: Playbook not idempotent
- **Cause**: Tasks always report "changed"
- **Fix**: Use `changed_when: false` or check before modify

---

## Step 3.5: SSO Integration (MANDATORY)

**Objective**: Configure Single Sign-On via Keycloak for service authentication

**This is a MANDATORY requirement.** No service is production-ready without SSO.

### Why SSO Integration Happens Here

SSO configuration requires:
- Working service (Step 1 complete)
- Service accessible via HTTPS (Step 1 complete)
- Validated automation (Step 3 complete)
- Stable service endpoint (before backups in Step 4)

### Implementation Approaches

**Choose the approach based on service capabilities:**

#### Approach A: Native OIDC Support (PREFERRED)

Use when service has built-in Keycloak/OIDC integration.

**Examples**: Nextcloud, GitLab, Jellyfin, Coolify, Grafana

**Steps**:

1. **Create Keycloak Client**:
   ```bash
   # Open Keycloak admin console
   open https://keycloak.viljo.se
   # Login with admin credentials (from vault)

   # Navigate: Clients → Create client
   # Client ID: servicename
   # Client Type: OpenID Connect
   # Client authentication: ON (confidential)
   # Valid redirect URIs: https://servicename.viljo.se/*
   # (Add service-specific callback URLs)
   ```

2. **Configure Client Mappers** (in Keycloak):
   - Add "username" mapper: `preferred_username` claim
   - Add "email verified" mapper: `email_verified` claim
   - See [SERVICE_IMPLEMENTATION_PIPELINE.md](SERVICE_IMPLEMENTATION_PIPELINE.md) Section B, Step A.3

3. **Store Client Secret**:
   ```bash
   # Edit vault
   ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt

   # Add:
   # vault_servicename_oidc_client_secret: "paste-secret-from-keycloak"
   ```

4. **Configure Service for OIDC**:
   - Add OIDC configuration to service
   - Use discovery endpoint: `https://keycloak.viljo.se/realms/master/.well-known/openid-configuration`
   - Client ID: `servicename`
   - Client Secret: `{{ vault_servicename_oidc_client_secret }}`
   - Enable auto-provisioning (create users on first login)

5. **Test SSO Login Flow**:
   ```bash
   # Open in incognito mode
   open https://servicename.viljo.se

   # Click SSO login button
   # Should redirect to Keycloak → GitLab.com
   # Authenticate with GitLab credentials
   # Should return to service, logged in
   ```

6. **Verify User Provisioning**:
   - Login via SSO
   - Check user created in service
   - Verify username and email populated
   - Grant admin access if needed (service-specific command)

#### Approach B: oauth2-proxy Forward Auth

Use when service lacks native OIDC support.

**Examples**: Legacy services, services without OAuth support

**Steps**:

1. **Create Keycloak Client** (same as Approach A, step 1)
   - Client ID: `servicename-proxy` (distinguish from service)
   - Redirect URI: `https://servicename.viljo.se/oauth2/callback`

2. **Store Client Secret in Vault** (same as Approach A, step 3)

3. **Configure oauth2-proxy** for service:
   - Add to oauth2-proxy configuration
   - Configure forward auth to service backend
   - See [SERVICE_IMPLEMENTATION_PIPELINE.md](SERVICE_IMPLEMENTATION_PIPELINE.md) Section B, Approach B

4. **Update Traefik Middleware**:
   ```yaml
   # inventory/group_vars/all/main.yml
   traefik_services:
     - name: servicename
       # ... existing config ...
       middlewares:
         - "oauth2-proxy-servicename@file"
   ```

5. **Deploy oauth2-proxy and Traefik**:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/oauth2-proxy-deploy.yml --ask-vault-pass
   ansible-playbook -i inventory/hosts.yml playbooks/traefik-deploy.yml --ask-vault-pass
   ```

6. **Test Forward Auth Flow**:
   - Access service
   - Should auto-redirect to oauth2-proxy
   - Login via Keycloak → GitLab.com
   - Should return to service with auth headers

### Detailed Implementation Guide

**For complete step-by-step instructions, see**:
[SERVICE_IMPLEMENTATION_PIPELINE.md](SERVICE_IMPLEMENTATION_PIPELINE.md) - Section B: Implementation Steps, Step 3

This comprehensive guide includes:
- Keycloak client creation procedures
- Client mapper configuration
- Service-specific OIDC configuration examples
- Troubleshooting common issues
- Testing procedures

### Acceptance Criteria

**SSO Configuration:**
- [ ] **Keycloak client created** with correct settings
- [ ] **Client secret stored in vault** (vault_servicename_oidc_client_secret)
- [ ] **Client mappers configured** (username, email_verified)
- [ ] **Service configured for OIDC** (discovery endpoint or manual endpoints)
- [ ] **Auto-provisioning enabled** (if service supports)

**SSO Testing:**
- [ ] **SSO login button appears** on service login page
- [ ] **Redirect to Keycloak works** (no errors)
- [ ] **GitLab.com authentication works** (can login)
- [ ] **Return to service successful** (no redirect loops)
- [ ] **User auto-provisioned** (user created on first login)
- [ ] **User attributes populated** (username, email correct)
- [ ] **Admin access granted** (if needed, via service-specific command)

**Documentation:**
- [ ] **SSO configuration documented** in service README
- [ ] **Admin user grant procedure documented**
- [ ] **Client secret location documented** (vault variable name)
- [ ] **Troubleshooting steps added** for common SSO issues

### Common Issues and Solutions

**Issue**: "invalid_redirect_uri" error
- **Fix**: Verify redirect URI in Keycloak matches service callback URL exactly
- Include wildcards if needed: `https://servicename.viljo.se/*`

**Issue**: User authenticated but no username/email
- **Fix**: Add username and email_verified mappers in Keycloak client

**Issue**: "OIDC provider not found"
- **Fix**: Verify discovery endpoint accessible from service container
- Test: `curl https://keycloak.viljo.se/realms/master/.well-known/openid-configuration`

**Issue**: Redirect loop
- **Fix**: Clear browser cookies, verify session storage in service works

**For complete troubleshooting guide, see**:
[SERVICE_IMPLEMENTATION_PIPELINE.md](SERVICE_IMPLEMENTATION_PIPELINE.md) - Section B, Step 3, "SSO Implementation Troubleshooting"

### Exception Handling

**If service truly cannot support SSO** (rare):

1. **Document why SSO is not possible**:
   - Technical limitation (no OIDC support, no reverse proxy support)
   - Service type (API-only, no web UI)
   - Legacy system constraints

2. **Propose alternative authentication**:
   - API keys with rotation policy
   - mTLS certificates
   - IP allowlisting

3. **Document security compensating controls**:
   - Strong password policy
   - MFA if available
   - Audit logging
   - Network isolation

4. **Get explicit approval** before proceeding

5. **Add to technical debt register** for future remediation

**Exception process documented in**:
[SERVICE_IMPLEMENTATION_PIPELINE.md](SERVICE_IMPLEMENTATION_PIPELINE.md) - Section A, "Exception Handling"

### Time Estimate

- **Approach A (Native OIDC)**: 15-30 minutes
- **Approach B (oauth2-proxy)**: 30-45 minutes
- **First time**: Add 15-30 minutes for learning
- **Troubleshooting**: Budget extra 15-30 minutes if issues arise

### Next Step

Once SSO is configured and tested, proceed to Step 4 (Backup Planning).

**Do not proceed without completing SSO integration.** This is a mandatory gate.

---

## Step 4: Implement Data Backup Plan

**Objective**: Integrate service data backups with project backup infrastructure

**Preference**: Data-level backups (not container/VM snapshots)

### Why Data-Level Backups?

✅ **Advantages**:
- Smaller backup size
- Faster backup/restore
- Point-in-time recovery
- Can restore to different container
- Better for large datasets

❌ **Container Snapshots**:
- Large size (includes OS, packages)
- Slower
- All-or-nothing restore
- Can be corrupted (GitLab example)

### Backup Types by Service

#### Database Services (PostgreSQL, MySQL, etc.)
```yaml
# roles/backup_infrastructure/defaults/main.yml
backup_postgresql_databases:
  - <new-service-db>

# Use pg_dump for PostgreSQL
pg_dump -Fc -h <host> -U <user> <database> > backup.dump
```

#### Key-Value Stores (Redis, etcd, etc.)
```yaml
# Use native persistence
redis-cli SAVE
cp /var/lib/redis/dump.rdb /backup/

# Or use RDB/AOF files
```

#### Document Stores (MongoDB, CouchDB, etc.)
```yaml
# Use native backup tools
mongodump --host <host> --out /backup/
```

#### File-Based Services (Nextcloud, GitLab, etc.)
```yaml
# Backup data directories
backup_docker_containers:
  - container_id: <id>
    name: <service>
    volumes:
      - "/opt/<service>/data"
      - "/opt/<service>/config"
```

#### Configuration Files
```yaml
# Backup service configs
backup_configs:
  - "/etc/<service>/config.yml"
  - "/opt/<service>/settings.json"
```

### Integration Steps

1. **Update backup role defaults** (`roles/backup_infrastructure/defaults/main.yml`):
   ```yaml
   # Add to appropriate section
   backup_<type>_<service>_enabled: true
   backup_<service>_<parameters>: <values>
   ```

2. **Update backup role tasks** (`roles/backup_infrastructure/tasks/main.yml`):
   ```yaml
   - name: Backup <service> data
     ansible.builtin.shell:
       cmd: |
         <backup command>
     when: backup_<service>_enabled
   ```

3. **Update restore role defaults** (`roles/restore_infrastructure/defaults/main.yml`):
   ```yaml
   restore_<service>_enabled: true
   restore_<service>_parameters: <values>
   ```

4. **Update restore role tasks** (`roles/restore_infrastructure/tasks/main.yml`):
   ```yaml
   - name: Restore <service> data
     ansible.builtin.shell:
       cmd: |
         <restore command>
     when: restore_<service>_enabled
   ```

### Acceptance Criteria

- [ ] Backup commands defined and tested
- [ ] Backup integrated into `backup_infrastructure` role
- [ ] Restore integrated into `restore_infrastructure` role
- [ ] Backup variables added to defaults
- [ ] Restore variables added to defaults
- [ ] Backup/restore toggles work (enabled/disabled)

### Documentation Required

- [ ] Backup strategy documented (what is backed up)
- [ ] Backup frequency documented (daily, hourly, etc.)
- [ ] Restore procedure documented
- [ ] RPO/RTO targets documented

---

## Step 5: Populate Service with Test Data

**Objective**: Add meaningful test data to verify backup/restore works correctly

### Why Test Data?

- **Validates backup**: Empty backup might "work" but not actually capture data
- **Validates restore**: Can verify data integrity after restore
- **Tests relationships**: Database foreign keys, file references, etc.
- **Realistic scenarios**: Tests with actual data structures

### Test Data Examples

#### Database Service
```sql
-- Create test users
INSERT INTO users (username, email) VALUES
  ('testuser1', 'test1@example.com'),
  ('testuser2', 'test2@example.com');

-- Create test data with relationships
INSERT INTO projects (name, owner_id) VALUES
  ('Test Project 1', 1),
  ('Test Project 2', 2);

-- Verify data
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM projects;
```

#### File Storage Service
```bash
# Upload test files
curl -X PUT https://<service>.viljo.se/files/test1.txt \
  --data "Test content 1"

# Create directory structure
mkdir -p /data/test/{a,b,c}
echo "content" > /data/test/a/file.txt

# Verify files
ls -laR /data/test/
```

#### Configuration Service
```bash
# Create test configuration
curl -X POST https://<service>.viljo.se/api/config \
  -d '{"key": "test_key", "value": "test_value"}'

# Verify configuration
curl https://<service>.viljo.se/api/config/test_key
```

#### Docker Service
```bash
# Create test data inside container
pct exec <id> -- docker exec <service> sh -c "
  echo 'test data' > /app/data/test.txt
  cat /app/data/test.txt
"
```

### Test Data Script Template

```bash
#!/bin/bash
# scripts/populate-<service>-testdata.sh

set -e

echo "Populating <service> with test data..."

# Create test users/data
<commands to create data>

# Verify data created
<commands to verify>

echo "✓ Test data created successfully"
echo "Summary:"
echo "  - <count> users created"
echo "  - <count> records created"
echo "  - <size> of data added"
```

### Acceptance Criteria

- [ ] At least 3 different types of test data created
- [ ] Data includes relationships/dependencies
- [ ] Data is verifiable (can count/list)
- [ ] Test data script created and documented
- [ ] Total data size > 1MB (to test backup/restore performance)
- [ ] Data verification script created

### Documentation Required

- [ ] Test data creation script in `scripts/`
- [ ] Test data verification procedure documented
- [ ] Expected data counts/sizes documented

---

## Step 6: Test Backup Script

**Objective**: Verify backup script captures service data correctly

### Run Backup

```bash
# Run backup playbook
ansible-playbook -i inventory/hosts.yml playbooks/backup-infrastructure.yml \
  --vault-password-file=.vault_pass.txt

# Check for service-specific backup
TIMESTAMP=$(ls -1 /var/backups/infrastructure/ | tail -1)
ls -lh /var/backups/infrastructure/$TIMESTAMP/
```

### Verify Backup Contents

#### Database Backups
```bash
# Check database dump exists and has size
ls -lh /var/backups/infrastructure/$TIMESTAMP/postgresql/<service>_$TIMESTAMP.dump

# Verify dump is valid (can list contents)
pg_restore --list /var/backups/infrastructure/$TIMESTAMP/postgresql/<service>_$TIMESTAMP.dump
```

#### File Backups
```bash
# Check archive exists
ls -lh /var/backups/infrastructure/$TIMESTAMP/docker-volumes/<service>_*_$TIMESTAMP.tar.gz

# Verify archive is valid
tar -tzf /var/backups/infrastructure/$TIMESTAMP/docker-volumes/<service>_*_$TIMESTAMP.tar.gz | head -20
```

#### Redis Backups
```bash
# Check dump.rdb exists
ls -lh /var/backups/infrastructure/$TIMESTAMP/redis_$TIMESTAMP.rdb

# Verify RDB is valid
redis-check-rdb /var/backups/infrastructure/$TIMESTAMP/redis_$TIMESTAMP.rdb
```

### Test Backup Size

```bash
# Check total backup size
du -sh /var/backups/infrastructure/$TIMESTAMP/

# Compare to previous backups
du -sh /var/backups/infrastructure/*/
```

### Acceptance Criteria

- [ ] Backup script runs without errors
- [ ] Service data captured in backup
- [ ] Backup files have reasonable size (> 0 bytes)
- [ ] Backup files are valid (not corrupted)
- [ ] Backup includes all test data created in Step 5
- [ ] Backup time < 5 minutes for the service

### Common Issues

**Problem**: Backup file is 0 bytes or very small
- **Cause**: Backup command failed silently
- **Fix**: Add error checking, verify paths

**Problem**: Backup script reports success but data missing
- **Cause**: Wrong path or incorrect command
- **Fix**: Verify backup source path, test command manually

**Problem**: Backup takes too long
- **Cause**: Inefficient backup method
- **Fix**: Use incremental backups, compress efficiently

---

## Step 7: Execute Backup (Create Baseline)

**Objective**: Create a verified baseline backup for restoration testing

### Pre-Backup Checklist

- [ ] Service is running and healthy
- [ ] Test data populated (Step 5 complete)
- [ ] Backup script tested (Step 6 complete)
- [ ] Sufficient storage space available
- [ ] Backup timestamp will be recorded

### Execute Backup

```bash
# Record start time
START_TIME=$(date +%Y-%m-%dT%H:%M:%S)
echo "Backup started: $START_TIME"

# Run backup
ansible-playbook -i inventory/hosts.yml playbooks/backup-infrastructure.yml \
  --vault-password-file=.vault_pass.txt

# Record end time
END_TIME=$(date +%Y-%m-%dT%H:%M:%S)
echo "Backup completed: $END_TIME"

# Record backup timestamp
BACKUP_TIMESTAMP=$(ls -1 /var/backups/infrastructure/ | tail -1)
echo "Backup timestamp: $BACKUP_TIMESTAMP"

# Save for restoration test
echo "$BACKUP_TIMESTAMP" > /tmp/<service>-backup-timestamp.txt
```

### Post-Backup Verification

```bash
# Verify backup exists
ls -lh /var/backups/infrastructure/$BACKUP_TIMESTAMP/

# Verify service-specific files
find /var/backups/infrastructure/$BACKUP_TIMESTAMP/ -name "*<service>*" -ls

# Check backup manifest
cat /var/backups/infrastructure/$BACKUP_TIMESTAMP/MANIFEST.yml
```

### Document Backup

```bash
# Create backup report
cat > /tmp/<service>-backup-report.txt <<EOF
Service: <service>
Backup Date: $(date)
Backup Timestamp: $BACKUP_TIMESTAMP
Backup Size: $(du -sh /var/backups/infrastructure/$BACKUP_TIMESTAMP/ | cut -f1)

Files Backed Up:
$(find /var/backups/infrastructure/$BACKUP_TIMESTAMP/ -name "*<service>*" -type f -ls)

Test Data Included:
- <description of test data>

Notes:
- <any observations or issues>
EOF

cat /tmp/<service>-backup-report.txt
```

### Acceptance Criteria

- [ ] Backup completed successfully
- [ ] Backup timestamp recorded
- [ ] All service data included in backup
- [ ] Backup size reasonable
- [ ] Backup report created
- [ ] Service still running after backup

---

## Step 8: Wipe Service (Destructive Test)

**Objective**: Completely remove service to test restoration

**⚠️ WARNING**: This is a destructive operation. Only proceed if you have verified backup in Step 7.

### Pre-Wipe Verification

```bash
# Confirm backup exists
BACKUP_TIMESTAMP=$(cat /tmp/<service>-backup-timestamp.txt)
ls -lh /var/backups/infrastructure/$BACKUP_TIMESTAMP/ | grep <service>

# Verify backup is complete
find /var/backups/infrastructure/$BACKUP_TIMESTAMP/ -name "*<service>*" -type f
```

### Wipe Service

#### Option A: Container-Only Wipe (Preferred)
```bash
# Stop container
pct stop <container-id>

# Destroy container (keeps backups)
pct destroy <container-id>

# Verify deletion
pct list | grep <container-id>  # Should return nothing
```

#### Option B: Container + Data Wipe (Complete)
```bash
# Stop container
pct stop <container-id>

# Destroy container
pct destroy <container-id>

# Delete service data from other containers (if applicable)
# Example: Delete database
pct exec 150 -- su - postgres -c "dropdb <service-db>"

# Delete Docker volumes (if applicable)
pct exec <parent-container> -- rm -rf /opt/<service>/
```

### Post-Wipe Verification

```bash
# Verify container deleted
pct list | grep <container-id>

# Verify service not accessible
curl -I https://<service>.viljo.se  # Should fail

# Verify data deleted (if Option B)
pct exec 150 -- su - postgres -c "psql -l" | grep <service-db>  # Should return nothing
```

### Document Wipe

```bash
# Create wipe report
cat > /tmp/<service>-wipe-report.txt <<EOF
Service: <service>
Wipe Date: $(date)
Wipe Type: <container-only|complete>
Container ID: <container-id>

Verification:
- Container deleted: $(pct list | grep -q <container-id> && echo "NO" || echo "YES")
- Service accessible: $(curl -s -o /dev/null -w "%{http_code}" https://<service>.viljo.se)
- Data deleted: <verification result>

Ready for restoration: YES
Backup to restore: $BACKUP_TIMESTAMP
EOF

cat /tmp/<service>-wipe-report.txt
```

### Acceptance Criteria

- [ ] Container completely deleted
- [ ] Service no longer accessible
- [ ] Data removed (if complete wipe)
- [ ] Backup still exists and accessible
- [ ] Wipe report created

---

## Step 9: Restore Service and Verify

**Objective**: Prove service can be fully restored from backup

### Restore Container

```bash
# Get backup timestamp
BACKUP_TIMESTAMP=$(cat /tmp/<service>-backup-timestamp.txt)

# Method A: Use automation (preferred)
ansible-playbook -i inventory/hosts.yml playbooks/<service>-deploy.yml \
  --vault-password-file=.vault_pass.txt

# Method B: Restore from container backup (if automation fails)
CONTAINER_BACKUP=$(pvesm list local | grep "vzdump-lxc-<container-id>" | tail -1 | awk '{print $1}')
pct restore <container-id> "$CONTAINER_BACKUP" --storage local-lvm
pct start <container-id>
```

### Restore Data

```bash
# Run data restoration playbook
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  --vault-password-file=.vault_pass.txt \
  -e restore_backup_timestamp=$BACKUP_TIMESTAMP \
  -e restore_<other-services>_enabled=false

# Or restore manually if automation not ready
# (See manual procedures in DR Runbook)
```

### Verify Service

```bash
# Check container running
pct status <container-id>

# Check service accessible
curl -I https://<service>.viljo.se

# Check service health endpoint
curl https://<service>.viljo.se/health
```

### Verify Data Restoration

#### Database Service
```bash
# Check database exists
pct exec 150 -- su - postgres -c "psql -l" | grep <service-db>

# Check record count matches
pct exec 150 -- su - postgres -c "psql -d <service-db> -c 'SELECT COUNT(*) FROM users;'"

# Compare to pre-backup count from Step 5
```

#### File Storage Service
```bash
# Check files exist
pct exec <container-id> -- ls -laR /data/test/

# Check file contents match
pct exec <container-id> -- cat /data/test/a/file.txt
# Compare to original from Step 5
```

#### Configuration Service
```bash
# Check configuration restored
curl https://<service>.viljo.se/api/config/test_key

# Compare to original from Step 5
```

### Calculate Recovery Metrics

```bash
# Recovery Time Objective (RTO)
RESTORE_START=$(date +%s -r /tmp/<service>-wipe-report.txt)
RESTORE_END=$(date +%s)
RTO_SECONDS=$((RESTORE_END - RESTORE_START))
RTO_MINUTES=$((RTO_SECONDS / 60))

echo "RTO: ${RTO_MINUTES} minutes"

# Recovery Point Objective (RPO)
BACKUP_TIME=$(date +%s -r /var/backups/infrastructure/$BACKUP_TIMESTAMP/)
DATA_LOSS_SECONDS=$((RESTORE_START - BACKUP_TIME))
DATA_LOSS_MINUTES=$((DATA_LOSS_SECONDS / 60))

echo "RPO: ${DATA_LOSS_MINUTES} minutes"
```

### Create Completion Report

```bash
cat > /tmp/<service>-completion-report.txt <<EOF
========================================
Service Deployment Workflow - COMPLETE
========================================

Service: <service>
Container ID: <container-id>
Completion Date: $(date)

Test Results:
✅ Step 1: Service implemented and deployed
✅ Step 2: External testing passed
✅ Step 3: Delete/recreate validation passed
✅ Step 4: Data backup plan integrated
✅ Step 5: Test data populated
✅ Step 6: Backup script tested
✅ Step 7: Baseline backup created
✅ Step 8: Service wiped
✅ Step 9: Service restored and verified

Recovery Metrics:
- RTO: ${RTO_MINUTES} minutes
- RPO: ${DATA_LOSS_MINUTES} minutes
- Backup Size: $(du -sh /var/backups/infrastructure/$BACKUP_TIMESTAMP/ | cut -f1)
- Success Rate: 100%

Data Verification:
- Database records: <count> (✓ matches)
- Files restored: <count> (✓ matches)
- Configuration: <status> (✓ matches)

External Access:
- HTTPS: $(curl -s -o /dev/null -w "%{http_code}" https://<service>.viljo.se)
- Health: $(curl -s https://<service>.viljo.se/health)

Service Status: PRODUCTION READY ✓

Next Steps:
1. Remove test data (if desired)
2. Configure for production use
3. Add monitoring
4. Add to regular backup schedule
5. Document in architecture docs

Backup Timestamp: $BACKUP_TIMESTAMP
EOF

cat /tmp/<service>-completion-report.txt
```

### Acceptance Criteria

- [ ] Container restored successfully
- [ ] Data restored successfully
- [ ] Service accessible via HTTPS
- [ ] Test data matches original (Step 5)
- [ ] RTO < 30 minutes
- [ ] RPO < 24 hours
- [ ] External testing passes (repeat Step 2)
- [ ] Completion report created
- [ ] Service declared PRODUCTION READY

---

## Workflow Checklist Template

Copy this to track progress for each new service:

```markdown
# Service: <SERVICE_NAME>
## Container ID: <ID>
## Started: <DATE>

### Step 1: Implement Service
- [ ] Ansible role created
- [ ] Deployment playbook created
- [ ] Health checks added
- [ ] Documentation created
- [ ] Initial deployment successful

### Step 2: Test with External Tools
- [ ] HTTPS access confirmed
- [ ] External testing service passed
- [ ] Mobile data test passed
- [ ] SSL certificate valid
- [ ] DNS resolves correctly

### Step 3: Delete and Recreate
- [ ] Container deleted successfully
- [ ] Playbook recreated service
- [ ] Service fully functional
- [ ] Idempotency verified
- [ ] Deployment time: ____ minutes

### Step 4: Implement Data Backup Plan
- [ ] Backup strategy defined
- [ ] Backup role updated
- [ ] Restore role updated
- [ ] Backup variables added
- [ ] Restore variables added

### Step 5: Populate with Test Data
- [ ] Test data created
- [ ] Test data script created
- [ ] Data verification script created
- [ ] Test data size: ____ MB
- [ ] Data counts documented

### Step 6: Test Backup Script
- [ ] Backup script ran successfully
- [ ] Backup files verified
- [ ] Backup size reasonable: ____ MB
- [ ] Backup time: ____ minutes
- [ ] Backup includes test data

### Step 7: Execute Backup
- [ ] Baseline backup created
- [ ] Backup timestamp recorded: ____________
- [ ] Backup report created
- [ ] Service still running after backup

### Step 8: Wipe Service
- [ ] Container deleted
- [ ] Data wiped (if applicable)
- [ ] Service inaccessible
- [ ] Backup still exists
- [ ] Wipe report created

### Step 9: Restore and Verify
- [ ] Container restored
- [ ] Data restored
- [ ] Service accessible
- [ ] Test data matches original
- [ ] RTO: ____ minutes
- [ ] RPO: ____ minutes
- [ ] Completion report created

### Final Status
- [ ] ✅ SERVICE PRODUCTION READY
- [ ] Documentation updated
- [ ] Backup schedule confirmed
- [ ] Monitoring added

## Notes
<Add any observations, issues encountered, or improvements needed>
```

---

## Integration with Project

### Update Project Documentation

After completing all 9 steps:

1. **Update README.md**:
   ```markdown
   - <Service Name> (<Container ID>) - <Description>
   ```

2. **Update container-mapping.md**:
   ```markdown
   | <ID> | <Service> | <Network> | <Resources> | ✅ Automated | Backup: ✅ |
   ```

3. **Update full-deployment.yml**:
   ```yaml
   - role: <service>_api
   ```

4. **Create ADR** (if significant architectural decision):
   ```markdown
   docs/adr/<number>-<service>-implementation.md
   ```

5. **Update backup schedule**:
   ```yaml
   # Add to cron or backup playbook
   ```

---

## Success Metrics

Track these metrics for each service:

| Metric | Target | Acceptable | Warning |
|--------|--------|------------|---------|
| Deployment Time | < 5 min | < 10 min | > 10 min |
| RTO (Recovery Time) | < 15 min | < 30 min | > 30 min |
| RPO (Data Loss) | < 1 hour | < 24 hours | > 24 hours |
| Backup Size | < 1GB | < 5GB | > 5GB |
| Idempotency | 0 changes | 1 change | > 1 change |
| External Test Success | 100% | > 95% | < 95% |

---

## Failure Scenarios

### What if a step fails?

**Step 1-2 Failure**: Service implementation issue
- **Action**: Debug and fix automation
- **Do not proceed** to next step until fixed

**Step 3 Failure**: Automation incomplete
- **Action**: Fix playbook, ensure idempotency
- **Critical**: Must pass before Step 4

**Step 4-6 Failure**: Backup implementation issue
- **Action**: Fix backup integration
- **Can proceed** with manual backup as temporary solution

**Step 7 Failure**: Backup execution failed
- **Action**: Fix backup script, retry
- **Do not proceed** to Step 8 without valid backup

**Step 8 Failure**: Wipe failed (container still exists)
- **Action**: Manual cleanup, verify deletion
- **Can proceed** once fully deleted

**Step 9 Failure**: Restoration failed
- **Action**: Critical issue - debug immediately
- **Do not deploy to production** until restore works

### Recovery from Failure

```bash
# If workflow interrupted
# Check which step was last completed
ls -lht /tmp/*-report.txt | head -5

# Resume from last completed step
cat /tmp/<service>-<step>-report.txt

# If service is in unknown state
pct list | grep <container-id>  # Check if exists
curl -I https://<service>.viljo.se  # Check if accessible

# If stuck, start over from Step 1
pct destroy <container-id>
# Re-run workflow from beginning
```

---

## Examples

See complete workflow examples:

- [Demo Site Workflow](../specs/completed/demo-site-deployment.md)
- [Mattermost Workflow](../specs/completed/mattermost-deployment.md)

---

**Document Owner**: Infrastructure Team
**Last Updated**: 2025-10-24
**Next Review**: After next service deployment
