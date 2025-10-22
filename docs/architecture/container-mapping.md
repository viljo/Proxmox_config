# Container ID and IP Mapping

Complete reference of all LXC containers in the Proxmox infrastructure.

## Mapping Standard

All containers follow the standardized pattern:

```
Container ID = Last octet of IP address
```

**Example**: Container ID `53` → IP Address `172.16.10.53`

This convention was established in [ADR-002: Container ID Standardization](../adr/002-container-id-standardization.md).

## DMZ Network Configuration

- **Network**: 172.16.10.0/24
- **Gateway**: 172.16.10.1 (Firewall container)
- **DNS**: 172.16.10.1, 1.1.1.1
- **Bridge**: vmbr3

## Container Inventory

### Infrastructure Services

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **1** | Firewall | 172.16.10.1 | firewall | `roles/firewall` | N/A (internal router) |
| **50** | PostgreSQL | 172.16.10.50 | postgres | `roles/postgresql` | N/A (internal database) |

### Authentication & Identity

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **51** | Keycloak | 172.16.10.51 | keycloak | `roles/keycloak` | https://keycloak.viljo.se |

### DevOps & Infrastructure

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **52** | NetBox | 172.16.10.52 | netbox | `roles/netbox` | https://netbox.viljo.se |
| **53** | GitLab | 172.16.10.53 | gitlab | `roles/gitlab` | https://gitlab.viljo.se |
| **54** | GitLab Runner | 172.16.10.54 | gitlab-runner | `roles/gitlab_runner` | N/A (internal) |
| **66** | Coolify | 172.16.10.66 | coolify | `roles/coolify` | https://coolify.viljo.se |

### Collaboration & Productivity

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **55** | Nextcloud | 172.16.10.55 | nextcloud | `roles/nextcloud` | https://nextcloud.viljo.se |
| **56** | Jellyfin | 172.16.10.56 | jellyfin | `roles/jellyfin` | https://jellyfin.viljo.se |
| **57** | Home Assistant | 172.16.10.57 | homeassistant | `roles/homeassistant` | https://ha.viljo.se |

### Utilities & Tools

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **59** | qBittorrent | 172.16.10.59 | qbittorrent | `roles/qbittorrent` | https://qbit.viljo.se |
| **60** | Demo Site | 172.16.10.60 | demosite | `roles/demo_site` | https://demosite.viljo.se |
| **62** | Wazuh | 172.16.10.62 | wazuh | `roles/wazuh` | https://wazuh.viljo.se |
| **64** | OpenMediaVault | 172.16.10.64 | openmediavault | `roles/openmediavault` | https://omv.viljo.se |
| **65** | Zipline | 172.16.10.65 | zipline | `roles/zipline` | https://zipline.viljo.se |
| **90** | WireGuard VPN | 172.16.10.90 | wireguard | `roles/wireguard` | N/A (VPN endpoint) |

## Resource Allocation Summary

| Service | CPU Cores | RAM (MB) | Disk (GB) | Notes |
|---------|-----------|----------|-----------|-------|
| Firewall | 1 | 512 | 8 | Minimal - routing only |
| PostgreSQL | 2 | 2048 | 32 | Shared database |
| Keycloak | 2 | 2048 | 16 | SSO/Authentication |
| NetBox | 2 | 2048 | 32 | Infrastructure docs |
| GitLab | 4 | 8192 | 128 | High resource usage |
| GitLab Runner | 2 | 4096 | 64 | Build executor |
| Coolify | 2 | 4096 | 64 | Self-hosted PaaS |
| Nextcloud | 2 | 4096 | 64 | File storage |
| Jellyfin | 4 | 4096 | 64 | Media streaming |
| Home Assistant | 2 | 2048 | 32 | IoT automation |
| qBittorrent | 2 | 2048 | 128 | Torrent client |
| Demo Site | 1 | 1024 | 8 | Static website |
| Wazuh | 4 | 8192 | 64 | Security monitoring |
| OpenMediaVault | 2 | 2048 | 64 | NAS/Storage |
| Zipline | 2 | 2048 | 32 | Screenshot sharing |
| WireGuard | 1 | 512 | 8 | VPN server |

