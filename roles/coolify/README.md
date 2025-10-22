# Role: coolify

## Purpose

Deploys Coolify v4, a self-hosted Platform-as-a-Service (PaaS) alternative to Heroku, Netlify, and Vercel, as a Docker-based application running in an LXC container on Proxmox VE.

Coolify provides:
- One-click application deployments (Git-based)
- Docker and Docker Compose support
- Database management (PostgreSQL, MySQL, MongoDB, Redis, etc.)
- Automated SSL certificates
- Built-in CI/CD pipelines
- Resource monitoring and management
- Multi-server support
- API-driven automation

This role is part of the DevOps platform tier and enables self-hosted application deployment and management.

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

#### Container Configuration
- `coolify_container_id: 66` - LXC container ID (matches IP last octet)
- `coolify_hostname: coolify` - Container hostname
- `coolify_domain: viljo.se` - Public domain name
- `coolify_memory: 4096` - RAM allocation in MB (4GB recommended for production)
- `coolify_cores: 2` - CPU core allocation
- `coolify_disk: 64` - Root filesystem size in GB
- `coolify_swap: 2048` - Swap size in MB

#### Network Configuration
- `coolify_bridge: vmbr3` - Network bridge (public DMZ)
- `coolify_ip_address: 172.16.10.66` - Static IP address
- `coolify_gateway: 172.16.10.1` - Default gateway (firewall)
- `coolify_dns_servers: [172.16.10.1, 1.1.1.1]` - DNS resolvers

#### Application Configuration
- `coolify_version: 4` - Coolify major version
- `coolify_service_port: 8000` - External HTTP port for web interface
- `coolify_internal_port: 8080` - Internal application port
- `coolify_compose_path: /opt/coolify` - Docker Compose directory
- `coolify_data_path: /data/coolify` - Application data directory

#### Security (Vault Variables)
- `vault_coolify_root_password` - Container root password
- `vault_coolify_postgres_password` - PostgreSQL database password
- `vault_coolify_redis_password` - Redis cache password
- `vault_coolify_app_id` - Application ID for authentication
- `vault_coolify_app_key` - Laravel application key
- `vault_coolify_pusher_app_secret` - Pusher/Soketi secret for real-time features

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)

**External Services:**
- PostgreSQL 16 (embedded in Docker Compose stack)
- Redis 7 (embedded in Docker Compose stack)
- Soketi (embedded in Docker Compose stack for real-time features)

**Container Requirements:**
- Docker Engine with Docker Compose plugin
- Unprivileged LXC container with nesting feature enabled
- Docker socket access for managing deployed applications

**Vault Variables:**
All sensitive variables must be defined in `inventory/group_vars/all/secrets.yml`:
```yaml
vault_coolify_root_password: "secure-password"
vault_coolify_postgres_password: "secure-db-password"
vault_coolify_redis_password: "secure-redis-password"
vault_coolify_app_id: "coolify-app-id"
vault_coolify_app_key: "base64:generated-laravel-key"
vault_coolify_pusher_app_secret: "random-pusher-secret"
```

**Related Roles:**
- `roles/firewall` - Provides network gateway and routing
- `roles/traefik` - Reverse proxy for HTTPS termination

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox_admin
  roles:
    - role: coolify
```

All configuration uses sensible defaults. Only vault secrets need to be defined.

### Advanced Configuration

```yaml
- hosts: proxmox_admin
  roles:
    - role: coolify
      vars:
        coolify_memory: 8192
        coolify_cores: 4
        coolify_disk: 128
        coolify_env_extra:
          APP_DEBUG: "false"
