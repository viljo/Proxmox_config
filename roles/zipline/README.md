# Role: zipline

## Purpose

Deploys Zipline, a modern self-hosted screenshot and file sharing service, as an LXC container on Proxmox VE. Zipline provides a ShareX-compatible API for automated screenshot uploads, file sharing with configurable expiration, and an intuitive web interface for managing uploads.

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

**Container Configuration:**
- `zipline_container_id`: LXC container ID (default: `65`)
- `zipline_hostname`: Container hostname (default: `zipline`)
- `zipline_domain`: Base domain name (default: `viljo.se`)
- `zipline_memory`: RAM allocation in MB (default: `2048`)
- `zipline_cores`: CPU core allocation (default: `2`)
- `zipline_disk`: Root filesystem size in GB (default: `32`)

**Network Configuration:**
- `zipline_ip_address`: Static IP address (default: `172.16.10.65`)
- `zipline_gateway`: Network gateway (default: `172.16.10.1`)
- `zipline_dns_servers`: DNS server list (default: `['172.16.10.1', '1.1.1.1']`)
- `zipline_bridge`: Proxmox network bridge (default: `vmbr3`)

**Application Configuration:**
- `zipline_service_port`: HTTP service port (default: `3000`)
- `zipline_compose_path`: Docker Compose directory (default: `/opt/zipline`)
- `zipline_external_domain`: Public access domain (default: `{{ loopia_dns_domain }}`)

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)
- `community.general` (for Proxmox LXC management)

**External Services:**
- **PostgreSQL** (Container ID 50): Database backend for storing file metadata
- **Firewall** (Container ID 1): Network gateway and NAT
- **Traefik**: Reverse proxy for HTTPS termination and routing

**Vault Variables:**
- `vault_zipline_root_password`: Root password for LXC container
- `vault_zipline_core_secret`: Secret key for Zipline application encryption
- `vault_postgres_zipline_user`: PostgreSQL username for Zipline database
- `vault_postgres_zipline_password`: PostgreSQL password
- `vault_postgres_zipline_db`: PostgreSQL database name

**Related Roles:**
- `roles/postgresql`: Must be deployed first to provide database backend
- `roles/firewall`: Provides network connectivity
- `roles/traefik`: Routes HTTPS traffic to Zipline

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox_admin
  roles:
    - role: zipline
```

### Advanced Configuration

```yaml
- hosts: proxmox_admin
  roles:
    - role: zipline
      vars:
        zipline_memory: 4096
        zipline_cores: 4
        zipline_disk: 64
```

## Deployment Process

This role performs the following steps:

1. **Template Management**: Downloads Debian 13 (Trixie) LXC template if not cached
2. **Container Creation**: Creates unprivileged LXC container with specified resources
3. **Network Configuration**: Configures static IP on DMZ network (172.16.10.0/24)
4. **Container Initialization**: Starts container and waits for boot completion
5. **Docker Installation**: Installs Docker Engine and Docker Compose plugin
6. **Application Deployment**: Deploys Zipline via Docker Compose with PostgreSQL backend
7. **Service Startup**: Starts Zipline service and marks container for auto-start

## Idempotency

The role ensures idempotent operations through:

- **Provisioning Marker**: Uses `/etc/zipline/.provisioned` marker to prevent re-provisioning
- **Container State Checks**: Verifies container existence before creation
- **Template Caching**: Downloads templates only if not already present
- **Docker Install Guard**: Skips Docker installation if provisioning marker exists
- **Compose Changes Only**: Docker Compose is restarted only when configuration changes

Safe to re-run multiple times without disrupting existing services.

## Notes

### Performance Considerations

- **Storage**: File uploads stored in Docker volumes; consider binding to larger storage for heavy use
- **Memory**: 2GB RAM suitable for light-to-moderate use; increase for high traffic or large files
- **Database**: Uses shared PostgreSQL container for better resource utilization

### Security

- **Unprivileged Container**: Runs as unprivileged LXC for enhanced security isolation
- **HTTPS Only**: Configure Traefik to enforce HTTPS and redirect HTTP traffic
- **Secret Management**: All sensitive credentials stored in Ansible Vault
- **Network Isolation**: Runs on DMZ network (vmbr3) with firewall-controlled access

### Integration

**ShareX Configuration:**
1. Navigate to `https://zipline.viljo.se` and create an account
2. Generate an API token in user settings
3. Configure ShareX with custom uploader using Zipline API endpoint

**Traefik Integration:**
- Ensure Traefik routing rule exists for `zipline.viljo.se` → `172.16.10.65:3000`
- Configure automatic TLS certificate via Loopia DNS-01 challenge

### Troubleshooting

**Container won't start:**
```bash
pct status 65
pct start 65
pct enter 65
```

**Check Zipline logs:**
```bash
pct exec 65 -- docker compose -f /opt/zipline/docker-compose.yml logs -f
```

**Database connection issues:**
```bash
# Verify PostgreSQL container is running
pct status 50
# Test connectivity from Zipline container
pct exec 65 -- ping -c 2 172.16.10.50
pct exec 65 -- nc -zv 172.16.10.50 5432
```

**Reset and redeploy:**
```bash
pct stop 65
pct destroy 65
ansible-playbook playbooks/site.yml --tags zipline
```

### Rollback Procedure

To remove Zipline:

```bash
# Stop and destroy container
pct stop 65
pct destroy 65

# Clean up LXC rootfs (if needed)
rm -rf /var/lib/lxc/65

# Remove from Proxmox configuration
rm /etc/pve/lxc/65.conf

# Drop database (from PostgreSQL container)
pct exec 50 -- psql -U postgres -c "DROP DATABASE zipline;"
pct exec 50 -- psql -U postgres -c "DROP USER zipline;"
```

### Known Limitations

- **Single Instance**: Role assumes single Zipline deployment per infrastructure
- **Storage Growth**: File uploads accumulate in Docker volumes; implement cleanup policy as needed
- **No Built-in Backup**: Configure external backup for Docker volumes or PostgreSQL database
- **Database Migration**: Switching from SQLite to PostgreSQL requires manual data migration

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role with declarative configuration
- ✅ **Security-First Design**: Unprivileged container, vault secrets, HTTPS enforcement
- ✅ **Idempotent Operations**: Safe to re-run; uses provisioning markers and state checks
- ✅ **Single Source of Truth**: Configuration centralized in role defaults and inventory
- ✅ **Automated Operations**: Full deployment automation from bare Proxmox to running service

---

**Status**: ✅ Production-ready implementation

**Container ID**: 65 | **IP Address**: 172.16.10.65 | **Public URL**: https://zipline.viljo.se

**Last Updated**: 2025-10-22
