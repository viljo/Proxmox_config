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

**Deploying a service?** See the [Deployment Documentation](docs/deployment/)

**Understanding the architecture?** Read the [Network Topology](docs/architecture/network-topology.md)

## Usage

Each Ansible role is contained in `roles/` and is designed to be idempotent.  The top-level playbook `playbooks/site.yml` orchestrates the deployment, while `playbooks/dmz-rebuild.yml` can be used to tear down and redeploy only the public services after network changes (it calls `roles/dmz_cleanup` to purge old LXCs before recreating them on the 172.16.10.0/24 DMZ).

Secrets and sensitive credentials now live exclusively in the encrypted vault (`inventory/group_vars/all/secrets.yml`); edit them with:
```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Or provide a custom `--vault-password-file`.  The helper password file `.vault_pass.txt` is ignored by Git—create it locally if you want non-interactive vault operations.  See the [documentation](docs/) for details on variables, network segmentation, backup schedules, and daily maintenance jobs.

Day-to-day access to the Proxmox host is via `ssh root@192.168.1.3`.  All Ansible playbooks target the `proxmox_admin` host defined in `inventory/hosts.yml`, using that SSH transport.

The host now keeps its default route on the management network (`vmbr0` → gateway `192.168.1.1`); the firewall LXC handles WAN access on `vmbr2`, while the service DMZ lives on `vmbr3` (`172.16.10.0/24`).

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

## Key Services

| Service | Container ID | IP Address | URL |
|---------|--------------|------------|-----|
| Firewall | 1 | 172.16.10.1 | N/A (NAT gateway) |
| PostgreSQL | 50 | 172.16.10.50 | N/A (internal) |
| Keycloak | 51 | 172.16.10.51 | https://keycloak.viljo.se |
| NetBox | 52 | 172.16.10.52 | https://netbox.viljo.se |
| GitLab | 53 | 172.16.10.53 | https://gitlab.viljo.se |
| Demo Site | 60 | 172.16.10.60 | https://demosite.viljo.se |

See [Container Mapping](docs/architecture/container-mapping.md) for all 16 services.

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
