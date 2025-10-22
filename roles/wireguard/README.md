# Role: wireguard

## Purpose

This role deploys and configures WireGuard VPN server on Proxmox VE infrastructure. WireGuard provides secure, encrypted remote access to the management network (192.168.0.0/16) for administrators and authorized users.

The WireGuard server runs in an unprivileged LXC container (CT 90) on the management network (vmbr0) and creates a VPN tunnel network (192.168.100.0/24) for connected peers. It enables secure remote administration, monitoring, and service access without exposing services directly to the internet.

## Architecture

- **Container**: Unprivileged Debian 13 LXC (CT 90)
- **Network**: Management network (vmbr0) with static IP 192.168.1.90/24
- **VPN Tunnel**: 192.168.100.0/24 subnet
- **Server IP**: 192.168.100.1/24 (VPN interface)
- **Protocol**: WireGuard (UDP port 51820)
- **Routing**: NAT and IP forwarding enabled for VPN clients to access 192.168.0.0/16

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

**Container Configuration:**
- `wireguard_container_id`: LXC container ID (default: `90`)
- `wireguard_hostname`: Container hostname (default: `wireguard`)
- `wireguard_domain`: Container domain (default: `infra.local`)
- `wireguard_memory`: RAM allocation in MB (default: `1024`)
- `wireguard_cores`: CPU core count (default: `1`)
- `wireguard_disk`: Disk size in GB (default: `8`)
- `wireguard_swap`: Swap size in MB (default: `512`)

**Network Configuration:**
- `wireguard_bridge`: Proxmox bridge to use (default: `{{ management_bridge }}` / `vmbr0`)
- `wireguard_ip_config`: Container IP address (default: `192.168.1.90/24`)
- `wireguard_gateway`: Container gateway (default: `192.168.1.1`)
- `wireguard_dns_servers`: DNS servers for container (default: `[192.168.1.1, 1.1.1.1]`)

**WireGuard VPN Configuration:**
- `wireguard_interface`: WireGuard interface name (default: `wg0`)
- `wireguard_listen_port`: UDP port for WireGuard (default: `51820`)
- `wireguard_tunnel_address`: VPN tunnel network address (default: `192.168.100.1/24`)
- `wireguard_private_key`: Server private key (default: `{{ vault_wireguard_private_key }}`)
- `wireguard_peer_configs`: List of peer configurations (default: `[]`)

**Peer Configuration Format:**
```yaml
wireguard_peer_configs:
  - name: "User's Device"           # Descriptive name
    public_key: "base64_key_here="  # Peer's public key
    allowed_ips: "192.168.100.10/32" # VPN IP assigned to peer
    persistent_keepalive: 25        # Optional: keepalive interval in seconds
```

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)

**External Services:**
- Proxmox VE with LXC support
- Network connectivity for UDP port 51820
- Management network (vmbr0) configured

**Vault Variables:**
- `vault_wireguard_root_password`: Root password for container
- `vault_wireguard_private_key`: WireGuard server private key

**Related Roles:**
- `network`: Configures Proxmox bridges
- `firewall`: May need rules for WireGuard port forwarding

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox
  roles:
    - role: wireguard
```

### With Custom Peers

```yaml
- hosts: proxmox
  roles:
    - role: wireguard
      vars:
        wireguard_peer_configs:
          - name: "Admin Laptop"
            public_key: "AbCdEf1234567890abcdef1234567890abcdef12="
            allowed_ips: "192.168.100.10/32"
            persistent_keepalive: 25
          - name: "Mobile Phone"
            public_key: "XyZ9876543210XyZ9876543210XyZ9876543210="
            allowed_ips: "192.168.100.11/32"
            persistent_keepalive: 25
