# Data Model: External SSH Access via viljo.se

**Feature**: External SSH Access via viljo.se
**Date**: 2025-10-20
**Purpose**: Define configuration entities, their attributes, and relationships

## Overview

This feature is infrastructure-focused and primarily deals with configuration data rather than traditional application data models. The "entities" are configuration objects managed by Ansible that define how external SSH access operates.

## Configuration Entities

### 1. SSH Daemon Configuration

**Purpose**: Controls OpenSSH server behavior on Proxmox host

**Attributes**:
- `ssh_port`: Integer (22 internal, configurable external port)
- `permit_root_login`: Enum (yes/without-password/no) - Set to "without-password" (keys only)
- `password_authentication`: Boolean - Set to false
- `pubkey_authentication`: Boolean - Set to true
- `allowed_users`: List[String] - Usernames permitted to connect (e.g., ["root"])
- `client_alive_interval`: Integer (seconds) - Keepalive interval (default: 300)
- `client_alive_count_max`: Integer - Max missed keepalives (default: 3)
- `max_auth_tries`: Integer - Failed auth attempts before disconnect (default: 3)
- `protocol`: Integer - SSH protocol version (2 only)
- `ciphers`: List[String] - Allowed encryption ciphers
- `macs`: List[String] - Allowed MAC algorithms
- `kex_algorithms`: List[String] - Key exchange algorithms

**Validation Rules**:
- `ssh_port` must be between 1-65535
- `password_authentication` must be false for external access
- `protocol` must be 2
- `allowed_users` must not be empty
- Ciphers, MACs, and KEX algorithms must be from approved secure list

**State Transitions**:
1. Initial: Default Proxmox SSH config (password auth enabled)
2. Configured: Hardened config applied, password auth disabled
3. Active: SSH service restarted, new config in effect

**Managed By**: Ansible template `roles/proxmox/templates/sshd_config.j2`

**Persisted In**: `/etc/ssh/sshd_config` on Proxmox host

---

### 2. Fail2ban Jail Configuration

**Purpose**: Define brute force protection rules for SSH

**Attributes**:
- `enabled`: Boolean - Jail is active (true)
- `port`: String - Port to monitor (matches SSH port, e.g., "22,2222")
- `filter`: String - Log pattern filter (default: "sshd")
- `logpath`: String - Path to auth logs (default: "/var/log/auth.log")
- `backend`: String - Log monitoring backend (default: "systemd")
- `maxretry`: Integer - Failed attempts before ban (default: 5)
- `findtime`: Integer (seconds) - Window for counting failures (default: 600)
- `bantime`: Integer (seconds) - Duration of ban (default: 3600)
- `ignoreip`: List[String] - Whitelisted IPs/networks (default: ["127.0.0.1/8", "192.168.0.0/16"])

**Validation Rules**:
- `maxretry` must be > 0 and < 20
- `findtime` must be >= 60 seconds
- `bantime` must be >= findtime
- `ignoreip` must include localhost
- `port` must match SSH daemon port

**State Transitions**:
1. Initial: fail2ban not installed
2. Installed: fail2ban package installed, default config
3. Configured: Custom SSH jail configured
4. Active: fail2ban service running, monitoring SSH

**Managed By**: Ansible template `roles/proxmox/templates/fail2ban-sshd.conf.j2`

**Persisted In**: `/etc/fail2ban/jail.d/sshd.conf` on Proxmox host

---

### 3. DNS Record Configuration

**Purpose**: Map viljo.se domain to external IP address

**Attributes**:
- `domain`: String - Domain name (e.g., "viljo.se")
- `record_type`: String - DNS record type (A)
- `ttl`: Integer (seconds) - Time to live (300)
- `value`: String - Current external IP address
- `last_updated`: Timestamp - When IP was last updated

**Validation Rules**:
- `domain` must be valid FQDN format
- `record_type` must be "A"
- `ttl` must be between 60-86400 seconds (recommend 300)
- `value` must be valid IPv4 address
- `value` must be reachable/pingable

**State Transitions**:
1. Initial: DNS record does not exist or points to old IP
2. Created: A record created via Loopia API
3. Updated: IP address updated when external IP changes
4. Propagated: DNS resolvers worldwide have new value

**Managed By**: Ansible role `loopia_ddns` (existing)

**Persisted In**: Loopia DNS servers (external)

---

### 4. Port Forwarding Rule

**Purpose**: Route external SSH traffic to Proxmox host

**Attributes**:
- `external_port`: Integer - Port exposed on router WAN (e.g., 2222)
- `internal_ip`: String - Proxmox host IP (192.168.1.3)
- `internal_port`: Integer - SSH port on Proxmox (22)
- `protocol`: String - Network protocol (TCP)
- `enabled`: Boolean - Rule is active (true)
- `description`: String - Human-readable label (e.g., "Proxmox SSH Access")

**Validation Rules**:
- `external_port` must be 1-65535, not used by other services
- `internal_ip` must be valid IPv4 in local network range
- `internal_port` must match SSH daemon port
- `protocol` must be "TCP"
- `internal_ip` should have static DHCP reservation

**State Transitions**:
1. Initial: No port forwarding configured
2. Configured: Rule created in router
3. Active: Traffic is being forwarded
4. Persistent: Rule survives router reboots

**Managed By**: Manual configuration OR Ansible role `firewall` (if router supports API)

**Persisted In**: Router/firewall configuration (device-dependent)

---

### 5. SSH Authorized Keys

**Purpose**: Define which public keys can authenticate to Proxmox host

**Attributes**:
- `username`: String - System user (e.g., "root")
- `keys`: List[SSHKey] - Authorized public keys
  - `SSHKey.type`: String - Key type (ssh-ed25519, ssh-rsa)
  - `SSHKey.public_key`: String - Base64-encoded public key
  - `SSHKey.comment`: String - Key identifier (e.g., "admin@laptop")
  - `SSHKey.added_date`: Timestamp - When key was added
  - `SSHKey.owner`: String - Person who owns this key

