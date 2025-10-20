# ADR-001: Network Topology Redesign (vmbr1 → vmbr2/vmbr3)

**Status**: Implemented
**Date**: 2025-10-19
**Decision Makers**: Infrastructure Team
**Related**: [Network Topology Documentation](../architecture/network-topology.md)

## Context

The original network design used `vmbr0` for management and attempted to use `vmbr1` for WAN/DMZ purposes. This created several issues:

1. **vmbr1 Configuration Issues**: The bridge had connectivity problems and DHCP lease issues
2. **Unclear Separation**: No clear distinction between WAN uplink and DMZ network
3. **Routing Complexity**: Difficult to manage NAT and routing with a single bridge
4. **Legacy Naming**: vmbr1 was a holdover from previous design iterations

## Decision

Redesign the network topology to use three distinct bridges:

| Bridge | Network | Purpose | Device |
|--------|---------|---------|--------|
| **vmbr0** | 192.168.1.0/24 | Management | Proxmox host management IP |
| **vmbr2** | DHCP (ISP) | WAN Uplink | Firewall external interface |
| **vmbr3** | 172.16.10.0/24 | Service DMZ | All application containers |

### Traffic Flow

```
Internet
   ↓
vmbr2 (WAN) - Firewall Container eth0 (DHCP)
   ↓
Firewall NAT/Routing
   ↓
vmbr3 (DMZ) - Firewall Container eth1 (172.16.10.1)
   ↓
All Services (172.16.10.50-90)
```

### Key Changes

1. **vmbr2 (WAN)**: Dedicated bridge for ISP connection via DHCP
   - Connected to firewall container `eth0`
   - Gets public IP from ISP
   - No other containers attached

2. **vmbr3 (DMZ)**: Internal network for all services
   - Static addressing: 172.16.10.0/24
   - Gateway: 172.16.10.1 (firewall container `eth1`)
   - DNS: 172.16.10.1, 1.1.1.1
   - All 16 service containers connected here

3. **vmbr0 (Management)**: Remains unchanged
   - Proxmox host at 192.168.1.3
   - Management access only
   - No production containers

4. **vmbr1**: Decommissioned
   - No longer in use
   - Can be removed if fully deprecated

## Rationale

### Separation of Concerns
- **WAN (vmbr2)**: Handles only external internet connectivity
- **DMZ (vmbr3)**: Isolated internal network for services
- **Management (vmbr0)**: Proxmox administration separate from services

### Security Benefits
- Services not directly exposed to internet
- All internet traffic routed through firewall container
- Firewall provides NAT masquerading and port forwarding
- Clear network boundaries for firewall rules

### Simplicity
- Each bridge has one clear purpose
- Easier to reason about traffic flows
- Simplified troubleshooting
- Standard enterprise network design pattern

### Scalability
- Easy to add new services to vmbr3
- Gateway (172.16.10.1) is single point for routing decisions
- Can easily add VLANs or additional networks later

## Implementation

### Firewall Container Configuration

**Container ID**: 1
**Interfaces**:
- `eth0` → `vmbr2` (DHCP from ISP)
- `eth1` → `vmbr3` (172.16.10.1/24)

**nftables Configuration**:
```nft
# NAT masquerading for DMZ → WAN
table ip nat {
    chain postrouting {
        type nat hook postrouting priority srcnat;
        ip saddr 172.16.10.0/24 oifname "eth0" masquerade
    }

    chain prerouting {
        type nat hook prerouting priority dstnat;
        iifname "eth0" tcp dport 80 dnat to 172.16.10.1:80
        iifname "eth0" tcp dport 443 dnat to 172.16.10.1:443
    }
}
```

### Service Container Configuration

All services configured with:
- **Bridge**: vmbr3
- **IP**: 172.16.10.{container_id}
- **Gateway**: 172.16.10.1
- **DNS**: 172.16.10.1, 1.1.1.1

### DNS Configuration

Loopia DDNS service monitors firewall WAN IP (vmbr2 interface) and updates DNS records:
- Runs on Proxmox host as systemd timer (every 15 minutes)
- Updates viljo.se and *.viljo.se to point to current WAN IP
- Uses Loopia API with credentials from Ansible Vault

## Consequences

### Positive
- ✅ Clear network architecture
- ✅ Improved security (NAT isolation)
- ✅ Easier troubleshooting
- ✅ Standard design pattern
- ✅ Better separation of management and production traffic
- ✅ Firewall is single egress point (easier to monitor/control)

### Negative
- ⚠️ All services depend on firewall container health
- ⚠️ Firewall is single point of failure for internet access
- ⚠️ All internet traffic through one container (potential bottleneck)
- ⚠️ Required migration of existing containers

### Neutral
- 🔵 Existing containers needed to be destroyed and recreated
- 🔵 All service configurations updated to use new network
- 🔵 Documentation updated to reflect new topology

## Migration Impact

### Affected Components
- All 16 service containers (destroyed and recreated)
- Firewall role (completely redesigned)
- Network role (updated for new bridges)
- DMZ cleanup role (updated for new IPs)
- All service inventory files (updated)

### Migration Steps Taken
1. Created backup of all configurations
2. Documented existing state
3. Created firewall role for new topology
4. Updated all inventory files with new IPs
5. Created `dmz-rebuild.yml` playbook
6. Destroyed old containers
7. Deployed new containers with new network config
8. Verified connectivity
9. Updated Loopia DDNS to monitor new WAN interface

## Alternatives Considered

### Alternative 1: Single Bridge for WAN+DMZ
Keep vmbr1 but use VLANs to separate WAN and DMZ.

**Rejected because**:
- More complex configuration
- vmbr1 had persistent issues
- Harder to troubleshoot
- Less clear separation

### Alternative 2: Direct WAN Access per Container
Give each service container its own WAN interface.

**Rejected because**:
- Security risk (services directly exposed)
- Would require many public IPs
- Harder to manage firewall rules
- Inconsistent with security best practices

### Alternative 3: Keep vmbr1, Fix Issues
Debug and fix vmbr1 instead of replacing it.

**Rejected because**:
- Root cause unclear
- Opportunity to improve architecture
- Clean slate easier than fixing unknown issues
- New design more maintainable

## References

- [Network Topology Documentation](../architecture/network-topology.md)
- [Firewall Deployment Guide](../deployment/firewall-deployment.md)
- Original discussion: Git commit history around Oct 18-19, 2025
- Ansible role: `roles/firewall/`
- Inventory: `inventory/group_vars/all/firewall.yml`

## Status History

- **2025-10-18**: vmbr1 connectivity issues identified
- **2025-10-19**: Decision made to redesign network
- **2025-10-19**: Implementation completed
- **2025-10-20**: Documentation created

---

**Last Updated**: 2025-10-20
**Next Review**: 2025-11-20 (1 month)