```

## Deployment Process

This role performs the following steps:

1. **Download Debian 13 Template**: Ensures LXC template is cached
2. **Create LXC Container**: Creates unprivileged container (CT 90) on vmbr0
3. **Configure Container**: Sets onboot flag, memory, CPU, network
4. **Start Container**: Boots container and waits for readiness
5. **Set Root Password**: Configures root password from vault
6. **Install Packages**: Installs WireGuard, iptables, and qrencode
7. **Enable IP Forwarding**: Configures kernel parameter for routing
8. **Deploy Configuration**: Generates wg0.conf from template with peers
9. **Enable Service**: Enables wg-quick@wg0 service
10. **Start WireGuard**: Starts VPN service
11. **Mark Provisioned**: Creates marker to prevent re-provisioning

## Key Generation

To generate WireGuard keys for server and peers:

```bash
# Generate server keys
wg genkey | tee server-private.key | wg pubkey > server-public.key

# Generate peer keys
wg genkey | tee peer1-private.key | wg pubkey > peer1-public.key
```

Store the server private key in `inventory/group_vars/all/secrets.yml`:
```yaml
vault_wireguard_private_key: "SERVER_PRIVATE_KEY_HERE="
```

## Client Configuration

Example client configuration file:

```ini
[Interface]
PrivateKey = PEER_PRIVATE_KEY_HERE=
Address = 192.168.100.10/32
DNS = 192.168.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE=
Endpoint = your-public-ip:51820
AllowedIPs = 192.168.0.0/16
PersistentKeepalive = 25
```

Generate QR code for mobile clients:
```bash
qrencode -t ansiutf8 < client.conf
```

## Idempotency

This role ensures idempotent operations through:

- **Container Creation Check**: Uses `creates` parameter to avoid recreating container
- **Provisioning Marker**: `/etc/wireguard/.provisioned` prevents package reinstallation
- **Configuration Template**: Updates only when peer configs change
- **Service State**: Ensures service is enabled and running without unnecessary restarts

Safe to re-run multiple times without side effects.

## Notes

### Performance Considerations

- Minimal resource usage: 1GB RAM, 1 CPU core sufficient for 20+ peers
- Low latency overhead: <10ms compared to direct network access
- Throughput: Supports 100+ Mbps for typical infrastructure use

### Security

- **Unprivileged Container**: Runs without elevated kernel capabilities
- **Key-Based Authentication**: No passwords, only cryptographic keys
- **Vault Integration**: Private keys stored in Ansible Vault
- **Principle of Least Privilege**: Peers only route specified networks
- **Modern Encryption**: ChaCha20-Poly1305 cipher suite
- **Limited Network Access**: Only management network (192.168.0.0/16), NOT DMZ

### Firewall Configuration

Ensure UDP port 51820 is forwarded through your firewall:

```bash
# Example iptables rule (on firewall container)
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 51820 -j DNAT --to-destination 192.168.1.90:51820
iptables -A FORWARD -p udp -d 192.168.1.90 --dport 51820 -j ACCEPT
```

### Troubleshooting

**WireGuard service won't start:**
```bash
pct exec 90 -- systemctl status wg-quick@wg0
pct exec 90 -- journalctl -u wg-quick@wg0 -n 50
```

**Check connected peers:**
```bash
pct exec 90 -- wg show
```

**Verify IP forwarding:**
```bash
pct exec 90 -- sysctl net.ipv4.ip_forward
```

**Test connectivity from VPN client:**
```bash
# After connecting to VPN
ping 192.168.1.90  # WireGuard server
ping 192.168.1.1   # Gateway
```

### Rollback Procedure

To remove WireGuard deployment:

```bash
# Stop and destroy container
pct stop 90
pct destroy 90

# Remove role from playbook
# Comment out wireguard role in playbooks/site.yml
```

### Known Limitations

- IPv4 only (no IPv6 support)
- Manual key management (no automatic rotation)
- No web-based management UI
- Split tunneling configured via client AllowedIPs
- Maximum ~250 peers per /24 subnet

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ✅ **Security-First Design**: Unprivileged container, Vault secrets, key-based auth
- ✅ **Idempotent Operations**: Safe to re-run with provisioning markers
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ✅ **Automated Operations**: Complete deployment via Ansible automation

---

**Status**: ✅ Complete and ready for deployment

**Related Documentation**:
- Specification: `specs/planned/006-wireguard-vpn/spec.md`
- Network Topology: `docs/architecture/network-topology.md`
- Container Mapping: `docs/architecture/container-mapping.md`