**Validation Rules**:
- `username` must exist on Proxmox host
- Each `SSHKey.type` must be from approved list (prefer ed25519)
- `SSHKey.public_key` must be valid base64 format
- Minimum 1 authorized key must exist
- No duplicate keys allowed

**State Transitions**:
1. Initial: Default Proxmox root key (if any)
2. Configured: Administrator keys added via Ansible
3. Active: Keys in authorized_keys file, authentication working
4. Rotated: Old keys removed, new keys added (annual maintenance)

**Managed By**: Ansible template `roles/proxmox/templates/authorized_keys.j2`

**Persisted In**: `/root/.ssh/authorized_keys` on Proxmox host

---

### 6. Connection Audit Log Entry

**Purpose**: Record SSH connection attempts for security monitoring

**Attributes** (logged, not configured):
- `timestamp`: DateTime - When connection occurred
- `source_ip`: String - Client IP address
- `username`: String - Attempted username
- `auth_method`: String - Authentication method used (publickey, password)
- `outcome`: Enum (success, failure) - Connection result
- `session_id`: String - Unique session identifier
- `disconnect_time`: DateTime (optional) - When session ended
- `fail2ban_action`: String (optional) - Ban action taken (if applicable)

**Validation Rules**:
- All fields except disconnect_time and fail2ban_action are required
- `source_ip` must be valid IPv4/IPv6
- `outcome` must be success or failure
- Logs must be retained for 90 days minimum

**State Transitions**:
1. Connection Attempt: Log entry created
2. Authenticated: Outcome recorded
3. Session Active: Session ID tracked
4. Disconnected: Disconnect time recorded
5. Archived: Log rotated after retention period

**Managed By**: OpenSSH daemon (sshd) and fail2ban

**Persisted In**: `/var/log/auth.log`, journald, and Wazuh SIEM (if available)

## Entity Relationships

```
DNS Record (viljo.se → External IP)
    ↓ resolves to
Router WAN Interface (External IP)
    ↓ forwards via
Port Forwarding Rule (External Port → 192.168.1.3:22)
    ↓ routes to
SSH Daemon Config (192.168.1.3:22)
    ↓ authenticates via
SSH Authorized Keys (public key verification)
    ↓ creates
Connection Audit Log Entry (success/failure)
    ↑ monitored by
Fail2ban Jail Config (bans brute force attackers)
```

## Configuration Dependencies

1. **DNS Record** depends on:
   - Loopia DDNS service (updates external IP)
   - Router WAN interface (provides external IP)

2. **Port Forwarding Rule** depends on:
   - Router/firewall capability
   - Proxmox host reachability (192.168.1.3)
   - SSH Daemon being active

3. **SSH Daemon Config** depends on:
   - OpenSSH package installed
   - SSH Authorized Keys configured
   - Firewall allowing port 22 internally

4. **Fail2ban Jail Config** depends on:
   - fail2ban package installed
   - SSH Daemon generating logs
   - systemd-journald running

5. **SSH Authorized Keys** depends on:
   - User accounts existing
   - .ssh directory with correct permissions (700)
   - authorized_keys file with correct permissions (600)

6. **Connection Audit Logs** depend on:
   - SSH Daemon LogLevel set to VERBOSE
   - syslog/journald running
   - Log rotation configured

## Ansible Variable Mapping

These configuration entities map to Ansible variables in `roles/proxmox/defaults/main.yml`:

```yaml
# SSH Daemon Configuration
proxmox_ssh_port: 22  # Internal port
proxmox_ssh_external_port: 2222  # External port (for docs/firewall)
proxmox_ssh_permit_root_login: "without-password"
proxmox_ssh_password_auth: false
proxmox_ssh_pubkey_auth: true
proxmox_ssh_allowed_users: ["root"]
proxmox_ssh_client_alive_interval: 300
proxmox_ssh_client_alive_count_max: 3

# Fail2ban Configuration
proxmox_fail2ban_enabled: true
proxmox_fail2ban_maxretry: 5
proxmox_fail2ban_findtime: 600
proxmox_fail2ban_bantime: 3600
proxmox_fail2ban_ignoreip: ["127.0.0.1/8", "192.168.0.0/16"]

# DNS Configuration (loopia_ddns role)
loopia_domain: "viljo.se"
loopia_dns_ttl: 300
loopia_update_interval: 300  # 5 minutes

# Port Forwarding (manual or firewall role)
router_port_forward_external: 2222
router_port_forward_internal_ip: "192.168.1.3"
router_port_forward_internal_port: 22

# SSH Keys (encrypted in vault)
proxmox_ssh_authorized_keys:
  - type: "ssh-ed25519"
    key: "{{ vault_admin_ssh_key }}"
    comment: "admin@workstation"
```

## State Management

All configuration entities are managed as **declarative state** via Ansible:

- **Idempotency**: Running playbook multiple times produces same result
- **Convergence**: Ansible ensures actual state matches desired state
- **Rollback**: Previous configurations backed up before changes
- **Validation**: Config syntax checked before service restart (e.g., `sshd -t`)

## Testing Strategy

Each entity should be validated after configuration:

1. **SSH Daemon Config**: `sshd -t` (syntax check), attempt connection
2. **Fail2ban Jail**: `fail2ban-client status sshd` (verify active)
3. **DNS Record**: `dig viljo.se` (verify A record)
4. **Port Forwarding**: External connectivity test from outside network
5. **SSH Authorized Keys**: SSH connection with key authentication
6. **Audit Logs**: Verify entries in `/var/log/auth.log`
