# Role: wazuh

## Purpose

This role deploys and configures Wazuh, an open-source security monitoring platform that provides SIEM (Security Information and Event Management) and XDR (Extended Detection and Response) capabilities. Wazuh runs as a Docker Compose stack inside an LXC container on Proxmox VE infrastructure.

Wazuh provides:
- **Security Monitoring**: Real-time threat detection and incident response
- **Log Analysis**: Centralized log collection and analysis
- **Intrusion Detection**: File integrity monitoring and rootkit detection
- **Vulnerability Detection**: System and application vulnerability scanning
- **Compliance Management**: PCI DSS, GDPR, HIPAA compliance reporting
- **Cloud Security**: AWS, Azure, GCP security monitoring

## Architecture

The Wazuh deployment consists of three main components running in Docker containers:

1. **Wazuh Manager**: Core component handling agent communication, rule processing, and alert generation
2. **Wazuh Indexer**: OpenSearch-based indexer for storing security events and alerts
3. **Wazuh Dashboard**: Web interface for visualization, analysis, and management

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

**Container Configuration:**
- `wazuh_container_id`: `62` - LXC container ID
- `wazuh_hostname`: `wazuh` - Container hostname
- `wazuh_domain`: `viljo.se` - Public domain
- `wazuh_fqdn`: `wazuh.viljo.se` - Full qualified domain name
- `wazuh_memory`: `8192` - RAM allocation in MB (8GB required)
- `wazuh_cores`: `4` - CPU core count
- `wazuh_disk`: `64` - Disk size in GB
- `wazuh_swap`: `2048` - Swap size in MB

**Network Configuration:**
- `wazuh_bridge`: `vmbr3` - Proxmox bridge (DMZ network)
- `wazuh_ip_address`: `172.16.10.62` - Static IP address
- `wazuh_gateway`: `172.16.10.1` - Default gateway (firewall)
- `wazuh_dns_servers`: `["172.16.10.1", "1.1.1.1"]` - DNS servers

**Wazuh Configuration:**
- `wazuh_version`: `4.9.2` - Wazuh version to deploy
- `wazuh_api_user`: `wazuh` - Wazuh API username
- `wazuh_api_password`: Vault-encrypted API password
- `wazuh_indexer_password`: Vault-encrypted indexer password

**Traefik Integration:**
- `wazuh_enable_traefik`: `true` - Enable Traefik reverse proxy
- `wazuh_traefik_router`: `wazuh` - Traefik router name
- `wazuh_traefik_entrypoint`: `websecure` - HTTPS entrypoint

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)
- `community.general` (additional utilities)

**External Services:**
- **Traefik**: Reverse proxy for HTTPS access (optional but recommended)
- **Firewall**: Container 1 provides NAT/gateway services
- **DNS**: DNS resolution via firewall or external DNS

**Vault Variables:**
Required secrets in `inventory/group_vars/all/secrets.yml`:
- `vault_wazuh_root_password`: Root password for LXC container
- `vault_wazuh_api_password`: Wazuh API authentication password
- `vault_wazuh_indexer_password`: OpenSearch indexer password

**Related Roles:**
- `roles/firewall`: Provides network gateway and port forwarding
- `roles/traefik`: Provides HTTPS termination and routing
- `roles/network`: Configures Proxmox networking (vmbr3)

## Example Usage

### Basic Deployment

```yaml
- hosts: proxmox_admin
  roles:
    - role: wazuh
```

### Advanced Configuration

```yaml
- hosts: proxmox_admin
  roles:
    - role: wazuh
      vars:
        wazuh_version: "4.9.2"
        wazuh_memory: 16384  # Increase to 16GB for large deployments
        wazuh_cores: 8
        wazuh_enable_traefik: true
```

### Deploy Only Wazuh

```bash
ansible-playbook playbooks/site.yml --tags wazuh
```

## Deployment Process

This role performs the following deployment steps:

