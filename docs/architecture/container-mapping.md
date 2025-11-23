# Container and Service Mapping

**Last Updated**: 2025-11-23
**Status**: Reflects actual deployed architecture
**Related**: [Network Topology](network-topology.md) | [ADR-001](../adr/001-network-topology-change.md)

## Architecture Overview

The infrastructure uses a **simplified single-LXC architecture**:

- **1 LXC Container**: Containers (ID: 200)
- **All services**: Run as Docker containers managed by Traefik reverse proxy
- **No individual service LXCs**: Previous multi-container architecture was never deployed
- **No DMZ network**: vmbr3 created but unused

## LXC Container Inventory

| Container ID | Service | Management IP | Public Interface | Status | Purpose |
|--------------|---------|---------------|------------------|--------|---------|
| **200** | Containers | 192.168.1.200/16 (eth1→vmbr0) | DHCP public IP (eth0→vmbr2) | ✅ Deployed | Docker host for all application services with Traefik reverse proxy |

### Containers LXC 200 Details

**Container Type**: Privileged LXC with Docker support
**OS**: Debian-based with Docker Engine
**Network Interfaces**:
- **eth0** → vmbr2 (WAN): Gets public IP via DHCP from ISP - all public service traffic
- **eth1** → vmbr0 (Management): Static IP 192.168.1.200/16 - Ansible management access

**Resource Allocation**:
- **CPU**: Depends on Proxmox host allocation
- **RAM**: Sufficient for Docker engine + all service containers
- **Disk**: LXC root + Docker volumes

