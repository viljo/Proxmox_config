# Role: demo_site

## Purpose

Deploys a multi-purpose web portal on Proxmox VE infrastructure serving three distinct sites:

1. **Links Portal** (`links.viljo.se`) - Centralized directory of all public-facing services
2. **Matrix Landing Page** (`viljo.se`) - Animated matrix rain effect landing page
3. **Demo Site** (`demo.viljo.se`) - Original validation website for Traefik/TLS testing

This role creates an unprivileged LXC container on the DMZ network running nginx with multiple virtual hosts, accessible via Traefik for HTTPS termination.

**Use Cases**:
- Provide users with easy access to all infrastructure services via links portal
- Display visually appealing landing page for root domain
- Validate that Traefik reverse proxy, DNS, and TLS are working correctly

## Architecture

```
Internet
   ↓
Loopia DNS (viljo.se, links.viljo.se, demo.viljo.se → Public IP)
   ↓
Traefik (TLS termination, HTTPS → HTTP)
   ↓
Demo Site Container (172.16.10.60:80)
   └─ Nginx with virtual hosts
      ├─ viljo.se → matrix.html (Matrix animation)
      ├─ links.viljo.se → links.html (Service directory)
      └─ demo.viljo.se → index.html (Demo page)
```

**Network**: DMZ network (vmbr3, 172.16.10.0/24)
**Container Type**: Unprivileged LXC
**Resources**: 1GB RAM, 1 CPU core, 8GB disk

### Served Pages

| Domain | Page | Purpose |
|--------|------|---------|
| `viljo.se` | `matrix.html` | Matrix rain animation landing page |
| `links.viljo.se` | `links.html` | Service directory with links to all infrastructure services |
| `demo.viljo.se` | `index.html` | Original demo/validation page |
| Any domain | `hello.html` | Secondary test page (accessible via direct path) |

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
   - Configure nginx virtual hosts for multiple domains

6. **Nginx Configuration**
   - Deploy nginx site configuration with server blocks
   - Configure domain-based routing (viljo.se, links.viljo.se, demo.viljo.se)
   - Remove default nginx site
   - Enable custom site configuration

7. **Content Deployment**
   - Render `matrix.html.j2` template for viljo.se landing page
   - Render `links.html.j2` template with all service links
   - Render `index.html.j2` template with custom title, message, and colors
   - Render `hello.html.j2` template for secondary page
   - Copy all HTML files to `/var/www/html/` in container

8. **Service Configuration**
   - Enable nginx service on container boot
   - Start/restart nginx service
   - Create provisioning marker to prevent re-provisioning

9. **Verification**
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
curl https://viljo.se/                # Matrix landing page
curl https://links.viljo.se/          # Service directory
curl https://demo.viljo.se/           # Demo page
curl https://demo.viljo.se/hello.html # Test page
```

### 4. DNS Resolution

```bash
# Verify DNS record
dig demosite.viljo.se

# Check from external network
curl -I https://demosite.viljo.se/
```

## Traefik Integration

The demo site requires Traefik configuration for HTTPS access to all three domains. The configuration is managed via the `traefik_services` variable in inventory.

**Inventory Configuration** (`inventory/group_vars/all/main.yml`):

```yaml
traefik_services:
  - name: viljo
    host: "{{ public_domain }}"           # viljo.se
    container_id: "{{ demo_site_container_id }}"
    port: "{{ demo_site_service_port }}"
  - name: links
    host: "links.{{ public_domain }}"     # links.viljo.se
    container_id: "{{ demo_site_container_id }}"
    port: "{{ demo_site_service_port }}"
  - name: demo
    host: "demo.{{ public_domain }}"      # demo.viljo.se
    container_id: "{{ demo_site_container_id }}"
    port: "{{ demo_site_service_port }}"
```

All three domains route to the same container (172.16.10.60:80), with nginx virtual hosts serving different content based on the `Host` header.

## DNS Configuration

Configure Loopia DNS records for all three domains:

**Required DNS Records**:
```
Record Type: A
Hostname: @         # Root domain (viljo.se)
Domain: viljo.se
Value: [Your Public IP]
TTL: 600

Record Type: A
Hostname: links     # Subdomain (links.viljo.se)
Domain: viljo.se
Value: [Your Public IP]
TTL: 600

Record Type: A
Hostname: demo      # Subdomain (demo.viljo.se)
Domain: viljo.se
Value: [Your Public IP]
TTL: 600
```

Or use the `loopia_dns` role to automate DNS management. The DNS records are configured via the `loopia_dns_records` variable in inventory.

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
- **Manual Service Updates**: New services must be manually added to `links.html.j2` template

### Service Registry Requirement

**IMPORTANT**: When deploying new public-facing services to the infrastructure, you MUST update the links portal to include them:

1. Edit `roles/demo_site/templates/links.html.j2`
2. Add a new service card with:
   - Service icon (emoji)
   - Service name
   - Service description
   - Service URL (following pattern: `servicename.{{ demo_site_external_domain }}`)
3. Group the service logically with similar services
4. Redeploy the demo_site role to update the links page

This requirement ensures users can discover all available services from the centralized portal.

**Reference**: See [Spec 010 - Links Portal](../../specs/completed/010-links-portal/spec.md) and [Global Service Requirements](../../specs/README.md#global-requirements-for-all-new-services)

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role with declarative configuration
- ✅ **Security-First Design**: Unprivileged LXC container, Ansible Vault for secrets, DMZ network isolation
- ✅ **Idempotent Operations**: Provisioning markers ensure safe re-runs without side effects
- ✅ **Single Source of Truth**: All configuration in role variables and templates
- ✅ **Automated Operations**: Fully automated deployment with verification and teardown playbooks

---

**Status**: ✅ Ready for deployment

**Quick Start**: `ansible-playbook -i inventory playbooks/demo-site-deploy.yml`
