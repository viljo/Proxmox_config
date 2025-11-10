# Network Topology - Simplified Coolify Architecture

**Last Updated**: 2025-11-10
**Status**: Accurate as of deployment
**Related**: [ADR-001: Network Architecture](../adr/001-network-topology-change.md) | [NETWORK_ARCHITECTURE.md](../NETWORK_ARCHITECTURE.md)

## Overview

The infrastructure uses a simplified network topology with Coolify PaaS managing all services in Docker containers within a single LXC container. This eliminates the complexity of multiple LXC containers, firewall/NAT layers, and DMZ networks.

## Bridge Configuration

| Bridge | Network | Purpose | Status | Connected Devices |
|--------|---------|---------|--------|-------------------|
| **vmbr0** | 192.168.1.0/16 | Management | Active | Proxmox host (192.168.1.3), Coolify LXC management interface (192.168.1.200) |
| **vmbr2** | DHCP from ISP | WAN/Public Internet | Active | Coolify LXC public interface (DHCP public IP) |
| **vmbr3** | 172.16.10.0/24 | Reserved (unused) | DOWN | Created but not active, available for future segmentation |

## Network Flow

```
                           Internet
                              ↓
                      ISP Router (DHCP)
                              ↓
                    ┌─────────────────────┐
                    │   vmbr2 (WAN)       │
                    │   Bridge on Proxmox │
                    └──────────┬──────────┘
                              ↓
              ┌───────────────────────────────┐
              │   Coolify LXC 200 (eth0)      │
              │   Public IP via DHCP          │
              │                               │
              │  ┌─────────────────────────┐  │
              │  │   Coolify Proxy         │  │
              │  │   (Built-in reverse     │  │
              │  │    proxy with SSL)      │  │
              │  └───────────┬─────────────┘  │
              │              ↓                 │
              │  ┌─────────────────────────┐  │
              │  │   Docker Containers     │  │
              │  │   (All services)        │  │
              │  └─────────────────────────┘  │
              └───────────────┬───────────────┘
                              │
                    Coolify LXC 200 (eth1)
                    192.168.1.200/16
                              ↓
                    ┌─────────────────────┐
                    │   vmbr0 (Management)│
                    │   192.168.1.0/16    │
                    └──────────┬──────────┘
                              ↓
                    Proxmox Host (192.168.1.3)
                    Ansible API Access
```

## Architecture Details

### Proxmox Host
- **IP Address**: 192.168.1.3/16 on vmbr0
- **Purpose**: Hypervisor management, Ansible control plane
- **Network**: Management only (vmbr0)

### Coolify LXC Container (ID: 200)
- **Container Type**: Privileged LXC with Docker support
- **Interfaces**:
  - **eth0** → vmbr2: Public IP via DHCP from ISP
  - **eth1** → vmbr0: Static IP 192.168.1.200/16 for management
- **Services**:
  - Docker Engine
  - Coolify API (port 8000 on management interface)
  - Coolify Proxy (built-in reverse proxy, replaces Traefik)
  - All application services as Docker containers

### Service Architecture

**No individual LXC containers** - all services run as Docker containers inside Coolify LXC:
- Coolify manages container lifecycle via API
- Coolify Proxy handles SSL termination and routing
- Services deployed via Ansible playbooks calling Coolify API
- Service definitions in separate repository: `/coolify_service/ansible`

## DNS Configuration

### Loopia DDNS Service

**Script Location**: `/usr/local/lib/loopia-ddns/update.py`
**Update Frequency**: Every 15 minutes (systemd timer)
**IP Source**: Coolify LXC 200 eth0 interface on vmbr2
**DNS Records**: All *.viljo.se subdomains point to Coolify public IP

**How It Works**:
```python
# Script reads public IP from Coolify LXC eth0 (vmbr2)
CONTAINER_ID = 200  # Coolify container
INTERFACE = "eth0"  # Public interface on vmbr2

# Get current public IP
ip_output = subprocess.check_output([
    "pct", "exec", str(CONTAINER_ID), "--",
    "ip", "-4", "-o", "addr", "show", "dev", INTERFACE
])
current_ip = ip_output.split()[3].split('/')[0]

# Update all DNS records to this IP via Loopia API
```

**Verification**:
```bash
# Check Coolify public IP (should match DNS)
pct exec 200 -- ip -4 addr show eth0 | grep inet

# Check DNS resolution (should match above)
dig +short paas.viljo.se @1.1.1.1
```

## Key Architectural Decisions

### Why This Design?

**Simplification Over Complexity**:
- **Before**: 16+ LXC containers, firewall LXC, DMZ network, complex NAT/routing
- **After**: 1 LXC container (Coolify), all services as Docker containers
- **Result**: Easier management, faster deployments, lower resource usage

