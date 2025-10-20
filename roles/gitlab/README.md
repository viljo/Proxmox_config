# Role: gitlab

## Purpose

Deploys GitLab CE (Community Edition) in an unprivileged LXC container on Proxmox VE. This role handles the complete lifecycle of GitLab deployment including:

- LXC container creation and configuration
- Debian repository setup with mirror fallbacks
- GitLab Omnibus package installation
- LDAP authentication integration
- Container Registry enablement
- Network configuration with optional VLAN tagging

GitLab serves as the central DevOps platform for repository hosting, CI/CD pipelines, package registries, and project management.

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

**Container Configuration:**
- `gitlab_container_id`: LXC container ID (default: `53`)
- `gitlab_hostname`: Container hostname (default: `gitlab`)
- `gitlab_domain`: Domain suffix for URLs (default: `infra.local`)
- `gitlab_cores`: CPU cores allocated (default: `4`)
- `gitlab_memory`: RAM in MB (default: `8192`)
- `gitlab_disk`: Root filesystem size in GB (default: `128`)
- `gitlab_swap`: Swap size in MB (default: `2048`)

**Network Configuration:**
- `gitlab_bridge`: Proxmox network bridge (default: `vmbr0` from `public_bridge`)
- `gitlab_ip_config`: IP configuration - `dhcp` or static IP (default: `dhcp`)
- `gitlab_vlan_tag`: Optional VLAN tag (default: `null`)
- `gitlab_gateway`: Optional gateway override (default: `null`)
- `gitlab_dns_servers`: List of DNS servers (default: `[]`)

**GitLab Configuration:**
- `gitlab_external_url`: Public URL for GitLab (default: `https://gitlab.{{ gitlab_domain }}`)
- `gitlab_omnibus_package`: Package to install (default: `gitlab-ce`)
- `gitlab_registry_enable`: Enable container registry (default: `true`)
- `gitlab_initial_root_password`: Initial root password (from vault: `vault_gitlab_root_password`)

**LDAP Integration:**
- `gitlab_ldap_enable`: Enable LDAP authentication (default: `true`)
- `gitlab_ldap_host`: LDAP server hostname (from `ldap_service_host`)
- `gitlab_ldap_port`: LDAP server port (from `ldap_service_port`)
- `gitlab_ldap_bind_dn`: LDAP bind DN (from `ldap_admin_bind_dn`)
- `gitlab_ldap_bind_password`: LDAP bind password (from `ldap_admin_password`)
- `gitlab_ldap_base`: LDAP search base (from `ldap_suffix`)
- `gitlab_ldap_user_filter`: LDAP user filter (default: `(&(objectClass=inetOrgPerson))`)

**Storage:**
- `gitlab_rootfs_storage`: Proxmox storage for container (default: `local-lvm`)
- `gitlab_template_url`: Debian template download URL
- `gitlab_template_file`: Local path to cached template

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)
- `community.general` (for potential proxmox module usage)

**External Services:**
- Proxmox VE host with API access
- LDAP server (if `gitlab_ldap_enable: true`)
- DNS resolution for `gitlab_external_url`
- Network connectivity for package downloads

**Vault Variables:**
- `vault_gitlab_root_password`: GitLab root password (stored in `group_vars/all/secrets.yml`)
- `ldap_admin_password`: LDAP bind password (stored in vault)

**Related Roles:**
- `ldap` - Provides LDAP directory for authentication
- `traefik` - Provides reverse proxy and TLS termination for `gitlab_external_url`
- `network` - Configures Proxmox network bridges

## Example Usage

### Basic Deployment with DHCP

```yaml
- hosts: proxmox
  roles:
    - role: gitlab
      vars:
        gitlab_container_id: 53
        gitlab_hostname: gitlab
        gitlab_domain: example.com
        gitlab_external_url: https://gitlab.example.com
```

### Production Deployment with Static IP and VLAN

```yaml
- hosts: proxmox
  roles:
    - role: gitlab
      vars:
        gitlab_container_id: 53
        gitlab_hostname: gitlab
        gitlab_domain: example.com
        gitlab_cores: 8
        gitlab_memory: 16384
        gitlab_disk: 256
        gitlab_ip_config: 172.16.10.53/24
        gitlab_gateway: 172.16.10.1
        gitlab_vlan_tag: 10
        gitlab_dns_servers:
          - 1.1.1.1
          - 8.8.8.8
        gitlab_external_url: https://gitlab.example.com
        gitlab_ldap_enable: true
```

### Disable LDAP Authentication

```yaml
- hosts: proxmox
  roles:
    - role: gitlab
      vars:
        gitlab_ldap_enable: false
        gitlab_initial_root_password: "{{ vault_gitlab_root_password }}"
```

## Deployment Process

1. **Template Download**: Downloads Debian 13 (Trixie) LXC template if not cached
2. **Container Creation**: Creates unprivileged LXC container with specified resources
3. **Network Configuration**: Configures network interface with DHCP or static IP
4. **Container Start**: Starts container and waits for boot completion
5. **APT Configuration**: Configures apt sources with mirror fallbacks and retry logic
6. **Dependency Installation**: Installs `curl`, `ca-certificates`, `tzdata`, `perl`, `gnupg`
7. **GitLab Repository**: Adds GitLab CE repository via official script
8. **GitLab Installation**: Installs GitLab Omnibus package with retries
9. **LDAP Configuration**: Configures LDAP authentication if enabled
10. **Reconfiguration**: Runs `gitlab-ctl reconfigure` to apply settings
11. **Provisioning Marker**: Creates `/etc/gitlab/.provisioned` marker to prevent re-provisioning

## Idempotency

- Container creation uses `creates` parameter - only runs if LXC config doesn't exist
- Provisioning marker (`/etc/gitlab/.provisioned`) prevents re-running expensive operations
- State checks before starting container (checks if already running)
- Configuration changes trigger reconfiguration only when needed

## Notes

### Performance Considerations
- GitLab requires significant resources: minimum 4 cores and 8GB RAM recommended
- Initial installation and reconfiguration can take 5-10 minutes
- Container registry requires additional disk space

### Security
- All passwords stored in Ansible Vault (encrypted)
- LXC container runs unprivileged for security isolation
- LDAP credentials use secure bind with `no_log: true` to prevent logging
- TLS termination should be handled by Traefik reverse proxy

### Troubleshooting
- Check container status: `pct status 53`
- View container logs: `pct enter 53` then `gitlab-ctl tail`
- Reconfigure GitLab: `pct exec 53 -- gitlab-ctl reconfigure`
- Check LDAP connectivity: `pct exec 53 -- gitlab-rake gitlab:ldap:check`

### Rollback Procedure
1. Stop container: `pct stop 53`
2. Backup container: `vzdump 53 --mode stop --storage local`
3. Destroy container: `pct destroy 53`
4. Restore from backup: `pct restore 53 /var/lib/vz/dump/vzdump-lxc-53-*.tar.zst`
5. Start container: `pct start 53`

### Known Limitations
- Uses `pct` command-line tool instead of native Ansible Proxmox module (manual state management)
- Initial root password set via command-line argument (briefly visible in process table)
- No automatic backup of GitLab data before destructive operations

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ✅ **Security-First Design**: LDAP integration, Vault secrets, unprivileged LXC
- ⚠️ **Idempotent Operations**: Mostly idempotent, but parameter changes require manual intervention
- ✅ **Single Source of Truth**: Variables centralized in inventory
- ✅ **Automated Operations**: Deployment fully automated via playbook
