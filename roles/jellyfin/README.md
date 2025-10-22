# Role: jellyfin

## Purpose

This role deploys and configures Jellyfin media server on Proxmox VE infrastructure as an unprivileged LXC container. Jellyfin provides streaming access to media content (videos, music, photos) with support for transcoding, multi-device access, and integration with the infrastructure's reverse proxy and authentication systems.

## Features

- Deploys Jellyfin in an unprivileged LXC container for security
- Configures static IP addressing on DMZ network (172.16.10.56)
- Installs latest stable Jellyfin from official repository
- Supports optional media storage mount points
- Integrates with Traefik reverse proxy for HTTPS access
- Idempotent deployment with provisioning markers

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

**Container Configuration:**
- `jellyfin_container_id`: Container ID (default: `56`)
- `jellyfin_hostname`: Container hostname (default: `jellyfin`)
- `jellyfin_domain`: External domain (default: `viljo.se`)
- `jellyfin_ip_address`: Static IP address (default: `172.16.10.56`)
- `jellyfin_gateway`: Network gateway (default: `172.16.10.1`)

**Resource Allocation:**
- `jellyfin_memory`: RAM in MB (default: `4096`)
- `jellyfin_cores`: CPU cores (default: `4`)
- `jellyfin_disk`: Root disk size in GB (default: `64`)
- `jellyfin_swap`: Swap in MB (default: `1024`)

**Network Configuration:**
- `jellyfin_bridge`: Network bridge (default: `vmbr3`)
- `jellyfin_dns_servers`: DNS servers (default: `['172.16.10.1', '1.1.1.1']`)
- `jellyfin_service_port`: Jellyfin HTTP port (default: `8096`)

**Media Storage:**
- `jellyfin_media_mounts`: List of media mount points (default: `[]`)

Example media mount configuration:
```yaml
jellyfin_media_mounts:
  - source: /mnt/storage/movies
    target: /media/movies
    ro: true  # Read-only (default: true)
  - source: /mnt/storage/tv
    target: /media/tv
    ro: true
  - source: /mnt/storage/music
    target: /media/music
    ro: true
```

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)

**External Services:**
- Proxmox VE host with LXC support
- Network infrastructure (firewall at 172.16.10.1)
- Traefik reverse proxy (for HTTPS access)
- Loopia DNS (for domain management)

**Vault Variables:**
- `vault_jellyfin_root_password`: Root password for container (optional)

**Related Roles:**
- `proxmox` - Proxmox host configuration
- `network` - Network bridge setup
- `firewall` - DMZ network gateway
- `traefik` - Reverse proxy and HTTPS
- `loopia_dns` - DNS record management

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox
  roles:
    - role: jellyfin
```

This deploys Jellyfin with default settings (container ID 56, 4GB RAM, 4 cores).

### Advanced Configuration with Media Mounts

```yaml
- hosts: proxmox
  roles:
    - role: jellyfin
      vars:
        jellyfin_memory: 8192
        jellyfin_cores: 6
        jellyfin_media_mounts:
          - source: /mnt/nas/movies
            target: /media/movies
            ro: true
          - source: /mnt/nas/tv-shows
            target: /media/tv
            ro: true
          - source: /mnt/nas/music
            target: /media/music
            ro: true
```

### Traefik Integration

Add to `inventory/group_vars/all/main.yml`:

```yaml
traefik_services:
  - name: jellyfin
    host: "jellyfin.{{ public_domain }}"
    container_id: "{{ jellyfin_container_id }}"
    port: 8096
```

Add to DNS records:
```yaml
loopia_dns_records:
  - host: jellyfin
```

## Deployment Process

The role performs the following steps:

1. **Template Preparation**
   - Ensures template cache directory exists
   - Downloads Debian 13 LXC template if not present

2. **Container Creation**
   - Creates unprivileged LXC container with specified ID (56)
   - Configures network with static IP (172.16.10.56/24)
   - Sets resource limits (CPU, RAM, disk)
   - Enables container nesting feature

3. **Container Configuration**
   - Sets container to start on boot
   - Configures DNS servers
   - Starts the container

4. **Jellyfin Installation**
   - Waits for container to boot
   - Sets root password
   - Installs repository prerequisites (curl, gnupg)
   - Adds Jellyfin GPG key
   - Configures Jellyfin apt repository
   - Installs Jellyfin package
   - Enables and starts Jellyfin service

5. **Media Storage Setup** (if configured)
   - Configures mount points in container config
   - Creates mount directories inside container
   - Restarts container if mounts were added

6. **Provisioning Marker**
   - Creates marker file to prevent re-provisioning
   - Ensures idempotent operations

## Idempotency

This role ensures idempotent operations through:

- **Container Creation**: Uses `creates` parameter to check for existing container config
- **Provisioning Marker**: Checks `/etc/jellyfin/.provisioned` before installing packages
- **Service State**: Only starts container if it's currently stopped
- **Boot Wait**: Retries boot probe until container is ready
- **Mount Configuration**: Uses regex-based line replacement for mount points

The role is safe to re-run multiple times without causing issues.

## Network Integration

Jellyfin integrates with the infrastructure network:

```
Internet
   ↓
Firewall (172.16.10.1) - Port forwarding 80/443
   ↓
Traefik (Proxmox Host) - Reverse proxy, HTTPS termination
   ↓
Jellyfin Container (172.16.10.56:8096) - Media server
   ↓
