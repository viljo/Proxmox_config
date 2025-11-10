# Container and Service Mapping

**Last Updated**: 2025-11-10
**Status**: Reflects actual deployed architecture
**Related**: [Network Topology](network-topology.md) | [ADR-001](../adr/001-network-topology-change.md)

## Architecture Overview

The infrastructure uses a **simplified single-LXC architecture** with Coolify PaaS:

- **1 LXC Container**: Coolify (ID: 200)
- **All services**: Run as Docker containers inside Coolify LXC
- **No individual service LXCs**: Previous multi-container architecture was never deployed
- **No DMZ network**: vmbr3 created but unused

## LXC Container Inventory

| Container ID | Service | Management IP | Public Interface | Status | Purpose |
|--------------|---------|---------------|------------------|--------|---------|
| **200** | Coolify | 192.168.1.200/16 (eth1→vmbr0) | DHCP public IP (eth0→vmbr2) | ✅ Deployed | PaaS platform hosting all services as Docker containers |

### Coolify LXC 200 Details

**Container Type**: Privileged LXC with Docker support
**OS**: Debian-based with Docker Engine
**Network Interfaces**:
- **eth0** → vmbr2 (WAN): Gets public IP via DHCP from ISP - all public service traffic
- **eth1** → vmbr0 (Management): Static IP 192.168.1.200/16 - Ansible API access

**Resource Allocation**:
- **CPU**: Depends on Proxmox host allocation
- **RAM**: Sufficient for Docker engine + all service containers
- **Disk**: LXC root + Docker volumes

**Services Inside Container**:
- Docker Engine
- Coolify API (port 8000 on management interface)
- Coolify Proxy (built-in reverse proxy with SSL)
- All application services (deployed as Docker containers)

## Docker Container Services

All services run as **Docker containers** inside Coolify LXC 200, managed via Coolify API.

### Service Deployment Repository

**Location**: `/coolify_service/ansible`
**Method**: Services deployed via Ansible playbooks that call Coolify API
**API Endpoint**: `http://192.168.1.200:8000/api/v1`

### Service Categories

#### Infrastructure Services
- **Coolify Dashboard**: https://paas.viljo.se
  - Service management interface
  - Deployment dashboard
  - Built-in proxy configuration

#### Application Services (Examples)
Services are deployed dynamically via Coolify API. Check the following for current services:

**Check deployed services**:
```bash
# Via Coolify API
curl -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
  http://192.168.1.200:8000/api/v1/services

# Via Docker in Coolify LXC
ssh root@192.168.1.3 pct exec 200 -- docker ps
```

**Example services** (deployment status may vary):
- Links Portal: https://links.viljo.se
- Media services: https://media.viljo.se
- Cloud storage: https://cloud.viljo.se
- Collaboration tools
- Development tools

**Note**: Services are defined in `/coolify_service/ansible` repository, not in this infrastructure repository.

## Network Configuration

### Proxmox Host
- **IP**: 192.168.1.3/16 on vmbr0
- **Function**: Hypervisor, Ansible control plane
- **Internet Access**: No (management network only)

### Coolify LXC 200 - Management Interface (eth1)
- **Bridge**: vmbr0 (management network)
- **IP**: 192.168.1.200/16 (static)
- **Gateway**: 192.168.1.1
- **Purpose**:
  - Ansible API access
  - Coolify API endpoint
  - Management/monitoring traffic

### Coolify LXC 200 - Public Interface (eth0)
- **Bridge**: vmbr2 (WAN)
- **IP**: DHCP from ISP (dynamic public IP)
- **Purpose**:
  - All public service traffic
  - SSL termination via Coolify Proxy
  - DNS points here (via Loopia DDNS)

### Bridge Status Summary

| Bridge | Network | Purpose | Status | Connected Devices |
|--------|---------|---------|--------|-------------------|
| vmbr0 | 192.168.1.0/16 | Management | Active | Proxmox host (192.168.1.3), Coolify eth1 (192.168.1.200) |
| vmbr2 | DHCP from ISP | WAN/Public | Active | Coolify eth0 (public IP) |
| vmbr3 | 172.16.10.0/24 | Reserved | DOWN | Created but unused, available for future segmentation |

## DNS and Service Discovery