**Total Resources**: ~37 cores, ~50GB RAM, ~808GB storage

## Configuration Files

Each service has configuration in:
- **Inventory**: `inventory/group_vars/all/<service>.yml`
- **Role**: `roles/<service>/defaults/main.yml`
- **Role README**: `roles/<service>/README.md`

## Network Dependencies

### Firewall (Container 1)
- **Upstream**: vmbr2 (WAN) - DHCP from ISP
- **Downstream**: vmbr3 (DMZ) - 172.16.10.1/24
- **Function**: NAT gateway, port forwarding (80/443 → Traefik)

### Traefik (Not a container)
- **Location**: Runs on Proxmox host
- **Function**: Reverse proxy, TLS termination
- **Upstream**: Firewall (172.16.10.1)
- **Downstream**: All public services on vmbr3

### PostgreSQL (Container 50)
- **Clients**: Keycloak, NetBox, Nextcloud, GitLab (via socket/TCP)

## Service Categories

### Core Infrastructure (Always Running)
- Firewall (1)
- PostgreSQL (50)
- Keycloak (51)

### DevOps Platform
- NetBox (52)
- GitLab (53)
- GitLab Runner (54)
- Coolify (66)

### User Applications
- Nextcloud (55)
- Jellyfin (56)
- Home Assistant (57)

### Utilities
- qBittorrent (59)
- Demo Site (60) - Testing only
- Wazuh (62)
- OpenMediaVault (64)
- Zipline (65)
- WireGuard VPN (90)

## Quick Reference Commands

### List All Containers
```bash
ssh root@192.168.1.3 pct list
```

### Check Specific Container
```bash
ssh root@192.168.1.3 pct status 53  # GitLab
ssh root@192.168.1.3 pct config 53  # Show config
ssh root@192.168.1.3 pct enter 53   # Enter container
```

### Network Testing
```bash
# From Proxmox host
ping 172.16.10.53  # Ping GitLab

# From within a container
ssh root@192.168.1.3 pct exec 53 -- ping -c 2 1.1.1.1
ssh root@192.168.1.3 pct exec 53 -- curl -I https://gitlab.viljo.se
```

## Provisioning Status

| Service | Status | Deployed | Notes |
|---------|--------|----------|-------|
| Firewall | ✅ Deployed | Yes | Production |
| PostgreSQL | ✅ Deployed | Yes | Production |
| Keycloak | ⚠️ Planned | No | Not yet implemented |
| NetBox | ✅ Implemented | No | Role complete, ready for deployment |
| Coolify | ✅ Implemented | No | Role complete, ready for deployment |
| GitLab | ⚠️ Partial | No | Role complete, not deployed |
| GitLab Runner | ⚠️ Planned | No | Depends on GitLab |
| Nextcloud | ⚠️ Planned | No | Not yet implemented |
| Jellyfin | ⚠️ Planned | No | Not yet implemented |
| Home Assistant | ⚠️ Planned | No | Not yet implemented |
| qBittorrent | ⚠️ Planned | No | Not yet implemented |
| Demo Site | ✅ Deployed | Yes | Testing/validation |
| Wazuh | ⚠️ Planned | No | Not yet implemented |
| OpenMediaVault | ⚠️ Planned | No | Not yet implemented |
| Zipline | ⚠️ Planned | No | Not yet implemented |
| WireGuard VPN | ⚠️ Planned | No | Not yet implemented |

## Reserved IP Ranges

- **1-49**: Infrastructure and future core services
- **50-59**: Backend services (databases, auth, etc.)
- **60-89**: User-facing applications
- **90-99**: Network services (VPN, DNS, etc.)

## See Also

- [Network Topology](network-topology.md) - Complete network architecture
- [Firewall Deployment](../deployment/firewall-deployment.md) - Firewall setup guide
- [ADR-002](../adr/002-container-id-standardization.md) - Container ID standardization decision

---

**Last Updated**: 2025-10-20 during project restructure
