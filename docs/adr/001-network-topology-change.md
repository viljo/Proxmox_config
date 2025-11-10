# ADR-001: Simplified Network Architecture with Coolify PaaS

**Status**: Implemented
**Date**: 2025-10-19 (Updated: 2025-11-10)
**Decision Makers**: Infrastructure Team
**Related**: [Network Topology Documentation](../architecture/network-topology.md)

## Context

The original network design used `vmbr0` for management and attempted to use `vmbr1` for WAN/DMZ purposes. This created several issues:

1. **vmbr1 Configuration Issues**: The bridge had connectivity problems and DHCP lease issues
2. **Complexity**: Managing multiple LXC containers with firewall/NAT/DMZ layers
3. **Maintenance Overhead**: Each service required separate LXC container deployment
4. **Routing Complexity**: Difficult to manage NAT and routing with multiple containers

## Decision

Implement a simplified network topology using Coolify PaaS platform in a single LXC container:

| Bridge | Network | Purpose | Connected Devices |
|--------|---------|---------|-------------------|
| **vmbr0** | 192.168.1.0/16 | Management | Proxmox host (192.168.1.3), Coolify management (192.168.1.200) |
| **vmbr2** | DHCP (ISP) | WAN/Public | Coolify LXC public interface |
| **vmbr3** | N/A (unused) | Reserved | Created but DOWN, available for future use |

### Traffic Flow

```
Internet
   ↓
vmbr2 (WAN) - Coolify LXC eth0 (Public IP via DHCP)
   ↓
Coolify Proxy (Built-in reverse proxy with SSL)
   ↓
Docker Containers (Services managed via Coolify API)

Management:
vmbr0 (192.168.1.0/16) - Coolify LXC eth1 (192.168.1.200)
   ↑
Ansible deployments via API
```

### Key Changes from Original Design

**Actual Implementation (as of 2025-11-10)**:

1. **vmbr0 (Management)**: Internal management network
   - Proxmox host: 192.168.1.3/16
   - Coolify LXC eth1: 192.168.1.200/16
   - Used for Ansible API access to Coolify

2. **vmbr2 (WAN)**: Direct public internet access
   - Coolify LXC eth0: Gets public IP via DHCP from ISP
   - **No firewall container** - Coolify directly exposed
   - All services accessible through this interface

3. **vmbr3**: Created but unused
   - Interface exists on Proxmox host but is DOWN (no carrier)
   - Originally planned as DMZ but never implemented
   - Reserved for future segmentation if needed

4. **vmbr1**: Never existed in current deployment

5. **Single Container Architecture**:
   - **Only one LXC container**: Coolify (ID: 200)
   - All services run as Docker containers inside Coolify LXC
   - Services managed via Coolify API (not individual LXCs)
   - Coolify provides built-in reverse proxy (replaces Traefik)

## Rationale

### Simplicity Over Complexity
- **Single LXC Container**: All services consolidated in Coolify
- **No Firewall Container**: Direct internet access reduces hop complexity
- **No DMZ Network**: Unnecessary with single-container architecture
- **API-Driven**: Services deployed via Coolify API using Ansible

### Operational Benefits
- **Unified Management**: Single Coolify interface for all services
- **Easier Deployment**: Services deployed via API calls, not LXC creation
- **Built-in Proxy**: Coolify proxy handles SSL, routing, and load balancing
- **Automatic SSL**: Let's Encrypt integration via Coolify
- **Resource Efficiency**: Docker containers more lightweight than LXC

### Trade-offs Accepted
- **Security**: Services directly exposed to internet (no firewall layer)
  - Mitigated by: Coolify proxy security, Docker network isolation, application-level security
- **Single Point of Failure**: All services in one LXC
  - Mitigated by: Docker container isolation, Ansible-based reproducibility
- **No Network Segmentation**: vmbr3 unused
  - Acceptable: Can be activated later if needed

## Implementation

### Coolify LXC Configuration

**Container ID**: 200
**Interfaces**:
- `eth0` → `vmbr2` (DHCP public IP from ISP)
- `eth1` → `vmbr0` (192.168.1.200/16 static)

**Docker Engine**: Running inside LXC
**Coolify Proxy**: Built-in reverse proxy container
**Service Management**: Via Coolify API (port 8000)

### Service Deployment Pattern

