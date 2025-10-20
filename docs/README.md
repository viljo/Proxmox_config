# Documentation Index

Welcome to the Proxmox Infrastructure documentation. This directory contains all documentation for deploying, operating, and maintaining the infrastructure.

## Quick Links

- **[Getting Started](getting-started.md)** - New to this project? Start here
- **[Architecture Overview](architecture/network-topology.md)** - Understand the infrastructure design
- **[Deployment Guide](deployment/)** - How to deploy services
- **[Operations](operations/)** - Day-to-day operations and runbooks

## Documentation Structure

### 📐 Architecture
High-level design decisions and system architecture documentation.

- **[Network Topology](architecture/network-topology.md)** - Network design (vmbr0/vmbr2/vmbr3)
- **[Container Mapping](architecture/container-mapping.md)** - Container ID reference table
- **[Security Model](architecture/security-model.md)** - Security architecture (planned)

### 🚀 Deployment
Step-by-step guides for deploying infrastructure components.

- **[Proxmox Access](deployment/proxmox-access.md)** - Initial Proxmox setup and access
- **[Firewall Deployment](deployment/firewall-deployment.md)** - Firewall LXC container setup
- **[Secrets Management](deployment/secrets-management.md)** - Ansible Vault usage

### ⚙️ Operations
Operational procedures, runbooks, and troubleshooting guides.

- **[Rollback Service](operations/rollback-service.md)** - How to rollback a failed deployment
- **[Runbook Template](operations/runbook-template.md)** - Template for creating new runbooks

### 📋 Architecture Decision Records (ADRs)
Historical records of significant architectural decisions.

- **[ADR Index](adr/README.md)** - All architecture decisions
- **[ADR-001: Network Topology Change](adr/001-network-topology-change.md)** - vmbr1 → vmbr2/vmbr3 redesign
- **[ADR-002: Container ID Standardization](adr/002-container-id-standardization.md)** - ID = IP last octet pattern

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

**Last Updated**: 2025-10-20 during project restructure
