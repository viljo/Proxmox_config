# Role: jellyfin

## Purpose

[TODO: Describe what this role does and its purpose in the infrastructure]

This role deploys and configures jellyfin on Proxmox VE infrastructure.

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

[TODO: Document key variables from defaults/main.yml]

**Example variables:**
- `jellyfin_container_id`: [Description needed]
- `jellyfin_hostname`: [Description needed]
- `jellyfin_domain`: [Description needed]
- `jellyfin_memory`: [Description needed]
- `jellyfin_cores`: [Description needed]

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
    - role: jellyfin
      vars:
        # Add example variables
```

### Advanced Configuration

```yaml
- hosts: proxmox
  roles:
    - role: jellyfin
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
