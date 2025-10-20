# Role: demo_site

## Purpose

Deploys a demonstration HTTPS website on Proxmox VE infrastructure to validate reverse proxy, TLS termination, and DNS configuration. This role creates an unprivileged LXC container on the DMZ network running nginx with custom HTML content, accessible via Traefik for HTTPS termination.

**Use Case**: Verify that Traefik reverse proxy, Loopia DNS, and TLS certificate generation are working correctly before deploying production services.

## Architecture

```
Internet
   ↓
Loopia DNS (demosite.viljo.se → Public IP)
   ↓
Traefik (TLS termination, HTTPS → HTTP)
   ↓
Demo Site Container (172.16.10.60:80)
   └─ Nginx serving static HTML
```

**Network**: DMZ network (vmbr3, 172.16.10.0/24)
**Container Type**: Unprivileged LXC
**Resources**: 1GB RAM, 1 CPU core, 8GB disk

## Variables

See [defaults/main.yml](defaults/main.yml) for all configurable variables.

### Container Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `demo_site_container_id` | `60` | Proxmox LXC container ID |
| `demo_site_hostname` | `demosite` | Container hostname |
| `demo_site_memory` | `1024` | RAM allocation in MB |
| `demo_site_cores` | `1` | CPU core allocation |
| `demo_site_disk_size` | `8` | Root disk size in GB |
| `demo_site_unprivileged` | `1` | Unprivileged container (security) |
| `demo_site_onboot` | `1` | Start container on Proxmox boot |

### Network Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `demo_site_ip_address` | `172.16.10.60` | Static IP on DMZ network |
| `demo_site_netmask` | `24` | CIDR netmask |
| `demo_site_gateway` | `172.16.10.1` | Default gateway (Proxmox host) |
| `demo_site_bridge` | `{{ public_bridge \| default('vmbr0') }}` | Network bridge (set to vmbr3 for DMZ) |

### Content Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `demo_site_title` | `"Demo HTTPS Application"` | HTML page title |
| `demo_site_message` | `"This is a demonstration..."` | Welcome message |
| `demo_site_primary_color` | `"#4CAF50"` | CSS accent color |
| `demo_site_domain` | `"viljo.se"` | Public domain |
| `demo_site_external_domain` | `{{ loopia_dns_domain }}` | Public DNS domain |

### Template Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `demo_site_template_name` | `"debian-12-standard_12.7-1_amd64.tar.zst"` | LXC template name |
| `demo_site_template_storage` | `"local"` | Proxmox storage for templates |
| `demo_site_root_storage` | `"local-lvm"` | Storage for container root disk |

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)
- `community.general` (proxmox module)

**External Services:**
- **Proxmox VE**: Host for LXC container
- **Traefik**: Reverse proxy with TLS termination (configured separately)
- **Loopia DNS**: Public DNS records pointing to Traefik
- **DMZ Network**: vmbr3 bridge on 172.16.10.0/24 network

**Vault Variables:**
- `vault_demo_site_root_password`: Root password for LXC container (encrypted in Ansible Vault)

**Related Roles:**
- `traefik`: Provides reverse proxy and HTTPS termination
- `loopia_dns`: Manages DNS records for external access

## Example Usage

### Basic Deployment

Deploy using the provided playbook:

```bash
ansible-playbook -i inventory playbooks/demo-site-deploy.yml
```

Or include in a playbook:

```yaml
- hosts: proxmox_hosts
  become: true
  roles:
    - role: demo_site
```

### Custom Configuration

```yaml
- hosts: proxmox_hosts
  become: true
  roles:
    - role: demo_site
      vars:
        demo_site_container_id: 2350
        demo_site_ip_address: 172.16.10.70
        demo_site_title: "Custom Demo Site"
        demo_site_message: "Welcome to my custom demonstration!"
        demo_site_primary_color: "#2196F3"
```

### Teardown

Remove the demo site container:

```bash
ansible-playbook -i inventory playbooks/demo-site-teardown.yml
```

**Warning**: Teardown is destructive and requires confirmation.

## Deployment Process

The role performs the following steps:

1. **Template Management**
   - Download Debian 12 LXC template to Proxmox if not already cached
   - Verify template integrity and availability

2. **Container Creation**
   - Create unprivileged LXC container with specified resources
   - Configure network interface on DMZ bridge with static IP
   - Set root password from Ansible Vault
   - Enable container autostart on Proxmox boot

3. **Container Start**
   - Start LXC container
   - Wait for container boot and network initialization

4. **Provisioning Check**
   - Check for `/etc/demo-site/.provisioned` marker
   - Skip provisioning if marker exists (idempotent)

5. **Nginx Installation** (if not provisioned)
   - Update apt package cache
   - Install nginx web server
   - Remove default nginx site

6. **Content Deployment**
   - Render `index.html.j2` template with custom title, message, and colors
   - Render `hello.html.j2` template for secondary page
   - Copy HTML files to `/var/www/html/` in container

7. **Service Configuration**
   - Enable nginx service on container boot
   - Start nginx service
   - Create provisioning marker to prevent re-provisioning

8. **Verification**
   - Display deployment summary with access URLs
   - Remind about Traefik configuration requirements

