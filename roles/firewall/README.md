# Role: firewall

## Purpose

Deploys and configures a dual-homed LXC firewall container that routes traffic between WAN and DMZ networks on Proxmox VE infrastructure.

**Key Functions:**
- NAT gateway for DMZ services (172.16.10.0/24)
- Port forwarding (80/443) to Traefik reverse proxy
- DHCP client on WAN interface
- nftables-based packet filtering and NAT

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `firewall_container_id` | `101` | Proxmox container ID (IP .1 + 100) |
| `firewall_wan_interface` | `eth0` | WAN interface connected to vmbr2 |
| `firewall_lan_interface` | `eth1` | DMZ interface connected to vmbr3 |
| `firewall_wan_ip_config` | `dhcp` | WAN IP configuration (dhcp or static) |
| `firewall_lan_ip_address` | `{{ dmz_gateway }}` | DMZ gateway IP (172.16.10.1) |
| `firewall_forward_services` | See defaults | Services to forward from WAN to DMZ |
| `firewall_allow_management_ports` | `[22]` | Ports to allow from WAN for management |

### Critical NAT Configuration

**⚠️ IMPORTANT**: The firewall uses **SNAT (masquerade)** for WAN→DMZ traffic to ensure replies route back correctly:

```nftables
# CRITICAL: Without this, replies from DMZ exit via Proxmox host's default route
iifname "eth0" oifname "eth1" masquerade
```

See [docs/operations/troubleshooting-firewall-nat.md](../../docs/operations/troubleshooting-firewall-nat.md) for details.

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)

**External Services:**
[TODO: List external service dependencies]

**Vault Variables:**
[TODO: List vault-encrypted variables if any]

**Related Roles:**
[TODO: List roles this depends on or integrates with]

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox
  roles:
    - role: firewall
      vars:
        # Add example variables
```

### Advanced Configuration

```yaml
- hosts: proxmox
  roles:
    - role: firewall
      vars:
        # Add advanced example
```

## Deployment Process

[TODO: Document the deployment steps this role performs]

1. Step 1
2. Step 2
3. Step 3

## Idempotency

[TODO: Describe how this role ensures idempotent operations]

- State checks before changes
- Markers to prevent re-provisioning
- Safe to re-run

## Notes

### Performance Considerations
[TODO: Document resource requirements and performance notes]

### Security
[TODO: Document security considerations]

### Troubleshooting
[TODO: Add common troubleshooting steps]

### Rollback Procedure
[TODO: Document how to rollback changes made by this role]

### Known Limitations
[TODO: List known issues or limitations]

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ⚠️ **Security-First Design**: [TODO: Verify LDAP/OIDC integration, Vault usage]
- ⚠️ **Idempotent Operations**: [TODO: Verify safe re-runnability]
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ⚠️ **Automated Operations**: [TODO: Verify automation completeness]

---

**Status**: 🚧 This README is a template and requires completion with actual role details.

**Action Required**: Please fill in the [TODO] sections based on the role's implementation in `tasks/main.yml`.
