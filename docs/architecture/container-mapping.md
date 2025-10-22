# Container ID and IP Mapping

Complete reference of all LXC containers in the Proxmox infrastructure.

## Mapping Standard

All containers follow the standardized pattern:

```
Container ID = Last octet of IP address + 100
```

**Example**: Container ID `153` → IP Address `172.16.10.153` (153 - 100 = 53)

This convention was established in [ADR-002: Container ID Standardization](../adr/002-container-id-standardization.md).

## DMZ Network Configuration

- **Network**: 172.16.10.0/24
- **Gateway**: 172.16.10.101 (Firewall container)
- **DNS**: 172.16.10.101, 1.1.1.1
- **Bridge**: vmbr3

## Container Inventory

### Currently Deployed Services

#### Infrastructure & Core Services

| Container ID | Service Name | IP Address | Network | Hostname | Role | Public URL | Automation Status |
|--------------|--------------|------------|---------|----------|------|------------|-------------------|
| **101** | Firewall | 172.16.10.101<br>192.168.1.1 | DMZ/Mgmt | firewall | `roles/firewall_api` | N/A (router) | ⚠️ Partial |
| **110** | SSH Bastion | 192.168.1.10 | Mgmt | bastion | N/A | ssh.viljo.se | ❌ Manual |
| **150** | PostgreSQL 17 | 172.16.10.150 | DMZ | postgres | N/A | N/A (internal) | ❌ Manual |
| **158** | Redis 8.0.2 | 172.16.10.158 | DMZ | redis | N/A | N/A (internal) | ❌ Manual |

#### Authentication & Identity

| Container ID | Service Name | IP Address | Network | Hostname | Role | Public URL | Automation Status |
|--------------|--------------|------------|---------|----------|------|------------|-------------------|
| **151** | Keycloak 24.0.3 | 172.16.10.151 | DMZ | keycloak | N/A | https://keycloak.viljo.se | ❌ Manual |

#### DevOps & Infrastructure

| Container ID | Service Name | IP Address | Network | Hostname | Role | Public URL | Automation Status |
|--------------|--------------|------------|---------|----------|------|------------|-------------------|
| **153** | GitLab CE 18.5.0 | 172.16.10.153 | DMZ | gitlab | N/A | https://gitlab.viljo.se | ❌ Manual |
| **154** | GitLab Runner 18.5.0 | 172.16.10.154 | DMZ | gitlab-runner | N/A | N/A (internal) | ❌ Manual |

#### Collaboration & Productivity

| Container ID | Service Name | IP Address | Network | Hostname | Role | Public URL | Automation Status |
|--------------|--------------|------------|---------|----------|------|------------|-------------------|
| **155** | Nextcloud 32.0.0 | 172.16.10.155 | DMZ | nextcloud | `roles/nextcloud_api` | https://nextcloud.viljo.se | ❌ Manual |
| **163** | Mattermost 11.0.2 | 172.16.10.163 | DMZ | mattermost | N/A | https://mattermost.viljo.se | ❌ Manual |

#### Utilities & Tools

| Container ID | Service Name | IP Address | Network | Hostname | Role | Public URL | Automation Status |
|--------------|--------------|------------|---------|----------|------|------------|-------------------|
| **160** | Demo Site | 172.16.10.160 | DMZ | demosite | `roles/demo_site_api` | https://demosite.viljo.se | ✅ Automated |
| **170** | Webtop (XFCE) | 172.16.10.170 | DMZ | webtop | N/A | https://browser.viljo.se | ❌ Manual |

**Automation Status Legend:**
- ✅ **Automated**: Fully deployed via Ansible (idempotent, supports `--check` mode)
- ⚠️ **Partial**: Ansible role exists but uses manual steps (pct exec commands)
- ❌ **Manual**: Deployed via SSH/pct exec (requires Ansible role for disaster recovery)

### Planned Services (Not Yet Deployed)

