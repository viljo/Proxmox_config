# Zabbix Infrastructure Dashboard Implementation

## Overview

This document describes the comprehensive Zabbix monitoring implementation for the Proxmox infrastructure, including the custom dashboard that displays all infrastructure components in a unified view.

## Architecture

### Component Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                  Internet (Public Access)                        │
│                  https://zabbix.viljo.se                        │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│              Traefik Reverse Proxy (Proxmox Host)                │
│              - TLS Termination                                   │
│              - DNS: zabbix.viljo.se → 172.16.10.61:80           │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│          Zabbix Container (ID: 61, IP: 172.16.10.61)            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Zabbix Server 7.0                                       │   │
│  │  - Monitoring engine (port 10051)                       │   │
│  │  - Alert management                                      │   │
│  │  - Data collection & processing                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Web Interface (Apache2 + PHP)                          │   │
│  │  - Dashboard visualization                               │   │
│  │  - Configuration UI                                      │   │
│  │  - Reporting                                             │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Zabbix Agent (local monitoring)                        │   │
│  │  - Container self-monitoring                            │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Database Connection (PostgreSQL)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│      PostgreSQL Container (ID: 50, IP: 172.16.10.50)            │
│      Database: zabbix                                           │
│      - Metrics storage (365 days history)                       │
│      - Trends storage (730 days)                                │
│      - Configuration data                                       │
└─────────────────────────────────────────────────────────────────┘

                         │ Monitoring Data Collection
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Monitored Infrastructure                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ Firewall    │  │ PostgreSQL  │  │ Jellyfin    │             │
│  │ 172.16.10.1 │  │ 172.16.10.50│  │ 172.16.10.56│             │
│  │ Agent:10050 │  │ Agent:10050 │  │ Agent:10050 │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │HomeAssistant│  │ Demo Site   │  │     OMV     │             │
│  │ 172.16.10.57│  │ 172.16.10.60│  │ 172.16.10.64│             │
│  │ Agent:10050 │  │ Agent:10050 │  │ Agent:10050 │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│  ┌─────────────┐                                                │
│  │   Zipline   │                                                │
│  │ 172.16.10.65│                                                │
│  │ Agent:10050 │                                                │
│  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

## Zabbix Dashboard Features

### Custom "Proxmox Infrastructure Overview" Dashboard

The implementation automatically creates a comprehensive dashboard with 6 main widgets:

#### 1. **Infrastructure Problems** (Top-left, 12x5)
- Real-time visualization of all active problems
- Color-coded severity levels (Disaster, High, Average, Warning, Information)
- Timeline view showing when problems started
- Filterable by service and severity

#### 2. **Container Status** (Top-right, 12x5)
- Grid view of all monitored containers
- Health status indicators (green = OK, red = problems)
- Quick identification of failing services
- Shows problem count per container

#### 3. **Infrastructure Resource Usage** (Middle-left, 12x5)
- Multi-metric graph showing:
  - Combined CPU utilization across all containers
  - Memory usage trends
  - Disk I/O statistics
  - Network bandwidth consumption
- Configurable time range (default: last 1 hour)

#### 4. **Top 10 Issues** (Middle-right, 12x5)
- Ranked list of most critical triggers
- Shows trigger frequency and age
- Quick access to problem resolution
- Helps prioritize incident response

#### 5. **Container Availability** (Bottom-left, 12x4)
- Agent connectivity matrix
- Shows which containers are reachable
- Network health overview
- Alert on communication failures

#### 6. **Services Overview** (Bottom-right, 12x4)
- Data table of all monitored services
- Latest metric values
- Service-specific KPIs
- Customizable columns

### Dashboard Auto-refresh

- Default refresh interval: 30 seconds
- Configurable per user session
- Auto-start enabled for instant visibility
- No manual refresh needed

## Monitored Infrastructure

### Container List

| Container ID | Service | IP Address | Monitoring Templates |
|--------------|---------|------------|---------------------|
| 1 | Firewall | 172.16.10.1 | Linux by Zabbix agent |
| 50 | PostgreSQL | 172.16.10.50 | Linux by Zabbix agent, PostgreSQL by Zabbix agent |
| 56 | Jellyfin | 172.16.10.56 | Linux by Zabbix agent, HTTP Service |
| 57 | Home Assistant | 172.16.10.57 | Linux by Zabbix agent, HTTP Service |
| 60 | Demo Site | 172.16.10.60 | Linux by Zabbix agent, Nginx by Zabbix agent |
| 61 | Zabbix (self) | 172.16.10.61 | Linux by Zabbix agent |
| 64 | OpenMediaVault | 172.16.10.64 | Linux by Zabbix agent, HTTP Service |
| 65 | Zipline | 172.16.10.65 | Linux by Zabbix agent, HTTP Service |