**Direct Internet Exposure**:
- Coolify LXC directly receives public IP on vmbr2
- No firewall/NAT layer (firewall container never deployed)
- Security provided by:
  - Coolify Proxy (reverse proxy with SSL)
  - Docker network isolation
  - Application-level security
  - Proxmox host firewall (if configured)

**vmbr3 Unused**:
- Created during initial planning but never activated
- Interface exists on Proxmox but is DOWN (no carrier)
- Reserved for future network segmentation if needed
- Not currently part of traffic flow

## Service Management

### Deployment Method

Services are deployed via Ansible playbooks that call the Coolify API:

```yaml
# Example: Deploy service to Coolify
- name: Create service in Coolify
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

### Service Discovery

All services accessible via:
- **Public**: https://service.viljo.se (via vmbr2 public IP)
- **Coolify Dashboard**: https://paas.viljo.se
- **Coolify API**: http://192.168.1.200:8000/api/v1 (management network)

## Comparison with Documented vs Actual

### What Documentation Described (But Never Existed)

- Firewall LXC 101 on vmbr2/vmbr3
- DMZ network on vmbr3 (172.16.10.0/24)
- NAT/routing between vmbr2 and vmbr3
- Traefik running on Proxmox host
- 16+ individual service LXC containers on vmbr3
- Port forwarding rules (80/443 → Traefik)

### What Actually Exists

- Coolify LXC 200 with eth0 on vmbr2 (public IP)
- Coolify LXC 200 with eth1 on vmbr0 (management IP)
- vmbr3 created but DOWN/unused
- Coolify Proxy (built-in, replaces Traefik)
- All services as Docker containers inside Coolify LXC
- No firewall container, no DMZ, no NAT layer

## Troubleshooting

### Check Coolify Public IP
```bash
# From Proxmox host
pct exec 200 -- ip addr show eth0

# Should show public IP from ISP DHCP
```

### Check Coolify Management IP
```bash
# From Proxmox host
pct exec 200 -- ip addr show eth1

# Should show 192.168.1.200/16
```

### Check Docker Containers
```bash
# List all running containers
pct exec 200 -- docker ps

# Check Coolify proxy
pct exec 200 -- docker ps --filter name=coolify-proxy
```

### Check DNS Resolution
```bash
# From Proxmox or any machine
dig +short paas.viljo.se @1.1.1.1

# Should match Coolify public IP on eth0
```

### Check Coolify API
```bash
# From Proxmox host
curl -s http://192.168.1.200:8000/health

# Should return {"status": "ok"}
```

## Security Considerations

### Current Security Model

**Positive Security Controls**:
- Docker network isolation between containers
- Coolify Proxy SSL termination (Let's Encrypt)
- Application-level authentication
- Ansible Vault for secrets management
- SSH key-based authentication only

**Known Trade-offs**:
- **No firewall/NAT layer**: Coolify directly exposed to internet
  - Acceptable: Single public IP, application security sufficient
- **Single LXC container**: All services in one failure domain
  - Mitigated: Docker container isolation, quick Ansible-based recovery
- **No network segmentation**: vmbr3 unused
  - Acceptable: Can be activated later if requirements change

### Future Hardening Options

If security requirements change:
1. **Activate vmbr3**: Move Coolify eth0 to vmbr3, create firewall LXC
2. **Add firewall rules**: Configure Proxmox host firewall
3. **Implement fail2ban**: Rate limiting on Coolify LXC
4. **Network segmentation**: Separate Docker networks per service type

## Migration Notes

### From Documented to Actual (This Update)

- Removed references to firewall LXC 101
- Removed references to vmbr3 DMZ network usage
- Removed references to Traefik on Proxmox host
- Updated DDNS script references (container 101 → 200)
- Updated to reflect Coolify PaaS architecture
- Documented vmbr3 as unused/reserved

### For Future Migrations

If implementing firewall/DMZ architecture:
1. Create firewall LXC with eth0→vmbr2, eth1→vmbr3
2. Move Coolify LXC eth0 from vmbr2 to vmbr3
3. Configure NAT/routing on firewall LXC
4. Update DDNS to monitor firewall WAN IP
5. Update DNS to point to firewall public IP

## References

- [ADR-001: Network Architecture Decision](../adr/001-network-topology-change.md)
- [Coolify Deployment Spec](../../specs/planned/002-docker-platform-selfservice)
- [Infrastructure Status Script](../../scripts/check-infrastructure-status.sh)
- [Services Configuration](../../inventory/group_vars/all/services.yml)
- [Main Configuration](../../inventory/group_vars/all/main.yml)

---

**Maintained By**: Infrastructure Team
**Review Schedule**: Monthly
**Next Review**: 2025-12-10
