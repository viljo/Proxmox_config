# Essential Project Goals

**Last Updated**: 2025-10-25

This document defines the core architectural principles and non-negotiable requirements for this infrastructure project.

## 1. Service Verification in Playbooks

**Status**: MANDATORY
**Since**: 2025-10-25

### Requirement

All service deployment playbooks SHALL end with thorough verification that the service is up and working.

### Implementation

- **Verification code MUST be in playbooks** (`playbooks/*-deploy.yml`)
- **Verification code MUST NOT be in roles** (`roles/*/tasks/main.yml`)

### Structure

```
playbooks/
  service-deploy.yml          ← Verification HERE ✅
    1. Include role
    2. Verify service works
    3. Fail if verification fails

roles/
  service_api/
    tasks/
      main.yml                ← NO verification here ❌
        1. Deploy container
        2. Install packages
        3. Configure service
        4. Start service
```

### Rationale

1. **Visibility**: Verification is immediately visible when reading playbooks
2. **Separation of Concerns**: Roles deploy, playbooks orchestrate and verify
3. **Maintainability**: Easy to update verification without modifying roles
4. **Clarity**: Clear distinction between "deploy" and "verify"
5. **Prevent False Positives**: Ansible "ok" means service is actually working

### Reference

See [Service Verification Strategy](deployment/service-verification-strategy.md) for detailed implementation guide.

### Examples

**Good** ✅:
- `playbooks/redis-deploy.yml` - Has verification tasks in playbook
- `playbooks/mattermost-deploy.yml` - Has verification section after role

**Bad** ❌:
- Verification tasks inside `roles/*/tasks/main.yml`
- Playbook ends immediately after including role
- No verification of service functionality

## 2. Configuration Management

**Status**: MANDATORY
**Since**: 2025-10-23

### Requirement

All infrastructure topology SHALL be tracked in git. All secrets SHALL be encrypted in Ansible Vault.

### Implementation

- **Track in Git**: Container IDs, IP addresses, ports, service names, DNS records
- **Keep in Vault**: Passwords, API tokens, certificates, private keys

### Rationale

- Version control for infrastructure changes
- Audit trail for all topology modifications
- Disaster recovery capability
- Separation of public topology from secrets

### Reference

See [Configuration Management Strategy](deployment/configuration-management.md)

## 3. Container ID Standardization

**Status**: MANDATORY
**Since**: 2025-10-20

### Requirement

All infrastructure containers SHALL use standardized container ID ranges.

### Ranges

- **100-149**: Infrastructure services (firewall, bastion, PostgreSQL, Redis, etc.)
- **150-199**: Application services (GitLab, Nextcloud, Keycloak, etc.)
- **200-249**: Reserved for future use
- **2300+**: Temporary/demo containers

### Rationale

- Predictable container organization
- Easy identification of service type
- Prevents ID conflicts
- Simplifies documentation

### Reference

See [ADR-002: Container ID Standardization](adr/002-container-id-standardization.md)

## 4. Infrastructure as Code

**Status**: MANDATORY
**Since**: 2024-01-01

### Requirement

All infrastructure SHALL be defined as code using Ansible.

### Implementation

- Container deployments via Ansible playbooks
- Configuration via Ansible templates
- Secrets via Ansible Vault
- No manual container creation
- No manual configuration changes

### Rationale

- Reproducible deployments
- Version-controlled changes
- Automated disaster recovery
- Documentation through code

## 5. Security by Default

**Status**: MANDATORY
**Since**: 2024-01-01

### Requirements

- All services SHALL use unprivileged LXC containers
- All external services SHALL use HTTPS with valid certificates
- All database connections SHALL use authentication
- All secrets SHALL be encrypted in Vault
- Firewall SHALL block all traffic except explicitly allowed

### Implementation

- Traefik automatic HTTPS via Let's Encrypt
- PostgreSQL password authentication
- Redis requirepass authentication
- Vault encryption for all passwords/tokens
- NFtables firewall rules

## Enforcement

These goals are non-negotiable. Code reviews and pull requests MUST verify compliance with these standards.

### Pre-commit Checks

Before committing:
1. ✅ Verify no hardcoded secrets in files
2. ✅ Verify playbooks have verification sections
3. ✅ Verify container IDs in correct ranges
4. ✅ Verify all topology changes are tracked in git

### Review Checklist

For all service deployments:
- [ ] Playbook has comprehensive verification section
- [ ] Verification tests actual service functionality
- [ ] Playbook fails if verification fails
- [ ] Success message shows service is FUNCTIONAL
- [ ] No verification code in role tasks

## Changelog

| Date | Goal Added | Description |
|------|------------|-------------|
| 2025-10-25 | Service Verification in Playbooks | Mandatory verification at playbook level |
| 2025-10-23 | Configuration Management | Git tracking + Vault encryption |
| 2025-10-20 | Container ID Standardization | Defined ID ranges for services |
| 2024-01-01 | Infrastructure as Code | Ansible-based deployments |
| 2024-01-01 | Security by Default | Unprivileged containers, HTTPS, auth |
