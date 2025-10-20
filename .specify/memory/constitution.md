<!-- Sync Impact Report
Version change: 0.0.0 → 1.0.0 (initial constitution)
Modified principles: N/A (initial creation)
Added sections: All sections (initial document)
Removed sections: None
Templates requiring updates:
  ✅ plan-template.md - updated with constitution checks
  ✅ spec-template.md - updated with infrastructure & security requirements
  ✅ tasks-template.md - updated with Ansible/infrastructure paths
  ✅ AGENTS.md - verified as runtime guidance file
Follow-up TODOs:
  - RATIFICATION_DATE requires confirmation or should be set to today (2025-10-20)
-->

# Proxmox Infrastructure Constitution

## Core Principles

### I. Infrastructure as Code
Every infrastructure component MUST be defined and managed through Ansible roles. No manual configuration changes are permitted on production systems. All roles must be version-controlled, documented, and testable. Manual operations are only acceptable during initial bootstrap or emergency recovery, and must be immediately codified into playbooks.

**Rationale**: Ensures reproducibility, auditability, and disaster recovery capability. Prevents configuration drift and enables reliable scaling.

### II. Security-First Design
All services MUST integrate with centralized authentication (LDAP/OIDC via Keycloak). Secrets MUST be stored in Ansible Vault with no plaintext credentials in repositories. Every LXC container MUST run unprivileged with AppArmor profiles, nftables firewalls, and Fail2Ban protection. TLS termination through Traefik is mandatory for all web services.

**Rationale**: Centralized identity management reduces attack surface and credential sprawl. Defense-in-depth approach ensures resilience against security breaches.

### III. Idempotent Operations
All Ansible playbooks and roles MUST be safely re-runnable without causing service disruption or data loss. Every role must implement proper state checks before making changes. Destructive operations require explicit confirmation flags or separate teardown playbooks (e.g., dmz-rebuild.yml).

**Rationale**: Enables confident automation, reduces human error, and supports continuous deployment workflows without fear of breaking running services.

### IV. Single Source of Truth
NetBox MUST serve as the authoritative Configuration Management Database (CMDB) for all infrastructure components. All monitoring (Zabbix), automation (Ansible dynamic inventory), and documentation must derive from NetBox data. Changes to infrastructure topology must be reflected in NetBox before implementation.

**Rationale**: Eliminates documentation drift, enables automated discovery and monitoring alignment, and provides a unified view of infrastructure state.

### V. Automated Operations
All routine operations MUST be automated through scheduled jobs, CI/CD pipelines, or event-driven automation. This includes security updates, backups, certificate renewal, monitoring synchronization, and alert routing. Manual intervention should only be required for approval gates or exceptional circumstances.

**Rationale**: Reduces operational burden, ensures consistency, improves reliability through elimination of human error in routine tasks.

## Testing & Validation Requirements

### Testing Strategy
- Unit tests required for all custom Ansible modules and plugins
- Integration tests for inter-service communication and API contracts
- Staging environment validation before production deployment
- Automated smoke tests after each deployment
- Backup restoration tests performed quarterly

### Validation Gates
- All pull requests must pass linting (ansible-lint, yamllint)
- Vault encryption must be verified before commit
- Network segmentation rules must be validated through firewall tests
- Service health checks must succeed before marking deployment complete

## Operational Standards

### Change Management
- All changes require pull request with peer review
- Emergency changes must be documented within 24 hours
- Rollback procedures must be documented for each role
- Change windows communicated via Mattermost alerts

### Documentation Requirements
- Every role must include a README with variables, dependencies, and examples
- Network topology diagrams must be maintained in docs/
- Runbooks for common operations and troubleshooting
- Architecture decision records for significant design choices

### Monitoring & Alerting
- Every service must expose health endpoints
- Critical alerts route to on-call via Mattermost
- SLA targets: 99.9% uptime for core services (LDAP, GitLab, Traefik)
- Metrics retention: 90 days in Prometheus, 1 year in Zabbix

## Governance

### Amendment Process
The Constitution supersedes all other practices and conventions. Amendments require:
1. Documented rationale and impact analysis
2. Pull request with technical review from at least two maintainers
3. Testing in staging environment
4. Migration plan for existing infrastructure
5. Update to all affected documentation and templates

### Compliance Verification
- All deployments must verify constitutional compliance through automated checks
- Quarterly audits of security posture and operational practices
- Deviations must be justified in writing with remediation timeline
- Use AGENTS.md for runtime development guidance and agent-specific instructions

### Versioning Policy
Constitution versions follow semantic versioning (MAJOR.MINOR.PATCH):
- MAJOR: Removal or fundamental change to core principles
- MINOR: Addition of new principles or significant sections
- PATCH: Clarifications, typo fixes, non-semantic improvements

**Version**: 1.0.0 | **Ratified**: 2025-10-20 | **Last Amended**: 2025-10-20