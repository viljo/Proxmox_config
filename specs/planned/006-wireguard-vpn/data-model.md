# Data Model: WireGuard VPN Server

**Phase**: 1 (Design & Contracts)
**Date**: 2025-10-20
**Feature**: Secure remote access VPN for infrastructure management

## Entity Definitions

### 1. WireGuard Server Container (LXC)

**Purpose**: LXC container hosting the WireGuard VPN server

**Attributes**:
- `container_id` (integer): Proxmox CT ID (default: 2090)
- `hostname` (string): Container hostname (default: "wireguard")
- `domain` (string): DNS domain (default: "infra.local")
- `ip_address` (IPv4): Static IP on management network (DHCP or static)
- `bridge` (string): Network bridge interface (default: "vmbr0")
- `memory_mb` (integer): RAM allocation in MB (default: 1024)
- `cpu_cores` (integer): CPU core count (default: 1)
- `disk_gb` (integer): Root disk size in GB (default: 8)
- `swap_mb` (integer): Swap allocation in MB (default: 512)
- `storage_pool` (string): Proxmox storage backend (default: "local-lvm")
- `unprivileged` (boolean): Unprivileged container flag (true, immutable)
- `onboot` (boolean): Auto-start on host boot (true)
- `nesting` (boolean): Container nesting support (true, required for network capabilities)

**State Transitions**:
```
[Created] → [Stopped] → [Running] → [Stopped] → [Destroyed]
                ↓            ↑
                └────────────┘
                  (restart)
```

**Validation Rules**:
- `container_id` must be unique across Proxmox cluster
- `memory_mb` >= 512 (minimum for WireGuard)
- `cpu_cores` >= 1
- `unprivileged` must be true (constitutional security requirement)
- `nesting` must be true (required for WireGuard network operations)

**Relationships**:
- Deployed on: Proxmox Host
- Registered in: NetBox (CMDB)
- Monitored by: Zabbix
- Backed up by: PBS (Proxmox Backup Server)

---

### 2. WireGuard Interface

**Purpose**: Virtual network interface (wg0) that handles VPN tunneling

**Attributes**:
- `interface_name` (string): Interface identifier (default: "wg0")
- `address` (IPv4 CIDR): VPN gateway IP (default: "10.8.0.1/24")
- `listen_port` (integer): UDP port for incoming connections (default: 51820)
- `private_key` (string): Server's private key (stored in Ansible Vault)
- `public_key` (string): Server's public key (derived from private key)
- `save_config` (boolean): Persist runtime changes to config file (true)

**State Transitions**:
```
[Down] → [Up] → [Down]
          ↕
    [Reconfiguring]
```

**Validation Rules**:
- `interface_name` must match config file name (wg0.conf → wg0)
- `address` must be in RFC 1918 private space
- `listen_port` must be 1-65535, typically 51820
- `private_key` must be valid Curve25519 private key (44 chars base64)
- `public_key` derived via `wg pubkey < privatekey`

**Relationships**:
- Hosted on: WireGuard Server Container
- Configured by: WireGuard Configuration File
- Connected to: Multiple Peer Tunnels

---

### 3. Peer Configuration

**Purpose**: Individual client or site that connects to the VPN

**Attributes**:
- `peer_name` (string): Human-readable identifier (e.g., "alice-laptop", "bob-phone")
- `public_key` (string): Peer's public key (provided by peer admin)
- `allowed_ips` (list[IPv4 CIDR]): IP ranges this peer can use (e.g., ["10.8.0.2/32"])
- `endpoint` (string): Peer's public address (optional, for site-to-site)
- `persistent_keepalive` (integer): Keepalive interval in seconds (default: 25 for NAT traversal)
- `preshared_key` (string): Optional additional encryption layer (quantum-resistant)
- `latest_handshake` (timestamp): Last successful key exchange (runtime data)
- `transfer_rx` (bytes): Data received from peer (runtime data)
- `transfer_tx` (bytes): Data sent to peer (runtime data)

**State Transitions**:
```
[Configured] → [Handshaking] → [Connected] → [Idle] → [Disconnected]
                     ↓              ↑
                     └──────────────┘
                   (keepalive/traffic)
```

