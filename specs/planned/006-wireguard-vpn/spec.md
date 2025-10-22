# Feature Specification: WireGuard VPN Server

**Feature Branch**: `006-wireguard-vpn`
**Created**: 2025-10-20
**Status**: Draft
**Input**: User description: "wireguard"

## Clarifications

### Session 2025-10-20

- Q: Which network segment should the WireGuard VPN container be deployed on? → A: Management network (vmbr0) for routing to the management network (192.168.0.0/16 only, NOT DMZ)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Secure Remote Access to Infrastructure (Priority: P1)

Users need secure, encrypted VPN access to the internal infrastructure network from external locations, enabling remote administration, monitoring, and service access without exposing services directly to the internet.

**Why this priority**: This is the core value proposition - providing secure remote access is essential for infrastructure management and enables all other remote work scenarios.

**Independent Test**: Can be fully tested by installing WireGuard client, importing configuration, connecting to VPN, and verifying ability to ping management network IPs (192.168.0.0/16).

**Acceptance Scenarios**:

1. **Given** user has WireGuard configuration file, **When** they connect via WireGuard client, **Then** VPN tunnel establishes within 5 seconds with valid IP assignment
2. **Given** VPN is connected, **When** user accesses internal service (e.g., ping any IP in 192.168.0.0/16), **Then** traffic routes through encrypted tunnel successfully
3. **Given** VPN connection is active, **When** user disconnects client, **Then** tunnel tears down cleanly without residual routes
4. **Given** user tries to connect with invalid key, **When** connection attempted, **Then** authentication fails and access is denied

---

### User Story 2 - Multi-Peer VPN Network (Priority: P2)

Administrators need to configure multiple authorized peers (users, servers, sites) with individualized access policies, enabling flexible network topologies and granular access control.

**Why this priority**: Supports scalability beyond single-user scenarios, but basic single-peer VPN works independently. Essential for team collaboration and site-to-site connectivity.

**Independent Test**: Can be tested by configuring two different peers with separate allowed IPs, verifying both can connect simultaneously and have appropriate routing.

**Acceptance Scenarios**:

1. **Given** administrator adds new peer configuration, **When** Ansible playbook runs, **Then** peer is added to WireGuard config without disrupting existing connections
2. **Given** multiple peers are configured, **When** all connect simultaneously, **Then** each receives correct IP allocation without conflicts
3. **Given** peer has specific allowed IPs, **When** peer connects, **Then** only specified traffic routes through VPN (split tunneling works correctly)
4. **Given** administrator removes peer, **When** Ansible runs, **Then** peer configuration is deleted and client can no longer connect

---

### User Story 3 - Persistent VPN Service (Priority: P3)

The VPN server must start automatically on system boot and maintain stable connections through network disruptions, minimizing downtime and manual intervention.

**Why this priority**: Enhances reliability and operational efficiency, but basic VPN functionality works without auto-start. Critical for production environments.

**Independent Test**: Can be tested by rebooting Proxmox host and verifying WireGuard LXC container and service start automatically, accepting connections within 2 minutes of boot.

**Acceptance Scenarios**:

1. **Given** Proxmox host reboots, **When** system comes online, **Then** WireGuard container starts automatically within 60 seconds
2. **Given** WireGuard container is running, **When** administrator checks service status, **Then** wg-quick service is active and enabled
3. **Given** network disruption occurs, **When** connectivity restores, **Then** existing peer connections reestablish automatically via keepalive
4. **Given** WireGuard service crashes, **When** systemd detects failure, **Then** service restarts automatically (if restart policy configured)

---

### Edge Cases

- What happens when WireGuard container runs out of available IP addresses in the 192.168.100.0/24 subnet?
- How does system handle peer connection attempts with expired or rotated keys?
- What occurs if WireGuard listen port (51820) is blocked by firewall or already in use?
- How are peer conflicts resolved when multiple peers claim the same allowed IPs?
- What happens when container network interface fails or loses connectivity?
- How does system handle configuration changes while active connections exist?
- What occurs if private key is compromised and needs rotation?
- How are connection logs and peer session data managed over time?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide encrypted VPN tunnel for remote network access
- **FR-002**: System MUST support multiple concurrent peer connections without degradation
- **FR-003**: System MUST assign unique VPN IP addresses to connected peers (192.168.100.0/24 subnet)
- **FR-004**: System MUST route traffic between VPN peers and infrastructure networks
- **FR-005**: System MUST persist peer configurations across service restarts
- **FR-006**: System MUST enable/disable peers without affecting other connections
- **FR-007**: System MUST provide connection status visibility (connected peers, data transfer stats)
- **FR-008**: System MUST support NAT traversal and persistent keepalive for unstable connections
- **FR-009**: System MUST handle peer authentication via cryptographic public/private key pairs
- **FR-010**: System MUST generate QR codes for mobile client configuration

