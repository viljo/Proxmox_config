# Research: WireGuard VPN Server

**Phase**: 0 (Outline & Research)
**Date**: 2025-10-20
**Feature**: Secure remote access VPN for infrastructure management

## Research Questions & Decisions

### 1. VPN Technology Selection

**Decision**: Use WireGuard protocol

**Rationale**:
- Modern, high-performance VPN protocol with minimal overhead
- Built into Linux kernel (5.6+), eliminating userspace performance penalties
- Cryptographically superior to OpenVPN (ChaCha20-Poly1305, Curve25519)
- Simple configuration (single config file vs complex certificate infrastructure)
- Excellent mobile client support (iOS, Android, Windows, macOS, Linux)
- Proven production use in enterprise and personal deployments
- Lower attack surface (~4,000 lines of code vs ~100,000 for OpenVPN)

**Alternatives Considered**:
- **OpenVPN**: Rejected - more complex configuration, higher overhead, slower performance, larger codebase with more vulnerabilities
- **IPsec/IKEv2**: Rejected - complex setup, difficult debugging, primarily for site-to-site rather than road warrior scenarios
- **Tailscale/Headscale**: Considered - built on WireGuard but adds mesh networking layer. Rejected for initial deployment to keep things simple, but could be future enhancement
- **ZeroTier**: Rejected - proprietary components, less control over routing

**References**:
- WireGuard whitepaper: https://www.wireguard.com/papers/wireguard.pdf
- Linux kernel integration since 5.6
- Existing role in repository demonstrates working implementation

### 2. Deployment Architecture

**Decision**: LXC container (CT 2090) on management network (vmbr0)

**Rationale**:
- Isolation from other services via containerization
- Unprivileged LXC meets security requirements
- Management network placement enables routing to 192.168.0.0/16
- Minimal resource overhead (1GB RAM, 1 CPU sufficient)
- Easy backup and migration via PBS

**Alternatives Considered**:
- **Bare metal deployment**: Rejected - less flexible, harder to manage, wastes host resources
- **VM instead of LXC**: Rejected - higher resource overhead for same functionality
- **DMZ network placement**: Rejected - would require complex routing to reach management network, violates network segmentation principles
- **Docker container**: Rejected - LXC provides better network control for VPN routing

**Network Flow**:
```
External Client
    ↓ (Internet)
Firewall/Router (WAN interface)
    ↓ (UDP port 51820 forward)
WireGuard LXC (vmbr0: 192.168.x.x)
    ↓ (VPN tunnel: 10.8.0.0/24)
Client gets 10.8.0.x IP
    ↓ (routing)
Access to 192.168.0.0/16 network
```

### 3. Authentication Mechanism

**Decision**: Cryptographic public/private key pairs (no username/password)

**Rationale**:
- WireGuard protocol design uses Curve25519 elliptic curve for key exchange
- Each peer has unique keypair - public key identifies peer, private key authenticates
- Eliminates password-based vulnerabilities (brute force, credential stuffing, phishing)
- Simpler than certificate infrastructure (no CA, CRL, OCSP complexity)
- Keys can be easily rotated by generating new pairs
- QR codes enable easy mobile client provisioning

**Key Management**:
- Server private key stored in Ansible Vault (vault_wireguard_private_key)
- Peer public keys stored in wireguard_peer_configs variable
- Keys generated with: `wg genkey | tee privatekey | wg pubkey > publickey`
- QR codes generated with: `qrencode -t ansiutf8 < client.conf`

**Not Applicable**:
- Keycloak/LDAP integration: WireGuard doesn't support username/password authentication
- This is a constitutional exception justified in Complexity Tracking

### 4. IP Address Allocation

**Decision**:
- VPN subnet: 10.8.0.0/24
- Server IP: 10.8.0.1/24
- Peer IPs: 10.8.0.2-254 (253 available addresses)

