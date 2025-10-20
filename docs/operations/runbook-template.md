# Operational Runbooks

This directory contains step-by-step procedures for common operational tasks and troubleshooting scenarios.

## What is a Runbook?

A runbook is a detailed procedure for accomplishing a specific operational task. Runbooks help team members perform tasks consistently and correctly, especially during incidents or unfamiliar situations.

## Runbook Categories

### Deployment Runbooks
- `deploy-new-service.md` - How to add a new service to the infrastructure
- `rollback-service.md` - How to rollback a failed deployment
- `dmz-rebuild.md` - How to rebuild DMZ network services

### Incident Response
- `service-down.md` - What to do when a service is unavailable
- `certificate-expired.md` - Handling expired TLS certificates
- `disk-full.md` - Resolving disk space issues
- `network-outage.md` - Network connectivity troubleshooting

### Maintenance
- `security-updates.md` - Applying security patches
- `backup-restore.md` - Backup and restore procedures
- `certificate-renewal.md` - Manual certificate renewal
- `lxc-resize.md` - Resizing LXC containers

### Troubleshooting
- `ldap-authentication-failure.md` - Debugging LDAP auth issues
- `traefik-routing-issues.md` - Fixing routing problems
- `gitlab-slow-performance.md` - GitLab performance troubleshooting
- `proxmox-api-errors.md` - Proxmox API troubleshooting

## Runbook Format

Each runbook should follow this structure:

```markdown
# [Task Name]

**Category**: [Deployment | Incident | Maintenance | Troubleshooting]
**Estimated Time**: [Time to complete]
**Risk Level**: [Low | Medium | High]
**Prerequisites**: [What you need before starting]

## Symptoms / Indicators

[For troubleshooting runbooks: what symptoms indicate this problem?]
[For operational runbooks: when should you perform this task?]

## Prerequisites

- Required access levels
- Required tools
- Required information

## Procedure

### Step 1: [Action]
```bash
# Command or action
```
**Expected Result**: [What should happen]
**If it fails**: [What to do]

### Step 2: [Action]
...

## Verification

How to verify the task completed successfully:
- [ ] Verification step 1
- [ ] Verification step 2

## Rollback (if applicable)

If something goes wrong, how to undo the changes:

1. Step 1
2. Step 2

## Common Issues

**Issue 1**: [Description]
**Solution**: [How to fix]

**Issue 2**: [Description]
**Solution**: [How to fix]

## Related Runbooks

- Link to related procedure
- Link to related troubleshooting

## References

- Internal documentation
- External resources
```

## Constitution Compliance

Runbooks are required by the Constitution (Section: Documentation Requirements):
> "Runbooks for common operations and troubleshooting"

Create runbooks for:
- Any procedure performed more than twice
- Incident response procedures
- Complex multi-step operations
- Tasks performed during off-hours or on-call

## Contributing

When you solve a problem or perform a complex task:
1. Document it as a runbook
2. Test the runbook by having someone else follow it
3. Update the runbook based on feedback
4. Keep runbooks up-to-date as systems change