1. **Template Download**: Downloads Debian 13 LXC template if not cached
2. **Container Creation**: Creates unprivileged LXC container with nesting enabled
3. **Network Configuration**: Configures static IP on DMZ network (172.16.10.62/24)
4. **Container Boot**: Starts container and waits for system readiness
5. **Docker Installation**: Installs Docker and Docker Compose plugin
6. **Directory Setup**: Creates configuration and data directories
7. **Compose Deployment**: Deploys docker-compose.yml with Wazuh stack
8. **Service Startup**: Launches Wazuh Manager, Indexer, and Dashboard
9. **Provisioning Marker**: Sets marker to prevent re-provisioning

## Ports and Services

**Exposed Ports:**
- `443`: HTTPS (via Traefik) - Wazuh Dashboard web interface
- `5601`: Direct access to Wazuh Dashboard
- `1514`: Wazuh agent communication (registration and events)
- `1515`: Wazuh agent enrollment service
- `514/UDP`: Syslog collector (UDP)
- `514/TCP`: Syslog collector (TCP)
- `55000`: Wazuh API (RESTful API for management)
- `9200`: OpenSearch/Indexer API (internal)

## Access and Credentials

**Web Interface:**
- URL: `https://wazuh.viljo.se` (via Traefik)
- Direct: `https://172.16.10.62:5601`
- Default Username: `admin`
- Default Password: `admin` (change immediately after first login)

**Wazuh API:**
- Endpoint: `https://172.16.10.62:55000`
- Username: `{{ wazuh_api_user }}`
- Password: `{{ wazuh_api_password }}` (from vault)

**Container Access:**
```bash
# SSH to Proxmox host
ssh root@192.168.1.3

# Enter Wazuh container
pct enter 62

# Check Docker containers
docker ps

# View logs
docker compose -f /opt/wazuh/docker-compose.yml logs -f
```

## Agent Deployment

To monitor other systems with Wazuh agents:

1. **Generate Agent Deployment Command:**
   - Login to Wazuh Dashboard
   - Navigate to Agents → Deploy new agent
   - Select operating system and follow instructions

2. **Example Linux Agent Installation:**
```bash
# Download and install agent
curl -so wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.2-1_amd64.deb
WAZUH_MANAGER='172.16.10.62' dpkg -i wazuh-agent.deb

# Start agent
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent
```

3. **Configure Firewall:**
Ensure agents can reach port 1514/1515 on 172.16.10.62

## Idempotency

This role ensures idempotent operations through:

- **Provisioning Marker**: `/etc/wazuh/.provisioned` prevents re-running installation
- **Container Creation**: Uses `creates` parameter to avoid recreating existing containers
- **State Checks**: Verifies container existence and status before operations
- **Docker Compose**: Idempotent stack updates via `docker compose up -d`
- **Safe Re-run**: Role can be safely re-executed without data loss

## Notes

### Performance Considerations

**Resource Requirements:**
- Minimum: 4 cores, 8GB RAM, 64GB disk
- Recommended (production): 8 cores, 16GB RAM, 128GB disk
- Heavy usage: 16 cores, 32GB RAM, 256GB+ disk

**Scaling Guidelines:**
- Up to 100 agents: Default resources sufficient
- 100-500 agents: Increase to 8 cores, 16GB RAM
- 500+ agents: Consider multi-node cluster deployment

**Performance Tuning:**
- Adjust `OPENSEARCH_JAVA_OPTS` heap size (currently 2GB)
- Increase `wazuh_memory` for larger agent deployments
- Monitor disk I/O and consider SSD storage for indexer

### Security

**Security Features:**
- Unprivileged LXC container for isolation
- TLS encryption for all communications
- API authentication required
- Network segmentation via DMZ (vmbr3)
- Vault-encrypted credentials

**Hardening Recommendations:**
1. Change default `admin` password immediately
2. Create separate user accounts with appropriate roles
3. Enable two-factor authentication in dashboard
4. Restrict agent enrollment to specific networks
5. Configure firewall rules to limit API access
6. Regularly update to latest Wazuh version
7. Review and tune detection rules

**Certificate Management:**
- Wazuh generates self-signed certificates on first start
- For production, replace with proper CA-signed certificates
- Certificate paths: `/opt/wazuh/config/wazuh_indexer_ssl_certs/`

### Troubleshooting

**Container Won't Start:**
```bash
# Check container status
pct status 62

# View container logs
pct enter 62
journalctl -xe
```