All services deployed as Docker containers via Coolify API:
```yaml
# Example: Deploy service via API
- name: Deploy service to Coolify
  uri:
    url: "http://192.168.1.200:8000/api/v1/services"
    method: POST
    headers:
      Authorization: "Bearer {{ coolify_api_token }}"
    body_format: json
    body:
      name: "service-name"
      fqdn: "service.viljo.se"
      docker_compose: "{{ docker_compose_content }}"
```

### DNS Configuration

Loopia DDNS service monitors Coolify WAN IP and updates DNS records:
- Runs on Proxmox host as systemd timer (every 15 minutes)
- Updates viljo.se and *.viljo.se to point to Coolify public IP
- Uses Loopia API with credentials from Ansible Vault

## Consequences

### Positive
- ✅ **Massive Simplification**: 16+ LXC containers reduced to 1
- ✅ **Faster Deployments**: API-driven vs manual LXC provisioning
- ✅ **Better Resource Usage**: Docker containers share kernel
- ✅ **Modern PaaS**: Coolify provides Heroku-like experience
- ✅ **Built-in Observability**: Coolify dashboard for all services
- ✅ **Automatic SSL**: Let's Encrypt certificates managed by Coolify
- ✅ **Easy Rollbacks**: Docker image versioning

### Negative
- ⚠️ **Direct Internet Exposure**: No firewall/NAT layer
- ⚠️ **Single LXC Container**: All services in one failure domain
- ⚠️ **Less Network Isolation**: No DMZ segmentation
- ⚠️ **Coolify Dependency**: Locked into Coolify ecosystem

### Neutral
- 🔵 **vmbr3 Unused**: Created but not active (future use possible)
- 🔵 **Different Paradigm**: Infrastructure-as-code via API instead of Ansible LXC roles
- 🔵 **Documentation Shift**: Focus on Coolify API instead of container networking

## Current State (2025-11-10)

### Active Infrastructure
- **Proxmox Host**: 192.168.1.3 (vmbr0)
- **Coolify LXC 200**:
  - eth0 → vmbr2 (public IP via DHCP)
  - eth1 → vmbr0 (192.168.1.200)
- **Services**: All deployed as Docker containers inside Coolify
- **Proxy**: Coolify built-in proxy (replaces Traefik)

### Removed Components
- ❌ Firewall container (never deployed)
- ❌ Individual service LXC containers (replaced by Docker containers)
- ❌ Traefik (replaced by Coolify proxy)
- ❌ DMZ network on vmbr3 (unused)

## Alternatives Considered

### Alternative 1: Firewall + DMZ Architecture
Deploy firewall container with NAT/routing to DMZ network on vmbr3.

**Rejected because**:
- Adds complexity without clear benefit
- Requires maintaining firewall rules
- Extra network hop increases latency
- Coolify proxy provides sufficient security
- Single public IP doesn't benefit from NAT

### Alternative 2: Multiple LXC Containers
Deploy each service in separate LXC container.

**Rejected because**:
- Maintenance overhead (16+ containers)
- Resource inefficiency (full OS per service)
- Complex networking setup
- Slower deployments
- Coolify PaaS provides better developer experience

### Alternative 3: Use vmbr3 as DMZ
Activate vmbr3 and move Coolify to DMZ behind firewall.

**Rejected for now because**:
- Adds complexity without immediate benefit
- Current setup working well
- Can be implemented later if security requirements change
- vmbr3 remains available for future use

## References

- [Network Topology Documentation](../architecture/network-topology.md)
- [Coolify Deployment Spec](../../specs/planned/002-docker-platform-selfservice)
- Original discussion: Git commit history around Oct 18-19, 2025
- Coolify LXC deployment: Commit 7a1004a (2025-11-10)
- Inventory: `inventory/group_vars/all/main.yml`
- Services: `inventory/group_vars/all/services.yml`

## Status History

- **2025-10-18**: vmbr1 connectivity issues identified
- **2025-10-19**: Decision made to adopt Coolify PaaS approach
- **2025-10-19**: Coolify LXC deployed with simplified network
- **2025-10-20**: Initial documentation created
- **2025-11-10**: Documentation updated to reflect actual implementation

---

**Last Updated**: 2025-11-10
**Next Review**: 2025-12-10 (1 month)