| Container ID | Service Name | IP Address | Hostname | Notes |
|--------------|--------------|------------|----------|-------|
| **152** | NetBox | 172.16.10.152 | netbox | Infrastructure documentation |
| **156** | Jellyfin | 172.16.10.156 | jellyfin | Media streaming |
| **157** | Home Assistant | 172.16.10.157 | homeassistant | IoT automation |
| **159** | qBittorrent | 172.16.10.159 | qbittorrent | Torrent client |
| **161** | Cosmos | 172.16.10.161 | cosmos | Dashboard |
| **162** | Wazuh | 172.16.10.162 | wazuh | Security monitoring |
| **164** | OpenMediaVault | 172.16.10.164 | openmediavault | NAS/Storage |
| **165** | Zipline | 172.16.10.165 | zipline | Screenshot sharing |
| **190** | WireGuard VPN | 172.16.10.190 | wireguard | VPN server |

## Resource Allocation Summary

### Currently Deployed Services

| Service | CPU Cores | RAM (GB) | Disk (GB) | Notes | Automation |
|---------|-----------|----------|-----------|-------|------------|
| Firewall | 1 | 0.5 | 8 | NAT gateway + routing | ⚠️ Partial |
| SSH Bastion | 1 | 0.5 | 8 | External SSH access | ❌ Manual |
| PostgreSQL | 4 | 8 | 100 | Shared database (Keycloak, GitLab, Nextcloud, Mattermost) | ❌ Manual |
| Redis | 2 | 2 | 20 | Cache + message queue (GitLab, Nextcloud) | ❌ Manual |
| Keycloak | 4 | 2 | 30 | SSO/Authentication | ❌ Manual |
| GitLab CE | 4 | 8 | 100 | DevOps platform + CI/CD | ❌ Manual |
| GitLab Runner | 2 | 2 | 40 | Build executor (3 runners) | ❌ Manual |
| Nextcloud | 4 | 6 | 100 | File storage + collaboration | ❌ Manual |
| Mattermost | 2 | 4 | 40 | Team collaboration | ❌ Manual |
| Demo Site | 1 | 1 | 8 | Static website (testing) | ✅ Automated |
| Webtop | 2 | 4 | 40 | Remote browser (XFCE desktop) | ❌ Manual |

**Total Deployed**: 27 cores, 38 GB RAM, 494 GB storage across 11 containers

### Additional Infrastructure (Not Containers)

| Component | Location | Resources | Notes |
|-----------|----------|-----------|-------|
| Traefik | Proxmox host | ~100MB RAM | Reverse proxy, HTTPS termination |
| Loopia DDNS | Proxmox host | Minimal | DNS auto-update (15min intervals) |

## Configuration Files

Each service has configuration in:
- **Inventory**: `inventory/group_vars/all/<service>.yml`
- **Role**: `roles/<service>/defaults/main.yml`
- **Role README**: `roles/<service>/README.md`

## Network Dependencies

### Firewall (Container 1)
- **Upstream**: vmbr2 (WAN) - DHCP from ISP
- **Downstream**: vmbr3 (DMZ) - 172.16.10.101/24
- **Function**: NAT gateway, port forwarding (80/443 → Traefik)

### Traefik (Not a container)
- **Location**: Runs on Proxmox host
- **Function**: Reverse proxy, TLS termination
- **Upstream**: Firewall (172.16.10.101)
- **Downstream**: All public services on vmbr3

### PostgreSQL (Container 50)
- **Clients**: Keycloak, NetBox, Nextcloud, GitLab (via socket/TCP)

## Service Categories

### Core Infrastructure (Always Running)
- Firewall (101)
- PostgreSQL (150)
- Keycloak (151)

### DevOps Platform
- NetBox (152)
- GitLab (153)
- GitLab Runner (154)

### User Applications
- Nextcloud (155)
- Jellyfin (156)
- Home Assistant (157)

### Utilities
- qBittorrent (159)
- Demo Site (160) - Testing only
- Cosmos (161)
- Wazuh (162)
- OpenMediaVault (164)
- Zipline (165)
- WireGuard VPN (190)

## Quick Reference Commands

### List All Containers
```bash
ssh root@192.168.1.3 pct list
```

### Check Specific Container
```bash
ssh root@192.168.1.3 pct status 153  # GitLab
ssh root@192.168.1.3 pct config 153  # Show config
ssh root@192.168.1.3 pct enter 153   # Enter container
```

