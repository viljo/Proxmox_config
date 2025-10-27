# Links Page Automation Recommendations

**Last Updated**: 2025-10-27
**Status**: Recommendations for Future Implementation
**Related**: [Links Page Maintenance Guide](LINKS_PAGE_MAINTENANCE.md)

---

## Overview

The Links Portal currently uses a **data-driven template** approach where services are defined in `inventory/group_vars/all/services.yml` and rendered via Jinja2 template. This document outlines **future automation opportunities** to make links page maintenance even more reliable and efficient.

**Current State**: ✅ Data-driven (good!)
**Future State**: 🚀 Fully automated with validation and CI/CD integration

---

## Automation Opportunities

### 1. Pre-Commit Validation Hook (High Priority)

**Problem**: Developers might commit invalid YAML or incomplete service entries.

**Solution**: Git pre-commit hook to validate services.yml before commit.

#### Implementation

**File**: `.git/hooks/pre-commit`

```bash
#!/bin/bash
# Pre-commit hook to validate services.yml

set -e

echo "🔍 Validating services.yml..."

# Check if services.yml was modified
if ! git diff --cached --name-only | grep -q "inventory/group_vars/all/services.yml"; then
  echo "✅ services.yml not modified, skipping validation"
  exit 0
fi

# Validate YAML syntax
if ! yamllint -c .yamllint inventory/group_vars/all/services.yml; then
  echo "❌ YAML syntax validation failed"
  exit 1
fi

# Validate service schema
if ! python3 scripts/validate-services-schema.py; then
  echo "❌ Service schema validation failed"
  exit 1
fi

echo "✅ services.yml validation passed"
exit 0
```

**Make executable**:
```bash
chmod +x .git/hooks/pre-commit
```

#### Validation Script

**File**: `scripts/validate-services-schema.py`

```python
#!/usr/bin/env python3
"""
Validate services.yml schema and required fields.
"""

import sys
import yaml
from pathlib import Path

SERVICES_FILE = Path("inventory/group_vars/all/services.yml")

REQUIRED_FIELDS = [
    "name",
    "slug",
    "icon",
    "description",
    "subdomain",
    "container_id",
    "status",
]

VALID_STATUSES = [
    "deployed_working",
    "deployed_nonworking",
    "planned",
]

def validate_services():
    """Validate services.yml structure and required fields."""

    if not SERVICES_FILE.exists():
        print(f"❌ File not found: {SERVICES_FILE}")
        return False

    try:
        with open(SERVICES_FILE) as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        print(f"❌ YAML parsing error: {e}")
        return False

    if "infrastructure_services" not in data:
        print("❌ Missing 'infrastructure_services' key")
        return False

    services = data["infrastructure_services"]
    errors = []

    for i, service in enumerate(services, 1):
        # Check required fields
        missing_fields = [
            field for field in REQUIRED_FIELDS
            if field not in service
        ]

        if missing_fields:
            errors.append(
                f"Service #{i} ({service.get('name', 'unnamed')}) "
                f"missing fields: {', '.join(missing_fields)}"
            )

        # Validate status
        if "status" in service and service["status"] not in VALID_STATUSES:
            errors.append(
                f"Service #{i} ({service.get('name', 'unnamed')}) "
                f"has invalid status: {service['status']}"
            )

        # Check subdomain doesn't contain full domain
        if "subdomain" in service and "." in service["subdomain"]:
            errors.append(
                f"Service #{i} ({service.get('name', 'unnamed')}) "
                f"subdomain should not include domain: {service['subdomain']}"
            )

    if errors:
        print("❌ Validation errors:")
        for error in errors:
            print(f"  • {error}")
        return False

    print(f"✅ Validated {len(services)} services")
    return True

if __name__ == "__main__":
    success = validate_services()
    sys.exit(0 if success else 1)
```

**Benefits**:
- ✅ Catches errors before commit
- ✅ Ensures all required fields present
- ✅ Validates data types and values
- ✅ Fast feedback loop

---

