# Role: openmediavault

## Purpose

This role deploys and configures OpenMediaVault (OMV) 7.x as an unprivileged LXC container on Proxmox VE infrastructure. OpenMediaVault is a network-attached storage (NAS) solution based on Debian Linux, providing file sharing (SMB/CIFS, NFS), user management, plugin ecosystem, and a comprehensive web-based administration interface.

**Key Features:**
- Automated LXC container provisioning in DMZ network (172.16.10.64)
- Official OMV installation via upstream installation script
- OMV-Extras plugin repository integration for extended functionality
- Web admin password configuration via omv-firstaid
- Idempotent operations with provisioning markers

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

#### Container Configuration
- `omv_container_id`: **64** - LXC container ID (matches IP last octet per ADR-002)
- `omv_hostname`: **openmediavault** - Container hostname
- `omv_domain`: **infra.local** - DNS domain suffix
- `omv_memory`: **2048** - RAM allocation in MB
- `omv_cores`: **2** - CPU core count
- `omv_disk`: **64** - Root filesystem size in GB
- `omv_swap`: **1024** - Swap space in MB

#### Network Configuration
- `omv_bridge`: **vmbr3** - Proxmox bridge (DMZ network)
- `omv_ip_config`: **172.16.10.64/24** - Static IP address with CIDR
- `omv_gateway`: **172.16.10.1** - Default gateway for DMZ
- `omv_dns_servers`: **[]** - Custom DNS servers (empty = use Proxmox host DNS)
- `omv_vlan_tag`: **null** - Optional VLAN tag

#### Storage Configuration
- `omv_rootfs_storage`: **local-lvm** - Proxmox storage backend for container rootfs
- `omv_template_url`: Debian 13 (Trixie) template download URL
- `omv_template_file`: Local cache path for Debian template

#### Security & Access
- `omv_root_password`: **vault_omv_root_password** - Container root password (Ansible Vault)
- `omv_admin_user`: **admin** - OMV web interface admin username
- `omv_admin_password`: **vault_omv_admin_password** - OMV web interface password (Ansible Vault)

#### Feature Flags
- `omv_unprivileged`: **true** - Deploy as unprivileged container (security best practice)
- `omv_start_onboot`: **true** - Auto-start container on Proxmox boot
- `omv_features`: **{nesting: 1}** - Container features (nesting enabled)
- `omv_install_extras`: **true** - Install OMV-Extras plugin repository

#### Advanced Configuration
- `omv_extra_plugins`: **[]** - List of additional OMV plugins to install (future use)
- `omv_release_codename`: **bookworm** - OMV release codename

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules: file, get_url, command, shell, lineinfile, stat)

**External Services:**
- **Proxmox VE 9.x**: Hypervisor for LXC container management
- **Debian Template**: Debian 13 (Trixie) LXC template for container base
- **Network Infrastructure**: DMZ bridge (vmbr3), gateway (172.16.10.1)

**Vault Variables (Required in production):**
- `vault_omv_root_password`: Root password for container SSH access
- `vault_omv_admin_password`: Web interface admin password for OMV

**Related Roles:**
- `firewall`: DMZ network routing and NAT configuration
- `traefik`: Reverse proxy for HTTPS access to OMV web interface
- `netbox`: Infrastructure inventory and IP address management

**Optional Integration:**
- **LDAP/Keycloak**: Can be configured post-deployment via OMV web interface for centralized authentication

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox
  roles:
    - role: openmediavault
      vars:
        omv_admin_password: "SecurePassword123!"
        omv_root_password: "RootPassword456!"
```

### Advanced Configuration

```yaml
- hosts: proxmox
  roles:
    - role: openmediavault
      vars:
        omv_container_id: 64
        omv_memory: 4096  # Increase RAM for heavy usage
        omv_cores: 4      # Increase CPU cores
        omv_disk: 128     # Larger root filesystem
        omv_install_extras: true
        omv_dns_servers:
          - 1.1.1.1
          - 1.0.0.1
```

### Deploy Only OpenMediaVault

```bash
ansible-playbook -i inventory playbooks/site.yml --tags openmediavault
```

## Deployment Process

This role performs the following deployment steps in order:

1. **Template Management**
   - Ensures template cache directory exists (`/var/lib/vz/template/cache/`)
   - Downloads Debian 13 (Trixie) LXC template if not present

2. **Container Provisioning**
   - Composes network configuration (bridge, IP, gateway, VLAN)
   - Creates unprivileged LXC container via `pct create`
   - Configures container features (nesting), onboot flag, DNS servers
   - Starts container and waits for boot completion

3. **Initial Container Setup**
   - Sets root password via `chpasswd`
   - Checks for provisioning marker (`/etc/openmediavault/.provisioned`)

4. **OpenMediaVault Installation** (if not provisioned)
   - Installs prerequisites: wget, gnupg, lsb-release, sudo
   - Runs official OMV installation script from GitHub
   - Populates configuration database via `omv-confdbadm populate`

5. **OMV Configuration**
   - Installs OMV-Extras plugin repository (if enabled)
   - Sets web admin password via `omv-firstaid` tool
   - Enables and starts `openmediavault-engined` service
   - Applies all configuration changes via `omv-salt deploy run`

6. **Finalization**
   - Creates provisioning marker to prevent re-provisioning on subsequent runs

## Idempotency

This role ensures safe, idempotent operations through multiple mechanisms:

- **Container Creation Guard**: Uses `creates` parameter to skip `pct create` if container config exists
- **Provisioning Marker**: Checks `/etc/openmediavault/.provisioned` before running installation tasks
- **State Checks**: Verifies container status before starting, checks boot readiness
- **Safe to Re-run**: All tasks include proper conditionals to prevent duplicate installations

**Re-running Behavior:**
- Existing containers are not recreated
- Configuration changes to container (memory, CPU) require manual adjustment or container recreation
- Provisioned OMV installations are not modified (preserves user configuration)
- Network settings and onboot flags are updated if changed

## Post-Deployment Configuration

After deployment, access OpenMediaVault via:
- **Internal URL**: `http://172.16.10.64`
- **External URL**: `https://omv.viljo.se` (via Traefik reverse proxy)
- **Default Credentials**:
  - Username: `admin`
  - Password: Value of `vault_omv_admin_password`

