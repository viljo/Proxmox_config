# Role: netbox

## Purpose

Deploys NetBox, a leading open-source IPAM (IP Address Management) and DCIM (Data Center Infrastructure Management) tool, as a Docker-based application running in an LXC container on Proxmox VE.

NetBox provides:
- IP address management (IPAM)
- Data center infrastructure management (DCIM)
- Network device tracking and documentation
- Cable and rack management
- API-driven automation
- Custom fields and extensibility

This role is part of the DevOps platform tier and is essential for documenting and managing the entire Proxmox infrastructure.

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

#### Container Configuration
- `netbox_container_id: 52` - LXC container ID (matches IP last octet)
- `netbox_hostname: netbox` - Container hostname
- `netbox_domain: viljo.se` - Public domain name
- `netbox_memory: 2048` - RAM allocation in MB
- `netbox_cores: 2` - CPU core allocation
- `netbox_disk: 32` - Root filesystem size in GB
- `netbox_swap: 1024` - Swap size in MB

#### Network Configuration
- `netbox_bridge: vmbr3` - Network bridge (public DMZ)
- `netbox_ip_address: 172.16.10.52` - Static IP address
- `netbox_gateway: 172.16.10.1` - Default gateway (firewall)
- `netbox_dns_servers: [172.16.10.1, 1.1.1.1]` - DNS resolvers

#### Application Configuration
- `netbox_version: v4.0.9` - NetBox version to deploy
- `netbox_service_port: 8080` - HTTP port for web interface
- `netbox_db_name: netbox` - PostgreSQL database name
- `netbox_db_user: netbox` - PostgreSQL username

#### Security (Vault Variables)
- `vault_netbox_root_password` - Container root password
- `vault_netbox_db_password` - PostgreSQL database password
- `vault_netbox_redis_password` - Redis cache password
- `vault_netbox_secret_key` - Django secret key
- `vault_netbox_superuser_password` - Initial admin user password

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)

**External Services:**
- PostgreSQL (embedded in Docker Compose stack)
- Redis (embedded in Docker Compose stack)

**Container Requirements:**
- Docker Engine with Docker Compose plugin
- Unprivileged LXC container with nesting feature enabled

**Vault Variables:**
All sensitive variables must be defined in `inventory/group_vars/all/secrets.yml`:
```yaml
vault_netbox_root_password: "secure-password"
vault_netbox_db_password: "secure-db-password"
vault_netbox_redis_password: "secure-redis-password"
vault_netbox_secret_key: "50-character-random-secret-key"
vault_netbox_superuser_password: "secure-admin-password"
```

**Related Roles:**
- `roles/firewall` - Provides network gateway and routing
- `roles/traefik` - Reverse proxy for HTTPS termination (if used)

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox_admin
  roles:
    - role: netbox
```

All configuration uses sensible defaults. Only vault secrets need to be defined.

### Advanced Configuration

```yaml
- hosts: proxmox_admin
  roles:
    - role: netbox
      vars:
        netbox_memory: 4096
        netbox_cores: 4
        netbox_version: v4.1.0
        netbox_env_extra:
          METRICS_ENABLED: "true"
          LOGIN_TIMEOUT: "1209600"  # 14 days
