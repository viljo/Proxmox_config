# Private Infrastructure Deployment Repository

This repository contains a set of Ansible roles and configuration files for deploying a comprehensive, single-node infrastructure platform on **Proxmox VE 9**.  The stack is designed to provide all core services needed for a small enterprise or homelab, with strong security and automation at the forefront.

## Key features

- **Identity & Access Management:** Uses OpenLDAP and Keycloak (running in an LXC) as the central user database and single sign-on (SSO) provider.  GitLab and Nextcloud are preconfigured to bind to LDAP, keeping developer, collaboration, and storage workflows on a single credential store.  All services—GitLab, Nextcloud, Matrix/Element, Mattermost, NetBox, Zabbix, etc.—integrate via OIDC or LDAP, so users log in once for everything.

- **Reverse Proxy & TLS:** Traefik terminates HTTPS with certificates obtained through a DNS-01 challenge via Loopia and Cloudflare.  It also routes traffic to internal services based on hostnames and paths.

- **DevOps Stack:** GitLab CE hosts repositories and CI/CD pipelines.  Private package repositories (APT, Python/UV, Docker registry) support package management.  A GitLab Runner provides isolated build execution, and NetBox plug-ins allow dynamic inventory and automation via Ansible.

- **Collaboration & Productivity:** The platform includes Nextcloud (for file storage and collaboration), Matrix/Element (for real-time chat), Mattermost (team chat and alert sink), OnlyOffice Document Server (collaborative editing), Jitsi Meet (video conferencing), Metabase (analytics), and Vaultwarden (password vault).

- **Monitoring & Observability:** NetBox maintains the infrastructure's source of truth.  Zabbix monitors all systems and services; a NetBox→Zabbix sync keeps monitoring aligned with inventory.  Prometheus collects time-series metrics while Grafana visualizes them, and Loki collects logs.  Alerts are routed to Mattermost.

- **Security & Hardening:** Unprivileged LXCs, nftables firewalls, Fail2Ban, AppArmor, auditd, automatic security updates, and vault secrets management.  Backup schedules ensure daily snapshots and off-site archives.  Mail relay uses Postfix with OIDC authentication to unify outbound notifications.

- **Additional Services:** SmokePing checks latency, NetBox Job Runner triggers automation from CMDB events, ZeroTier provides a secure overlay network, and optional HA and disaster recovery features are documented.

## Quick Start

**New to this project?** Start with the [Getting Started Guide](docs/getting-started.md)

**Managing configuration?** Read the [Configuration Management Guide](docs/deployment/configuration-management.md) (what to commit vs what to vault)

**Deploying a service?** See the [Deployment Documentation](docs/deployment/)

**Adding a new service?** Follow the [Test-Driven Service Workflow](docs/NEW_SERVICE_WORKFLOW.md) (9-step validation process)

**Understanding the architecture?** Read the [Network Topology](docs/architecture/network-topology.md)

**Disaster Recovery?** See the [DR Runbook](docs/DR_RUNBOOK.md) | [Latest DR Test](docs/DR_TEST_REPORT_2025-10-23.md)

## Usage