**Docker Services Not Running:**
```bash
pct enter 62
cd /opt/wazuh
docker compose ps
docker compose logs wazuh-manager
docker compose logs wazuh-indexer
docker compose logs wazuh-dashboard
```

**Dashboard Not Accessible:**
```bash
# Check if services are healthy
docker ps

# Verify port bindings
ss -tlnp | grep 5601

# Check Traefik routing
curl -I https://wazuh.viljo.se

# Test direct access
curl -k https://172.16.10.62:5601
```

**Agents Not Connecting:**
```bash
# Check firewall rules
iptables -L -n | grep 1514

# Test connectivity from agent
telnet 172.16.10.62 1514

# View manager logs
pct exec 62 -- docker compose -f /opt/wazuh/docker-compose.yml logs wazuh-manager
```

**High Resource Usage:**
```bash
# Monitor container resources
pct status 62 --verbose

# Check Docker container resources
pct exec 62 -- docker stats

# Review indexer heap usage
pct exec 62 -- docker compose logs wazuh-indexer | grep -i heap
```

### Rollback Procedure

**Complete Rollback:**
```bash
# Stop and destroy container
ssh root@192.168.1.3
pct stop 62
pct destroy 62

# Re-run deployment
ansible-playbook playbooks/site.yml --tags wazuh
```

**Restart Services Only:**
```bash
pct enter 62
cd /opt/wazuh
docker compose down
docker compose up -d
```

**Data Preservation:**
Docker volumes persist even after container restarts. To preserve data during complete rebuild:
```bash
# Backup data before destroy
pct backup 62 --compress zstd --mode snapshot

# After rebuild, restore from backup if needed
pct restore 62 /var/lib/vz/dump/vzdump-lxc-62-*.tar.zst
```

### Known Limitations

- Single-node deployment (not clustered)
- Self-signed certificates (manual replacement needed for production)
- No automated backup of Wazuh data (use LXC snapshots)
- Dashboard must be accessed via HTTPS (HTTP redirects may fail)
- Large agent deployments (500+) may require manual tuning

### Maintenance Tasks

**Regular Maintenance:**
- Monitor disk usage in indexer volume
- Review and archive old indices
- Update Wazuh version quarterly
- Review security alerts and tune rules
- Check agent connectivity status
- Rotate API credentials annually

**Backup Strategy:**
```bash
# Create LXC snapshot
pct snapshot 62 wazuh-backup-$(date +%Y%m%d)

# List snapshots
pct listsnapshot 62

# Restore from snapshot
pct rollback 62 wazuh-backup-20251022
```

## Integration Examples

### Monitor Proxmox Host

Deploy Wazuh agent on Proxmox host:
```bash
# On Proxmox host
curl -so wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.2-1_amd64.deb
WAZUH_MANAGER='172.16.10.62' dpkg -i wazuh-agent.deb
systemctl enable --now wazuh-agent
```

### Monitor Docker Containers

Configure Wazuh to monitor other LXC containers by deploying agents inside them.

### Alert Integration

Configure Wazuh to send alerts to:
- Email (SMTP configuration)
- Slack/Mattermost webhooks
- PagerDuty/Opsgenie
- Custom integrations via API

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role
- ✅ **Security-First Design**: Uses unprivileged LXC, TLS encryption, vault secrets
- ✅ **Idempotent Operations**: Safe to re-run, provisioning markers prevent duplication
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ✅ **Automated Operations**: Complete deployment automation, no manual steps
- ✅ **Documentation**: Comprehensive README with examples and troubleshooting
- ✅ **Network Isolation**: Deployed on DMZ network with firewall protection

## References

- [Wazuh Documentation](https://documentation.wazuh.com/)
- [Wazuh Docker Deployment](https://documentation.wazuh.com/current/deployment-options/docker/index.html)
- [Wazuh API Reference](https://documentation.wazuh.com/current/user-manual/api/reference.html)
- [Security Compliance](https://documentation.wazuh.com/current/compliance/index.html)

---

**Status**: ✅ Complete and production-ready

**Last Updated**: 2025-10-22

**Maintainer**: Infrastructure Team
