# Group Variables Consolidation Plan

**Status**: Recommended Action
**Priority**: Medium
**Risk Level**: Low
**Estimated Time**: 30 minutes

## Current Situation

The repository has duplicate `group_vars` directories:

1. **Root level**: `group_vars/all/secrets.yml` (vault encrypted secrets only)
2. **Inventory level**: `inventory/group_vars/all/*.yml` (20+ service-specific variable files + secrets.yml)

This creates potential confusion about which is the authoritative source for variables.

## Problem

- **Confusion**: Team members may not know where to look for variables
- **Drift Risk**: Changes might be made to wrong location
- **Convention Violation**: Ansible best practice is single `group_vars` location per inventory

## Recommendation

**Consolidate all variables to `inventory/group_vars/all/`** and remove root-level `group_vars/`.

### Rationale
1. `inventory/group_vars/all/` is already the most complete source
2. Keeps variables co-located with inventory files
3. Follows Ansible convention for inventory-based projects
4. Reduces confusion for new team members

## Implementation Plan

### Step 1: Verify Secrets Match

```bash
# Compare the two secrets files
diff -u <(ansible-vault view group_vars/all/secrets.yml | sort) \
        <(ansible-vault view inventory/group_vars/all/secrets.yml | sort)
```

**Expected Result**: Files should be identical or `inventory/` version should be superset

**Action**: If differences exist, merge into `inventory/group_vars/all/secrets.yml`

### Step 2: Update Ansible Configuration

Edit `ansible.cfg`:

```ini
[defaults]
# ... existing config ...

# Explicitly set inventory path (already configured)
inventory = inventory/

# This ensures group_vars under inventory/ is used
```

**Note**: This is likely already configured correctly.

### Step 3: Remove Root-Level group_vars (AFTER VERIFICATION)

```bash
# Backup first
cp -r group_vars group_vars.backup

# Remove root-level group_vars
git rm -r group_vars/

# Commit the change
git add ansible.cfg
git commit -m "Consolidate group_vars to inventory/ directory

- Removed duplicate root-level group_vars/
- All variables now in inventory/group_vars/all/
- Reduces confusion and follows Ansible best practices

Constitution compliance: Single Source of Truth principle"
```

### Step 4: Update Documentation

Add note to `docs/secrets-management.md`:

```markdown
## Variable Location

All group variables are located in:
- `inventory/group_vars/all/` - All service-specific variables and secrets

Previous location `group_vars/all/` has been removed to eliminate confusion.
```

### Step 5: Test Playbooks

```bash
# Test with check mode
ansible-playbook -i inventory/ playbooks/site.yml --check

# Verify variables are loaded correctly
ansible-playbook -i inventory/ playbooks/pct-help.yml --list-tasks
```

**Expected Result**: Playbooks should work identically

## Verification Checklist

- [ ] Secrets files compared and verified identical
- [ ] Backup of root `group_vars/` created
- [ ] Root `group_vars/` removed
- [ ] Ansible.cfg reviewed
- [ ] Test playbook executed successfully
- [ ] Documentation updated
- [ ] Changes committed to git

## Rollback Procedure

If issues arise:

```bash
# Restore from backup
git revert <commit-hash>
cp -r group_vars.backup group_vars
git add group_vars/
git commit -m "Rollback: Restore root-level group_vars"
```

## References

- Ansible Best Practices: https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html#tip-for-variables-and-vaults
- Constitution Principle IV: Single Source of Truth

## Constitution Compliance

This consolidation aligns with:
- **Single Source of Truth**: Eliminates duplicate variable locations
- **Infrastructure as Code**: Variables properly organized and version-controlled
- **Idempotent Operations**: No functional change, just organizational improvement