```

## Deployment Process

This role performs the following steps:

1. **Template Management**
   - Ensures template cache directory exists
   - Downloads Debian 13 LXC template (cached, idempotent)

2. **Container Creation**
   - Creates unprivileged LXC container with ID 66
   - Configures network with static IP 172.16.10.66
   - Allocates 2 CPU cores, 4GB RAM, 64GB disk
   - Enables nesting feature for Docker support

3. **Container Configuration**
   - Sets onboot flag for automatic startup
   - Configures DNS servers
   - Starts container and waits for boot completion
   - Sets root password

4. **Service Installation** (guarded by provisioning marker)
   - Installs Docker Engine and Docker Compose plugin
   - Creates compose directory `/opt/coolify`
   - Creates data directory `/data/coolify/source`
   - Deploys docker-compose.yml with Coolify stack

5. **Stack Components**
   - PostgreSQL 16 container for database
   - Redis 7 container for caching and queues
   - Soketi container for real-time WebSocket features
   - Coolify main application container

6. **Provisioning Marker**
   - Creates `/etc/coolify/.provisioned` marker
   - Prevents re-installation on subsequent runs

## Idempotency

This role is fully idempotent and safe to re-run:

- **Container Creation**: Uses `creates` guard to skip if container exists
- **Template Download**: Uses `force: false` to download only if missing
- **Service Installation**: Guarded by `/etc/coolify/.provisioned` marker
- **Configuration Updates**: Docker Compose file changes trigger stack restart via handler
- **State Checks**: Container status verified before starting

Running this role multiple times will:
- Skip container creation if already exists
- Update Docker Compose configuration if changed
- Restart stack only when configuration changes
- Not re-run package installation

## Notes

### Performance Considerations

**Resource Usage:**
- Base container: ~512MB RAM (idle)
- Coolify application: ~1.5GB RAM (active)
- PostgreSQL: ~256MB RAM
- Redis: ~128MB RAM
- Soketi: ~64MB RAM
- Deployed applications: Additional resources per app
- **Total recommended: 4GB RAM minimum, 8GB for production**

**Storage:**
- PostgreSQL database for application metadata
- Docker volumes for deployed applications
- Source code and build artifacts
- 64GB disk recommended for multiple applications

**Network:**
- Web UI: HTTP on port 8000 (reverse proxy recommended)
- Soketi WebSockets: port 6001 (internal)
- API: Same port as web UI, `/api/` endpoint
- Deployed applications: Additional ports as needed

### Security

**Container Security:**
- Unprivileged LXC container (user namespace isolation)
- Nesting feature required for Docker (security trade-off accepted)
- Docker socket mounted (required for app deployment)
- No direct internet access (routes through firewall)

**Application Security:**
- Strong APP_KEY required (Laravel application key)
- PostgreSQL database isolated within container
- Redis password protected
- Soketi authentication via app ID and secret
- HTTPS strongly recommended (use Traefik reverse proxy)
- SSH key management for Git deployments

**Vault Integration:**
All secrets stored in Ansible Vault:
- Database passwords
- Redis password
- Application keys
- Pusher/Soketi secrets

**Important Security Note:**
After deployment, immediately create your admin account by accessing the Coolify web interface. If someone else accesses the registration page before you, they might gain full control of your server.

### Troubleshooting

**Container won't start:**
```bash
pct status 66
pct start 66
journalctl -u pve-container@66
```

**Check Docker services:**
```bash
pct exec 66 -- bash -lc "docker ps"
pct exec 66 -- bash -lc "cd /opt/coolify && docker compose logs -f"
```

**Check Coolify application logs:**
```bash
pct exec 66 -- bash -lc "cd /opt/coolify && docker compose logs -f coolify"
```

**Database issues:**
```bash
pct exec 66 -- bash -lc "cd /opt/coolify && docker compose logs postgres"
```

**WebSocket/real-time issues:**
```bash
pct exec 66 -- bash -lc "cd /opt/coolify && docker compose logs soketi"
```

**Reset and redeploy:**
```bash
pct stop 66
pct destroy 66
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags coolify
```

**Access Coolify container:**
```bash
pct enter 66
```

### Rollback Procedure

To rollback Coolify deployment:

1. Stop and remove container:
   ```bash
   pct stop 66
   pct destroy 66
   ```

2. Remove from inventory/playbooks if added

3. Update container-mapping.md status back to "Planned"

4. Clean vault secrets (optional):
   ```bash
   ansible-vault edit inventory/group_vars/all/secrets.yml
   # Remove coolify variables
   ```

### Known Limitations

- Coolify requires PostgreSQL, Redis, and Soketi (all included in stack)
- Docker socket access required (security consideration)
- First user to register becomes admin (secure immediately after deployment)
- Embedded databases not shared with other services
- HTTPS requires external reverse proxy (Traefik recommended)
- Applications deployed by Coolify consume additional resources
- Multi-server feature requires additional configuration

## Integration

### Traefik Reverse Proxy

Add to `inventory/group_vars/all/main.yml`:

```yaml
traefik_services:
  - name: coolify
    host: coolify.viljo.se
    container_id: 66
    port: 8000
    scheme: http
```

### DNS Configuration

Add to Loopia DNS records:

```yaml
loopia_dns_records:
  - host: coolify
    type: A
    priority: 0
    rdata: <public-ip>
    ttl: 3600
```

### API Access

Coolify API available at:
- Internal: `http://172.16.10.66:8000/api/`
- External: `https://coolify.viljo.se/api/` (via Traefik)

API token required - generate in Coolify web UI under Settings → API Tokens.

### Initial Setup

After deployment:

1. Access Coolify at https://coolify.viljo.se
2. **Immediately** register your admin account
3. Configure server settings
4. Add Git repositories or Docker registries
5. Deploy your first application

## Use Cases

Coolify is ideal for:

- **Self-hosted PaaS**: Deploy applications without vendor lock-in
- **Development environments**: Quick staging and testing deployments
- **Small to medium applications**: Web apps, APIs, static sites
- **Containerized workloads**: Docker and Docker Compose applications
- **Database hosting**: Managed PostgreSQL, MySQL, MongoDB instances
- **CI/CD automation**: Git-based deployments with automatic builds

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ✅ **Security-First Design**: Vault-encrypted secrets, unprivileged container, password-protected services
- ✅ **Idempotent Operations**: Safe to re-run without side effects
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ✅ **Automated Operations**: Fully automated deployment and configuration

---

**Status**: ✅ Production ready

**Deployment**: Available via `ansible-playbook playbooks/site.yml --tags coolify`

**Public URL**: https://coolify.viljo.se (when Traefik configured)

**Documentation**: https://coolify.io/docs