### Loopia DDNS Service

**Script Location**: `/usr/local/lib/loopia-ddns/update.py` (on Proxmox host)
**Systemd Service**: `loopia-ddns.service`
**Systemd Timer**: `loopia-ddns.timer` (every 15 minutes)

**Configuration**:
```python
# Script monitors Coolify LXC 200 eth0 interface (vmbr2)
CONTAINER_ID = 200  # Coolify container
INTERFACE = "eth0"  # Public interface on vmbr2

# Updates all *.viljo.se DNS records to Coolify public IP
```

**Verification**:
```bash
# Check Coolify public IP
ssh root@192.168.1.3 pct exec 200 -- ip -4 addr show eth0 | grep inet

# Check DNS resolution (should match above)
dig +short paas.viljo.se @1.1.1.1
```

### Service Access Patterns

**Public Access** (via vmbr2):
```
Internet → ISP Router (DHCP) → vmbr2 → Coolify eth0 → Coolify Proxy → Docker Container
```

**Management Access** (via vmbr0):
```
Ansible → 192.168.1.3 (Proxmox) → vmbr0 → Coolify eth1 (192.168.1.200) → Coolify API
```

## Comparison: Documented vs Actual

### What Was Documented (But Never Existed)

The previous documentation described a complex architecture that was never deployed:

- ❌ **Firewall LXC (101)**: NAT gateway on vmbr2/vmbr3 - never created
- ❌ **DMZ Network**: Active vmbr3 (172.16.10.0/24) with service containers - never activated
- ❌ **Individual Service LXCs**: 16+ containers with IPs like 172.16.10.X - never created
- ❌ **Traefik on Proxmox**: Reverse proxy on host - never deployed
- ❌ **Complex NAT/Routing**: Port forwarding rules - never configured
- ❌ **PostgreSQL LXC (50)**: Shared database container - never created
- ❌ **Keycloak LXC (51)**: SSO container - never created

**Previous container mapping** (all fictional):
```
Container 1:   Firewall (172.16.10.1)       [NEVER EXISTED]
Container 50:  PostgreSQL (172.16.10.50)    [NEVER EXISTED]
Container 51:  Keycloak (172.16.10.51)      [NEVER EXISTED]
Container 52:  NetBox (172.16.10.52)        [NEVER EXISTED]
Container 53:  GitLab (172.16.10.53)        [NEVER EXISTED]
... (16+ more containers)                   [ALL NEVER EXISTED]
```

### What Actually Exists

**Actual deployed architecture** (as of 2025-11-10):

- ✅ **Coolify LXC (200)**: Single container hosting everything
- ✅ **vmbr2 (WAN)**: Coolify eth0 gets public IP directly
- ✅ **vmbr0 (Management)**: Coolify eth1 for management (192.168.1.200)
- ✅ **vmbr3**: Created but DOWN (interface exists, no active network)
- ✅ **Docker Containers**: All services as containers inside Coolify LXC
- ✅ **Coolify Proxy**: Built-in reverse proxy (replaces Traefik)
- ✅ **Direct Internet Exposure**: No firewall/NAT layer

**Actual container mapping**:
```
Container 200: Coolify PaaS                 [DEPLOYED & ACTIVE]
  ├─ eth0 → vmbr2 (public IP via DHCP)
  ├─ eth1 → vmbr0 (192.168.1.200)
  ├─ Docker Engine
  ├─ Coolify API (port 8000)
  ├─ Coolify Proxy (reverse proxy)
  └─ All services (as Docker containers)
```

## Quick Reference Commands

### Check LXC Container Status
```bash
# List all LXC containers (should only show Coolify 200)
ssh root@192.168.1.3 pct list

# Check Coolify container status
ssh root@192.168.1.3 pct status 200

# Check Coolify container config
ssh root@192.168.1.3 pct config 200

# Enter Coolify container
ssh root@192.168.1.3 pct enter 200
```

### Check Docker Containers
```bash
# List all Docker containers in Coolify
ssh root@192.168.1.3 pct exec 200 -- docker ps

# Check specific service
ssh root@192.168.1.3 pct exec 200 -- docker ps --filter name=SERVICE_NAME

# Check Coolify proxy
ssh root@192.168.1.3 pct exec 200 -- docker ps --filter name=coolify-proxy

# View container logs
ssh root@192.168.1.3 pct exec 200 -- docker logs CONTAINER_NAME
```