### 2. CI/CD Pipeline Validation (Medium Priority)

**Problem**: Changes merged to main might still have issues.

**Solution**: GitLab CI/CD pipeline to validate and optionally auto-deploy.

#### Implementation

**File**: `.gitlab-ci.yml` (add these stages)

```yaml
stages:
  - validate
  - deploy

# Validate services.yml on every commit
validate-services:
  stage: validate
  image: python:3.11-slim
  before_script:
    - pip install pyyaml yamllint
  script:
    - yamllint inventory/group_vars/all/services.yml
    - python3 scripts/validate-services-schema.py
  only:
    changes:
      - inventory/group_vars/all/services.yml
      - roles/demo_site/templates/links.html.j2

# Optional: Auto-deploy links page on merge to main
deploy-links-page:
  stage: deploy
  image: willhallonline/ansible:latest
  before_script:
    - echo "$VAULT_PASSWORD" > .vault_pass.txt
    - chmod 600 .vault_pass.txt
  script:
    - ansible-playbook -i inventory/hosts.yml playbooks/demo-site-deploy.yml
  after_script:
    - rm -f .vault_pass.txt
  only:
    refs:
      - main
    changes:
      - inventory/group_vars/all/services.yml
      - roles/demo_site/templates/links.html.j2
  when: manual  # Require manual trigger for safety
  environment:
    name: production
    url: https://links.viljo.se
```

**Benefits**:
- ✅ Automated validation on every push
- ✅ Prevents broken changes from merging
- ✅ Optional auto-deployment
- ✅ Visibility in GitLab UI

---

### 3. Service Discovery Audit Script (Medium Priority)

**Problem**: Deployed containers might not be listed in services.yml.

**Solution**: Periodic audit script to compare Proxmox containers with services.yml.

#### Implementation

**File**: `scripts/audit-services.sh`

```bash
#!/bin/bash
# Audit script to find services not listed in links page

set -euo pipefail

PROXMOX_HOST="192.168.1.3"
SERVICES_FILE="inventory/group_vars/all/services.yml"

echo "🔍 Auditing services vs Proxmox containers..."
echo

# Get all running containers with IPs in DMZ range
containers=$(ssh root@$PROXMOX_HOST "pct list | awk 'NR>1 {print \$1}' | while read id; do pct config \$id | grep -q 'net0.*172.16.10' && echo \$id; done")

# Extract container IDs from services.yml
services_containers=$(grep -E 'container_id:.*[0-9]+' "$SERVICES_FILE" | grep -oE '[0-9]+' | sort -u)

echo "📦 Containers in DMZ (172.16.10.0/24):"
echo "$containers" | tr '\n' ' '
echo
echo

echo "📋 Containers referenced in services.yml:"
echo "$services_containers" | tr '\n' ' '
echo
echo

# Find containers not in services.yml
echo "⚠️  Containers NOT in services.yml:"
comm -23 <(echo "$containers" | sort) <(echo "$services_containers" | sort) | while read id; do
  name=$(ssh root@$PROXMOX_HOST "pct config $id | grep hostname | cut -d: -f2 | tr -d ' '")
  ip=$(ssh root@$PROXMOX_HOST "pct config $id | grep 'net0.*172.16.10' | grep -oE '172\.16\.10\.[0-9]+'")
  echo "  • Container $id: $name ($ip)"
done

echo

# Find services.yml entries that don't have deployed containers
echo "⚠️  Services in services.yml without containers:"
comm -13 <(echo "$containers" | sort) <(echo "$services_containers" | sort) | while read id; do
  service=$(grep -B5 "container_id.*$id" "$SERVICES_FILE" | grep "name:" | head -1 | cut -d: -f2 | tr -d ' "')
  echo "  • Container $id: $service (referenced but not deployed)"
done

echo
echo "✅ Audit complete"
```

**Run manually**:
```bash
bash scripts/audit-services.sh
```