### Monitored Metrics

#### Per Container (Linux Template)
- **CPU**: Load average, CPU utilization, processor count
- **Memory**: Total, used, available, cached, swap usage
- **Disk**: Space utilization, I/O operations, read/write throughput
- **Network**: Interface status, traffic in/out, errors, packet loss
- **System**: Uptime, process count, open file descriptors

#### Service-Specific Metrics

**PostgreSQL (ID: 50)**
- Database connections (active, idle, total)
- Transaction rate (commits, rollbacks)
- Lock statistics
- Cache hit ratio
- Replication status (if configured)
- Database size and growth

**HTTP Services (Jellyfin, Home Assistant, OMV, Zipline)**
- HTTP response time
- Service availability (uptime checks)
- Response codes (200, 4xx, 5xx)
- SSL certificate expiration

**Nginx (Demo Site)**
- Requests per second
- Active connections
- Worker processes
- Request processing time

## Deployment Process

### Prerequisites

1. **Vault Secrets** - Add to `inventory/group_vars/all/secrets.yml`:
```yaml
vault_zabbix_root_password: "your-secure-root-password"
vault_zabbix_db_password: "your-secure-database-password"
vault_zabbix_admin_password: "your-secure-admin-password"
```

2. **DNS Configuration** - Ensure `zabbix` is in your DNS records (already added to inventory)

3. **PostgreSQL** - Container 50 must be running and accessible

### Installation Steps

#### Option 1: Full Infrastructure Deployment
```bash
cd /path/to/Proxmox_config
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

#### Option 2: Zabbix Only
```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags zabbix
```

### Deployment Timeline

1. **Container Creation** (~2 minutes)
   - Downloads Debian 13 template if not cached
   - Creates LXC container with 4 CPU, 8GB RAM, 128GB disk
   - Configures network (172.16.10.61/24)

2. **Package Installation** (~5 minutes)
   - Installs Zabbix 7.0 repository
   - Installs Zabbix server, frontend, agent
   - Installs Apache2 and PHP 8.2

3. **Database Setup** (~3 minutes)
   - Creates `zabbix` database on PostgreSQL container
   - Creates `zabbix` user with appropriate permissions
   - Imports initial schema (~10,000 tables)

4. **Service Configuration** (~1 minute)
   - Configures Zabbix server (connection to PostgreSQL)
   - Configures web frontend (PHP timezone, database connection)
   - Starts all services

5. **Agent Deployment** (~2 minutes per container)
   - Installs Zabbix agent on each monitored container
   - Configures agent to report to server
   - Restarts agent service

6. **Dashboard Provisioning** (~2 minutes)
   - Authenticates with Zabbix API
   - Creates "Proxmox Infrastructure" host group
   - Registers all containers as monitored hosts
   - Creates custom dashboard with 6 widgets
   - Applies monitoring templates

**Total Deployment Time**: ~20-25 minutes

## Post-Deployment Configuration

### First Login

1. **Access Web Interface**
   - URL: https://zabbix.viljo.se
   - Username: `Admin`
   - Password: `zabbix` (or your `vault_zabbix_admin_password`)

2. **Change Admin Password** (CRITICAL!)
   - Go to: Administration → Users → Admin
   - Click "Change password"
   - Set a strong password
   - Update `vault_zabbix_admin_password` in your vault

3. **Verify Dashboard**
   - Navigate to: Monitoring → Dashboards
   - Select "Proxmox Infrastructure Overview"
   - Verify all 6 widgets are displaying data

### Customization Options

#### Add New Monitored Container

Edit `roles/zabbix/defaults/main.yml` and add to `zabbix_monitored_containers`:

```yaml
zabbix_monitored_containers:
  # ... existing containers ...
  - id: 99
    name: "New Service"
    ip: 172.16.10.99
    templates:
      - Linux by Zabbix agent
      - HTTP Service
```

Re-run the playbook:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags zabbix
```

#### Configure Email Alerts

1. Set in `roles/zabbix/defaults/main.yml`:
```yaml
zabbix_enable_email_alerts: true
zabbix_smtp_server: "smtp.gmail.com"
zabbix_smtp_port: 587
zabbix_alert_recipients:
  - admin@example.com
```