**Rationale**:
- RFC 1918 private address space avoids conflicts with infrastructure networks
- /24 subnet provides 254 usable IPs (sufficient for 20+ peer target + future growth)
- 10.8.x.x range unlikely to conflict with home/corporate networks (most use 192.168.x.x or 10.0.x.x)
- Smaller than /16 to limit blast radius if VPN is compromised

**Routing Configuration**:
- Allowed IPs for clients: 192.168.0.0/16 (management network only)
- NOT routed: 172.16.10.0/24 (DMZ network - explicit exclusion per spec clarification)
- IP forwarding enabled in container: `net.ipv4.ip_forward=1`
- NAT/masquerading may be needed depending on firewall config

### 5. Peer Configuration Management

**Decision**: Ansible variable-based peer list (wireguard_peer_configs array)

**Rationale**:
- Declarative configuration aligns with Infrastructure as Code principles
- Easy to add/remove peers via variable changes
- Version control tracks all peer modifications
- Idempotent deployment (re-running playbook safe)
- Template-driven config generation ensures consistency

**Peer Configuration Schema**:
```yaml
wireguard_peer_configs:
  - public_key: "peer1_public_key_here"
    allowed_ips: "10.8.0.2/32"
    endpoint: null  # For road warrior clients (server doesn't initiate)
    persistent_keepalive: 25  # For NAT traversal

  - public_key: "peer2_public_key_here"
    allowed_ips: "10.8.0.3/32"
    endpoint: null
    persistent_keepalive: 25
```

**Alternatives Considered**:
- **Web UI for peer management**: Rejected for initial deployment - adds complexity, web service attack surface. Could be future enhancement (wg-easy, wireguard-ui)
- **Database-backed configuration**: Rejected - file-based config simpler, easier to backup
- **Automatic peer discovery**: Rejected - requires mesh networking layer (Tailscale/Headscale), increases complexity

### 6. Container Resource Allocation

**Decision**:
- RAM: 1GB
- CPU: 1 core
- Disk: 8GB
- Swap: 512MB

**Rationale**:
- WireGuard is extremely lightweight (kernel space, minimal daemon)
- 1GB RAM handles 20+ concurrent connections with headroom
- Single CPU core sufficient for crypto operations (ChaCha20 is fast)
- 8GB disk more than adequate (WireGuard binary ~80KB, configs <10KB each)
- These match existing role defaults and have proven sufficient in production

**Scaling Considerations**:
- For >50 peers, consider 2 CPU cores for crypto parallelization
- For >100 peers, increase RAM to 2GB
- Disk usage grows minimally with peers (configs are tiny)

### 7. Firewall Configuration

**Decision**: UDP port 51820 forwarded from WAN to WireGuard container

**Rationale**:
- 51820 is WireGuard's default port (IANA registered)
- UDP chosen over TCP for performance (VPN-over-TCP causes double acknowledgment issues)
- Single port minimizes firewall complexity
- Port forwarding required for external clients to reach container on management network

**Firewall Rules Needed**:
```
# On firewall/router
UDP 51820 (WAN) → 192.168.x.x:51820 (WireGuard container)

# On WireGuard container (nftables/iptables)
Allow UDP 51820 inbound
Allow established/related traffic
Enable IP forwarding
Optionally NAT/masquerade VPN traffic to management network
```

### 8. Configuration File Structure

**Decision**: Single wg0.conf file with Interface + Peer sections

**Rationale**:
- WireGuard's native configuration format
- Simple, human-readable
- wg-quick parses and applies automatically
- Easy to backup (single file)
- Template-driven generation via Ansible ensures consistency

**Configuration Template** (wg0.conf.j2):
```ini
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = {{ wireguard_private_key }}
SaveConfig = true  # Allows wg set commands to persist

{% for peer in wireguard_peer_configs %}
[Peer]
PublicKey = {{ peer.public_key }}
AllowedIPs = {{ peer.allowed_ips }}
{% if peer.endpoint %}Endpoint = {{ peer.endpoint }}{% endif %}
{% if peer.persistent_keepalive %}PersistentKeepalive = {{ peer.persistent_keepalive }}{% endif %}

{% endfor %}
```

