# Role: homeassistant

## Purpose

This role deploys and configures **Home Assistant Supervised** on Proxmox VE infrastructure. Home Assistant Supervised provides a full-featured home automation platform with support for add-ons (formerly Hass.io), allowing users to extend functionality with additional services like MQTT brokers, databases, file editors, and community integrations.

The deployment uses an LXC container running Debian 12 with Docker as the container runtime for the Home Assistant Supervisor and add-ons.

## Key Features

- **Full Add-on Support**: Install and manage official and community add-ons through the Supervisor
- **Docker-Based**: Supervisor manages Home Assistant Core and add-ons as Docker containers
- **Automatic Updates**: Update Home Assistant and add-ons through the web interface
- **Integrated Backups**: Create and restore full system backups via the Supervisor
- **Web-Based Management**: Complete configuration through the Home Assistant web interface
- **HTTPS Access**: Secured access via Traefik reverse proxy with automatic TLS certificates

## Architecture

**Installation Method**: Home Assistant Supervised (not Core, Container, or OS)

**Container Stack**:
```
┌─────────────────────────────────────────┐
│ Proxmox Host                            │
│  ┌───────────────────────────────────┐  │
│  │ LXC Container (CT 57)             │  │
│  │ Debian 12 (Bookworm)              │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │ Docker Engine               │  │  │
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │ Home Assistant Core   │  │  │  │
│  │  │  │ (Docker container)    │  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │ Supervisor            │  │  │  │
│  │  │  │ (Docker container)    │  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │ Add-on 1, 2, 3...     │  │  │  │
│  │  │  │ (Docker containers)   │  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

**Container Identification**:
- `ha_container_id: 57` - Container ID (standardized per ADR-002, .57 = IoT mnemonic)
- `ha_hostname: homeassistant` - Container hostname
- `ha_domain: infra.local` - Domain suffix

**Container Resources** (adjust based on add-on requirements):
- `ha_memory: 4096` - RAM in MB (minimum 2048, recommended 4096-8192)
- `ha_cores: 4` - CPU cores (minimum 2, recommended 4-6)
- `ha_disk: 64` - Disk size in GB (minimum 32, recommended 64-128)
- `ha_swap: 2048` - Swap space in MB

**Container Network**:
- `ha_bridge: "{{ management_bridge | default('vmbr2') }}"` - Network bridge
- `ha_ip_config: "172.16.10.57/24"` - Static IP configuration
- `ha_gateway: "172.16.10.1"` - Default gateway
- `ha_dns_servers: ["172.16.10.1", "1.1.1.1"]` - DNS servers

**Container Security**:
- `ha_unprivileged: false` - **Must be false (privileged)** for Docker support
- `ha_start_onboot: true` - Auto-start container on Proxmox boot
- Container features: `nesting=1` (set automatically, required for Docker)

**Home Assistant Configuration**:
- `ha_service_port: 8123` - Web interface port
- `ha_public_hostname: "ha.viljo.se"` - Public FQDN for Traefik routing
- `ha_supervised_installer_url` - URL to official Supervised installer .deb package
- `ha_machine_type: "qemux86-64"` - Machine architecture for add-on compatibility

**Templates** (Debian 12 required):
- `ha_template_url` - Proxmox Debian 12 template download URL
- `ha_template_file` - Local template cache path

## Dependencies

**Required Ansible Collections**:
- `ansible.builtin` (core modules)

**External Services**:
- Proxmox VE host with LXC support
- Network bridge (vmbr2 for Management network)
- Internet connectivity for Docker Hub and Home Assistant repositories
- Traefik reverse proxy (for HTTPS access)
- DNS resolution for public hostname

**Vault Variables**:
- `vault_homeassistant_root_password` - Container root password (encrypted)

**Related Roles**:
- `traefik` - Provides HTTPS reverse proxy and TLS certificate management
- `firewall` - Network security and traffic routing

**System Requirements**:
- Proxmox kernel with AppArmor support
- Debian 12 (Bookworm) template available
- Sufficient storage for Docker images and volumes

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox
  roles:
    - role: homeassistant
```

This uses all default values from `defaults/main.yml`.

### Custom Resource Allocation

```yaml
- hosts: proxmox
  roles:
    - role: homeassistant
      vars:
        ha_memory: 8192        # 8GB RAM for many add-ons
        ha_cores: 6            # 6 CPU cores
        ha_disk: 128           # 128GB disk for media and backups
```

### Custom Network Configuration

```yaml
- hosts: proxmox
  roles:
    - role: homeassistant
      vars:
        ha_ip_config: "192.168.1.100/24"
        ha_gateway: "192.168.1.1"
        ha_dns_servers:
          - "192.168.1.1"
          - "8.8.8.8"
```

