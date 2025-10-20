# Implementation Plan: Webtop Browser Instance

**Branch**: `005-webtop-browser` | **Date**: 2025-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-webtop-browser/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy a browser-accessible Linux desktop environment (Webtop) in an unprivileged LXC container on the DMZ network (vmbr3), accessible via browser.viljo.se through Traefik HTTPS reverse proxy. The solution provides users with a full desktop experience through their web browser using KasmVNC technology, supporting persistent sessions, authentication, and full internet access from the desktop environment.

## Technical Context

**Language/Version**: YAML (Ansible 2.15+), Jinja2 templates
**Primary Dependencies**: LinuxServer.io Webtop Docker image, KasmVNC, Docker in LXC, Traefik reverse proxy
**Storage**: LXC container storage (ZFS/LVM), persistent volumes for user home directories
**Testing**: ansible-lint, yamllint, molecule (infrastructure testing), manual acceptance testing
**Target Platform**: Proxmox VE 8.x, unprivileged LXC container, Debian 13 base
**Project Type**: Infrastructure deployment (Ansible role-based)
**Performance Goals**: <10s desktop load time, <100ms input latency, 30fps minimum rendering, 5 concurrent users
**Constraints**: Unprivileged LXC (no nested virtualization), DMZ network isolation, HTTPS-only access, 2GB RAM / 2 CPU cores minimum
**Scale/Scope**: Single LXC container deployment, Ansible role with idempotent operations, Traefik integration for browser.viljo.se domain

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Infrastructure as Code
- [x] All infrastructure changes defined in Ansible roles (webtop role to be created in roles/)
- [x] No manual configuration steps required (fully automated LXC + Docker deployment)
- [x] Roles are version-controlled and documented (will include README.md with variables and examples)

### Security-First Design
- [x] Integration with Keycloak/LDAP authentication (Webtop supports LDAP authentication via environment variables)
- [x] No plaintext secrets (using Ansible Vault for passwords, API keys, TLS certificates)
- [x] Container security (unprivileged LXC, firewall rules limiting access to port 3000, HTTPS-only via Traefik)

### Idempotent Operations
- [x] All playbooks can be re-run safely (check container existence before creation, skip if exists)
- [x] Proper state checks before changes (verify LXC state, Docker service status, volume mounts)
- [x] Destructive operations require explicit flags (container destruction via separate teardown playbook)

### Single Source of Truth
- [x] NetBox integration for inventory (webtop container registered in NetBox with DMZ network assignment)
- [x] Monitoring aligned with CMDB (Zabbix template for Docker container health, KasmVNC port monitoring)
- [x] Documentation derived from NetBox data (IP addressing, network topology from NetBox API)

### Automated Operations
- [x] CI/CD pipeline configuration (GitLab CI pipeline for ansible-lint, yamllint, deployment to staging)
- [x] Automated testing approach defined (molecule for role testing, ansible-lint for syntax, manual smoke tests)
- [x] Backup and monitoring automation included (PBS backup of LXC container, user data volume backups, Zabbix health checks)

## Project Structure

### Documentation (this feature)

```
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
roles/webtop/
├── README.md                    # Role documentation with variables and usage
├── defaults/
│   └── main.yml                 # Default variables (container ID, resources, networking)
├── tasks/
│   ├── main.yml                 # Main task entry point
│   ├── lxc_container.yml        # LXC container creation and configuration
│   ├── docker_setup.yml         # Docker installation in LXC
│   ├── webtop_deploy.yml        # Webtop Docker container deployment
│   ├── traefik_config.yml       # Traefik route configuration
│   └── netbox_register.yml      # NetBox CMDB registration
├── templates/
│   ├── docker-compose.yml.j2    # Docker Compose for Webtop
│   ├── traefik_labels.j2        # Traefik routing labels
│   └── webtop.env.j2            # Environment variables (auth, display settings)
├── handlers/
│   └── main.yml                 # Restart handlers for Docker, Traefik
├── vars/
│   └── main.yml                 # Non-overridable variables
├── meta/
│   └── main.yml                 # Role metadata and dependencies
└── molecule/
    └── default/
        ├── molecule.yml         # Molecule test configuration
        ├── converge.yml         # Test playbook
        └── verify.yml           # Verification tests

playbooks/
├── webtop-deploy.yml            # Main deployment playbook
└── webtop-teardown.yml          # Container removal playbook

group_vars/
└── all/
    └── webtop.yml               # Group variables for webtop deployment

docs/
└── webtop-architecture.md       # Architecture documentation with network diagram
```

**Structure Decision**: Infrastructure as Code deployment using Ansible roles. The webtop role follows the existing pattern established by demo_site, gitlab, and other service roles in the repository. All configuration is managed through Ansible with no manual steps, ensuring idempotency and reproducibility.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

**Status**: ✅ No violations - All constitutional requirements satisfied

The webtop deployment fully complies with all constitutional principles. No complexity justifications required.

