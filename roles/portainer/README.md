# Role: portainer

## Purpose

Deploys Portainer CE (Community Edition), a lightweight container management platform, as an LXC container on Proxmox VE. Portainer provides a web-based UI for managing Docker containers, images, networks, and volumes, making it easier to administer containerized applications across single or multiple Docker hosts.

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

**Container Configuration:**
- `portainer_container_id`: LXC container ID (default: `61`)
- `portainer_hostname`: Container hostname (default: `portainer`)
- `portainer_domain`: Base domain name (default: `infra.local`)
- `portainer_memory`: RAM allocation in MB (default: `1024`)
- `portainer_cores`: CPU core allocation (default: `2`)
- `portainer_disk`: Root filesystem size in GB (default: `16`)

**Network Configuration:**
- `portainer_ip_address`: Static IP address (default: `172.16.10.61`)
- `portainer_gateway`: Network gateway (default: `172.16.10.1`)
- `portainer_dns_servers`: DNS server list (default: `['172.16.10.1', '1.1.1.1']`)
- `portainer_bridge`: Proxmox network bridge (default: `vmbr3`)

**Application Configuration:**
- `portainer_service_port_http`: HTTP service port (default: `9000`)
- `portainer_service_port_https`: HTTPS service port (default: `9443`)
- `portainer_service_port_edge`: Edge agent tunnel port (default: `8000`)
- `portainer_compose_path`: Docker Compose directory (default: `/opt/portainer`)
- `portainer_edition`: Portainer edition (default: `portainer-ce`)
- `portainer_version`: Portainer version tag (default: `latest`)
- `portainer_public_hostname`: Public access domain (default: `portainer.viljo.se`)

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)
- `community.general` (for Proxmox LXC management)

**External Services:**
- **Firewall** (Container ID 1): Network gateway and NAT
- **Traefik** (optional): Reverse proxy for HTTPS termination and routing

**Vault Variables:**
- `vault_portainer_root_password`: Root password for LXC container

**Related Roles:**
- `roles/firewall`: Provides network connectivity
- `roles/traefik`: Routes HTTPS traffic to Portainer (optional)

## Features

- **Container Management**: Manage Docker containers (start/stop/restart/remove)
- **Image Management**: Pull, build, and manage Docker images
- **Network Management**: Create and configure Docker networks
- **Volume Management**: Manage Docker volumes and persistent storage
- **Stack Deployment**: Deploy multi-container applications via Docker Compose
- **User Management**: Role-based access control for team collaboration
- **Environment Management**: Connect to and manage multiple Docker hosts

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox_admin
  roles:
    - role: portainer
```

### Advanced Configuration

```yaml
- hosts: proxmox_admin
  roles:
    - role: portainer
      vars:
        portainer_memory: 2048
        portainer_cores: 4
        portainer_disk: 32
        portainer_edition: portainer-ee
        portainer_version: "2.19.4"
```

## Deployment Process

This role performs the following steps:

1. **Template Management**: Downloads Debian 13 (Trixie) LXC template if not cached
2. **Container Creation**: Creates unprivileged LXC container with nesting enabled
3. **Network Configuration**: Configures static IP on DMZ network (172.16.10.0/24)
4. **Container Initialization**: Starts container and waits for boot completion
5. **Docker Installation**: Installs Docker Engine and Docker Compose plugin
6. **Application Deployment**: Deploys Portainer via Docker Compose with data persistence
7. **Service Startup**: Starts Portainer service and marks container for auto-start

## Idempotency

The role ensures idempotent operations through:

- **Provisioning Marker**: Uses `/etc/portainer/.provisioned` marker to prevent re-provisioning
- **Container State Checks**: Verifies container existence before creation
- **Template Caching**: Downloads templates only if not already present
- **Docker Install Guard**: Skips Docker installation if provisioning marker exists
- **Compose Changes Only**: Docker Compose is restarted only when configuration changes

Safe to re-run multiple times without disrupting existing services.

## Post-Deployment Steps

After deployment, complete the initial setup:

1. **Access Web Interface**:
   - HTTP: `http://172.16.10.61:9000`
   - HTTPS: `https://172.16.10.61:9443`
   - Or via Traefik: `https://portainer.viljo.se`

2. **Create Admin User** (must be done within 5 minutes of first start):
   - Open the web interface
   - Create an admin username and password (minimum 12 characters)
   - Click "Create user"

3. **Connect to Local Docker**:
   - Select "Get Started" or "Docker" environment
   - Portainer will auto-detect the local Docker socket
   - Click "Connect"

4. **Configure Access** (optional):
   - Enable HTTPS with custom certificates
   - Configure LDAP/OAuth authentication via Keycloak
   - Set up teams and role-based access control

## Security Considerations

- **Docker Socket Access**: Portainer has read-only access to `/var/run/docker.sock`
- **Unprivileged Container**: Runs in unprivileged LXC with nesting for Docker support
- **No New Privileges**: Docker security option `no-new-privileges:true` is enabled
- **Network Isolation**: Isolated on DMZ network (172.16.10.0/24)
- **Admin Account**: Initial admin account must be created within 5 minutes to prevent unauthorized access

## Troubleshooting

### Container Won't Start
```bash
# Check container status
pct status 61

# View container logs
pct exec 61 -- journalctl -u docker

# Verify nesting is enabled
pct config 61 | grep features
```

### Docker Service Issues
```bash
# Check Docker service status
pct exec 61 -- systemctl status docker

# Restart Docker service
pct exec 61 -- systemctl restart docker
```

### Portainer Not Accessible
```bash
# Check if Portainer container is running
pct exec 61 -- docker ps

# View Portainer logs
pct exec 61 -- docker logs portainer

# Restart Portainer stack
pct exec 61 -- bash -lc "cd /opt/portainer && docker compose up -d"
```

### Admin Account Timeout
If you didn't create an admin account within 5 minutes:
```bash
# Restart the Portainer container
pct exec 61 -- docker compose -f /opt/portainer/docker-compose.yml down
pct exec 61 -- docker compose -f /opt/portainer/docker-compose.yml up -d
```

## Monitoring

**Health Checks:**
- Web UI accessibility (HTTP 9000, HTTPS 9443)
- Docker service status
- Container resource usage

**Logs:**
- Portainer logs: `docker logs portainer`
- Docker daemon: `journalctl -u docker`
- Container system: `pct exec 61 -- journalctl`

## Backup and Recovery

**Data to Backup:**
- Portainer data volume: Contains all Portainer configuration, users, and settings
- Docker Compose file: `/opt/portainer/docker-compose.yml`

**Backup Commands:**
```bash
# Backup Portainer data
docker run --rm -v portainer_data:/data -v $(pwd):/backup alpine tar czf /backup/portainer_data.tar.gz /data

# Restore Portainer data
docker run --rm -v portainer_data:/data -v $(pwd):/backup alpine tar xzf /backup/portainer_data.tar.gz -C /
```

## References

- [Portainer Official Documentation](https://docs.portainer.io/)
- [Portainer CE Installation Guide](https://docs.portainer.io/start/install-ce/server/docker/linux)
- [Container Mapping](../../docs/architecture/container-mapping.md)
- [ADR-002: Container ID Standardization](../../docs/adr/002-container-id-standardization.md)

## License

This role follows the same license as the parent repository.

---

**Status**: Ready for deployment | **Container ID**: 61 | **IP**: 172.16.10.61