### Integration with Inventory Variables

The role automatically uses inventory variables when available:

```yaml
# inventory/group_vars/all/main.yml
management_bridge: vmbr2
vault_homeassistant_root_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  [encrypted password]
```

## Deployment Process

The role performs the following steps automatically:

### Phase 1: Container Creation
1. Ensure Debian 12 template is cached locally
2. Create LXC container with specified resources
3. Configure container network settings

### Phase 2: Container Configuration
4. Set container onboot flag for auto-start
5. Enable nesting feature for Docker support
6. Configure DNS servers

### Phase 3: Container Startup and Initial Setup
7. Start container if not running
8. Wait for container to boot and become responsive
9. Set root password from vault

### Phase 4: Provisioning Check
10. Check for provisioning marker to ensure idempotency
11. Skip remaining steps if already provisioned

### Phase 5: System Prerequisites
12. Update apt package cache
13. Install Home Assistant Supervised prerequisites:
    - apparmor, dbus, jq, wget, curl
    - network-manager, systemd-resolved
    - udisks2, libglib2.0-bin
    - cifs-utils, nfs-common

### Phase 6: Docker Installation
14. Check if Docker is already installed
15. Add Docker GPG key and repository
16. Install Docker CE, CLI, containerd, and plugins
17. Enable and start Docker service

### Phase 7: Home Assistant Supervised Installation
18. Download official Home Assistant Supervised installer (.deb)
19. Install Home Assistant Supervised package
20. Wait for Supervisor to initialize (may take 10-20 minutes)

### Phase 8: Final Configuration
21. Create provisioning marker for idempotency
22. Display access information and next steps

**Total Deployment Time**: Approximately 15-30 minutes depending on network speed

## Idempotency

The role ensures safe re-runnability through multiple mechanisms:

**Provisioning Marker**:
- Marker file: `/etc/homeassistant/.provisioned`
- Once set, major installation steps are skipped
- Container can be reconfigured without re-provisioning

**State Checks**:
- Container existence: `creates: "/etc/pve/lxc/{{ ha_container_id }}.conf"`
- Docker installation: `which docker` check
- Supervisor installation: `test -f /usr/bin/ha` check

**Safe Re-run Behavior**:
- Re-running the role will:
  - ✅ Update container configuration (resources, network)
  - ✅ Ensure services are running
  - ✅ Apply configuration changes
  - ❌ Not reinstall Docker or Home Assistant (skipped if present)
  - ❌ Not destroy existing data or configurations

**Data Preservation**:
- Home Assistant configuration persists in `/usr/share/hassio`
- Add-on data persists across role re-runs
- Docker volumes are not removed

## Access and Usage

### Web Interface

After deployment, access Home Assistant at:
- **Internal**: `http://homeassistant.infra.local:8123`
- **External (via Traefik)**: `https://ha.viljo.se`

### Initial Setup

1. First access takes 10-20 minutes as Supervisor downloads and starts containers
2. Create admin account through web interface onboarding
3. Access Supervisor from sidebar
4. Navigate to Add-on Store to install add-ons

### Managing Add-ons

1. Open Home Assistant web interface
2. Click **Supervisor** in sidebar
3. Click **Add-on Store** tab
4. Browse official and community add-ons
5. Click add-on → **Install** → **Start**

### Common Add-ons

- **File Editor**: Edit configuration.yaml through web interface
- **Mosquitto Broker**: MQTT message broker for IoT devices
- **Node-RED**: Visual automation and workflow tool
- **MariaDB**: SQL database for Home Assistant recorder
- **Samba Share**: Network file sharing
- **Terminal & SSH**: SSH access to container

## Notes

### Performance Considerations

**Resource Requirements by Use Case**:
- **Minimal** (Core only, 1-2 add-ons): 2GB RAM, 2 cores, 32GB disk
- **Standard** (5-10 add-ons, moderate automation): 4GB RAM, 4 cores, 64GB disk
- **Advanced** (10+ add-ons, media, extensive history): 8GB RAM, 6 cores, 128GB disk

**Performance Tips**:
- Increase RAM if running multiple database add-ons
- Increase disk space if using media add-ons or extensive backups
- Monitor resource usage through Supervisor → System tab
- Reduce recorder history retention if database grows large

### Security

**Container Privilege Consideration**:
- Container runs as **privileged** (not unprivileged) due to Docker requirements
- This is a documented security trade-off for running Docker in LXC
- Alternative: Use VM instead of LXC for stronger isolation
- Mitigation: Network segmentation, firewall rules, minimal host exposure

**Network Security**:
- Container on Management network (172.16.10.0/24), not DMZ
- External access only through Traefik reverse proxy
- HTTPS enforced with automatic TLS certificates
- Add-ons isolated via Docker networking