### Network Testing
```bash
# From Proxmox host
ping 172.16.10.153  # Ping GitLab

# From within a container
ssh root@192.168.1.3 pct exec 153 -- ping -c 2 1.1.1.1
ssh root@192.168.1.3 pct exec 153 -- curl -I https://gitlab.viljo.se
```

## Deployment and Automation Status

### Deployed Services (11 containers)

| Service | Status | Automation | Ansible Role | External Access | Notes |
|---------|--------|------------|--------------|-----------------|-------|
| Firewall | ✅ Running | ⚠️ Partial | `firewall_api` | N/A | Role uses pct exec |
| SSH Bastion | ✅ Running | ❌ Manual | N/A | ssh.viljo.se | SSH gateway |
| PostgreSQL 17 | ✅ Running | ❌ Manual | N/A | N/A | Shared DB (4 services) |
| Redis 8.0.2 | ✅ Running | ❌ Manual | N/A | N/A | Cache + queue |
| Keycloak 24.0.3 | ✅ Running | ❌ Manual | N/A | https://keycloak.viljo.se | SSO (not externally validated) |
| GitLab CE 18.5.0 | ✅ Running | ❌ Manual | N/A | https://gitlab.viljo.se | DevOps platform |
| GitLab Runner 18.5.0 | ✅ Running | ❌ Manual | N/A | N/A | 3 runners active |
| Nextcloud 32.0.0 | ✅ Running | ❌ Manual | `nextcloud_api` | https://nextcloud.viljo.se | File sharing |
| Mattermost 11.0.2 | ✅ Running | ❌ Manual | N/A | https://mattermost.viljo.se | Awaiting external test |
| Demo Site | ✅ Running | ✅ Automated | `demo_site_api` | https://demosite.viljo.se | Only automated service |
| Webtop (XFCE) | ✅ Running | ❌ Manual | N/A | https://browser.viljo.se | Remote desktop |

### Planned Services (9 services)

| Service | Container ID | IP | Priority | Notes |
|---------|--------------|-----|----------|-------|
| NetBox | 152 | 172.16.10.152 | Medium | Infrastructure docs |
| Jellyfin | 156 | 172.16.10.156 | Low | Media streaming |
| Home Assistant | 157 | 172.16.10.157 | Low | IoT automation |
| qBittorrent | 159 | 172.16.10.159 | Low | Torrent client |
| Cosmos | 161 | 172.16.10.161 | Low | Dashboard |
| Wazuh | 162 | 172.16.10.162 | Medium | Security monitoring |
| OpenMediaVault | 164 | 172.16.10.164 | Low | NAS/Storage |
| Zipline | 165 | 172.16.10.165 | Low | Screenshot sharing |
| WireGuard VPN | 190 | 172.16.10.190 | High | VPN server |

## Reserved IP Ranges

- **1-49**: Infrastructure and future core services
- **50-59**: Backend services (databases, auth, etc.)
- **60-89**: User-facing applications
- **90-99**: Network services (VPN, DNS, etc.)

## Disaster Recovery and Automation

**Current Automation Coverage**: ~9% (1 of 11 services fully automated)

**Disaster Recovery Goal**: Clean Proxmox install → Ansible playbooks → Backup restore → 100% functionality in <1 hour

See [Automation Audit](../AUTOMATION_AUDIT.md) for:
- Detailed automation gaps analysis
- Roadmap for creating Ansible roles
- Milestone tracking with target dates
- Success metrics and progress tracking

See [External Testing Methodology](../operations/external-testing-methodology.md#disaster-recovery-validation) for disaster recovery validation procedures.

## See Also

- [Network Topology](network-topology.md) - Complete network architecture
- [Firewall Deployment](../deployment/firewall-deployment.md) - Firewall setup guide
- [ADR-002](../adr/002-container-id-standardization.md) - Container ID standardization decision
- [SSH Access Methods](../operations/ssh-access-methods.md) - Remote and on-site access
- [Automation Audit](../AUTOMATION_AUDIT.md) - Automation gaps and roadmap

---

**Last Updated**: 2025-10-22 during automation audit
