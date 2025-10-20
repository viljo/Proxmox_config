# Implementation Plan: GitLab CI/CD Platform

**Branch**: `008-gitlab-cicd` | **Date**: 2025-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-gitlab-cicd/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deploy self-hosted GitLab Community Edition server and GitLab Runner agents in LXC containers on Proxmox infrastructure, providing Git version control, CI/CD pipeline automation, code review workflows, and private Docker container registry. The solution integrates with existing Keycloak authentication, Traefik reverse proxy, NetBox CMDB, Zabbix monitoring, and PBS backup infrastructure.

## Technical Context

**Language/Version**: YAML (Ansible 2.15+), Jinja2 templates, Shell scripts (bash), GitLab CE 16.x+, GitLab Runner 16.x+
**Primary Dependencies**: GitLab Omnibus package, GitLab Runner package, Docker CE (for runner executor), PostgreSQL 13+ (bundled), Redis 6+ (bundled), Git 2.x
**Storage**: File-based repository storage (/var/opt/gitlab/git-data), PostgreSQL for metadata, Redis for caching/queuing, artifact storage (/var/opt/gitlab/gitlab-rails/shared/artifacts)
**Testing**: ansible-lint, yamllint for playbook validation, manual integration testing via quickstart procedures, GitLab health checks
**Target Platform**: Proxmox VE 8.x, unprivileged LXC containers, Debian 12/13 base images
**Project Type**: Infrastructure deployment (Ansible role-based orchestration)
**Performance Goals**: 10 concurrent pipeline executions, 10 MB/s repository clone rate, <2s web UI page load, <30s pipeline trigger latency, 100+ Mbps network throughput
**Constraints**: Unprivileged LXC containers only, management network (vmbr0) deployment, minimum 4GB RAM for GitLab server, Docker-in-LXC for runner execution, HTTPS-only access via Traefik
**Scale/Scope**: GitLab server (4GB RAM, 4 CPU, 100GB disk), 2+ runner containers (2GB RAM, 2 CPU each), support for 100GB initial repository storage (expandable), 10 concurrent CI/CD pipelines, unlimited private repositories

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Infrastructure as Code
- [x] All infrastructure changes defined in Ansible roles (roles/gitlab/, roles/gitlab_runner/)
- [x] No manual configuration steps required (fully automated LXC + GitLab + Runner deployment)
- [x] Roles are version-controlled and documented (new roles to be created with comprehensive READMEs)

### Security-First Design
- [x] Integration with Keycloak/LDAP authentication (GitLab OIDC integration for Keycloak)
- [x] No plaintext secrets (using Ansible Vault for GitLab root password, runner registration tokens, database passwords)
- [x] Container security (unprivileged LXC with nesting for Docker, nftables firewall, Fail2Ban for SSH/HTTP brute force protection)

### Idempotent Operations
- [x] All playbooks can be re-run safely (provision markers prevent re-installation, config changes detected via checksums)
- [x] Proper state checks before changes (container existence checks, GitLab installation status, runner registration status)
- [x] Destructive operations require explicit flags (separate teardown playbooks for container removal)

### Single Source of Truth
- [x] NetBox integration for inventory (GitLab server and runner containers registered in CMDB with IP addresses, resources)
- [x] Monitoring aligned with CMDB (Zabbix auto-discovery from NetBox data, health check endpoints exposed)
- [x] Documentation derived from NetBox data (architecture diagrams generated from NetBox topology)

### Automated Operations
- [x] CI/CD pipeline configuration (GitLab CI pipeline for Ansible role testing: ansible-lint, yamllint, Molecule tests)
- [x] Automated testing approach defined (Molecule framework for role testing, integration tests via quickstart validation)
- [x] Backup and monitoring automation included (PBS scheduled backups of LXC containers, Zabbix monitoring of GitLab health, pipeline metrics)

## Project Structure

### Documentation (this feature)