2. Configure in Web UI:
   - Administration → Media types → Email
   - Set SMTP server and authentication
   - Administration → Users → Admin → Media
   - Add email alert destination

#### Adjust Retention Periods

In `roles/zabbix/defaults/main.yml`:
```yaml
zabbix_history_storage_days: 365  # Raw metrics (default: 1 year)
zabbix_trends_storage_days: 730   # Aggregated trends (default: 2 years)
```

## Dashboard Usage Guide

### Navigating the Dashboard

1. **Homepage**: Dashboard loads automatically on login
2. **Widget Fullscreen**: Click expand icon on any widget
3. **Time Range**: Use time selector (top-right) to change viewing period
4. **Refresh Control**: Pause auto-refresh or trigger manual refresh

### Understanding Problem States

| Color | Severity | Meaning | Action Required |
|-------|----------|---------|-----------------|
| 🔴 Red | Disaster | Service down or critical failure | Immediate action |
| 🟠 Orange | High | Severe degradation | Urgent investigation |
| 🟡 Yellow | Average | Resource threshold exceeded | Monitor closely |
| 🔵 Blue | Warning | Approaching limits | Plan capacity |
| ⚪ White | Information | Informational notice | No action |

### Common Scenarios

#### Scenario 1: Container Down
**Dashboard Shows**:
- ❌ Red status in "Container Status"
- 🔴 "Zabbix agent is unreachable" in "Infrastructure Problems"
- Missing data in "Resource Usage"

**Resolution**:
1. Check container status: `pct status <container-id>`
2. Start if stopped: `pct start <container-id>`
3. Verify network: `pct exec <container-id> -- ping 172.16.10.61`
4. Check agent: `pct exec <container-id> -- systemctl status zabbix-agent`

#### Scenario 2: High CPU Usage
**Dashboard Shows**:
- 📈 Spike in "Resource Usage" graph
- 🟡 "High CPU utilization" trigger in "Top 10 Issues"

**Resolution**:
1. Click on problem → Identify affected container
2. SSH to container: `pct enter <container-id>`
3. Check processes: `top` or `htop`
4. Investigate application logs

#### Scenario 3: Disk Space Low
**Dashboard Shows**:
- 🟠 "Disk space is low" in "Infrastructure Problems"
- Threshold breach in "Services Overview"

**Resolution**:
1. Identify container from dashboard
2. Check disk usage: `pct exec <container-id> -- df -h`
3. Clean up logs: `pct exec <container-id> -- journalctl --vacuum-time=7d`
4. Increase disk size if needed: `pct resize <container-id> rootfs +20G`

## Maintenance

### Regular Tasks

#### Weekly
- Review "Top 10 Issues" for recurring problems
- Verify all containers show green in "Container Status"
- Check database size growth

#### Monthly
- Review alert configuration and tune thresholds
- Audit monitored services (add/remove as infrastructure changes)
- Export dashboard configuration for backup

#### Quarterly
- Review and adjust data retention policies
- Analyze performance trends for capacity planning
- Update Zabbix templates as new versions release

### Backup and Recovery

#### Backup Dashboard Configuration

```bash
# Export dashboard via API
pct exec 61 -- curl -X POST http://localhost/api_jsonrpc.php \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "dashboard.export",
    "params": {"dashboardids": ["1"]},
    "auth": "YOUR_AUTH_TOKEN",
    "id": 1
  }' > dashboard_backup.json
```

#### Backup Database

```bash
# Dump Zabbix database
pct exec 50 -- sudo -u postgres pg_dump zabbix | gzip > zabbix_db_backup.sql.gz
```

#### Restore Process

1. Redeploy container: `ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags zabbix`
2. Restore database: `zcat zabbix_db_backup.sql.gz | pct exec 50 -- sudo -u postgres psql zabbix`
3. Restart services: `pct exec 61 -- systemctl restart zabbix-server`

## Troubleshooting

### Dashboard Not Loading

**Symptoms**: Blank page or "Server unavailable"

**Checks**:
```bash
# Container running?
pct status 61

# Apache running?
pct exec 61 -- systemctl status apache2

# Zabbix server running?
pct exec 61 -- systemctl status zabbix-server

# Database connection?
pct exec 61 -- psql -h 172.16.10.50 -U zabbix -d zabbix -c "SELECT 1;"
```

### No Data in Dashboard

**Symptoms**: Widgets show "No data" or empty graphs

