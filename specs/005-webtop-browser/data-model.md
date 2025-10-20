# Data Model: Webtop Browser Instance

**Phase**: 1 (Design & Contracts)
**Date**: 2025-10-20
**Feature**: Browser-accessible Linux desktop environment

## Entity Definitions

### 1. Webtop Container (LXC)

**Purpose**: LXC container hosting Docker and the webtop desktop environment

**Attributes**:
- `container_id` (integer): Proxmox CT ID (e.g., 2400)
- `hostname` (string): Container hostname (e.g., "webtop")
- `ip_address` (IPv4): Static IP on DMZ network (e.g., 172.16.10.70)
- `netmask` (integer): Network subnet mask (e.g., 24)
- `gateway` (IPv4): Default gateway (e.g., 172.16.10.1)
- `bridge` (string): Network bridge interface (e.g., "vmbr3")
- `memory_mb` (integer): RAM allocation in MB (e.g., 4096)
- `cpu_cores` (integer): CPU core count (e.g., 2)
- `disk_gb` (integer): Root disk size in GB (e.g., 20)
- `swap_mb` (integer): Swap allocation in MB (e.g., 2048)
- `storage_pool` (string): Proxmox storage backend (e.g., "local-zfs")
- `onboot` (boolean): Auto-start on host boot (true)
- `unprivileged` (boolean): Unprivileged container flag (true)
- `nesting` (boolean): Docker nesting support (true)
- `fuse` (boolean): FUSE filesystem support (true)

**State Transitions**:
```
[Created] → [Stopped] → [Running] → [Stopped] → [Destroyed]
                ↓            ↑
                └────────────┘
                  (restart)
```

**Validation Rules**:
- `container_id` must be unique across Proxmox cluster
- `ip_address` must not conflict with existing DMZ assignments
- `memory_mb` >= 2048 (minimum for desktop environment)
- `cpu_cores` >= 1
- `unprivileged` must be true (constitutional security requirement)

**Relationships**:
- Deployed on: Proxmox Host
- Registered in: NetBox (CMDB)
- Monitored by: Zabbix
- Backed up by: PBS (Proxmox Backup Server)

---

### 2. Webtop Docker Container

**Purpose**: Docker container running LinuxServer.io webtop image with KasmVNC and XFCE

**Attributes**:
- `container_name` (string): Docker container identifier (e.g., "webtop")
- `image` (string): Docker image reference (e.g., "linuxserver/webtop:debian-xfce")
- `web_port` (integer): KasmVNC web interface port (default: 3000)
- `vnc_port` (integer): VNC protocol port (default: 3001)
- `environment_variables` (map): Configuration key-value pairs
  - `PUID` (integer): User ID for file permissions (e.g., 1000)
  - `PGID` (integer): Group ID for file permissions (e.g., 1000)
  - `TZ` (string): Timezone (e.g., "Europe/Stockholm")
  - `CUSTOM_USER` (string): Initial username (from Ansible Vault)
  - `CUSTOM_PASSWORD` (string): Initial password (from Ansible Vault)
  - `SUBFOLDER` (string): URL subfolder (default: "/")
  - `TITLE` (string): Browser tab title (e.g., "Webtop - browser.viljo.se")
- `volumes` (list): Persistent volume mounts
  - `/var/lib/webtop/config:/config` (desktop settings persistence)
  - `/var/lib/webtop/data:/data` (user home directories)
- `restart_policy` (string): Container restart behavior (e.g., "unless-stopped")
- `network_mode` (string): Docker network mode (e.g., "bridge")

**State Transitions**:
```
[Image Pulled] → [Created] → [Running] → [Stopped] → [Removed]
                      ↓           ↑
                      └───────────┘
                       (restart)
```

**Validation Rules**:
- `web_port` must not conflict with other services in LXC
- `CUSTOM_PASSWORD` must be encrypted in Ansible Vault
- `volumes` must map to existing directories on LXC host
- `restart_policy` should be "unless-stopped" for auto-recovery

**Relationships**:
- Runs inside: Webtop Container (LXC)
- Exposed via: Traefik Route
- Monitored by: Zabbix (Docker container health)

---

### 3. Traefik Route

**Purpose**: Reverse proxy routing configuration for HTTPS access to webtop