**Validation Rules**:
- `public_key` must be valid Curve25519 public key (44 chars base64)
- `allowed_ips` must not overlap with other peers (each IP unique)
- `allowed_ips` must be subset of VPN subnet (10.8.0.0/24)
- `endpoint` format: `host:port` or null for road warrior clients
- `persistent_keepalive` range: 0-65535 seconds (0 = disabled)

**Relationships**:
- Belongs to: WireGuard Interface
- Configured in: wireguard_peer_configs Ansible variable
- Authenticated via: Public/Private Key Pair

---

### 4. VPN Tunnel

**Purpose**: Encrypted connection between server and peer

**Attributes**:
- `local_endpoint` (IPv4:port): Server's listen address (e.g., "192.168.x.x:51820")
- `remote_endpoint` (IPv4:port): Peer's public address (if known)
- `tunnel_ip_local` (IPv4): Server VPN IP (10.8.0.1)
- `tunnel_ip_remote` (IPv4): Peer VPN IP (e.g., 10.8.0.2)
- `encryption_cipher` (string): ChaCha20-Poly1305
- `key_exchange` (string): Curve25519
- `handshake_interval` (seconds): Key rotation period (120 seconds)
- `status` (enum): connected | handshaking | disconnected

**State Transitions**:
```
[Initiating] → [Handshaking] → [Established] → [Idle] → [Expired]
                     ↑              ↓
                     └──────────────┘
                   (key rotation)
```

**Validation Rules**:
- `tunnel_ip_remote` must match peer's allowed_ips
- Handshake must succeed within 5 seconds
- Keys rotate every 120 seconds when traffic flows
- Tunnel expires after 180 seconds without traffic (unless keepalive enabled)

**Relationships**:
- Connects: WireGuard Interface ↔ Peer Configuration
- Encrypted with: Cryptographic Key Pair
- Routes traffic to: Allowed IP Ranges

---

### 5. Configuration File

**Purpose**: Persistent storage of WireGuard settings

**Attributes**:
- `file_path` (path): Location on filesystem (/etc/wireguard/wg0.conf)
- `permissions` (octal): File access mode (0600, owner read/write only)
- `owner` (string): File owner (root)
- `group` (string): File group (root)
- `format` (string): INI-style configuration
- `checksum` (string): File hash for change detection

**Content Sections**:
```ini
[Interface]
# Server configuration

[Peer]
# First peer

[Peer]
# Second peer
...
```

**Validation Rules**:
- File must be readable only by root (permissions 0600)
- Must contain exactly one [Interface] section
- May contain zero or more [Peer] sections
- PrivateKey must be present and valid in [Interface]
- PublicKey must be present and valid in each [Peer]

**Relationships**:
- Deployed to: WireGuard Server Container (/etc/wireguard/)
- Generated from: Ansible Template (wg0.conf.j2)
- Loaded by: wg-quick systemd service

---

### 6. Cryptographic Key Pair

**Purpose**: Asymmetric encryption keys for authentication and encryption

**Attributes**:
- `private_key` (string): Secret key (44 chars base64, Curve25519)
- `public_key` (string): Public key derived from private (44 chars base64)
- `preshared_key` (string): Optional symmetric key for quantum resistance
- `generation_date` (timestamp): When key was created
- `rotation_policy` (string): Manual or automatic rotation

**Key Generation**:
```bash
# Private key
wg genkey > privatekey

# Public key (derived)
wg pubkey < privatekey > publickey

# Preshared key (optional)
wg genpsk > presharedkey
```

**Validation Rules**:
- Private key must be 32 bytes (44 chars base64)
- Public key must be 32 bytes (44 chars base64)
- Private key must never be transmitted or logged
- Server private key stored in Ansible Vault only

**Relationships**:
- Owned by: WireGuard Server or Peer
- Stored in: Ansible Vault (server), client device (peer)
- Used for: Tunnel Authentication and Encryption

---

### 7. Routing Configuration

**Purpose**: Network routes that direct traffic through VPN