### Infrastructure Requirements *(for Proxmox deployments)*

- **IR-001**: Service MUST run in unprivileged LXC container (CT 90) for isolation and resource efficiency
- **IR-002**: Container MUST be deployed on management network (vmbr0) to enable routing to management network (192.168.0.0/16 only)
- **IR-003**: Container MUST allocate minimal resources (1GB RAM, 1 CPU core, 8GB disk) sufficient for VPN routing
- **IR-004**: Container MUST expose UDP port 51820 for WireGuard protocol traffic
- **IR-005**: Configuration MUST be managed via Ansible for reproducibility and idempotency
- **IR-006**: Container MUST integrate with NetBox for inventory management
- **IR-007**: System MUST expose monitoring metrics for Zabbix (connection count, bandwidth, peer status)

### Security Requirements *(mandatory for all services)*

- **SR-001**: Service MUST use cryptographically secure private/public key pairs for peer authentication
- **SR-002**: Private keys MUST be stored in Ansible Vault with no plaintext credentials in repositories
- **SR-003**: Container MUST run as unprivileged LXC with minimal kernel capabilities
- **SR-004**: Service MUST use modern encryption (ChaCha20-Poly1305 or AES-GCM)
- **SR-005**: Firewall MUST restrict WireGuard port access to authorized external IPs (if not fully public)
- **SR-006**: Peer configurations MUST use principle of least privilege (only necessary allowed IPs)
- **SR-007**: System MUST log connection attempts and authentication failures for security auditing

### Key Entities

- **WireGuard Server**: LXC container (CT 90) running WireGuard daemon listening on UDP port 51820
- **VPN Interface**: wg0 network interface with IP 192.168.100.1/24 serving as VPN gateway
- **Server Key Pair**: Cryptographic private/public key pair identifying the VPN server
- **Peer Configuration**: Individual client/server peer with public key, allowed IPs, endpoint, and keepalive settings
- **VPN Tunnel**: Encrypted connection between server and peer with automatic key rotation and handshake
- **Allowed IPs**: List of IP ranges that route through VPN tunnel for each peer
- **Configuration File**: /etc/wireguard/wg0.conf containing interface and peer definitions

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can establish VPN connection within 5 seconds of client authentication
- **SC-002**: VPN maintains 99.5% uptime during evaluation period
- **SC-003**: System supports minimum 20 concurrent peer connections without performance degradation
- **SC-004**: VPN throughput achieves minimum 100 Mbps for typical infrastructure use cases
- **SC-005**: Peer configuration changes deploy via Ansible in under 2 minutes
- **SC-006**: New peer onboarding (key generation, config deployment, client setup) completes in under 10 minutes
- **SC-007**: Connection latency overhead remains under 10ms compared to direct network access
- **SC-008**: 95% of connection attempts succeed on first try without manual troubleshooting

## Assumptions

- Proxmox VE host has network connectivity for VPN traffic (firewall allows UDP 51820)
- DNS resolution available for internal services accessed via VPN
- Clients use modern WireGuard client software (Windows, macOS, Linux, iOS, Android)
- Network topology supports routing between VPN subnet (192.168.100.0/24) and management network (192.168.0.0/16)
- Firewall rules allow VPN traffic to reach management network (192.168.0.0/16) but NOT DMZ (172.16.10.0/24)
- Public IP address or dynamic DNS available for external peer connections
- Loopia DDNS (or similar) keeps external hostname updated if using dynamic IP
- Administrator has secure method for distributing peer configuration files
- Peer devices have sufficient security posture (not compromised endpoints)

## Dependencies

- Proxmox VE host with LXC support
- Debian 13 LXC template for container base
- WireGuard kernel module support (available in modern Linux kernels)
- Ansible for configuration management
- Network routing between VPN subnet and infrastructure networks
- Firewall configuration (nftables/iptables) for NAT and forwarding rules
- NetBox for CMDB integration (optional but recommended)
- Zabbix for monitoring integration (optional but recommended)
- Ansible Vault for secure key storage

## Out of Scope

- Commercial VPN features (multi-hop routing, geo-distributed servers, load balancing)
- Web-based VPN management UI (WireGuard uses configuration files)
- Integration with external identity providers (WireGuard uses key-based auth, not username/password)
- Bandwidth throttling or QoS policies per peer
- Deep packet inspection or traffic filtering beyond IP-based routing
- Automatic peer key rotation (manual key management required)
- Split DNS configuration for VPN clients
- IPv6 support (current implementation IPv4-only)
- Site-to-site VPN tunnels (focused on client-to-site access)
- VPN analytics dashboard or usage reporting beyond basic monitoring