**Add to cron** (optional):
```bash
# Run weekly audit
0 9 * * 1 cd /path/to/Proxmox_config && bash scripts/audit-services.sh | mail -s "Services Audit" admin@example.com
```

**Benefits**:
- ✅ Finds missing service entries
- ✅ Finds orphaned references
- ✅ Can be automated with cron
- ✅ Helps maintain accuracy

---

### 4. Service Status Monitoring (Low Priority)

**Problem**: Services might be marked as "working" but are actually down.

**Solution**: Automated health checks to update service status.

#### Implementation

**File**: `scripts/check-service-health.py`

```python
#!/usr/bin/env python3
"""
Check health of all services and update status if needed.
"""

import yaml
import requests
from pathlib import Path

SERVICES_FILE = Path("inventory/group_vars/all/services.yml")
DOMAIN = "viljo.se"
TIMEOUT = 10

def check_service_health(subdomain):
    """Check if service responds with 200 or redirect."""
    url = f"https://{subdomain}.{DOMAIN}"
    try:
        response = requests.get(url, timeout=TIMEOUT, allow_redirects=False)
        # Consider 200, 301, 302, 303, 307 as healthy
        return response.status_code in [200, 301, 302, 303, 307, 401, 403]
    except Exception as e:
        print(f"  ❌ {subdomain}: {e}")
        return False

def check_all_services():
    """Check health of all deployed services."""
    with open(SERVICES_FILE) as f:
        data = yaml.safe_load(f)

    services = data["infrastructure_services"]
    deployed = [s for s in services if s["status"] in ["deployed_working", "deployed_nonworking"]]

    print(f"🔍 Checking {len(deployed)} deployed services...\n")

    issues = []

    for service in deployed:
        name = service["name"]
        subdomain = service["subdomain"]
        status = service["status"]

        is_healthy = check_service_health(subdomain)

        if is_healthy:
            print(f"  ✅ {name} ({subdomain}.{DOMAIN})")
            if status == "deployed_nonworking":
                issues.append(f"  ⚠️  {name} is healthy but marked as deployed_nonworking")
        else:
            print(f"  ❌ {name} ({subdomain}.{DOMAIN})")
            if status == "deployed_working":
                issues.append(f"  ⚠️  {name} is down but marked as deployed_working")

    if issues:
        print("\n⚠️  Status mismatches detected:")
        for issue in issues:
            print(issue)
        print("\n💡 Consider updating services.yml and redeploying links page")
    else:
        print("\n✅ All service statuses are correct")

if __name__ == "__main__":
    check_all_services()
```

**Usage**:
```bash
python3 scripts/check-service-health.py
```

**Benefits**:
- ✅ Automatically detects down services
- ✅ Can trigger alerts
- ✅ Helps keep links page accurate
- ❌ Requires maintenance (health check endpoints vary)

---

### 5. Automatic Service Registration (Future / Advanced)

**Problem**: Developers must manually update services.yml.

**Solution**: Service discovery via Proxmox API + metadata.

#### Concept

Services could self-register via metadata in container config:

```yaml
# In container config
meta:
  - key: service_name
    value: "Jellyfin"
  - key: service_icon
    value: "🎬"
  - key: service_description
    value: "Media streaming server"
  - key: service_subdomain
    value: "jellyfin"
```

**Script** would:
1. Query Proxmox API for all containers
2. Extract metadata
3. Generate services.yml automatically
4. Redeploy links page

**Complexity**: High
**Maintenance**: High
**Benefit**: Moderate (current solution works well)

**Recommendation**: ❌ Not worth complexity at current scale

---

## Implementation Priority

| Priority | Feature | Effort | Benefit | Status |
|----------|---------|--------|---------|--------|
| **High** | Pre-commit hook | Low | High | ⭐ Recommended |
| **Medium** | CI/CD validation | Medium | High | ⭐ Recommended |
| **Medium** | Audit script | Low | Medium | ⭐ Recommended |
| **Low** | Health monitoring | Medium | Medium | Optional |
| **Future** | Auto-registration | High | Low | Not recommended |

