# Research: Webtop Browser Instance

**Phase**: 0 (Outline & Research)
**Date**: 2025-10-20
**Feature**: Browser-accessible Linux desktop environment

## Research Questions & Decisions

### 1. Webtop Implementation Choice

**Decision**: Use LinuxServer.io Webtop Docker image running inside unprivileged LXC container

**Rationale**:
- LinuxServer.io maintains official, well-documented Webtop images with KasmVNC
- Pre-configured desktop environments (XFCE, KDE, i3, etc.) available as image variants
- Active community support and regular security updates
- Proven production-ready solution used by thousands of deployments
- Built-in authentication support (username/password, LDAP integration)
- Docker-in-LXC pattern already established in existing infrastructure roles

**Alternatives Considered**:
- **Bare LXC with manual VNC setup**: Rejected - requires extensive custom configuration, less maintainable
- **KVM VM with full desktop OS**: Rejected - higher resource overhead, slower provisioning, unnecessary for use case
- **Apache Guacamole**: Rejected - more complex architecture (database requirement, separate gateway), overkill for single desktop instance
- **NoVNC + TigerVNC**: Rejected - LinuxServer.io Webtop provides better performance with KasmVNC and pre-built integration

**References**:
- LinuxServer.io Webtop documentation: https://docs.linuxserver.io/images/docker-webtop/
- KasmVNC performance benchmarks show 60fps capability at 1080p
- Existing demo_site role demonstrates Docker-in-LXC pattern

### 2. Desktop Environment Selection

**Decision**: XFCE desktop environment (linuxserver/webtop:debian-xfce)

**Rationale**:
- Lightweight resource footprint (critical for 2GB RAM constraint)
- Proven stability and performance in VNC/remote access scenarios
- Familiar UI for users accustomed to traditional desktop layouts
- Excellent balance between features and resource usage
- Well-supported by LinuxServer.io with regular updates

**Alternatives Considered**:
- **KDE Plasma**: Rejected - higher resource requirements (3-4GB RAM recommended)
- **i3 (tiling WM)**: Rejected - steep learning curve for non-technical users
- **MATE**: Considered - similar to XFCE but less optimized for remote access
- **LXDE/LXQt**: Considered - very lightweight but fewer features than XFCE

**Performance Impact**:
- XFCE typically uses 300-500MB RAM idle
- Leaves 1.5GB available for user applications
- Meets <10s load time requirement (typical XFCE boot: 5-7 seconds)

### 3. Authentication Strategy

**Decision**: Multi-tier authentication approach
1. **Phase 1**: Built-in username/password authentication (webtop native)
2. **Phase 2**: LDAP integration with existing infrastructure LDAP server
3. **Phase 3** (future): Traefik ForwardAuth with Keycloak OIDC

**Rationale**:
- Phase 1 allows immediate deployment and testing
- LDAP integration provides centralized credential management (constitutional requirement)
- Webtop natively supports LDAP via environment variables (CUSTOM_USER, CUSTOM_PASSWORD, LDAP_* vars)
- ForwardAuth provides SSO across all infrastructure services (future enhancement)

**Implementation Details**:
- Initial: Single admin user credentials in Ansible Vault
- LDAP: Bind to existing LDAP server (ldap.infra.local), search base for user validation
- Environment variables passed via docker-compose.yml template

### 4. Persistent Storage Strategy

**Decision**: Bind mount LXC host directory to Docker container /config volume

**Rationale**:
- Survives Docker container recreation (idempotent deployments)
- Easy backup via PBS (LXC container includes all user data)
- No Docker volume management complexity
- Follows existing pattern in infrastructure

**Directory Structure**:
```
/var/lib/webtop/
├── config/              # Desktop settings, panel configurations
├── data/                # User home directories
│   └── username/
│       ├── Desktop/
│       ├── Documents/
│       └── Downloads/
└── logs/                # Application and VNC logs
```

**Backup Strategy**:
- PBS backs up entire LXC container daily
- User data survives container destruction and recreation
- No separate volume backup strategy needed

### 5. Network Configuration

**Decision**: DMZ network (vmbr3) with Traefik reverse proxy access

**IP Allocation**: 172.16.10.70/24 (next available in DMZ range)
**Internal Port**: 3000 (KasmVNC web interface)
**External Access**: https://browser.viljo.se → Traefik → webtop:3000