Media Storage (mounted volumes)
```

## Performance Considerations

**Resource Requirements:**
- **CPU**: 4 cores recommended (2 minimum)
  - More cores improve transcoding performance
  - Hardware transcoding (future) reduces CPU load
- **RAM**: 4GB recommended (2GB minimum)
  - Increases with concurrent streams and library size
- **Disk**: 64GB for Jellyfin metadata and transcoding cache
  - Media files stored on separate mounted volumes
  - SSD recommended for better metadata performance

**Transcoding:**
- Software transcoding is CPU-intensive
- Consider hardware acceleration for better performance:
  - Intel QuickSync (requires GPU passthrough)
  - NVIDIA GPU (requires GPU passthrough and drivers)

## Security

**Container Security:**
- ✅ Unprivileged LXC container (no root privileges on host)
- ✅ Network isolation on DMZ (vmbr3)
- ✅ Minimal attack surface (only port 8096 exposed internally)

**Access Control:**
- ✅ HTTPS enforced via Traefik
- ✅ Authentication required by Jellyfin
- ⚠️ Built-in Jellyfin authentication (LDAP/OIDC integration future)

**Media Storage:**
- ✅ Read-only mounts by default (prevents media tampering)
- ✅ Proper permission separation
- ✅ Host filesystem protected from container

**Recommendations:**
1. Use strong Jellyfin admin password
2. Enable two-factor authentication in Jellyfin (if available)
3. Consider LDAP/OIDC integration for centralized auth
4. Regular security updates via `apt upgrade`
5. Monitor access logs for suspicious activity

## Troubleshooting

### Container Won't Start
```bash
# Check container status
pct status 56

# View container logs
journalctl -u pve-container@56

# Try manual start
pct start 56
```

### Jellyfin Service Not Running
```bash
# Check service status
pct exec 56 -- systemctl status jellyfin

# View Jellyfin logs
pct exec 56 -- journalctl -u jellyfin -n 50

# Restart service
pct exec 56 -- systemctl restart jellyfin
```

### Media Files Not Visible
```bash
# Check mount points
cat /etc/pve/lxc/56.conf | grep ^mp

# Verify mounts inside container
pct exec 56 -- df -h
pct exec 56 -- ls -la /media/

# Check permissions
pct exec 56 -- ls -la /media/movies
```

### Transcoding Fails
```bash
# Check Jellyfin logs for errors
pct exec 56 -- cat /var/log/jellyfin/jellyfin.log | grep -i transcode

# Verify ffmpeg is installed
pct exec 56 -- which ffmpeg

# Check available CPU/RAM
pct exec 56 -- top
```

### Can't Access via HTTPS
```bash
# Check Traefik routing
curl -H "Host: jellyfin.viljo.se" http://172.16.10.2

# Verify DNS resolution
dig jellyfin.viljo.se

# Check Traefik logs
journalctl -u traefik -n 50

# Test direct access
curl http://172.16.10.56:8096
```

## Rollback Procedure

To rollback or remove Jellyfin:

1. **Stop the container:**
   ```bash
   pct stop 56
   ```

2. **Remove from Traefik** (edit `inventory/group_vars/all/main.yml`):
   - Remove Jellyfin from `traefik_services`
   - Remove from `loopia_dns_records`
   - Re-run `traefik` role

3. **Delete the container:**
   ```bash
   pct destroy 56
   ```

4. **Clean up mounts:**
   - Mount points are automatically removed with container

## Known Limitations

1. **Hardware Transcoding**: Not configured (requires GPU passthrough)
2. **Authentication**: Uses built-in Jellyfin auth (Keycloak integration planned)
3. **Media Storage**: Requires manual configuration of mount points
4. **Backup**: Media files must be backed up separately
5. **Mobile Apps**: Require separate client-side configuration
6. **Live TV/DVR**: Not configured (requires additional hardware)

## Future Enhancements

### Planned Features
- LDAP/OIDC authentication with Keycloak
- Hardware transcoding (GPU passthrough)
- Automated media organization integration
- Enhanced monitoring and alerting
- Multi-user profiles and permissions
- Plugin ecosystem configuration

### Potential Integrations
- **qBittorrent**: Automatic media downloads
- **OpenMediaVault**: Centralized media storage
- **Sonarr/Radarr**: Automated media management (if needed)
- **Tautulli**: Usage statistics and monitoring

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ✅ **Security-First Design**: Unprivileged container, HTTPS, isolated network
- ✅ **Idempotent Operations**: Safe to re-run without side effects
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ✅ **Automated Operations**: Fully automated deployment and configuration
- ⚠️ **Centralized Authentication**: Future enhancement (Keycloak integration planned)
- ✅ **Documentation**: Comprehensive README with examples
- ✅ **Monitoring Ready**: Service health can be monitored via standard tools

## References

- [Jellyfin Official Documentation](https://jellyfin.org/docs/)
- [Feature Specification](../../specs/planned/009-jellyfin-media-server/spec.md)
- [Container Mapping](../../docs/architecture/container-mapping.md)
- [Network Topology](../../docs/architecture/network-topology.md)
- [ADR-002: Container ID Standardization](../../docs/adr/002-container-id-standardization.md)

## Support

For issues specific to this role:
1. Check the troubleshooting section above
2. Review Jellyfin logs: `pct exec 56 -- journalctl -u jellyfin`
3. Consult the feature specification in `specs/planned/009-jellyfin-media-server/`
4. Review Proxmox container logs: `journalctl -u pve-container@56`

For Jellyfin-specific issues:
- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Jellyfin Community Forum](https://forum.jellyfin.org/)
- [Jellyfin GitHub Issues](https://github.com/jellyfin/jellyfin/issues)

---

**Status**: ✅ Ready for deployment

**Last Updated**: 2025-10-22
**Version**: 1.0
**Maintainer**: Infrastructure Team
