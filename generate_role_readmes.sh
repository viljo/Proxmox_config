#!/bin/bash
# Generate README.md files for roles without documentation
# Run from repository root: bash generate_role_readmes.sh

set -euo pipefail

# Roles with custom READMEs already created
SKIP_ROLES=("gitlab" "traefik")

# Generate template README for a role
generate_readme() {
    local role=$1
    local readme_path="roles/$role/README.md"

    # Skip if README already exists
    if [[ -f "$readme_path" ]]; then
        echo "⏭️  Skipping $role (README exists)"
        return
    fi

    # Check if defaults/main.yml exists to extract variables
    local defaults_file="roles/$role/defaults/main.yml"
    local has_defaults=false
    if [[ -f "$defaults_file" ]]; then
        has_defaults=true
    fi

    cat > "$readme_path" << EOF
# Role: $role

## Purpose

[TODO: Describe what this role does and its purpose in the infrastructure]

This role deploys and configures $role on Proxmox VE infrastructure.

## Variables

See \`defaults/main.yml\` for all configurable variables.

### Key Variables

EOF

    # Extract variable names from defaults/main.yml if it exists
    if [[ "$has_defaults" == "true" ]]; then
        echo "[TODO: Document key variables from defaults/main.yml]" >> "$readme_path"
        echo "" >> "$readme_path"
        echo "**Example variables:**" >> "$readme_path"
        # Get first 5 variable names as examples
        grep "^[a-z_]*:" "$defaults_file" | head -5 | while read -r line; do
            varname=$(echo "$line" | cut -d: -f1)
            echo "- \`$varname\`: [Description needed]" >> "$readme_path"
        done
    else
        echo "[No defaults/main.yml found - this role may use role parameters or facts]" >> "$readme_path"
    fi

    cat >> "$readme_path" << 'EOF'

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)

**External Services:**
[TODO: List external service dependencies]

**Vault Variables:**
[TODO: List vault-encrypted variables if any]

**Related Roles:**
[TODO: List roles this depends on or integrates with]

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox
  roles:
    - role: ROLENAME
      vars:
        # Add example variables
```

### Advanced Configuration

```yaml
- hosts: proxmox
  roles:
    - role: ROLENAME
      vars:
        # Add advanced example
```

## Deployment Process

[TODO: Document the deployment steps this role performs]

1. Step 1
2. Step 2
3. Step 3

## Idempotency

[TODO: Describe how this role ensures idempotent operations]

- State checks before changes
- Markers to prevent re-provisioning
- Safe to re-run

## Notes

### Performance Considerations
[TODO: Document resource requirements and performance notes]

### Security
[TODO: Document security considerations]

### Troubleshooting
[TODO: Add common troubleshooting steps]

### Rollback Procedure
[TODO: Document how to rollback changes made by this role]

### Known Limitations
[TODO: List known issues or limitations]

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ⚠️ **Security-First Design**: [TODO: Verify LDAP/OIDC integration, Vault usage]
- ⚠️ **Idempotent Operations**: [TODO: Verify safe re-runnability]
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ⚠️ **Automated Operations**: [TODO: Verify automation completeness]

---

**Status**: 🚧 This README is a template and requires completion with actual role details.

**Action Required**: Please fill in the [TODO] sections based on the role's implementation in `tasks/main.yml`.
EOF

    # Replace ROLENAME placeholder
    sed -i '' "s/ROLENAME/$role/g" "$readme_path" 2>/dev/null || sed -i "s/ROLENAME/$role/g" "$readme_path"

    echo "✅ Generated README for: $role"
}

# Main execution
echo "🚀 Generating README.md files for roles..."
echo ""

for role in roles/*/; do
    role_name=$(basename "$role")

    # Skip if in skip list
    if [[ " ${SKIP_ROLES[@]} " =~ " ${role_name} " ]]; then
        continue
    fi

    generate_readme "$role_name"
done

echo ""
echo "📊 Summary:"
echo "  - Skipped roles with existing READMEs: ${#SKIP_ROLES[@]}"
echo "  - Generated template READMEs for remaining roles"
echo ""
echo "⚠️  Next steps:"
echo "  1. Review each generated README.md"
echo "  2. Fill in [TODO] sections with actual implementation details"
echo "  3. Document variables from defaults/main.yml"
echo "  4. Add troubleshooting and rollback procedures"
echo "  5. Remove '🚧 Template' notice after completion"
EOF
chmod +x generate_role_readmes.sh