**Total Deployment Time**: ~5-10 minutes (includes template download on first run)

## Idempotency

This role is fully idempotent and safe to re-run:

- **Provisioning Marker**: Creates `/etc/demo-site/.provisioned` marker after initial setup
- **Container Existence Check**: Skips creation if container already exists
- **Template Download**: Downloads template only if not already present
- **Service State**: Ensures nginx is running without restarting unnecessarily

**Re-running the role will**:
- ✅ Verify container exists and is running
- ✅ Skip provisioning if marker file exists
- ✅ Not modify existing configuration

**To force reprovisioning**: Delete the marker file inside the container:
```bash
pct exec 60 -- rm -f /etc/demo-site/.provisioned
```

## Verification

### 1. Container Status

```bash
# Check container is running
pct status 60

# View container configuration
pct config 60

# Check container resource usage
pct status 60 --verbose
```

### 2. Network Connectivity

```bash
# Ping container from Proxmox host
ping -c 3 172.16.10.60

# Check nginx is listening on port 80
pct exec 60 -- ss -tlnp | grep :80
```

### 3. Web Service

```bash
# HTTP access (direct to container)
curl http://172.16.10.60/

# HTTPS access (via Traefik)
curl https://demosite.viljo.se/
curl https://demosite.viljo.se/hello.html
```

### 4. DNS Resolution

```bash
# Verify DNS record
dig demosite.viljo.se

# Check from external network
curl -I https://demosite.viljo.se/
```

## Traefik Integration

The demo site requires Traefik configuration for HTTPS access. Add to Traefik's dynamic configuration:

**File**: `traefik/dynamic/demo-site.yml`

```yaml
http:
  routers:
    demo-site:
      rule: "Host(`demosite.viljo.se`)"
      entryPoints:
        - websecure
      service: demo-site
      tls:
        certResolver: letsencrypt

  services:
    demo-site:
      loadBalancer:
        servers:
          - url: "http://172.16.10.60:80"
```

## DNS Configuration

Configure Loopia DNS to point to your public IP:

```
Record Type: A
Hostname: demosite
Domain: viljo.se
Value: [Your Public IP]
TTL: 3600
```

Or use the `loopia_dns` role to automate DNS management.

## Notes

### Performance Considerations

- **Resources**: 1GB RAM and 1 CPU are sufficient for a static website demo
- **Scaling**: Not designed for production traffic; use for validation only
- **Storage**: 8GB disk includes OS + nginx (uses ~2GB actual)

### Security

- ✅ **Unprivileged Container**: Runs as unprivileged LXC for isolation
- ✅ **Vault-Encrypted Password**: Root password stored in Ansible Vault
- ✅ **DMZ Network**: Isolated on separate VLAN (172.16.10.0/24)
- ✅ **TLS Termination**: HTTPS handled by Traefik, not exposed on container
- ⚠️ **No Authentication**: Demo site has no authentication (by design)
- ⚠️ **Static Content**: No database or user input processing

### Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Container creation fails | Template not available | Verify template name and storage location |
| Cannot ping 172.16.10.60 | Network configuration error | Check vmbr3 bridge exists and has correct subnet |
| Nginx not running | Service failed to start | Run `pct exec 60 -- systemctl status nginx` |
| 502 Bad Gateway from Traefik | Traefik cannot reach container | Verify Traefik can route to 172.16.10.60 |
| DNS not resolving | Loopia record not configured | Check DNS propagation with `dig demosite.viljo.se` |
| HTTPS certificate error | Let's Encrypt challenge failed | Verify port 80/443 forwarding to Traefik |

**Debug Commands**:
```bash
# View container logs
pct enter 60
journalctl -u nginx -f

# Test nginx configuration
pct exec 60 -- nginx -t

# Check Traefik logs for routing issues
docker logs traefik | grep demo-site
```

### Rollback Procedure

To remove the demo site:

```bash
# Use teardown playbook (recommended)
ansible-playbook -i inventory playbooks/demo-site-teardown.yml

# Or manual cleanup
pct stop 60
pct destroy 60

# Remove Traefik configuration
rm traefik/dynamic/demo-site.yml

# Remove DNS record (via Loopia control panel or loopia_dns role)
```

### Known Limitations

- **Single Instance**: Default container ID (60) prevents multiple demo sites without variable override
- **Static Content Only**: No dynamic content generation or backend processing
- **No Persistence**: HTML content regenerated on reprovisioning (not persistent edits)
- **DMZ Network Required**: Assumes vmbr3 bridge exists with 172.16.10.0/24 subnet
- **Traefik Dependency**: HTTPS access requires separate Traefik deployment

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role with declarative configuration
- ✅ **Security-First Design**: Unprivileged LXC container, Ansible Vault for secrets, DMZ network isolation
- ✅ **Idempotent Operations**: Provisioning markers ensure safe re-runs without side effects
- ✅ **Single Source of Truth**: All configuration in role variables and templates
- ✅ **Automated Operations**: Fully automated deployment with verification and teardown playbooks

---

**Status**: ✅ Ready for deployment

**Quick Start**: `ansible-playbook -i inventory playbooks/demo-site-deploy.yml`