**Attributes**:
- `rule` (string): Routing rule (e.g., "Host(`browser.viljo.se`)")
- `entrypoint` (string): Traefik entrypoint (e.g., "websecure")
- `service_name` (string): Traefik service identifier (e.g., "webtop")
- `service_port` (integer): Backend service port (e.g., 3000)
- `tls_enabled` (boolean): TLS termination enabled (true)
- `cert_resolver` (string): Certificate resolver name (e.g., "letsencrypt")
- `middleware` (list): Applied middlewares (e.g., ["redirect-to-https"])

**Auto-Discovery via Docker Labels**:
```yaml
traefik.enable: "true"
traefik.http.routers.webtop.rule: "Host(`browser.viljo.se`)"
traefik.http.routers.webtop.entrypoints: "websecure"
traefik.http.routers.webtop.tls.certresolver: "letsencrypt"
traefik.http.services.webtop.loadbalancer.server.port: "3000"
```

**Validation Rules**:
- `rule` must specify valid domain (DNS A record must exist)
- `service_port` must match webtop container exposed port
- `cert_resolver` must be configured in Traefik static config

**Relationships**:
- Routes to: Webtop Docker Container (port 3000)
- Managed by: Traefik reverse proxy
- Certificate from: Let's Encrypt (via Traefik)

---

### 4. User Session

**Purpose**: Individual desktop session for authenticated user

**Attributes**:
- `session_id` (UUID): Unique session identifier
- `username` (string): Authenticated user identifier
- `connection_time` (timestamp): Session start time
- `last_activity` (timestamp): Last user interaction timestamp
- `display_resolution` (string): Browser window resolution (e.g., "1920x1080")
- `clipboard_data` (text): Synchronized clipboard content
- `session_state` (enum): Current state (active, idle, disconnected)
- `idle_timeout_seconds` (integer): Inactivity timeout (e.g., 3600)

**State Transitions**:
```
[Authenticated] → [Active] → [Idle] → [Timeout] → [Terminated]
                     ↓          ↑
                     └──────────┘
                   (user activity)
```

**Validation Rules**:
- `username` must exist in authentication provider (LDAP or local)
- `idle_timeout_seconds` must be > 0
- `session_state` transitions follow state machine rules

**Relationships**:
- Authenticated via: Authentication Provider (LDAP/local)
- Persisted in: User Data Volume
- Managed by: KasmVNC session manager

---

### 5. Persistent Volume

**Purpose**: Storage for user data, desktop configurations, and application state

**Attributes**:
- `mount_path_host` (path): LXC host directory (e.g., "/var/lib/webtop/config")
- `mount_path_container` (path): Docker container mount (e.g., "/config")
- `size_gb` (integer): Allocated storage size
- `owner_uid` (integer): File ownership UID (e.g., 1000)
- `owner_gid` (integer): File ownership GID (e.g., 1000)
- `permissions` (octal): Directory permissions (e.g., 0755)

**Directory Structure**:
```
/var/lib/webtop/
├── config/
│   ├── .config/           # XFCE configuration
│   ├── .local/            # Application data
│   └── Desktop/           # Desktop shortcuts
├── data/
│   └── username/
│       ├── Documents/
│       ├── Downloads/
│       └── Projects/
└── logs/
    ├── kasmvnc.log
    └── supervisor.log
```

**Validation Rules**:
- `mount_path_host` must exist on LXC filesystem
- `owner_uid` and `owner_gid` must match webtop container user
- `size_gb` must have sufficient free space on LXC storage

**Relationships**:
- Mounted in: Webtop Docker Container
- Backed up by: PBS (via LXC container backup)
- Contains: User Session data

---

### 6. Authentication Provider

**Purpose**: Identity verification for webtop access

**Attributes** (LDAP Integration):
- `ldap_uri` (string): LDAP server URI (e.g., "ldap://ldap.infra.local:389")
- `ldap_base_dn` (string): Search base (e.g., "dc=infra,dc=local")
- `ldap_bind_dn` (string): Service account DN (from Ansible Vault)
- `ldap_bind_password` (string): Service account password (from Ansible Vault)
- `ldap_user_filter` (string): User search filter (e.g., "(uid=%s)")
- `ldap_attribute_username` (string): Username attribute (e.g., "uid")