**Access Control**:
- Root password stored encrypted in Ansible Vault
- Home Assistant user authentication required
- Supervisor API access restricted to authenticated users
- Use secrets.yaml for sensitive Home Assistant configuration

### Troubleshooting

**Container won't start**:
```bash
# Check container status
pct status 57

# View container logs
pct exec 57 -- journalctl -xe

# Restart container
pct restart 57
```

**Docker service issues**:
```bash
# Check Docker status
pct exec 57 -- systemctl status docker

# Restart Docker
pct exec 57 -- systemctl restart docker

# View Docker logs
pct exec 57 -- journalctl -u docker
```

**Supervisor not starting**:
```bash
# Check Supervisor status
pct exec 57 -- systemctl status hassio-supervisor

# View Supervisor logs
pct exec 57 -- journalctl -u hassio-supervisor

# Check Docker containers
pct exec 57 -- docker ps -a
```

**Add-on installation fails**:
- Check disk space: `pct exec 57 -- df -h`
- Check internet connectivity: `pct exec 57 -- curl -I https://hub.docker.com`
- View Supervisor logs through web interface
- Check add-on compatibility with machine type (qemux86-64)

**Home Assistant not accessible**:
- Verify container is running: `pct status 57`
- Check port 8123 is listening: `pct exec 57 -- netstat -tlnp | grep 8123`
- Verify Traefik routing configuration
- Check firewall rules allow traffic to Traefik

**Initial setup takes very long**:
- Normal: First startup downloads multiple Docker images (500MB+)
- Monitor progress: `pct exec 57 -- docker ps` shows containers starting
- Check network speed: Download speed affects initialization time
- Wait at least 20 minutes before troubleshooting

### Rollback Procedure

**To rollback to previous state**:

1. **Stop and remove container**:
   ```bash
   pct stop 57
   pct destroy 57
   ```

2. **Restore from backup** (if available):
   - Use Proxmox container backup
   - Or restore Home Assistant backup through Supervisor (requires working installation)

3. **Redeploy previous version**:
   - Check out previous git commit of this role
   - Re-run Ansible playbook

**Data Recovery**:
- Home Assistant data stored in `/usr/share/hassio` on container rootfs
- Can mount stopped container rootfs to extract data
- Regular backups recommended through Supervisor backup feature

### Known Limitations

1. **Debian 12 Required**: Home Assistant Supervised only supports Debian 12, not Debian 13 yet
2. **Privileged Container**: Security trade-off for Docker support
3. **Machine Type Locked**: Once installed, changing machine type breaks add-on compatibility
4. **OS Check Bypass**: Installer requires `BYPASS_OS_CHECK=true` for LXC environment
5. **No High Availability**: Single container deployment, not clustered
6. **Add-on ARM Limitations**: Some add-ons only available for ARM architectures (e.g., Raspberry Pi)
7. **Update Delays**: Major updates may require manual intervention or waiting for Supervisor support
8. **Network Manager Requirement**: NetworkManager installed but may conflict with LXC network management

### Migration from Home Assistant Core

If migrating from the previous Home Assistant Core (Python venv) installation:

1. **Backup Core configuration**:
   - Copy `/srv/homeassistant/config` directory

2. **Deploy Supervised** (this role):
   - Run playbook to create new container

3. **Restore configuration**:
   - Wait for initial setup to complete
   - Replace `/usr/share/hassio/homeassistant` with backed up configuration
   - Restart Supervisor

4. **Reinstall custom components**:
   - Use HACS (Home Assistant Community Store) add-on
   - Or manually install to custom_components directory

**Note**: Database migration may be needed for historical data retention.

## Related Documentation

- [Feature Specification](../../specs/active/009-home-assistant-supervised/spec.md) - Full requirements and design
- [ADR-002: Container ID Standardization](../../docs/adr/002-container-id-standardization.md) - Container ID rationale
- [Container Mapping](../../docs/architecture/container-mapping.md) - Infrastructure overview
- [Home Assistant Supervised Installer](https://github.com/home-assistant/supervised-installer) - Official installer repo
- [Docker in LXC Containers](https://pve.proxmox.com/wiki/Linux_Container#pct_container_features) - Proxmox documentation

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ⚠️ **Security-First Design**: Container privileged for Docker (documented trade-off), Vault-encrypted passwords
- ✅ **Idempotent Operations**: Safe to re-run with provisioning markers and state checks
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ✅ **Automated Operations**: Complete automated deployment from bare Proxmox to running Home Assistant

---

**Status**: ✅ Production Ready - Home Assistant Supervised with full add-on support

**Last Updated**: 2025-10-22