**Services Inside Container**:
- Docker Engine
- Traefik (reverse proxy with automatic SSL via Let's Encrypt)
- OAuth2-Proxy instances (for SSO-protected services)
- All application services (deployed as Docker containers)

## Docker Container Services

All services run as **Docker containers** inside LXC 200, managed by Traefik reverse proxy.

### Service Deployment

**Method**: Ansible playbooks deploy Docker Compose stacks directly to LXC 200
**Management**: SSH to Proxmox host, then `pct exec 200` commands

### Service Categories

#### Application Services

**Check deployed services**:
```bash
# Via Docker in LXC 200
ssh root@192.168.1.3 pct exec 200 -- docker ps

# Via Traefik dashboard
ssh root@192.168.1.3 pct exec 200 -- docker logs traefik --tail 50
```

**Currently deployed services**:
- **Links Portal**: https://links.viljo.se (landing page)
- **Jitsi Meet**: https://meet.viljo.se (video conferencing)
- **Nextcloud**: https://cloud.viljo.se (file storage)
- **Jellyfin**: https://media.viljo.se (media streaming)
- **qBittorrent**: https://torrent.viljo.se (torrent client)
- **Zipline**: https://zipline.viljo.se (file sharing)
- **Webtop**: https://webtop.viljo.se (browser desktop - SSO)
- **Mailhog**: https://mail.viljo.se (email testing - SSO)

**Service configuration**: See `inventory/group_vars/all/services.yml`

## Network Configuration

### Proxmox Host
- **IP**: 192.168.1.3/16 on vmbr0
- **Function**: Hypervisor, Ansible control plane
- **Internet Access**: No (management network only)

### Containers LXC 200 - Management Interface (eth1)
- **Bridge**: vmbr0 (management network)
- **IP**: 192.168.1.200/16 (static)
- **Gateway**: 192.168.1.1
- **Purpose**:
  - Ansible management access
  - SSH administration
  - Management/monitoring traffic

### Containers LXC 200 - Public Interface (eth0)
- **Bridge**: vmbr2 (WAN)
- **IP**: DHCP from ISP (dynamic public IP)
- **Purpose**:
  - All public service traffic
  - SSL termination via Traefik
  - DNS points here (via Loopia DDNS)

### Bridge Status Summary

| Bridge | Network | Purpose | Status | Connected Devices |
|--------|---------|---------|--------|-------------------|
| vmbr0 | 192.168.1.0/16 | Management | Active | Proxmox host (192.168.1.3), Containers eth1 (192.168.1.200) |
| vmbr2 | DHCP from ISP | WAN/Public | Active | Containers eth0 (public IP) |
| vmbr3 | 172.16.10.0/24 | Reserved | DOWN | Created but unused, available for future segmentation |

## DNS and Service Discovery

### Loopia DDNS Service

**Script Location**: `/usr/local/lib/loopia-ddns/update.py` (on Proxmox host)
**Systemd Service**: `loopia-ddns.service`
**Systemd Timer**: `loopia-ddns.timer` (every 15 minutes)

**Configuration**:
```python
# Script monitors Containers LXC 200 eth0 interface (vmbr2)
CONTAINER_ID = 200  # Containers LXC
INTERFACE = "eth0"  # Public interface on vmbr2

# Updates all *.viljo.se DNS records to LXC 200 public IP
```

**Verification**:
```bash
# Check LXC 200 public IP
ssh root@192.168.1.3 pct exec 200 -- ip -4 addr show eth0 | grep inet

# Check DNS resolution (should match above)
dig +short links.viljo.se @1.1.1.1
```

### Service Access Patterns

**Public Access** (via vmbr2):
```
Internet → ISP Router (DHCP) → vmbr2 → LXC 200 eth0 → Traefik → Docker Container
```

**Management Access** (via vmbr0):
```
Ansible → 192.168.1.3 (Proxmox) → vmbr0 → LXC 200 eth1 (192.168.1.200) → Docker/SSH
```

## Comparison: Documented vs Actual

### What Was Documented (But Never Existed)

The previous documentation described a complex architecture that was never deployed:

- ❌ **Firewall LXC (101)**: NAT gateway on vmbr2/vmbr3 - never created
- ❌ **DMZ Network**: Active vmbr3 (172.16.10.0/24) with service containers - never activated
- ❌ **Individual Service LXCs**: 16+ containers with IPs like 172.16.10.X - never created
- ❌ **Traefik on Proxmox**: Reverse proxy on host - never deployed
- ❌ **Complex NAT/Routing**: Port forwarding rules - never configured

**Previous container mapping** (all fictional):
```
Container 1:   Firewall (172.16.10.1)       [NEVER EXISTED]
Container 50:  PostgreSQL (172.16.10.50)    [NEVER EXISTED]
Container 53:  GitLab (172.16.10.53)        [NEVER EXISTED]
... (16+ more containers)                   [ALL NEVER EXISTED]
```

### What Actually Exists

**Actual deployed architecture** (as of 2025-11-10):

- ✅ **Containers LXC (200)**: Single container hosting everything
- ✅ **vmbr2 (WAN)**: LXC 200 eth0 gets public IP directly
- ✅ **vmbr0 (Management)**: LXC 200 eth1 for management (192.168.1.200)
- ✅ **vmbr3**: Created but DOWN (interface exists, no active network)
- ✅ **Docker Containers**: All services as containers inside LXC 200
- ✅ **Traefik**: Reverse proxy with automatic SSL
- ✅ **Direct Internet Exposure**: No firewall/NAT layer

**Actual container mapping**:
```
Container 200: Containers (Docker Host)    [DEPLOYED & ACTIVE]
  ├─ eth0 → vmbr2 (public IP via DHCP)
  ├─ eth1 → vmbr0 (192.168.1.200)
  ├─ Docker Engine
  ├─ Traefik (reverse proxy)
  ├─ OAuth2-Proxy instances
  └─ All application services (as Docker containers)
```

## Quick Reference Commands

### Check LXC Container Status
```bash
# List all LXC containers (should only show Containers 200)
ssh root@192.168.1.3 pct list

# Check Containers LXC status
ssh root@192.168.1.3 pct status 200

# Check Containers LXC config
ssh root@192.168.1.3 pct config 200

# Enter Containers LXC
ssh root@192.168.1.3 pct enter 200
```

### Check Docker Containers
```bash
# List all Docker containers in LXC 200
ssh root@192.168.1.3 pct exec 200 -- docker ps

# Check specific service
ssh root@192.168.1.3 pct exec 200 -- docker ps --filter name=SERVICE_NAME

# Check Traefik reverse proxy
ssh root@192.168.1.3 pct exec 200 -- docker ps --filter name=traefik

# View container logs
ssh root@192.168.1.3 pct exec 200 -- docker logs CONTAINER_NAME
```

### Check Network Interfaces
```bash
# Check LXC 200 public IP (eth0 on vmbr2)
ssh root@192.168.1.3 pct exec 200 -- ip addr show eth0

# Check LXC 200 management IP (eth1 on vmbr0)
ssh root@192.168.1.3 pct exec 200 -- ip addr show eth1

# Test internet connectivity from LXC 200
ssh root@192.168.1.3 pct exec 200 -- ping -c 2 1.1.1.1

# Test DNS resolution
ssh root@192.168.1.3 pct exec 200 -- dig +short links.viljo.se
```

### Check Traefik Reverse Proxy
```bash
# Check Traefik status
ssh root@192.168.1.3 pct exec 200 -- docker ps --filter name=traefik

# View Traefik logs
ssh root@192.168.1.3 pct exec 200 -- docker logs traefik --tail 50

# Check Traefik routing
ssh root@192.168.1.3 pct exec 200 -- docker exec traefik cat /etc/traefik/traefik.yml
```

### Service Deployment
```bash
# Services are deployed via Ansible playbooks in this repository
cd /path/to/Proxmox_config

# Deploy media services
ansible-playbook playbooks/media-services-deploy.yml

# Deploy OAuth2-Proxy SSO
ansible-playbook playbooks/oauth2-proxy-deploy.yml
```

## Resource Summary

### Current Resource Usage

**Single LXC Container**:
- Containers LXC 200: Resources allocated via Proxmox LXC configuration

**Docker Containers**: Variable based on deployed services
- Each service runs as Docker container within LXC 200
- Check current resource usage via `docker stats` or Proxmox web UI

### Comparison with Previous Documentation

**Old documentation claimed**:
- 37 CPU cores allocated across 16+ LXC containers
- 47GB RAM allocated
- 760GB storage allocated

**Actual reality**:
- 1 LXC container (Containers 200)
- Resources allocated to single LXC
- Docker containers share resources within LXC 200
- More efficient resource usage than multiple LXCs

## Configuration Files

### Infrastructure Configuration
- **Services Inventory**: `inventory/group_vars/all/services.yml`
- **Network Configuration**: `inventory/group_vars/all/main.yml`
- **Service Roles**: `roles/` (Jellyfin, qBittorrent, OAuth2-Proxy, etc.)

### Service Configuration
- **Ansible Playbooks**: `playbooks/` (media-services-deploy.yml, oauth2-proxy-deploy.yml, etc.)
- **Service Variables**: `inventory/group_vars/all/`
- **Ansible Roles**: `roles/` (service-specific deployment logic)

## Troubleshooting

### Container Not Found
If you see references to containers other than 200:
```bash
# This is expected - only Containers LXC exists
ssh root@192.168.1.3 pct list

# You should only see:
# VMID  Status  Name
# 200   running containers
```

### Service Not Accessible
If a service isn't reachable:
```bash
# 1. Check DNS resolution
dig +short SERVICE.viljo.se @1.1.1.1

# 2. Check LXC 200 public IP
ssh root@192.168.1.3 pct exec 200 -- ip -4 addr show eth0 | grep inet

# 3. Check if service container is running
ssh root@192.168.1.3 pct exec 200 -- docker ps --filter name=SERVICE_NAME

# 4. Check Traefik reverse proxy
ssh root@192.168.1.3 pct exec 200 -- docker logs traefik | tail -50
```

### Cannot Access Services
If you cannot reach services:
```bash
# 1. Check LXC 200 is running
ssh root@192.168.1.3 pct status 200

# 2. Check Traefik is running
ssh root@192.168.1.3 pct exec 200 -- docker ps --filter name=traefik

# 3. Check service containers
ssh root@192.168.1.3 pct exec 200 -- docker ps
```

## Migration Notes

### If You Need Multi-Container Architecture

If future requirements demand network segmentation or firewall layer:

1. **Activate vmbr3**:
   - Bring up vmbr3 interface on Proxmox
   - Configure 172.16.10.0/24 network

2. **Create Firewall LXC**:
   - Deploy container 101 with eth0→vmbr2, eth1→vmbr3
   - Configure NAT/routing

3. **Move LXC 200 to DMZ**:
   - Move LXC 200 eth0 from vmbr2 to vmbr3
   - Assign static IP 172.16.10.200
   - Update routing through firewall

4. **Update DDNS**:
   - Change DDNS script to monitor firewall container (101) eth0
   - Update DNS to point to firewall public IP

5. **Update Documentation**:
   - Update all references to network topology
   - Document firewall rules and NAT configuration

## See Also

- [Network Topology](network-topology.md) - Complete network architecture
- [ADR-001: Network Architecture Decision](../adr/001-network-topology-change.md)
- [Infrastructure Status Script](../../scripts/check-infrastructure-status.sh)
- [Services Configuration](../../inventory/group_vars/all/services.yml)

---

**Maintained By**: Infrastructure Team
**Review Schedule**: Monthly
**Next Review**: 2025-12-10