```
specs/008-gitlab-cicd/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── gitlab-config-schema.yml       # GitLab configuration structure
│   └── gitlab-ci-pipeline-schema.yml  # CI/CD pipeline definition schema
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```
roles/gitlab/                        # NEW ROLE
├── README.md                        # Role documentation (installation, variables, examples)
├── defaults/
│   └── main.yml                     # Default variables (CT ID, resources, GitLab config)
├── tasks/
│   ├── main.yml                     # Main task orchestration
│   ├── lxc.yml                      # LXC container creation and configuration
│   ├── install.yml                  # GitLab Omnibus package installation
│   ├── configure.yml                # GitLab configuration (gitlab.rb templating)
│   ├── keycloak.yml                 # Keycloak OIDC integration setup
│   ├── netbox.yml                   # NetBox CMDB registration
│   ├── zabbix.yml                   # Zabbix monitoring setup
│   └── backup.yml                   # PBS backup configuration
├── templates/
│   ├── gitlab.rb.j2                 # GitLab Omnibus configuration template
│   └── gitlab-traefik.yml.j2        # Traefik routing configuration
├── handlers/
│   └── main.yml                     # GitLab reconfigure/restart handlers
├── vars/
│   └── main.yml                     # Non-overridable variables
├── meta/
│   └── main.yml                     # Role metadata and dependencies
└── molecule/                        # NEW: Molecule testing framework
    └── default/
        ├── molecule.yml             # Test configuration
        ├── converge.yml             # Test playbook
        └── verify.yml               # Verification tests

roles/gitlab_runner/                 # NEW ROLE
├── README.md                        # Runner role documentation
├── defaults/
│   └── main.yml                     # Default variables (runner count, resources)
├── tasks/
│   ├── main.yml                     # Main task orchestration
│   ├── lxc.yml                      # Runner LXC container creation
│   ├── docker.yml                   # Docker installation for executor
│   ├── install.yml                  # GitLab Runner package installation
│   ├── register.yml                 # Runner registration with GitLab server
│   ├── netbox.yml                   # NetBox registration
│   └── zabbix.yml                   # Zabbix monitoring
├── templates/
│   ├── config.toml.j2               # Runner configuration template
│   └── docker-daemon.json.j2        # Docker daemon configuration
├── handlers/
│   └── main.yml                     # Runner restart handler
├── meta/
│   └── main.yml                     # Role metadata
└── molecule/                        # Molecule tests
    └── default/
        ├── molecule.yml
        ├── converge.yml
        └── verify.yml

playbooks/
├── gitlab-deploy.yml                # NEW: Main GitLab deployment playbook
├── gitlab-runner-deploy.yml         # NEW: Runner deployment playbook
├── gitlab-teardown.yml              # NEW: GitLab removal playbook
└── gitlab-runner-teardown.yml       # NEW: Runner removal playbook

inventory/group_vars/all/
├── gitlab.yml                       # NEW: GitLab server configuration variables
└── gitlab_runners.yml               # NEW: Runner configuration variables

docs/gitlab/
├── architecture.md                  # NEW: Architecture documentation (network, components)
├── deployment-guide.md              # NEW: Step-by-step deployment instructions
├── keycloak-integration.md          # NEW: OIDC authentication setup
├── runner-configuration.md          # NEW: Runner executor configuration
├── backup-recovery.md               # NEW: Backup and disaster recovery procedures
└── troubleshooting.md               # NEW: Common issues and solutions

.gitlab-ci.yml                       # NEW: GitLab CI pipeline for this repository
```

**Structure Decision**: Infrastructure as Code deployment using Ansible roles. Two new roles will be created:
1. **roles/gitlab/** - Deploys GitLab Omnibus server in LXC container with Keycloak OIDC, Traefik integration, NetBox registration, Zabbix monitoring, and PBS backups
2. **roles/gitlab_runner/** - Deploys one or more GitLab Runner containers with Docker executor, registers with GitLab server, and integrates with monitoring/backup infrastructure

The roles follow existing patterns from wireguard, keycloak, and other services. Playbooks in playbooks/ orchestrate deployment and teardown operations.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | All constitutional requirements met | N/A |

**Note**: GitLab CI/CD deployment fully complies with all five constitutional principles:
- Infrastructure as Code: Complete Ansible automation
- Security-First Design: Keycloak OIDC, Ansible Vault, unprivileged LXC, Traefik HTTPS
- Idempotent Operations: Safe re-run capability with state checks
- Single Source of Truth: NetBox CMDB integration for all containers
- Automated Operations: CI/CD for role testing, automated backups, monitoring