### 9. Service Management

**Decision**: systemd wg-quick@wg0.service

**Rationale**:
- wg-quick is WireGuard's official configuration utility
- Handles interface creation, IP assignment, routing automatically
- systemd integration provides auto-start on boot
- Simple commands: `wg-quick up wg0`, `wg-quick down wg0`
- Status monitoring via `systemctl status wg-quick@wg0`

**Service Commands**:
- Enable: `systemctl enable wg-quick@wg0`
- Start: `systemctl start wg-quick@wg0`
- Restart: `systemctl restart wg-quick@wg0`
- Status: `wg show` (live connection info)

### 10. Client Configuration Distribution

**Decision**: QR codes for mobile, config files for desktop

**Rationale**:
- Mobile clients (iOS, Android) support QR code scanning for instant setup
- Desktop clients (Windows, macOS, Linux) import .conf files
- qrencode utility generates QR codes from config text
- Secure distribution: admin generates configs, shares via secure channel (encrypted email, password-protected zip)

**Client Config Template**:
```ini
[Interface]
PrivateKey = <client_private_key>
Address = 10.8.0.2/32  # Unique per client
DNS = 192.168.0.1      # Infrastructure DNS server

[Peer]
PublicKey = <server_public_key>
Endpoint = vpn.viljo.se:51820  # Or public IP
AllowedIPs = 192.168.0.0/16    # Management network only
PersistentKeepalive = 25       # NAT traversal
```

**QR Code Generation**:
```bash
qrencode -t ansiutf8 < client.conf  # Terminal output
qrencode -o client.png < client.conf  # PNG file
```

## Technology Stack Summary

| Component | Technology | Version |
|-----------|-----------|---------|
| VPN Protocol | WireGuard | Kernel module (5.6+) |
| Container Runtime | LXC (unprivileged) | Proxmox 8.x |
| Base OS | Debian | 13 (Trixie) |
| Orchestration | Ansible | 2.15+ |
| Service Manager | systemd | wg-quick@wg0.service |
| Cryptography | ChaCha20-Poly1305 | Curve25519 (ECDH) |
| Key Storage | Ansible Vault | Encrypted YAML |
| Configuration | wg-quick | Single file (/etc/wireguard/wg0.conf) |
| QR Code Generator | qrencode | For mobile provisioning |
| Monitoring | Zabbix | (To be implemented) |
| Backup | Proxmox Backup Server | (To be implemented) |

## Open Questions (Resolved)

All technical decisions finalized based on specification requirements and existing role analysis.

## Gap Analysis: Existing Role vs. Constitutional Requirements

### What Exists
✅ LXC container creation and configuration
✅ WireGuard package installation
✅ Config file templating (wg0.conf.j2)
✅ Systemd service enablement
✅ Idempotent provisioning marker
✅ Ansible Vault for private key storage

### What's Missing (To Implement in Phase 1)
❌ NetBox CMDB integration (container registration)
❌ Zabbix monitoring (peer count, bandwidth, connection status)
❌ PBS backup configuration (automated LXC backups)
❌ GitLab CI pipeline (ansible-lint, yamllint, deployment automation)
❌ Comprehensive role documentation (README completion)
❌ Molecule testing framework
❌ Deployment/teardown playbooks
❌ Peer management playbook (add/remove peers)
❌ Architecture documentation

## Next Steps

Phase 1 deliverables:
1. Create data-model.md (entity definitions for VPN components)
2. Generate contracts/ (WireGuard config schema, peer config schema)
3. Write quickstart.md (deployment instructions, peer onboarding)
4. Update agent context with WireGuard technologies
5. Document gaps for implementation in tasks.md (Phase 2)