---

## Recommended Implementation Order

### Phase 1: Immediate (Week 1)
1. ✅ Create `scripts/validate-services-schema.py`
2. ✅ Install pre-commit hook
3. ✅ Test validation with intentionally broken YAML
4. ✅ Document in LINKS_PAGE_MAINTENANCE.md

### Phase 2: Short-term (Week 2-3)
1. ✅ Add GitLab CI/CD validation stage
2. ✅ Test CI pipeline
3. ✅ Create audit script
4. ✅ Run initial audit and fix discrepancies

### Phase 3: Optional (Future)
1. ⏸️ Implement health monitoring (if needed)
2. ⏸️ Schedule weekly audits via cron (if desired)
3. ⏸️ Add Slack/email notifications for issues

---

## Testing Validation

### Test Pre-Commit Hook

```bash
# Test 1: Valid YAML should pass
git add inventory/group_vars/all/services.yml
git commit -m "test"
# Expected: ✅ Validation passes

# Test 2: Invalid YAML should fail
# Temporarily break services.yml (remove a colon)
git add inventory/group_vars/all/services.yml
git commit -m "test"
# Expected: ❌ Validation fails

# Test 3: Missing field should fail
# Remove 'icon' field from a service
git add inventory/group_vars/all/services.yml
git commit -m "test"
# Expected: ❌ Validation fails
```

### Test CI Pipeline

```bash
# Push to test branch
git checkout -b test-ci-validation
# Make change to services.yml
git add inventory/group_vars/all/services.yml
git commit -m "Test CI validation"
git push origin test-ci-validation

# Check GitLab pipeline status
# Expected: Pipeline runs and validates
```

---

## Maintenance

### Updating Validation Rules

**File**: `scripts/validate-services-schema.py`

To add new validation rules:

```python
# Add to REQUIRED_FIELDS list
REQUIRED_FIELDS = [
    "name",
    "slug",
    "icon",
    "description",
    "subdomain",
    "container_id",
    "status",
    "category",  # New field
]

# Add custom validation
if service.get("priority") and service["status"] != "planned":
    errors.append(
        f"Service #{i} has 'priority' but status is not 'planned'"
    )
```

### Bypassing Validation

If you need to commit despite validation errors (emergency):

```bash
# Skip pre-commit hook (use sparingly!)
git commit --no-verify -m "Emergency fix"

# Or temporarily disable hook
mv .git/hooks/pre-commit .git/hooks/pre-commit.disabled
git commit -m "Fix"
mv .git/hooks/pre-commit.disabled .git/hooks/pre-commit
```

---

## Metrics & Success Criteria

Track automation effectiveness:

| Metric | Target | Current |
|--------|--------|---------|
| Validation errors caught before merge | > 95% | TBD |
| Services missing from links page | 0 | TBD |
| Incorrect service statuses | < 5% | TBD |
| Time to update links page | < 5 min | ~3 min |
| Manual interventions per month | < 2 | TBD |

---

## Related Documentation

- [Links Page Maintenance Guide](LINKS_PAGE_MAINTENANCE.md) - Manual procedures
- [New Service Workflow](NEW_SERVICE_WORKFLOW.md) - Service deployment process
- [CI/CD Configuration](../.gitlab-ci.yml) - GitLab pipeline
- [Container Mapping](architecture/container-mapping.md) - Container reference

---

## Summary

**Current Approach**: ✅ Data-driven template (good foundation)

**Recommended Next Steps**:
1. ✅ Add pre-commit validation hook (high priority)
2. ✅ Add CI/CD validation stage (medium priority)
3. ✅ Create audit script (medium priority)
4. ⏸️ Consider health monitoring (low priority)

**Not Recommended**:
- ❌ Automatic service registration (too complex for current scale)

The current data-driven approach is solid. Adding validation automation will make it even more reliable without adding significant complexity.

---

**Document Version**: 1.0
**Last Updated**: 2025-10-27
**Next Review**: After implementing Phase 1 recommendations