**Recommended Next Steps:**
1. Log in to OMV web interface
2. Configure storage devices and filesystems
3. Create shared folders (SMB/CIFS, NFS)
4. Set up user accounts or integrate with LDAP
5. Install additional plugins via OMV-Extras
6. Configure scheduled tasks and notifications
7. Set up SMART monitoring for connected disks

## Notes

### Performance Considerations
- **Default Resources**: 2 CPU cores, 2GB RAM suitable for basic file serving
- **Heavy Usage**: Increase to 4 cores and 4-8GB RAM for multiple simultaneous users
- **Storage**: Container rootfs (64GB) is for OS only; attach additional storage via bind mounts or Proxmox storage passthrough
- **Network**: DMZ placement requires NAT configuration for internet access (handled by firewall role)

### Security
- **Unprivileged Container**: Runs as unprivileged LXC for enhanced security isolation
- **Vault-Encrypted Passwords**: All sensitive credentials must be stored in Ansible Vault
- **DMZ Segmentation**: Isolated in DMZ network (172.16.10.0/24), not directly on LAN
- **HTTPS Access**: External access should be via Traefik reverse proxy with TLS termination
- **Firewall Rules**: Configure nftables rules to restrict access to necessary ports only

### Storage Integration
- **Proxmox Storage**: Bind mount Proxmox storage pools into container via `pct set` commands
- **Physical Disks**: Pass through physical disks via `/dev/disk/by-id/` device paths
- **Example Bind Mount**: `pct set 64 -mp0 /mnt/data,mp=/srv/data`
- **Permissions**: Ensure UID/GID mapping for unprivileged containers when using bind mounts

### Troubleshooting

**Container Won't Start:**
```bash
pct status 64
pct start 64
journalctl -xe
```

**OMV Web Interface Not Accessible:**
```bash
pct exec 64 -- systemctl status openmediavault-engined nginx
pct exec 64 -- netstat -tlnp | grep -E ':80|:443'
```

**Reset OMV Admin Password:**
```bash
pct exec 64 -- omv-firstaid
# Select option 1: Configure web control panel administrator
```

**View OMV Logs:**
```bash
pct exec 64 -- journalctl -u openmediavault-engined -f
pct exec 64 -- cat /var/log/nginx/error.log
```

**Connectivity Issues:**
```bash
pct exec 64 -- ping -c 3 8.8.8.8  # Test internet connectivity
pct exec 64 -- ip addr show
pct exec 64 -- ip route show
```

### Rollback Procedure

To rollback/remove OpenMediaVault deployment:

```bash
# Stop container
pct stop 64

# Optional: Backup container before destruction
vzdump 64 --storage local --mode snapshot

# Destroy container
pct destroy 64

# Clean up templates (optional)
rm /var/lib/vz/template/cache/debian-13-standard_13.1-2_amd64.tar.zst
```

To redeploy after rollback:
```bash
ansible-playbook -i inventory playbooks/site.yml --tags openmediavault
```

### Known Limitations

1. **LDAP Integration**: Not automated; must be configured manually via OMV web interface
2. **Plugin Installation**: Only OMV-Extras repository is installed; individual plugins require manual installation
3. **Storage Configuration**: Disk attachments and filesystem setup are manual processes
4. **Backup Configuration**: OMV backup jobs must be configured in web interface
5. **Email Notifications**: SMTP settings require manual configuration in OMV
6. **Unprivileged UID Mapping**: Bind mounts require careful UID/GID mapping consideration

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role with declarative configuration
- ✅ **Security-First Design**: Unprivileged container, vault-encrypted credentials, DMZ isolation
- ✅ **Idempotent Operations**: Safe to re-run; provisioning markers prevent duplicate installations
- ✅ **Single Source of Truth**: All configuration centralized in role defaults and inventory variables
- ✅ **Automated Operations**: Complete deployment automation from container creation to service startup

---

**Status**: ✅ Production ready - Fully implemented and documented

**Container Details:**
- **ID**: 64
- **IP**: 172.16.10.64/24
- **Gateway**: 172.16.10.1
- **Bridge**: vmbr3 (DMZ)
- **Access**: https://omv.viljo.se

**Integration Points:**
- Traefik reverse proxy routing configured
- DNS records: openmediavault.viljo.se
- NetBox inventory: Container 64 documented
- DMZ firewall rules required for NAT and port forwarding