### Check Network Interfaces
```bash
# Check Coolify public IP (eth0 on vmbr2)
ssh root@192.168.1.3 pct exec 200 -- ip addr show eth0

# Check Coolify management IP (eth1 on vmbr0)
ssh root@192.168.1.3 pct exec 200 -- ip addr show eth1

# Test internet connectivity from Coolify
ssh root@192.168.1.3 pct exec 200 -- ping -c 2 1.1.1.1

# Test DNS resolution
ssh root@192.168.1.3 pct exec 200 -- dig +short paas.viljo.se
```

### Check Coolify API
```bash
# Check API health (from Proxmox host)
curl -s http://192.168.1.200:8000/health

# List services via API
curl -s -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
  http://192.168.1.200:8000/api/v1/services | jq

# List applications via API
curl -s -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
  http://192.168.1.200:8000/api/v1/applications | jq
```

### Service Deployment
```bash
# Services are deployed via Ansible playbooks in /coolify_service/ansible
cd /path/to/coolify_service/ansible

# Deploy a service
ansible-playbook -i inventory/production.ini \
  playbooks/deploy-SERVICE-via-api.yml \
  --vault-password-file=.vault_pass.txt
```

## Resource Summary

### Current Resource Usage

**Single LXC Container**:
- Coolify LXC 200: Resources allocated via Proxmox LXC configuration

**Docker Containers**: Variable based on deployed services
- Each service runs as Docker container with resources managed by Coolify
- Check current resource usage via Coolify dashboard: https://paas.viljo.se

### Comparison with Previous Documentation

**Old documentation claimed**:
- 37 CPU cores allocated across 16+ LXC containers
- 47GB RAM allocated
- 760GB storage allocated

**Actual reality**:
- 1 LXC container (Coolify 200)
- Resources allocated to single LXC
- Docker containers share resources within Coolify LXC
- More efficient resource usage than multiple LXCs

## Configuration Files

### Infrastructure Configuration
- **Services Inventory**: `inventory/group_vars/all/services.yml`
- **Network Configuration**: `inventory/group_vars/all/main.yml`
- **Coolify Deployment**: `specs/planned/002-docker-platform-selfservice/`

### Service Configuration
- **Service Definitions**: `/coolify_service/ansible/` (separate repository)
- **API Deployment Playbooks**: `/coolify_service/ansible/playbooks/`
- **Service Variables**: `/coolify_service/ansible/inventory/group_vars/`

## Troubleshooting

### Container Not Found
If you see references to containers other than 200:
```bash
# This is expected - only Coolify container exists
ssh root@192.168.1.3 pct list

# You should only see:
# VMID  Status  Name
# 200   running coolify
```

### Service Not Accessible
If a service isn't reachable:
```bash
# 1. Check DNS resolution
dig +short SERVICE.viljo.se @1.1.1.1

# 2. Check Coolify public IP
ssh root@192.168.1.3 pct exec 200 -- ip -4 addr show eth0 | grep inet

# 3. Check if service container is running
ssh root@192.168.1.3 pct exec 200 -- docker ps --filter name=SERVICE_NAME

# 4. Check Coolify proxy
ssh root@192.168.1.3 pct exec 200 -- docker logs coolify-proxy | tail -50
```

### Cannot Access Coolify API
If you cannot reach the Coolify API:
```bash
# 1. Check Coolify management interface
ssh root@192.168.1.3 pct exec 200 -- ip addr show eth1

# 2. Test API from Proxmox host
curl -s http://192.168.1.200:8000/health

# 3. Check Coolify container is running
ssh root@192.168.1.3 pct status 200
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

3. **Move Coolify to DMZ**:
   - Move Coolify eth0 from vmbr2 to vmbr3
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
- [Coolify Deployment Spec](../../specs/planned/002-docker-platform-selfservice/)
- [Infrastructure Status Script](../../scripts/check-infrastructure-status.sh)
- [Services Configuration](../../inventory/group_vars/all/services.yml)

---

**Maintained By**: Infrastructure Team
**Review Schedule**: Monthly
**Next Review**: 2025-12-10