**Attributes** (Built-in Authentication):
- `username` (string): Local username (from Ansible Vault)
- `password_hash` (string): Hashed password (from Ansible Vault)

**Authentication Flow**:
```
User → Webtop Login Page → Authentication Provider → Session Created
                                    ↓
                            [LDAP Bind + Search]
                                    ↓
                            [Valid] / [Invalid]
```

**Validation Rules**:
- LDAP credentials must be encrypted in Ansible Vault
- LDAP URI must be reachable from DMZ network
- User filter must return unique user records

**Relationships**:
- Validates: User Session credentials
- Integrated with: Infrastructure LDAP server
- Configured via: Docker environment variables

---

## Data Relationships Diagram

```
┌──────────────────────┐
│   Proxmox Host       │
│                      │
│  ┌────────────────┐  │
│  │ Webtop LXC     │  │
│  │ (CT 2400)      │  │      ┌─────────────────┐
│  │                │  │      │  Traefik Proxy  │
│  │  ┌──────────┐  │  │      │  (DMZ)          │
│  │  │ Docker   │  │  │      │                 │
│  │  │          │  │  │      │  Routes:        │
│  │  │ Webtop   │◄─┼──┼──────┤  browser.viljo  │◄─── Internet
│  │  │ Container│  │  │      │  .se → :3000    │
│  │  └────┬─────┘  │  │      │                 │
│  │       │        │  │      │  Let's Encrypt  │
│  │       ▼        │  │      │  Cert           │
│  │  ┌──────────┐  │  │      └─────────────────┘
│  │  │ Volumes  │  │  │
│  │  │ /var/lib/│  │  │
│  │  │ webtop   │  │  │
│  │  └──────────┘  │  │
│  └────────────────┘  │
└──────────────────────┘
         │
         ▼
┌─────────────────────┐       ┌──────────────────┐
│  NetBox (CMDB)      │       │  LDAP Server     │
│  - IP: 172.16.10.70 │       │  - Auth Provider │
│  - CT ID: 2400      │       │  - User Validation│
└─────────────────────┘       └──────────────────┘
         │
         ▼
┌─────────────────────┐
│  PBS Backup Server  │
│  - Daily LXC backup │
│  - User data        │
└─────────────────────┘
```

## Entity Lifecycle Management

### Create Workflow
1. Create LXC container on Proxmox host
2. Install Docker inside LXC container
3. Create persistent volume directories
4. Deploy webtop Docker container with environment config
5. Register container in NetBox CMDB
6. Configure Zabbix monitoring
7. Verify Traefik route auto-discovery

### Update Workflow
1. Pull new webtop Docker image
2. Stop current webtop container
3. Start new container (volumes persist data)
4. Verify connectivity and session restoration
5. Update NetBox metadata if configuration changed

### Destroy Workflow
1. Stop webtop Docker container
2. Backup persistent volumes (final snapshot)
3. Stop LXC container
4. Remove LXC container from Proxmox
5. Remove NetBox entry
6. Remove Zabbix monitoring
7. Archive backup to long-term storage

## Constraints & Invariants

### Infrastructure Constraints
- LXC container must remain unprivileged (security requirement)
- Only one webtop instance per LXC container
- DMZ network isolation (no direct management network access)
- HTTPS-only external access (no HTTP allowed)

### Data Constraints
- User session data must persist across container restarts
- Clipboard synchronization limited to text data (no binary files)
- Maximum session idle time: 1 hour (configurable)
- Minimum password length: 12 characters (LDAP policy enforced)

### Performance Constraints
- Desktop load time: <10 seconds from authentication
- Input latency: <100ms for mouse/keyboard
- Frame rate: minimum 30fps for typical desktop use
- Concurrent users: maximum 5 per instance

## Security Considerations

### Data Protection
- All credentials stored in Ansible Vault (encrypted at rest)
- TLS termination at Traefik (encrypted in transit)
- User home directories isolated per session
- No persistent clipboard history (cleared on session end)

### Access Control
- Authentication required before desktop access
- No anonymous/guest sessions permitted
- Session timeout enforced after idle period
- Container runs as non-root user (UID 1000)

### Network Security
- No direct internet exposure (Traefik proxy only)
- Firewall rules limit LXC port 3000 to Traefik source
- DMZ network segmentation prevents access to management network
- Outbound internet from desktop environment allowed (per specification)