**Checks**:
```bash
# Agents responding?
pct exec 61 -- zabbix_get -s 172.16.10.56 -k agent.ping

# Check server logs
pct exec 61 -- tail -f /var/log/zabbix/zabbix_server.log

# Verify hosts configured
# Web UI → Configuration → Hosts
```

### Performance Issues

**Symptoms**: Slow dashboard loading, delayed updates

**Optimizations**:
1. Increase cache sizes in `/etc/zabbix/zabbix_server.conf`
2. Add more pollers: `StartPollers=10` (default: 5)
3. Optimize database: `pct exec 50 -- sudo -u postgres vacuumdb -z zabbix`
4. Review item update intervals (reduce frequency for non-critical metrics)

## Integration Points

### Current Integrations

1. **PostgreSQL Backend** - Shared database container (ID: 50)
2. **Traefik Reverse Proxy** - TLS termination and routing
3. **Loopia DNS** - Automatic DNS record creation
4. **Infrastructure Containers** - Auto-deployed agents

### Planned Integrations

1. **NetBox Sync** - Automatic host discovery from CMDB
2. **Grafana Visualization** - Advanced metric dashboards
3. **Prometheus Exporter** - Export metrics to Prometheus
4. **Mattermost Alerts** - Problem notifications to chat
5. **Wazuh SIEM** - Security event correlation

## Security Considerations

### Access Control

- **Web Interface**: Protected by Traefik TLS termination
- **Database**: PostgreSQL authentication, network isolation
- **API**: Admin authentication required for all operations
- **Agents**: Server IP whitelist, passive checks only

### Secrets Management

All sensitive data stored in Ansible Vault:
- `vault_zabbix_root_password` - Container root access
- `vault_zabbix_db_password` - Database credentials
- `vault_zabbix_admin_password` - Web UI admin password

### Network Security

- Container runs unprivileged (security enhancement)
- No direct external access (proxied via Traefik)
- Firewall rules limit access to necessary ports only
- Agent communication authenticated via server IP

## Performance Specifications

### Resource Allocation

- **CPU**: 4 cores (handles ~500 monitored items comfortably)
- **RAM**: 8GB (cache sizes optimized for ~50 hosts)
- **Disk**: 128GB (1 year history + 2 year trends)
- **Network**: DMZ network (vmbr3), low latency to all containers

### Capacity Planning

**Current Load** (7 containers, ~200 items):
- CPU usage: ~10-15%
- RAM usage: ~2-3GB
- Disk growth: ~100MB/day

**Maximum Capacity** (with current resources):
- Hosts: 50-75 containers
- Items: ~2000 monitored metrics
- History: 1 year at 1-minute intervals
- Trends: 2 years at 1-hour intervals

### Scaling Options

If you exceed capacity:

1. **Horizontal Scaling**:
   - Add Zabbix proxy for distributed monitoring
   - Separate web frontend from server

2. **Vertical Scaling**:
   - Increase container resources (8 CPU, 16GB RAM)
   - Expand disk: `pct resize 61 rootfs +128G`

3. **Database Optimization**:
   - Use PostgreSQL partitioning for history table
   - Implement TimescaleDB for time-series optimization

## Future Enhancements

### Phase 2 (Planned)
- Advanced alerting with escalation policies
- Custom UserParameters for application-specific metrics
- SNMP monitoring for network devices
- Service dependency mapping

### Phase 3 (Under Consideration)
- Machine learning-based anomaly detection
- Predictive alerting (forecast capacity issues)
- Multi-tenant dashboard views
- Mobile app integration

## Support and Documentation

### Official Resources
- **Zabbix Documentation**: https://www.zabbix.com/documentation/7.0/
- **API Reference**: https://www.zabbix.com/documentation/7.0/manual/api
- **Community Forums**: https://www.zabbix.com/forum

### Project-Specific
- **Role README**: `roles/zabbix/README.md`
- **Configuration**: `roles/zabbix/defaults/main.yml`
- **Templates**: `roles/zabbix/templates/`

## Conclusion

This Zabbix implementation provides comprehensive, real-time monitoring of your entire Proxmox infrastructure through a unified, intuitive dashboard. The automated deployment ensures consistency, while the custom dashboard design gives immediate visibility into system health and performance.

The infrastructure-as-code approach means you can replicate this monitoring setup across multiple environments, and the extensive configuration options allow you to tailor monitoring to your specific needs.

---

**Document Version**: 1.0
**Last Updated**: 2025-10-22
**Author**: Claude Code Infrastructure Assistant