**Attributes**:
- `source_network` (IPv4 CIDR): Traffic origin (VPN subnet 10.8.0.0/24)
- `destination_network` (IPv4 CIDR): Traffic destination (192.168.0.0/16)
- `gateway` (IPv4): Next hop (WireGuard interface 10.8.0.1)
- `route_type` (enum): static | dynamic
- `metric` (integer): Route priority

**Route Table Entries**:
```
# On WireGuard server (container)
10.8.0.0/24 dev wg0          # VPN subnet routes to wg0 interface
192.168.0.0/16 dev eth0      # Management network routes to container's eth0

# On VPN clients
192.168.0.0/16 via 10.8.0.1  # Management network routes through VPN
```

**Validation Rules**:
- No overlapping routes between VPN and infrastructure networks
- Source network must match VPN subnet
- Destination must NOT include DMZ (172.16.10.0/24) per specification
- IP forwarding must be enabled on server: `net.ipv4.ip_forward=1`

**Relationships**:
- Configured on: WireGuard Server Container
- Affects: VPN Tunnel traffic routing
- Enforced by: Linux kernel routing table

---

### 8. systemd Service

**Purpose**: Service manager for WireGuard interface

**Attributes**:
- `service_name` (string): wg-quick@wg0.service
- `service_type` (string): oneshot
- `enabled` (boolean): Auto-start on boot (true)
- `active` (boolean): Currently running (true/false)
- `restart_policy` (string): on-failure

**Service Commands**:
- Start: `systemctl start wg-quick@wg0`
- Stop: `systemctl stop wg-quick@wg0`
- Restart: `systemctl restart wg-quick@wg0`
- Enable: `systemctl enable wg-quick@wg0`
- Status: `systemctl status wg-quick@wg0`

**State Transitions**:
```
[Inactive] → [Activating] → [Active] → [Deactivating] → [Inactive]
                                ↕
                            [Failed]
```

**Validation Rules**:
- Service must be enabled for auto-start
- Configuration file must exist before service can start
- Service restart triggers interface down/up cycle

**Relationships**:
- Manages: WireGuard Interface (wg0)
- Loads config from: Configuration File (/etc/wireguard/wg0.conf)
- Controlled by: Ansible handlers (restart wireguard)

---

## Data Relationships Diagram

```
┌──────────────────────────────┐
│   Proxmox Host (vmbr0)       │
│                              │
│  ┌────────────────────────┐  │
│  │ WireGuard LXC (CT 2090)│  │
│  │                        │  │      ┌─────────────────┐
│  │  ┌──────────────────┐  │  │      │  External Peer  │
│  │  │ wg0 Interface    │◄─┼──┼──────┤  (Road Warrior) │
│  │  │ 10.8.0.1/24      │  │  │      │  10.8.0.2       │
│  │  │ UDP :51820       │  │  │      └─────────────────┘
│  │  └────┬─────────────┘  │  │
│  │       │                │  │
│  │       ▼                │  │
│  │  ┌──────────────────┐  │  │
│  │  │ Config File      │  │  │
│  │  │ /etc/wireguard/  │  │  │
│  │  │ wg0.conf         │  │  │
│  │  └──────────────────┘  │  │
│  │       │                │  │
│  │       ▼                │  │
│  │  ┌──────────────────┐  │  │
│  │  │ systemd Service  │  │  │
│  │  │ wg-quick@wg0     │  │  │
│  │  └──────────────────┘  │  │
│  │                        │  │
│  │  eth0: 192.168.x.x     │  │
│  └─────────┬──────────────┘  │
│            │                 │
└────────────┼─────────────────┘
             ↓
    ┌────────────────────┐
    │  Management Network│
    │  192.168.0.0/16    │
    │                    │
    │  - Proxmox Host    │
    │  - Infrastructure  │
    │  - Services        │
    └────────────────────┘
```

## Entity Lifecycle Management

### Create Workflow
1. Create LXC container on Proxmox host
2. Download Debian template if not cached
3. Start container and wait for boot
4. Install WireGuard packages (wireguard, qrencode)
5. Deploy configuration file from Ansible template
6. Enable and start wg-quick@wg0 systemd service
7. Register container in NetBox CMDB
8. Configure Zabbix monitoring
9. Add to PBS backup schedule

