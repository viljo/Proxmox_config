# Links Page Maintenance Guide

**Last Updated**: 2025-10-27
**Maintained By**: Infrastructure Team
**Related Services**: Links Portal (Container 160), Demo Site Role

---

## Purpose

The Links Portal (https://links.viljo.se) serves as the **single source of truth** for discovering all public-facing services in the Viljo infrastructure. It must **always reflect the current state** of deployed services to ensure:

1. **User Discovery**: Users can find and access all available services
2. **Service Inventory**: Accurate catalog of what's deployed and operational
3. **Status Transparency**: Clear indication of which services are working, under maintenance, or planned
4. **Professional Image**: Up-to-date portal demonstrates well-maintained infrastructure

**Critical Principle**: The links page is NOT optional documentation - it's a **required component** of service deployment.

---

## When to Update

The links page **MUST** be updated in the following scenarios:

### 1. New Service Deployment
**Trigger**: Any new public-facing service is deployed to the infrastructure

**Action Required**:
- Add service to `infrastructure_services` list in `inventory/group_vars/all/services.yml`
- Set status to `deployed_working` or `deployed_nonworking`
- Redeploy links portal

**Example Services**: GitLab, Nextcloud, Jellyfin, Coolify, etc.

### 2. Service Removal/Decommission
**Trigger**: A service is permanently removed from the infrastructure

**Action Required**:
- Remove service entry from `infrastructure_services` list
- OR move to a "deprecated" section with explanatory note
- Redeploy links portal

**Recent Example**: Mattermost was removed (deprecated in favor of other tools)

### 3. Service URL/Domain Change
**Trigger**: A service's public URL or subdomain changes

**Action Required**:
- Update `subdomain` field in service entry
- Update DNS configuration if needed
- Redeploy links portal
- Test new URL accessibility

### 4. Service Status Change
**Trigger**: A service's operational status changes

**Possible Status Values**:
- `deployed_working` - Service is running and accessible
- `deployed_nonworking` - Service exists but has issues
- `planned` - Service is planned but not yet deployed

**Action Required**:
- Update `status` field in service entry
- Optionally add `issue` field for non-working services
- Redeploy links portal

### 5. Service Metadata Update
**Trigger**: Service description, icon, or other display information changes

**Action Required**:
- Update relevant fields (`description`, `icon`, `name`, etc.)
- Redeploy links portal

---

## How to Update

### Method 1: Update via Ansible (Recommended - Infrastructure as Code)

This is the **correct and only approved method** for updating the links page.

#### Step 1: Edit the Services Registry

```bash
cd /Users/anders/git/Proxmox_config

# Edit the services registry file
vi inventory/group_vars/all/services.yml
```

#### Step 2: Add/Update Service Entry

Add new service to the appropriate section:

```yaml
infrastructure_services:
  # ==================================================================
  # DEPLOYED & WORKING - Services that are running and accessible
  # ==================================================================

  - name: Your Service Name
    slug: servicename
    icon: "🚀"  # Choose appropriate emoji
    description: Brief description of what this service does
    subdomain: servicename  # Results in servicename.viljo.se
    container_id: "{{ servicename_container_id }}"
    status: deployed_working
    spec: specs/path/to/spec  # Optional
    has_api: true  # Optional
    priority: P1  # For planned services
```

**Service Field Reference**:

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| `name` | Yes | Display name of service | `"Jellyfin"` |
| `slug` | Yes | Machine-readable identifier | `jellyfin` |
| `icon` | Yes | Emoji representing service | `"🎬"` |
| `description` | Yes | Brief service description | `"Media streaming server"` |
| `subdomain` | Yes | Subdomain (without domain) | `jellyfin` → `jellyfin.viljo.se` |
| `container_id` | Yes | LXC container ID variable | `"{{ jellyfin_container_id }}"` |
| `status` | Yes | Deployment status | `deployed_working`, `deployed_nonworking`, `planned` |
| `spec` | Optional | Path to specification | `specs/planned/009-jellyfin-media-server` |
| `has_api` | Optional | Service has API endpoint | `true` or `false` |
| `api_note` | Optional | Note about API behavior | `"API requires authentication"` |
| `priority` | Optional | For planned services | `P1`, `P2`, `P3` |
| `issue` | Optional | For non-working services | `"Database migration pending"` |
| `note` | Optional | Additional information | `"No web interface - VPN only"` |

#### Step 3: Verify Variable References

Ensure the container ID variable is defined in the service's inventory file:

```bash
# Check if variable exists
grep -r "servicename_container_id" inventory/group_vars/all/

# If not found, add to inventory/group_vars/all/servicename.yml:
servicename_container_id: 123
```

#### Step 4: Validate YAML Syntax

```bash
# Check for YAML syntax errors
ansible-playbook --syntax-check playbooks/demo-site-deploy.yml

# Or use yamllint
yamllint inventory/group_vars/all/services.yml
```

#### Step 5: Deploy Links Portal

```bash
cd /Users/anders/git/Proxmox_config

# Dry run to see what will change
ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml --check

# Deploy for real
ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml

# Or if using vault
ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml --ask-vault-pass
```

**Deployment Time**: ~2-5 minutes

#### Step 6: Commit Changes

```bash
git add inventory/group_vars/all/services.yml
git commit -m "Update links page: Add [Service Name]

- Added [Service Name] to deployed services
- Status: deployed_working
- URL: https://servicename.viljo.se

Updates links portal to reflect current infrastructure state.
"
git push
```

---

## Verification

After updating the links page, **always verify** the changes are correct:

### 1. Visual Verification

```bash
# Open links page in browser
open https://links.viljo.se

# Or use curl to check it's accessible
curl -I https://links.viljo.se
```

**Check**:
- ✅ New service appears in the correct section
- ✅ Service icon displays properly
- ✅ Service description is accurate
- ✅ Service URL is clickable

### 2. Link Testing

Test that each service link works:

```bash
# Test new service URL
curl -I https://servicename.viljo.se

# Expected: HTTP/2 200 or redirect to login
# Not expected: 404, 502, 503
```

### 3. Service Count Verification

The footer statistics should update automatically:
- **Services Online**: Count of `deployed_working` services
- **Maintenance**: Count of `deployed_nonworking` services
- **Services Planned**: Count of `planned` services
- **Total Services**: Sum of all above

### 4. Mobile Responsiveness

```bash
# Test on mobile device or use browser dev tools
# - Switch to mobile view
# - Verify cards display correctly
# - Check layout doesn't break
```

### 5. Cross-Browser Testing

Test in multiple browsers (Chrome, Firefox, Safari) to ensure compatibility.

---

## Automation

### Current Implementation

The links portal uses a **data-driven template** approach:

1. **Data Source**: `inventory/group_vars/all/services.yml`
2. **Template**: `roles/demo_site/templates/links.html.j2`
3. **Deployment**: `playbooks/demo-site-deploy.yml`

The template automatically:
- ✅ Groups services by status
- ✅ Generates service cards from data
- ✅ Calculates statistics
- ✅ Applies correct styling per status

### Future Automation Opportunities

#### 1. Pre-Commit Hook (Recommended)

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Validate services.yml on commit

echo "Validating services.yml..."

# Check YAML syntax
if ! yamllint inventory/group_vars/all/services.yml; then
  echo "ERROR: services.yml has syntax errors"
  exit 1
fi

# Check for required fields
if ! python3 scripts/validate-services.py; then
  echo "ERROR: services.yml missing required fields"
  exit 1
fi

echo "services.yml validation passed"
```

#### 2. CI/CD Pipeline Check

Add to `.gitlab-ci.yml`:

```yaml
validate-links-page:
  stage: validate
  script:
    - yamllint inventory/group_vars/all/services.yml
    - python3 scripts/validate-services.py
  only:
    changes:
      - inventory/group_vars/all/services.yml
```

#### 3. Automatic Deployment on Merge

```yaml
deploy-links-page:
  stage: deploy
  script:
    - ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml
  only:
    changes:
      - inventory/group_vars/all/services.yml
      - roles/demo_site/templates/links.html.j2
  when: manual
```

#### 4. Service Discovery Script

Create `scripts/audit-services.sh`:

```bash
#!/bin/bash
# Audit deployed containers vs services.yml

echo "Checking for containers not in services.yml..."
# Compare pct list output with services.yml
# Report any discrepancies
```

---

## Checklist for Common Operations

### ✅ Deploying a New Service

- [ ] Service is deployed and accessible via URL
- [ ] Container ID is documented in `inventory/group_vars/all/SERVICENAME.yml`
- [ ] Service added to `services.yml` with all required fields
- [ ] Status set to `deployed_working`
- [ ] YAML syntax validated
- [ ] Links portal redeployed via Ansible
- [ ] Service appears on links page
- [ ] Service URL tested and working
- [ ] Changes committed to git
- [ ] Documentation updated (if needed)

### ✅ Removing a Service

- [ ] Service container stopped and removed
- [ ] Service removed from `services.yml`
- [ ] DNS record removed/updated (if needed)
- [ ] Traefik routes removed
- [ ] Links portal redeployed via Ansible
- [ ] Service no longer appears on links page
- [ ] Changes committed to git
- [ ] Deprecation documented (if needed)

### ✅ Marking Service as Non-Working

- [ ] Service status changed to `deployed_nonworking`
- [ ] `issue` field added with explanation
- [ ] Links portal redeployed via Ansible
- [ ] Service moved to "Under Maintenance" section
- [ ] Issue tracking ticket created (if applicable)
- [ ] Changes committed to git

### ✅ Promoting Planned to Deployed

- [ ] Service deployment completed successfully
- [ ] Service accessible via public URL
- [ ] Status changed from `planned` to `deployed_working`
- [ ] `priority` field removed
- [ ] Links portal redeployed via Ansible
- [ ] Service moved from "Planned" to "Available" section
- [ ] Service URL tested and working
- [ ] Changes committed to git

---

## Troubleshooting

### Issue: Links page not updating after redeploy

**Possible Causes**:
1. Browser cache
2. Deployment didn't complete
3. Nginx not reloaded

**Solution**:
```bash
# Hard refresh browser (Ctrl+Shift+R or Cmd+Shift+R)

# Check container is running
ssh root@192.168.1.3 pct status 160

# Check nginx is running
ssh root@192.168.1.3 pct exec 160 -- systemctl status nginx

# Restart nginx
ssh root@192.168.1.3 pct exec 160 -- systemctl restart nginx

# Check deployment logs
ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml -vvv
```

### Issue: Service not appearing on links page

**Possible Causes**:
1. Wrong status value
2. Typo in services.yml
3. YAML indentation error
4. Template not re-rendered

**Solution**:
```bash
# Validate YAML syntax
yamllint inventory/group_vars/all/services.yml

# Check for the service entry
grep -A 10 "name: ServiceName" inventory/group_vars/all/services.yml

# Verify status is correct
# Must be: deployed_working, deployed_nonworking, or planned

# Force re-render by removing provisioning marker
ssh root@192.168.1.3 pct exec 160 -- rm -f /etc/demo-site/.provisioned

# Redeploy
ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml
```

### Issue: Service link gives 404 or 502 error

**Possible Causes**:
1. Service not actually running
2. Traefik not configured
3. DNS not configured
4. Wrong subdomain in services.yml

**Solution**:
```bash
# Check container is running
ssh root@192.168.1.3 pct status <container_id>

# Check service listening on port
ssh root@192.168.1.3 pct exec <container_id> -- ss -tlnp

# Check Traefik can reach service
curl -I http://172.16.10.<container_id>:<port>

# Check DNS resolution
dig servicename.viljo.se

# Verify subdomain matches Traefik configuration
grep -r "servicename" inventory/group_vars/all/main.yml
```

### Issue: Wrong icon or description

**Solution**:
```bash
# Update services.yml
vi inventory/group_vars/all/services.yml

# Change icon or description fields
# Redeploy links portal
ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml

# Hard refresh browser
```

---

## Reference Documentation

### Related Files

| File | Purpose |
|------|---------|
| `inventory/group_vars/all/services.yml` | **Single source of truth** for all services |
| `roles/demo_site/templates/links.html.j2` | Jinja2 template for links page HTML |
| `roles/demo_site/README.md` | Demo site role documentation |
| `playbooks/demo-site-deploy.yml` | Playbook to deploy links portal |
| `specs/completed/010-links-portal/spec.md` | Original specification |

### Related Guides

- [NEW_SERVICE_WORKFLOW.md](NEW_SERVICE_WORKFLOW.md) - Complete new service deployment workflow
- [Service Checklist Template](SERVICE_CHECKLIST_TEMPLATE.md) - Checklist for service deployment
- [Container Mapping](architecture/container-mapping.md) - Container ID assignments

### Ansible Variables

```yaml
# Demo Site / Links Portal Configuration
demo_site_container_id: 160
demo_site_hostname: links
demo_site_ip_address: 172.16.10.160
demo_site_external_domain: viljo.se

# Services list (used by links template)
infrastructure_services: [...]  # Defined in services.yml
```

---

## Best Practices

### 1. Update Atomically
- Update services.yml and redeploy in a single workflow
- Don't leave services.yml out of sync with reality

### 2. Test Before Committing
- Always verify the links page displays correctly
- Test service URLs before marking as `deployed_working`

### 3. Use Descriptive Commits
- Commit messages should explain what changed and why
- Reference issue/ticket numbers when applicable

### 4. Document Removals
- When removing a service, document why in git commit message
- Consider moving to deprecated section instead of deleting

### 5. Consistent Formatting
- Follow existing patterns in services.yml
- Use proper YAML indentation (2 spaces)
- Keep sections clearly separated with comment headers

### 6. Validate Container IDs
- Ensure container_id variables are defined in inventory
- Use variables, not hard-coded IDs (except for special cases)

### 7. Choose Appropriate Icons
- Use emojis that clearly represent the service type
- Be consistent with similar services
- Test emoji rendering in different browsers

---

## Quick Reference Commands

```bash
# Edit services registry
vi inventory/group_vars/all/services.yml

# Validate YAML
yamllint inventory/group_vars/all/services.yml

# Dry run deployment
ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml --check

# Deploy links portal
ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml

# Test links page
curl -I https://links.viljo.se

# Test specific service
curl -I https://servicename.viljo.se

# View links page in browser
open https://links.viljo.se

# Check container status
ssh root@192.168.1.3 pct status 160

# Restart nginx in container
ssh root@192.168.1.3 pct exec 160 -- systemctl restart nginx

# View nginx error logs
ssh root@192.168.1.3 pct exec 160 -- tail -f /var/log/nginx/error.log
```

---

## Support

For questions or issues:

1. **Check this documentation first**
2. **Review error logs** (nginx, ansible)
3. **Validate YAML syntax** (common cause of issues)
4. **Test service URLs** independently
5. **Consult related documentation** (see Reference Documentation section)

---

**Remember**: The links page is a critical user-facing service. Keeping it current is not optional - it's a required part of infrastructure maintenance.

---

**Document Version**: 1.0
**Last Updated**: 2025-10-27
**Next Review**: When links portal functionality changes
