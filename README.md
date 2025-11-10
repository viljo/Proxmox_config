# Proxmox Infrastructure with Coolify PaaS

This repository contains Ansible automation for deploying and managing a **single-node Proxmox infrastructure** using **Coolify PaaS**. The entire infrastructure runs inside a single LXC container (Coolify) that hosts all services as Docker containers, providing a simple, efficient, and maintainable self-hosted platform.

## Architecture Overview

**Simple by Design**: The infrastructure uses Coolify PaaS to consolidate all services into Docker containers within a single LXC container. This eliminates the complexity of managing multiple LXC containers, firewall/NAT layers, and DMZ networks while maintaining security through Docker container isolation and the built-in Coolify Proxy.

**Core Components**:
- **Proxmox VE 9**: Hypervisor (192.168.1.3 on management network)
- **Coolify LXC 200**: Single privileged LXC container hosting all services
  - Management interface: 192.168.1.200/16 (eth1 on vmbr0)
  - Public interface: DHCP public IP (eth0 on vmbr2)
  - Built-in reverse proxy with automatic SSL (Let's Encrypt)
  - API-driven service deployment
- **Service Deployment**: Separate repository at `/coolify_service/ansible`
- **Infrastructure Management**: This repository (Proxmox & Coolify deployment only)

## Quick Start

**New to this project?** Start with the [Getting Started Guide](docs/getting-started.md)

**Understanding the architecture?** Read:
- [Network Topology](docs/architecture/network-topology.md) - Complete network design
- [ADR-001: Network Architecture Decision](docs/adr/001-network-topology-change.md) - Why we chose this design
- [Container Mapping](docs/architecture/container-mapping.md) - LXC and Docker container reference

**Deploying services?** Services are deployed via the Coolify API using Ansible playbooks in the `/coolify_service/ansible` repository.

**Disaster Recovery?** See the [DR Runbook](docs/DR_RUNBOOK.md)

## Key Features

### Simplified Infrastructure
- **Single LXC Container**: All services consolidated in Coolify (LXC 200)
- **Docker Containers**: Services run as containers managed via Coolify API
- **No Firewall/NAT Layer**: Direct internet exposure with application-level security
- **API-Driven Deployment**: Services deployed via Coolify API calls from Ansible
- **Built-in Proxy**: Coolify Proxy handles SSL termination and routing (replaces Traefik)

### Network Architecture
- **vmbr0 (Management)**: Internal management network (192.168.1.0/16)
  - Proxmox host: 192.168.1.3
  - Coolify management interface: 192.168.1.200
- **vmbr2 (WAN)**: Public internet access via ISP DHCP
  - Coolify public interface gets DHCP IP
  - All public services accessible through this interface
- **vmbr3**: Created but unused (reserved for future segmentation)

### Security & Operations
- **Docker Network Isolation**: Services isolated in separate Docker networks
- **Coolify Proxy**: SSL termination with Let's Encrypt certificates
- **Ansible Vault**: Encrypted secrets management
- **SSH Key-Based Auth**: No password authentication
- **Loopia DDNS**: Automatic DNS updates every 15 minutes
- **Application-Level Security**: Each service manages its own authentication
- **Ansible-Based Reproducibility**: Complete infrastructure deployment automation

### Service Management
All services deployed and managed via Coolify:
- **Coolify Dashboard**: https://paas.viljo.se
- **API Access**: http://192.168.1.200:8000/api/v1 (management network)
- **Service Repository**: `/coolify_service/ansible` (separate repository)

## Usage

### Deploying the Coolify Infrastructure

This repository manages the Proxmox infrastructure and Coolify deployment:

```bash
# Deploy Coolify LXC container to Proxmox
ansible-playbook -i inventory/production.ini playbooks/coolify-deploy.yml
```

**Note**: Individual application services (GitLab, Nextcloud, media services, etc.) are deployed via the `/coolify_service/ansible` repository using Coolify API calls.

### Accessing the Infrastructure

**Proxmox Host**:
```bash
# Direct access (if on management network)
ssh root@192.168.1.3

# Via public DNS (if configured)
ssh root@viljo.se
```

**Coolify Management**:
```bash
# Enter Coolify LXC container
ssh root@192.168.1.3 pct enter 200

# Check Coolify API
curl -s http://192.168.1.200:8000/health

# List Docker containers
ssh root@192.168.1.3 pct exec 200 -- docker ps
```

**Coolify Dashboard**:
- Web UI: https://paas.viljo.se
- API: http://192.168.1.200:8000/api/v1

### Managing Secrets

All sensitive credentials stored in encrypted vault:
```bash
# Edit vault secrets
ansible-vault edit inventory/group_vars/all/secrets.yml

# Or use custom vault password file
ansible-vault edit inventory/group_vars/all/secrets.yml --vault-password-file=.vault_pass.txt
```

The `.vault_pass.txt` file is ignored by Git—create it locally for non-interactive vault operations.

## Deployed Infrastructure

### LXC Containers

| Container ID | Service | Management IP | Public Interface | Status |
|--------------|---------|---------------|------------------|--------|
| **200** | Coolify PaaS | 192.168.1.200/16 (vmbr0) | DHCP public IP (vmbr2) | ✅ Active |

### Application Services

All application services run as **Docker containers** inside Coolify LXC 200. Services are deployed via Coolify API using Ansible playbooks in the `/coolify_service/ansible` repository.

**Check deployed services**:
```bash
# Via Coolify API
curl -s -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
  http://192.168.1.200:8000/api/v1/services | jq

# Via Docker
ssh root@192.168.1.3 pct exec 200 -- docker ps
```

**Example services** (deployment status may vary):
- Coolify Dashboard: https://paas.viljo.se
- Links Portal: https://links.viljo.se
- Media services, cloud storage, collaboration tools, etc.

See [Services Configuration](inventory/group_vars/all/services.yml) and `/coolify_service/ansible` repository for complete service inventory.

## Network Topology

```
                    Internet
                       ↓
               ISP Router (DHCP)
                       ↓
            ┌──────────────────────┐
            │   vmbr2 (WAN)        │
            │   Bridge on Proxmox  │
            └──────────┬───────────┘
                       ↓
      ┌────────────────────────────────┐
      │   Coolify LXC 200 (eth0)       │
      │   Public IP via DHCP           │
      │                                │
      │  ┌──────────────────────────┐  │
      │  │   Coolify Proxy          │  │
      │  │   (SSL termination)      │  │
      │  └──────────┬───────────────┘  │
      │             ↓                   │
      │  ┌──────────────────────────┐  │
      │  │   Docker Containers      │  │
      │  │   (All services)         │  │
      │  └──────────────────────────┘  │
      └────────────────┬───────────────┘
                       │
              Coolify LXC 200 (eth1)
              192.168.1.200/16
                       ↓
            ┌──────────────────────┐
            │   vmbr0 (Management) │
            │   192.168.1.0/16     │
            └──────────┬───────────┘
                       ↓
            Proxmox Host (192.168.1.3)
            Ansible API Access
```

See [Network Topology Documentation](docs/architecture/network-topology.md) for complete details.

## Repository Structure

- **`inventory/`** – Ansible inventory and variables
  - `production.ini` – Proxmox host inventory
  - `group_vars/all/*.yml` – Configuration variables
  - `group_vars/all/secrets.yml` – Encrypted vault (Ansible Vault)
- **`playbooks/`** – Infrastructure deployment playbooks
  - `coolify-deploy.yml` – Deploy Coolify LXC container
  - Infrastructure management playbooks
- **`docs/`** – Documentation organized by category
  - `architecture/` – Network topology, container mapping, design decisions
  - `adr/` – Architecture Decision Records
  - `operations/` – Operational procedures
  - See [Documentation Index](docs/README.md)
- **`scripts/`** – Utility scripts
  - `check-infrastructure-status.sh` – Infrastructure health check
  - DNS and maintenance scripts
- **`specs/`** – Feature specifications
  - See [Specs Index](specs/README.md)
- **`.tooling/`** – Development tool configurations

## Disaster Recovery

**Current Status**: Infrastructure is reproducible via Ansible automation

### Quick Recovery Process

```bash
# 1. Restore Proxmox host from backup (if needed)
# 2. Deploy Coolify LXC container
ansible-playbook -i inventory/production.ini playbooks/coolify-deploy.yml

# 3. Restore services via Coolify
# Services are deployed via /coolify_service/ansible repository
# See DR Runbook for complete procedures
```

**Complete Procedures**: See [DR Runbook](docs/DR_RUNBOOK.md) for step-by-step recovery instructions.

**Verification Commands**:
```bash
# Check Coolify container is running
ssh root@192.168.1.3 pct status 200

# Check Coolify API
curl -s http://192.168.1.200:8000/health

# Check Docker containers
ssh root@192.168.1.3 pct exec 200 -- docker ps

# Check public DNS resolution
dig +short paas.viljo.se @1.1.1.1
```

## Documentation

### Architecture & Design
- [Network Topology](docs/architecture/network-topology.md) – Complete network architecture
- [Container Mapping](docs/architecture/container-mapping.md) – LXC and Docker container reference
- [ADR-001: Network Architecture](docs/adr/001-network-topology-change.md) – Architectural decision rationale
- [Network Architecture Deep Dive](docs/NETWORK_ARCHITECTURE.md) – Comprehensive network guide

### Operations
- [Getting Started Guide](docs/getting-started.md) – Quick start for new users
- [DR Runbook](docs/DR_RUNBOOK.md) – Disaster recovery procedures
- [Infrastructure Status Script](scripts/check-infrastructure-status.sh) – Health monitoring

### Reference
- [Documentation Index](docs/README.md) – Complete documentation catalog
- [Services Configuration](inventory/group_vars/all/services.yml) – Service inventory
- [Main Configuration](inventory/group_vars/all/main.yml) – Infrastructure variables

## Key Architectural Decisions

### Why Coolify PaaS?

**Simplicity Over Complexity**:
- **Before** (planned but never deployed): 16+ LXC containers, firewall container, DMZ network, complex NAT/routing
- **After** (actual deployment): 1 LXC container, all services as Docker containers
- **Result**: Easier management, faster deployments, lower resource usage

**Trade-offs Accepted**:
- ⚠️ No firewall/NAT layer (services directly exposed to internet)
  - Mitigated by: Coolify Proxy security, Docker network isolation, application-level security
- ⚠️ Single LXC container (all services in one failure domain)
  - Mitigated by: Docker container isolation, Ansible-based reproducibility
- ⚠️ No network segmentation (vmbr3 unused)
  - Acceptable: Can be activated later if security requirements change

See [ADR-001](docs/adr/001-network-topology-change.md) for complete rationale and alternatives considered.

### What Changed From Original Plan?

The original documentation described a complex multi-container architecture with firewall, DMZ, and individual service LXCs. This was **never deployed**. The actual implementation uses Coolify PaaS for simplicity and efficiency.

See [Network Topology Documentation](docs/architecture/network-topology.md) for comparison of documented vs actual architecture.

## Contributing

Contributions to infrastructure automation are welcome! Please:

1. Test changes in a non-production environment
2. Follow existing Ansible role patterns
3. Update documentation for any architecture changes
4. Add specs to `specs/` directory for new features

For service deployments, contribute to the `/coolify_service/ansible` repository instead.

---

**Project Status**: Active | **Infrastructure Type**: Coolify PaaS on Proxmox VE 9 | **Last Updated**: 2025-11-10
