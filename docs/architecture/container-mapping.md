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

### Infrastructure Services

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **101** | Firewall | 172.16.10.101 | firewall | `roles/firewall` | N/A (internal router) |
| **150** | PostgreSQL | 172.16.10.150 | postgres | `roles/postgresql` | N/A (internal database) |

### Authentication & Identity

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **151** | Keycloak | 172.16.10.151 | keycloak | `roles/keycloak` | https://keycloak.viljo.se |

### DevOps & Infrastructure

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **152** | NetBox | 172.16.10.152 | netbox | `roles/netbox` | https://netbox.viljo.se |
| **153** | GitLab | 172.16.10.153 | gitlab | `roles/gitlab` | https://gitlab.viljo.se |
| **154** | GitLab Runner | 172.16.10.154 | gitlab-runner | `roles/gitlab_runner` | N/A (internal) |

### Collaboration & Productivity

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **155** | Nextcloud | 172.16.10.155 | nextcloud | `roles/nextcloud` | https://nextcloud.viljo.se |
| **156** | Jellyfin | 172.16.10.156 | jellyfin | `roles/jellyfin` | https://jellyfin.viljo.se |
| **157** | Home Assistant | 172.16.10.157 | homeassistant | `roles/homeassistant` | https://ha.viljo.se |

### Utilities & Tools

| Container ID | Service Name | IP Address | Hostname | Role | Public URL |
|--------------|--------------|------------|----------|------|------------|
| **159** | qBittorrent | 172.16.10.159 | qbittorrent | `roles/qbittorrent` | https://qbit.viljo.se |
| **160** | Demo Site | 172.16.10.160 | demosite | `roles/demo_site` | https://demosite.viljo.se |
| **161** | Cosmos | 172.16.10.161 | cosmos | `roles/cosmos` | https://cosmos.viljo.se |
| **162** | Wazuh | 172.16.10.162 | wazuh | `roles/wazuh` | https://wazuh.viljo.se |
| **164** | OpenMediaVault | 172.16.10.164 | openmediavault | `roles/openmediavault` | https://omv.viljo.se |
| **165** | Zipline | 172.16.10.165 | zipline | `roles/zipline` | https://zipline.viljo.se |
| **190** | WireGuard VPN | 172.16.10.190 | wireguard | `roles/wireguard` | N/A (VPN endpoint) |

## Resource Allocation Summary

| Service | CPU Cores | RAM (MB) | Disk (GB) | Notes |
|---------|-----------|----------|-----------|-------|
| Firewall | 1 | 512 | 8 | Minimal - routing only |
| PostgreSQL | 2 | 2048 | 32 | Shared database |
| Keycloak | 2 | 2048 | 16 | SSO/Authentication |
| NetBox | 2 | 2048 | 32 | Infrastructure docs |
| GitLab | 4 | 8192 | 128 | High resource usage |
| GitLab Runner | 2 | 4096 | 64 | Build executor |
| Nextcloud | 2 | 4096 | 64 | File storage |
| Jellyfin | 4 | 4096 | 64 | Media streaming |
| Home Assistant | 2 | 2048 | 32 | IoT automation |
| qBittorrent | 2 | 2048 | 128 | Torrent client |
| Demo Site | 1 | 1024 | 8 | Static website |
| Cosmos | 2 | 2048 | 32 | Dashboard |
| Wazuh | 4 | 8192 | 64 | Security monitoring |
| OpenMediaVault | 2 | 2048 | 64 | NAS/Storage |
| Zipline | 2 | 2048 | 32 | Screenshot sharing |
| WireGuard | 1 | 512 | 8 | VPN server |

**Total Resources**: ~37 cores, ~48GB RAM, ~776GB storage

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

## Provisioning Status

| Service | Status | Deployed | Notes |
|---------|--------|----------|-------|
| Firewall | ✅ Deployed | Yes | Production |
| PostgreSQL | ✅ Deployed | Yes | Production |
| Keycloak | ⚠️ Planned | No | Not yet implemented |
| NetBox | ⚠️ Planned | No | Not yet implemented |
| GitLab | ⚠️ Partial | No | Role complete, not deployed |
| GitLab Runner | ⚠️ Planned | No | Depends on GitLab |
| Nextcloud | ⚠️ Planned | No | Not yet implemented |
| Jellyfin | ⚠️ Planned | No | Not yet implemented |
| Home Assistant | ⚠️ Planned | No | Not yet implemented |
| qBittorrent | ⚠️ Planned | No | Not yet implemented |
| Demo Site | ✅ Deployed | Yes | Testing/validation |
| Cosmos | ⚠️ Planned | No | Not yet implemented |
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