### Peer Add Workflow
1. Generate keypair on admin workstation (`wg genkey | wg pubkey`)
2. Add peer config to wireguard_peer_configs Ansible variable
3. Re-run Ansible playbook (idempotent)
4. Ansible regenerates wg0.conf with new peer
5. Ansible triggers handler to restart WireGuard service
6. Peer can now connect with their private key + client config

### Peer Remove Workflow
1. Remove peer entry from wireguard_peer_configs
2. Re-run Ansible playbook
3. Ansible regenerates wg0.conf without peer
4. Ansible restarts WireGuard service
5. Peer's public key no longer accepted

### Update Workflow
1. Modify wireguard configuration variables
2. Re-run Ansible playbook
3. Ansible detects config changes via template checksum
4. Ansible regenerates wg0.conf
5. Handler restarts WireGuard service
6. Active connections re-establish automatically

### Destroy Workflow
1. Stop wg-quick@wg0 service
2. Remove WireGuard configuration files
3. Stop LXC container
4. Destroy LXC container from Proxmox
5. Remove NetBox entry
6. Remove Zabbix monitoring
7. Remove from PBS backup schedule

## Constraints & Invariants

### Infrastructure Constraints
- LXC container must remain unprivileged (security requirement)
- Container must have nesting enabled (for network operations)
- Single WireGuard interface per container (wg0)
- Management network only routing (no DMZ access)

### Network Constraints
- VPN subnet (10.8.0.0/24) must not overlap with infrastructure networks
- Each peer must have unique allowed_ips (no IP conflicts)
- UDP port 51820 must be accessible from external networks
- IP forwarding must be enabled in container kernel

### Security Constraints
- Private keys never logged or transmitted in plaintext
- Configuration file permissions must be 0600 (root only)
- All secret keys stored in Ansible Vault
- Peer authentication via cryptographic keys only (no passwords)

### Performance Constraints
- Connection establishment <5 seconds
- Throughput ≥100 Mbps (typically limited by network, not WireGuard)
- Latency overhead <10ms (WireGuard adds minimal latency)
- Support ≥20 concurrent peer connections

## Security Considerations

### Cryptographic Security
- Curve25519 for ECDH key exchange (256-bit security)
- ChaCha20-Poly1305 for authenticated encryption
- BLAKE2s for hashing
- HKDF for key derivation
- Automatic key rotation every 120 seconds during active sessions

### Key Management
- Server private key stored in Ansible Vault (encrypted at rest)
- Peer private keys stored on client devices (user responsibility)
- No certificate authority or PKI complexity
- Keys rotated manually by generating new pairs

### Network Security
- Unprivileged LXC container limits attack surface
- Firewall restricts UDP 51820 to necessary sources
- No DMZ routing prevents lateral movement if VPN compromised
- IP source validation via allowed_ips prevents spoofing

### Access Control
- Each peer has unique public key (identity)
- Allowed IPs define what traffic peer can send (authorization)
- No wildcard allowed_ips (each peer explicitly configured)
- Peer removal immediately revokes access

## Monitoring & Observability

### Metrics to Track (Zabbix)
- Active peer connections count
- Bytes transferred (RX/TX) per peer
- Last handshake timestamp per peer
- Interface status (up/down)
- UDP port 51820 reachability
- Container CPU and memory usage

### Health Checks
- `wg show` returns peer list
- At least one peer with recent handshake
- systemd service is active and enabled
- Configuration file exists and valid
- UDP port 51820 responding to connections

### Logging
- systemd journal for service events
- WireGuard kernel module logs to dmesg
- Connection attempts and handshakes logged
- Peer additions/removals logged via Ansible

## Backup & Recovery

### Backup Scope
- Entire LXC container via PBS (includes all configs, keys)
- Configuration files backed up to version control (excluding keys)
- Ansible Vault backup (server private key)

### Recovery Process
1. Restore LXC container from PBS snapshot
2. Start container
3. Verify wg-quick@wg0 service auto-starts
4. Test peer connection
5. If keys lost: regenerate keypairs, redistribute to peers

### Disaster Recovery
- RTO: <30 minutes (restore container + verify connectivity)
- RPO: Last PBS backup (typically daily)
- Key rotation: Generate new server keypair, update all peer configs