**Rationale**:
- Matches specification requirement (DMZ network deployment)
- Traefik handles TLS termination (Let's Encrypt certificates)
- No direct internet exposure of webtop container
- Firewall rules limit access to port 3000 from Traefik only

**Network Flow**:
```
Internet → Firewall LXC:443 → Traefik (DMZ):443 → Webtop LXC:3000
```

### 6. Resource Allocation

**Decision**:
- **RAM**: 4GB (exceeds 2GB minimum, allows comfortable multi-application usage)
- **CPU**: 2 cores (meets minimum, sufficient for desktop responsiveness)
- **Disk**: 20GB (OS + desktop apps + user data storage)
- **Swap**: 2GB (handles memory spikes during heavy application usage)

**Rationale**:
- 4GB RAM provides headroom for browser (Firefox/Chromium) memory usage
- 20GB disk allows installation of development tools, office applications
- Meets all success criteria (5 concurrent users via multi-session support)

**Scaling Consideration**:
- For >5 concurrent users, consider separate webtop instances or higher resource allocation
- Docker resource limits prevent container from consuming excessive host resources

### 7. LXC Container Configuration

**Decision**: Unprivileged LXC with Docker nesting enabled

**Configuration Flags**:
```yaml
features:
  nesting: 1              # Required for Docker-in-LXC
  fuse: 1                 # Allows FUSE filesystems in desktop
onboot: 1                 # Auto-start container on Proxmox boot
```

**Security Considerations**:
- Unprivileged container runs as UID/GID 100000+ on host
- AppArmor profile limits system call access
- No direct hardware access (no GPU passthrough in Phase 1)
- Docker daemon isolated within container namespace

**Compliance**: Meets SR-003 (minimal privileges) and constitutional security requirements

### 8. Traefik Integration Pattern

**Decision**: Docker labels on webtop container for automatic Traefik discovery

**Traefik Labels** (applied via docker-compose template):
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.webtop.rule=Host(`browser.viljo.se`)"
  - "traefik.http.routers.webtop.entrypoints=websecure"
  - "traefik.http.routers.webtop.tls.certresolver=letsencrypt"
  - "traefik.http.services.webtop.loadbalancer.server.port=3000"
```

**Rationale**:
- Traefik automatically detects labeled containers via Docker socket
- No manual Traefik configuration file edits required
- Automatic Let's Encrypt certificate provisioning
- Follows existing pattern used by other infrastructure services

**Requirement**: Traefik must have access to Docker socket in webtop LXC (via network or socket sharing)

### 9. Testing Strategy

**Decision**: Multi-layer testing approach

**Layers**:
1. **Syntax Testing**: ansible-lint, yamllint (CI/CD pipeline)
2. **Role Testing**: Molecule with Docker driver (verify task execution)
3. **Integration Testing**: Deploy to staging Proxmox host, verify connectivity
4. **Acceptance Testing**: Manual verification of user stories (browser access, desktop functionality)

**Automated Checks**:
- LXC container exists and running
- Docker service active inside container
- Webtop container running and healthy
- Port 3000 accessible from Traefik
- HTTPS cert valid for browser.viljo.se

**Manual Acceptance**:
- Navigate to browser.viljo.se, authenticate
- Open 3 application types (terminal, file manager, browser)
- Verify clipboard copy/paste functionality
- Test session persistence (disconnect, reconnect)

### 10. Backup & Disaster Recovery

**Decision**: PBS (Proxmox Backup Server) integration via existing backup role

**Backup Scope**:
- Full LXC container backup (includes Docker images, volumes, configuration)
- Daily backup schedule (aligned with other DMZ services)
- 7-day retention for daily backups
- 4-week retention for weekly backups

**Recovery Process**:
1. Restore LXC container from PBS
2. Start container (Docker auto-starts webtop via compose)
3. Verify Traefik routing (automatic re-detection via labels)
4. User data immediately available (persistent volumes included in backup)

**RTO**: <30 minutes (restore LXC + verify connectivity)
**RPO**: 24 hours (daily backup window)

## Technology Stack Summary

| Component | Technology | Version |
|-----------|-----------|---------|
| Container Runtime | LXC (unprivileged) | Proxmox 8.x |
| Orchestration | Ansible | 2.15+ |
| Desktop Container | LinuxServer.io Webtop | latest (Debian-based) |
| Desktop Environment | XFCE | 4.18+ |
| VNC Server | KasmVNC | Bundled with Webtop |
| Reverse Proxy | Traefik | 2.x |
| TLS Certificates | Let's Encrypt | via Traefik |
| Authentication | LDAP | (Phase 2) |
| Backup | Proxmox Backup Server | Existing infrastructure |
| Monitoring | Zabbix | Docker container template |

## Open Questions (Resolved)

None - all technical decisions finalized based on specification requirements and infrastructure constraints.

## Next Steps

Phase 1 deliverables:
1. Create data-model.md (entity definitions)
2. Generate contracts/ (API schemas for Traefik, LDAP integration points)
3. Write quickstart.md (deployment instructions)
4. Update agent context with new technologies
