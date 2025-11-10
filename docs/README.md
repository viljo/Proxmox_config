# Documentation Index

Welcome to the Proxmox Infrastructure documentation. This directory contains all documentation for deploying, operating, and maintaining the infrastructure.

## Quick Links

- **[Getting Started](getting-started.md)** - New to this project? Start here
- **[Network Architecture](NETWORK_ARCHITECTURE.md)** - CRITICAL: Understand the Coolify-based architecture
- **[Architecture Overview](architecture/network-topology.md)** - Complete network topology
- **[Container Mapping](architecture/container-mapping.md)** - LXC and Docker container reference
- **[Operations](operations/)** - Day-to-day operations and runbooks

## Documentation Structure

### 📐 Architecture
High-level design decisions and system architecture documentation.

- **[Network Architecture](NETWORK_ARCHITECTURE.md)** - CRITICAL: Coolify PaaS architecture guide (MUST READ)
- **[Network Topology](architecture/network-topology.md)** - Simplified single-LXC network design
- **[Container Mapping](architecture/container-mapping.md)** - LXC and Docker container reference
- **[ADR-001: Network Architecture Decision](adr/001-network-topology-change.md)** - Why we chose Coolify
- **[Security Model](architecture/security-model.md)** - Security architecture (planned)

### 🚀 Deployment
Step-by-step guides for deploying infrastructure components.

- **[Proxmox Access](deployment/proxmox-access.md)** - Initial Proxmox setup and access
- **[Coolify Deployment](../specs/planned/002-docker-platform-selfservice/)** - Deploy Coolify LXC container
- **[Secrets Management](deployment/secrets-management.md)** - Ansible Vault usage
- **[Service Deployment](../README.md#usage)** - Deploy services via Coolify API

### ⚙️ Operations
Operational procedures, runbooks, and troubleshooting guides.

- **[Rollback Service](operations/rollback-service.md)** - How to rollback a failed deployment
- **[Runbook Template](operations/runbook-template.md)** - Template for creating new runbooks
- **[SSH Access Methods](operations/ssh-access-methods.md)** - How to access infrastructure (bastion vs direct)
- **[External Testing Methodology](operations/external-testing-methodology.md)** - How to validate external accessibility

### 🔥 Disaster Recovery
Comprehensive DR procedures, testing reports, and recovery automation.

#### Core DR Documentation
- **[DR Runbook](DR_RUNBOOK.md)** - Complete disaster recovery procedures (44KB)
- **[DR Test Report (2025-10-23)](DR_TEST_REPORT_2025-10-23.md)** - Latest DR test results (13KB)
- **[DR Test Lessons Learned](DR_TEST_LESSONS_LEARNED.md)** - Action items from DR test (8.5KB)

#### Backup & Restore
- **[Backup Infrastructure Role](../roles/backup_infrastructure/)** - Automated backup system
- **[Restore Infrastructure Role](../roles/restore_infrastructure/)** - Automated restoration system
- **[Backup Verification Script](../scripts/verify-backup.sh)** - Test backup validity
- **[Firewall Quick Restore Script](../scripts/restore-firewall.sh)** - Fast firewall recovery

#### Production Readiness
- **[New Service Workflow](NEW_SERVICE_WORKFLOW.md)** - 9-step TDD workflow for new services (96KB)
- **[Service Checklist Template](SERVICE_CHECKLIST_TEMPLATE.md)** - Track TDD workflow progress
- **[Links Page Maintenance](LINKS_PAGE_MAINTENANCE.md)** - REQUIRED: Keep service directory current
- **[TDD Workflow Status](TDD_WORKFLOW_STATUS.md)** - Completion status for all 11 services (36KB)
- **[Vault Variables](VAULT_VARIABLES.md)** - Required vault variables (3KB)
- **[Vault Completion Checklist](VAULT_COMPLETION_CHECKLIST.md)** - Complete vault configuration (21KB)

#### Investigations & Audits
- **[Automation Audit](AUTOMATION_AUDIT.md)** - Automation coverage analysis (23KB)
- **[GitLab Backup Investigation](GITLAB_BACKUP_INVESTIGATION.md)** - Resolve backup corruption (18KB)

### 📋 Architecture Decision Records (ADRs)
Historical records of significant architectural decisions.

- **[ADR Index](adr/README.md)** - All architecture decisions
- **[ADR-001: Network Architecture Decision](adr/001-network-topology-change.md)** - Simplified Coolify PaaS approach
- **[ADR-002: Container ID Standardization](adr/002-container-id-standardization.md)** - DEPRECATED (single-container architecture)

### 💻 Development
Guides for contributing to and developing this infrastructure.

- **[Contributing Guide](development/contributing.md)** - How to contribute
- **[Role Development](development/role-development.md)** - Creating Ansible roles
- **[Testing Guide](development/testing.md)** - Testing infrastructure changes

## Related Documentation

- **[Project README](../README.md)** - Project overview and quickstart
- **[Role Documentation](../roles/)** - Individual role README files (24 roles)
- **[Feature Specifications](../specs/)** - Detailed feature specs

## Documentation Standards

All documentation should follow these principles:

1. **Clear and Concise** - Get to the point quickly
2. **Examples** - Include code examples and commands
3. **Current** - Keep documentation up-to-date with code changes
4. **Tested** - Verify procedures work before documenting
5. **Linked** - Link to related documentation

## Need Help?

- Check the [Getting Started Guide](getting-started.md)
- Review [Architecture Documentation](architecture/)
- Search for keywords in documentation
- Check git history for context: `git log --all --grep="keyword"`

---

**Last Updated**: 2025-11-10 - Updated all documentation to reflect actual Coolify-based architecture