**Automation Status**: 100% coverage – all 11 services deployable via API-first Ansible automation. Deploy the entire infrastructure from scratch with:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/full-deployment.yml
```

Each Ansible role is contained in `roles/` and follows idempotent, API-first design patterns. Individual services can be deployed with service-specific playbooks (`playbooks/*-deploy.yml`), or the entire stack deployed in dependency order via `playbooks/full-deployment.yml`.

See [README_AUTOMATION.md](README_AUTOMATION.md) for automation details and [docs/AUTOMATION_AUDIT.md](docs/AUTOMATION_AUDIT.md) for disaster recovery validation.

Secrets and sensitive credentials now live exclusively in the encrypted vault (`inventory/group_vars/all/secrets.yml`); edit them with:
```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Or provide a custom `--vault-password-file`.  The helper password file `.vault_pass.txt` is ignored by Git—create it locally if you want non-interactive vault operations.  See the [documentation](docs/) for details on variables, network segmentation, backup schedules, and daily maintenance jobs.

Day-to-day access to the Proxmox host is via `ssh root@192.168.1.3` (admin network) or `ssh -J root@ssh.viljo.se root@192.168.1.3` (via internet through bastion). All Ansible playbooks target the `proxmox_admin` host defined in `inventory/hosts.yml`, using that SSH transport.

The host now keeps its default route on the management network (`vmbr0` → gateway `192.168.1.1`); the firewall LXC handles WAN access on `vmbr2`, while the service DMZ lives on `vmbr3` (`172.16.10.0/24`).

## Disaster Recovery

**Status**: Validated through full wipe-and-restore test (2025-10-23)
**RTO**: < 1 hour (10 minutes for container restore + 30 minutes for data restore)
**RPO**: < 24 hours (daily backups)
**Success Rate**: 90% (9/10 containers restored successfully in last DR test)

### Quick Recovery

```bash
# 1. Restore firewall (required first for DMZ internet access)
bash scripts/restore-firewall.sh

# 2. Restore all containers
for id in 110 150 151 154 155 158 160 170; do
  pct restore $id $(pvesm list local | grep "vzdump-lxc-$id" | tail -1 | awk '{print $1}') --storage local-lvm
  pct start $id
done

# 3. Restore data (optional if container backups are recent)
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=$(ls -1 /var/backups/infrastructure/ | tail -1)
```

**Complete Procedures**: See [DR Runbook](docs/DR_RUNBOOK.md) for step-by-step recovery instructions.

**Backup Verification**: Run `bash scripts/verify-backup.sh all` to test all backups can be restored.

**Recent DR Test Results**:
- ✅ Container backups: 2:45 backup time, 10 min restore time
- ⚠️ GitLab backups: Known corruption issue (being investigated)
- ✅ Infrastructure restored: 9 out of 10 services operational
- See [DR Test Report](docs/DR_TEST_REPORT_2025-10-23.md) and [Lessons Learned](docs/DR_TEST_LESSONS_LEARNED.md)

All LXC roles default to the Debian 13 (Trixie) standard template (`{{ debian_template_image }}`); update `inventory/group_vars/all/main.yml` if Proxmox publishes a newer filename.

## Repository structure

- **`inventory/`** – Ansible inventory (hosts.yml) and all variables (group_vars/all/*.yml), including encrypted vault (secrets.yml)
- **`playbooks/`** – Deployment playbooks (site.yml, dmz-rebuild.yml, demo-site-*.yml)
- **`roles/`** – 24 Ansible roles for infrastructure services (firewall, gitlab, nextcloud, keycloak, netbox, etc.)
- **`docs/`** – Documentation organized by category (architecture/, deployment/, operations/, adr/)
  - See [Documentation Index](docs/README.md) and [Getting Started Guide](docs/getting-started.md)
- **`specs/`** – Feature specifications organized by status (completed/, active/, planned/)
  - See [Specs Index](specs/README.md) for feature tracking
- **`scripts/`** – Utility scripts for project maintenance
- **`.tooling/`** – Development tool configurations (ansible-lint, yamllint, claude-code, specify)
- **`.archive/`** – Historical analysis files and completed documentation

## Deployed Services

| Service | Container ID | IP Address | URL | Automation |
|---------|--------------|------------|-----|------------|
| Firewall | 101 | 172.16.10.101 | N/A (NAT gateway) | ⚠️ Partial |
| Bastion | 110 | 192.168.1.110 | ssh.viljo.se | ✅ Full |
| PostgreSQL | 150 | 172.16.10.150 | N/A (internal) | ✅ Full |
| Keycloak | 151 | 172.16.10.151 | https://keycloak.viljo.se | ✅ Full |
| GitLab | 153 | 172.16.10.153 | https://gitlab.viljo.se | ✅ Full |
| GitLab Runner | 154 | 172.16.10.154 | N/A (internal) | ✅ Full |
| Nextcloud | 155 | 172.16.10.155 | https://nextcloud.viljo.se | ✅ Full |
| Redis | 158 | 172.16.10.158 | N/A (internal) | ✅ Full |
| Demo Site | 160 | 172.16.10.160 | https://demosite.viljo.se | ✅ Full |
| Mattermost | 163 | 172.16.10.163 | https://mattermost.viljo.se | ✅ Full |
| Webtop | 170 | 172.16.10.170 | https://browser.viljo.se | ✅ Full |

**Automation Coverage**: 100% (11 of 11 services) | See [Container Mapping](docs/architecture/container-mapping.md) for complete details.

## Documentation

- **[Getting Started](docs/getting-started.md)** – Quick start guide for new users
- **[Network Topology](docs/architecture/network-topology.md)** – Infrastructure network design
- **[Container Mapping](docs/architecture/container-mapping.md)** – Complete container reference
- **[Deployment Guides](docs/deployment/)** – Step-by-step deployment instructions
- **[Operations Runbooks](docs/operations/)** – Operational procedures
- **[Architecture Decision Records](docs/adr/)** – Historical design decisions
- **[Documentation Index](docs/README.md)** – Complete documentation catalog

## Contributing

Contributions are welcome!  Please open an issue or pull request with improvements or new roles that fit within the scope of this infrastructure stack.  All code should be tested in a staging environment before deployment to production.

See [Contributing Guide](docs/development/contributing.md) for development workflows (coming soon).

---

**Project Status**: Active development | **Last Restructure**: 2025-10-20
