# Role: traefik

## Purpose

Deploys Traefik v2 as a reverse proxy and TLS termination gateway for all infrastructure services. This role handles:

- Traefik binary download and installation
- Static configuration setup (entrypoints, providers, ACME)
- Dynamic configuration management (routes, services, middlewares)
- Let's Encrypt TLS certificate automation via DNS-01 challenge
- Systemd service configuration
- Log rotation and monitoring setup

Traefik serves as the central HTTPS gateway, routing traffic to backend services (GitLab, Nextcloud, Matrix, etc.) with automatic TLS certificate provisioning.

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

**Installation:**
- `traefik_version`: Traefik version to install (default: `v2.11.0`)
- `traefik_arch`: Architecture (default: `linux_amd64`)
- `traefik_install_dir`: Binary installation path (default: `/usr/local/bin`)
- `traefik_config_dir`: Configuration directory (default: `/etc/traefik`)
- `traefik_dynamic_dir`: Dynamic config directory (default: `/etc/traefik/dynamic`)
- `traefik_data_dir`: Data directory for ACME storage (default: `/var/lib/traefik`)
- `traefik_log_dir`: Log directory (default: `/var/log/traefik`)

**User/Group:**
- `traefik_user`: System user for Traefik process (default: `traefik`)
- `traefik_group`: System group (default: `traefik`)

**Logging:**
- `traefik_log_level`: Log verbosity - `DEBUG`, `INFO`, `WARN`, `ERROR` (default: `INFO`)

**ACME/Let's Encrypt:**
- `traefik_acme_email`: Email for Let's Encrypt notifications (default: `admin@example.com`)
- `traefik_dns_challenge_provider`: DNS provider for ACME challenges (default: `cloudflare`)
- `traefik_dns_challenge_delay`: Delay before validation in seconds (default: `0`)
- `traefik_dns_challenge_resolvers`: Custom DNS resolvers for challenge validation (default: `[]`)

**DNS Provider Credentials (Loopia Example):**
- `traefik_dns_api_user`: DNS API username (from `loopia_api_user` or vault)
- `traefik_dns_api_password`: DNS API password (from `loopia_api_password` or vault)
- `traefik_dns_challenge_env`: Environment variables for DNS provider

**Configuration:**
- `traefik_bind_interface`: Bind to specific network interface (default: `""` - all interfaces)
- `traefik_entrypoints`: Custom entrypoint definitions (default: `{}`)
- `traefik_static_config_extra`: Additional static configuration (default: `{}`)
- `traefik_dynamic_configs`: List of dynamic configuration files (default: `[]`)
- `traefik_services`: List of backend services to route (default: `[]`)

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)
- `ansible.posix` (for systemd service management)

**External Services:**
- DNS provider with API access (Cloudflare, Route53, Loopia, etc.)
- Let's Encrypt ACME endpoints (internet connectivity required)
- Backend services to proxy (GitLab, Nextcloud, etc.)

**Vault Variables:**
- `loopia_api_user`: Loopia DNS API username (if using Loopia)
- `loopia_api_password`: Loopia DNS API password (if using Loopia)

**System Requirements:**
- Modern Linux with systemd
- Ports 80 and 443 available
- Network connectivity for ACME challenges

## Example Usage

### Basic Deployment with Cloudflare DNS

```yaml
- hosts: proxmox
  roles:
    - role: traefik
      vars:
        traefik_version: v2.11.0
        traefik_acme_email: admin@example.com
        traefik_dns_challenge_provider: cloudflare
        traefik_dns_challenge_env:
          CF_API_EMAIL: "{{ vault_cloudflare_email }}"
          CF_API_KEY: "{{ vault_cloudflare_api_key }}"
```

### Production Deployment with Custom Entrypoints

```yaml
- hosts: proxmox
  roles:
    - role: traefik
      vars:
        traefik_version: v2.11.0
        traefik_acme_email: admin@example.com
        traefik_log_level: WARN
        traefik_entrypoints:
          web:
            address: ":80"
            http:
              redirections:
                entryPoint:
                  to: websecure
                  scheme: https
          websecure:
            address: ":443"
            http:
              tls:
                certResolver: letsencrypt
        traefik_static_config_extra:
          accessLog:
            filePath: /var/log/traefik/access.log
```

### Deployment with Loopia DNS Provider

```yaml
- hosts: proxmox
  roles:
    - role: traefik
      vars:
        traefik_dns_challenge_provider: loopia
        traefik_dns_api_user: "{{ vault_loopia_api_user }}"
        traefik_dns_api_password: "{{ vault_loopia_api_password }}"
```

## Deployment Process

1. **Binary Download**: Downloads Traefik binary from GitHub releases
2. **User Creation**: Creates `traefik` system user and group
3. **Directory Setup**: Creates config, data, and log directories with proper permissions
4. **Static Configuration**: Generates `/etc/traefik/traefik.yml` with entrypoints and ACME settings
5. **Dynamic Configuration**: Creates dynamic config directory for service routes
6. **Systemd Service**: Installs and enables `traefik.service`
7. **Service Start**: Starts Traefik and validates startup
8. **ACME Bootstrap**: Initiates first certificate request via DNS-01 challenge

## Idempotency

- Binary download uses checksum verification (if `traefik_binary_checksum` provided)
- Configuration changes trigger service reload (not restart) to prevent downtime
- ACME storage persists in `/var/lib/traefik/acme.json`
- Systemd service is enabled only if not already enabled

## Dynamic Configuration

Traefik watches `/etc/traefik/dynamic/` for configuration files. Example dynamic config for GitLab:

```yaml
# /etc/traefik/dynamic/gitlab.yml
http:
  routers:
    gitlab:
      rule: "Host(`gitlab.example.com`)"
      service: gitlab
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

  services:
    gitlab:
      loadBalancer:
        servers:
          - url: "http://192.168.1.50:80"
```

## Notes

### TLS Certificate Management
- Certificates stored in `/var/lib/traefik/acme.json`
- Automatic renewal 30 days before expiration
- DNS-01 challenge supports wildcard certificates (`*.example.com`)
- Let's Encrypt rate limits: 50 certificates per domain per week

### Performance Considerations
- Traefik is lightweight - typically uses <100MB RAM
- HTTP/2 and HTTP/3 support available
- Connection pooling to backend services

### Security
- Runs as unprivileged `traefik` user
- DNS API credentials stored in Ansible Vault
- TLS 1.2+ enforced (configurable)
- Security headers can be added via middlewares

### Troubleshooting
- Check Traefik logs: `journalctl -u traefik -f`
- View dashboard: Enable in static config with basic auth
- Test certificate issuance: `traefik version` shows ACME status
- Validate dynamic configs: Check `/var/log/traefik/traefik.log` for errors

### Rollback Procedure
1. Stop service: `systemctl stop traefik`
2. Backup ACME storage: `cp /var/lib/traefik/acme.json /root/acme.json.backup`
3. Restore previous binary: `cp /usr/local/bin/traefik.old /usr/local/bin/traefik`
4. Restart service: `systemctl restart traefik`

### Known Limitations
- DNS-01 challenge requires DNS provider API access
- Configuration changes require validation before reload
- Backend service health checks not enabled by default

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ✅ **Security-First Design**: TLS enforcement, Vault secrets, unprivileged user
- ✅ **Idempotent Operations**: Rerunnable without disruption
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ✅ **Automated Operations**: Certificate renewal fully automated
