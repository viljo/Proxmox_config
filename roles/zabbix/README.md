# Zabbix Monitoring Role

This role deploys a Zabbix monitoring server in an LXC container on Proxmox and automatically configures monitoring for all infrastructure components.

## Features

- **Zabbix Server 7.0** with PostgreSQL backend
- **Web Interface** with Apache2
- **Automatic Agent Deployment** to all monitored containers
- **Custom Infrastructure Dashboard** showing all services
- **Auto-discovery** of container network
- **Long-term Metrics Storage** (365 days history, 730 days trends)

## Container Specifications

- **Container ID**: 61
- **IP Address**: 172.16.10.61/24
- **Hostname**: zabbix
- **Resources**: 4 CPU cores, 8GB RAM, 128GB disk
- **Network**: DMZ (vmbr3)

## Prerequisites

- PostgreSQL container (ID 50) must be running
- Containers to be monitored must be running
- DNS and Traefik configuration for external access

## Configuration

### Default Variables (defaults/main.yml)

Key variables you may want to customize:

```yaml
# Database credentials
zabbix_db_password: "{{ vault_zabbix_db_password }}"

# Admin password (change after first login!)
zabbix_admin_password: "{{ vault_zabbix_admin_password }}"

# Monitored containers
zabbix_monitored_containers:
  - id: 50
    name: PostgreSQL
    ip: 172.16.10.50
    templates:
      - Linux by Zabbix agent
      - PostgreSQL by Zabbix agent
```

### Vault Secrets

Add these to `inventory/group_vars/all/secrets.yml`:

```yaml
vault_zabbix_root_password: "secure-root-password"
vault_zabbix_db_password: "secure-db-password"
vault_zabbix_admin_password: "secure-admin-password"
```

## Usage

### Deploy Zabbix Server

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags zabbix
```

### Access Web Interface

After deployment, access Zabbix at:

- **URL**: https://zabbix.viljo.se (or http://172.16.10.61)
- **Username**: Admin
- **Password**: zabbix (default) or your vault_zabbix_admin_password

**IMPORTANT**: Change the admin password immediately after first login!

## Infrastructure Dashboard

The role automatically creates a comprehensive "Proxmox Infrastructure Overview" dashboard with:

1. **Infrastructure Problems** - Real-time issue visualization
2. **Container Status** - Health status of all containers
3. **Resource Usage Graph** - CPU, memory, disk trends
4. **Top Issues** - Most critical problems
5. **Container Availability** - Agent connectivity status
6. **Services Overview** - All monitored services at a glance

## Monitored Services

By default, the following containers are monitored:

| Container | IP | Templates |
|-----------|-----|-----------|
| PostgreSQL | 172.16.10.50 | Linux, PostgreSQL |
| Jellyfin | 172.16.10.56 | Linux, HTTP Service |
| Home Assistant | 172.16.10.57 | Linux, HTTP Service |
| Demo Site | 172.16.10.60 | Linux, Nginx |
| OpenMediaVault | 172.16.10.64 | Linux, HTTP Service |
| Zipline | 172.16.10.65 | Linux, HTTP Service |
| Firewall | 172.16.10.1 | Linux |

## Adding New Hosts

To monitor additional containers, add them to `zabbix_monitored_containers` in your inventory:

```yaml
zabbix_monitored_containers:
  - id: 99
    name: "My New Service"
    ip: 172.16.10.99
    templates:
      - Linux by Zabbix agent
      - HTTP Service
```

Then re-run the playbook with:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags zabbix
```

## Integration with NetBox

Future enhancement: Automatic host synchronization from NetBox CMDB to Zabbix monitoring.

## Troubleshooting

### Check Zabbix Server Status

```bash
pct exec 61 -- systemctl status zabbix-server
```

### View Zabbix Logs

```bash
pct exec 61 -- tail -f /var/log/zabbix/zabbix_server.log
```

### Test Database Connection

```bash
pct exec 61 -- psql -h 172.16.10.50 -U zabbix -d zabbix -c "SELECT version();"
```

### Verify Agent Connectivity

```bash
pct exec 61 -- zabbix_get -s 172.16.10.56 -k agent.ping
```

## Performance Tuning

The role includes optimized cache sizes for infrastructure monitoring:

- CacheSize: 128M
- HistoryCacheSize: 64M
- ValueCacheSize: 128M
- StartPollers: 5

Adjust these in `templates/zabbix_server.conf.j2` for larger deployments.

## Security

- Container runs unprivileged
- Database credentials stored in Ansible Vault
- Agent connections restricted to Zabbix server IP
- External access via Traefik with TLS termination

## Architecture

```
┌─────────────────────────────────────────────┐
│         Traefik (Proxmox Host)              │
│         https://zabbix.viljo.se             │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│     Zabbix Container (172.16.10.61)         │
│  ┌──────────────────────────────────┐       │
│  │   Zabbix Server + Web UI         │       │
│  │   Apache2 + PHP Frontend         │       │
│  └───────────┬──────────────────────┘       │
└──────────────┼──────────────────────────────┘
               │
               │ PostgreSQL Connection
               ▼
┌──────────────────────────────────────────────┐
│   PostgreSQL Container (172.16.10.50)        │
│   Database: zabbix                           │
└──────────────────────────────────────────────┘

               │ Zabbix Agent Monitoring
               ▼
┌──────────────────────────────────────────────┐
│         Monitored Containers                 │
│  - Jellyfin, Home Assistant, Firewall, etc.  │
│  - Each runs Zabbix Agent (port 10050)       │
└──────────────────────────────────────────────┘
```

## License

Part of the Proxmox Infrastructure Configuration project.

## Author

Generated by Claude Code for comprehensive infrastructure monitoring.