```

## Deployment Process

This role performs the following steps:

1. **Template Management**
   - Ensures template cache directory exists
   - Downloads Debian 13 LXC template (cached, idempotent)

2. **Container Creation**
   - Creates unprivileged LXC container with ID 52
   - Configures network with static IP 172.16.10.52
   - Allocates 2 CPU cores, 2GB RAM, 32GB disk
   - Enables nesting feature for Docker support

3. **Container Configuration**
   - Sets onboot flag for automatic startup
   - Configures DNS servers
   - Starts container and waits for boot completion
   - Sets root password

4. **Service Installation** (guarded by provisioning marker)
   - Installs Docker Engine and Docker Compose plugin
   - Creates compose directory `/opt/netbox`
   - Deploys docker-compose.yml with NetBox stack

5. **Stack Components**
   - PostgreSQL 15 container for database
   - Redis 7 container for caching and queues
   - NetBox web application container
   - NetBox worker container for background jobs
   - NetBox housekeeping container for maintenance tasks

6. **Provisioning Marker**
   - Creates `/etc/netbox/.provisioned` marker
   - Prevents re-installation on subsequent runs

## Idempotency

This role is fully idempotent and safe to re-run:

- **Container Creation**: Uses `creates` guard to skip if container exists
- **Template Download**: Uses `force: false` to download only if missing
- **Service Installation**: Guarded by `/etc/netbox/.provisioned` marker
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
- NetBox application: ~1GB RAM (active)
- PostgreSQL: ~256MB RAM
- Total recommended: 2GB RAM minimum

**Storage:**
- PostgreSQL database grows with infrastructure size
- Media files for device images and attachments
- 32GB disk provides ample space for typical use

**Network:**
- Web UI: HTTP on port 8080 (reverse proxy recommended)
- API: Same port, `/api/` endpoint
- Low bandwidth requirements

### Security

**Container Security:**
- Unprivileged LXC container (user namespace isolation)
- Nesting feature required for Docker (security trade-off accepted)
- No direct internet access (routes through firewall)

**Application Security:**
- Strong SECRET_KEY required (50+ random characters)
- PostgreSQL database isolated within container
- Redis password protected
- CSRF protection enabled
- Login required by default
- HTTPS recommended (use Traefik reverse proxy)

**Vault Integration:**
All secrets stored in Ansible Vault:
- Database passwords
- Redis password
- Django secret key
- Admin credentials

### Troubleshooting

**Container won't start:**
```bash
pct status 52
pct start 52
journalctl -u pve-container@52
```

**Check Docker services:**
```bash
pct exec 52 -- bash -lc "docker ps"
pct exec 52 -- bash -lc "cd /opt/netbox && docker compose logs -f"
```

**Database issues:**
```bash
pct exec 52 -- bash -lc "cd /opt/netbox && docker compose logs postgres"
```

**Reset and redeploy:**
```bash
pct stop 52
pct destroy 52
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags netbox
```

**Access NetBox shell:**
```bash
pct exec 52 -- bash -lc "cd /opt/netbox && docker compose exec netbox python /opt/netbox/netbox/manage.py shell"
```

### Rollback Procedure

To rollback NetBox deployment:

1. Stop and remove container:
   ```bash
   pct stop 52
   pct destroy 52
   ```

2. Remove from inventory/playbooks if added

3. Update container-mapping.md status back to "Planned"

4. Clean vault secrets (optional):
   ```bash
   ansible-vault edit inventory/group_vars/all/secrets.yml
   # Remove netbox variables
   ```

### Known Limitations

- NetBox requires PostgreSQL and Redis (included in stack)
- Initial superuser created automatically (email: admin@viljo.se)
- Embedded PostgreSQL not shared with other services
- No automated backup configured (add via separate role/script)
- HTTPS requires external reverse proxy (Traefik recommended)

## Integration

### Traefik Reverse Proxy

Add to `inventory/group_vars/all/main.yml`:

```yaml
traefik_services:
  - name: netbox
    host: netbox.viljo.se
    container_id: 52
    port: 8080
    scheme: http
```

### DNS Configuration

Add to Loopia DNS records:

```yaml
loopia_dns_records:
  - host: netbox
    type: A
    priority: 0
    rdata: <public-ip>
    ttl: 3600
```

### API Access

NetBox API available at:
- Internal: `http://172.16.10.52:8080/api/`
- External: `https://netbox.viljo.se/api/` (via Traefik)

API token required - generate in NetBox web UI under user profile.

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ✅ **Security-First Design**: Vault-encrypted secrets, unprivileged container, password-protected services
- ✅ **Idempotent Operations**: Safe to re-run without side effects
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ✅ **Automated Operations**: Fully automated deployment and configuration

---

**Status**: ✅ Production ready

**Deployment**: Available via `ansible-playbook playbooks/site.yml --tags netbox`

**Public URL**: https://netbox.viljo.se (when Traefik configured)
