# Infrastructure Backup Role

Comprehensive backup role for all infrastructure components including LXC containers, PostgreSQL databases, Redis data, Docker volumes, and Proxmox configurations.

## Overview

This role performs automated backups of:
- **11 LXC containers** via Proxmox vzdump
- **4 PostgreSQL databases** (Keycloak, GitLab, Nextcloud, Mattermost)
- **Redis data** (dump.rdb)
- **Docker volumes** from 5 containers
- **Proxmox configuration files** (LXC configs, network, Traefik, etc.)

## Quick Start

### Basic Backup

```bash
ansible-playbook -i inventory/hosts.yml playbooks/backup-infrastructure.yml
```

### Backup with Custom Retention

```bash
ansible-playbook -i inventory/hosts.yml playbooks/backup-infrastructure.yml \
  -e backup_retention_daily=14
```

### Backup with Remote Sync

```bash
ansible-playbook -i inventory/hosts.yml playbooks/backup-infrastructure.yml \
  -e backup_remote_enabled=true \
  -e backup_remote_host=backup.example.com \
  -e backup_remote_path=/backup/proxmox
```

## Backup Contents

### Directory Structure

```
/var/backups/infrastructure/
└── 20250123T120000/              # Timestamp directory
    ├── MANIFEST.yml               # Backup metadata
    ├── BACKUP_SUMMARY.txt         # Human-readable summary
    ├── containers/                # LXC container backups
    │   ├── backup-status.txt
    │   └── (backups stored in Proxmox storage)
    ├── postgresql/                # Database dumps
    │   ├── keycloak_20250123T120000.dump
    │   ├── gitlab_20250123T120000.dump
    │   ├── nextcloud_20250123T120000.dump
    │   ├── mattermost_20250123T120000.dump
    │   └── backup-status.txt
    ├── docker-volumes/            # Docker volume archives
    │   ├── keycloak_data_20250123T120000.tar.gz
    │   ├── gitlab_data_20250123T120000.tar.gz
    │   └── ...
    └── configs/                   # Configuration archives
        └── proxmox-configs_20250123T120000.tar.gz
```

## Configuration

### Default Variables

See [defaults/main.yml](defaults/main.yml) for all configuration options.

Key variables:

```yaml
# Backup destination
backup_storage: "local"
backup_base_dir: "/var/backups/infrastructure"

# Retention (days)
backup_retention_daily: 7
backup_retention_weekly: 4
backup_retention_monthly: 3

# Enable/disable components
backup_postgresql_enabled: true
backup_redis_enabled: true
backup_docker_volumes_enabled: true
backup_proxmox_configs_enabled: true

# Remote backup
backup_remote_enabled: false
backup_remote_host: ""
backup_remote_user: "backup"
backup_remote_path: "/backup/proxmox"
```

### Container Backup Configuration

Customize which containers to back up:

```yaml
backup_containers:
  - id: 150
    name: postgresql
    enabled: true
    compress: true
    stop_before_backup: false  # Don't stop database during backup
```

## Backup Features

### Container Backups
- Uses Proxmox `vzdump` with snapshot mode
- Zstandard compression for optimal size/speed
- Stored in Proxmox backup storage
- No downtime required

### PostgreSQL Backups
- Custom format (`pg_dump -Fc`) for flexibility
- Includes all database objects and data
- Compressed dumps
- Verification after backup

### Redis Backup
- Forces SAVE operation for consistency
- Copies dump.rdb file
- Minimal service interruption

### Docker Volume Backups
- Archives entire volume contents
- Preserves permissions and ownership
- Per-container organization

### Configuration Backups
- Includes LXC configurations
- Network settings
- Traefik configuration
- Custom scripts and services

## Retention Policy

Backups are automatically cleaned up based on retention settings:

- **Daily**: Keep last 7 days (default)
- **Weekly**: Keep last 4 weeks
- **Monthly**: Keep last 3 months

Customize via variables:
```yaml
backup_retention_daily: 14    # Keep 14 days
backup_retention_weekly: 8    # Keep 8 weeks
backup_retention_monthly: 6   # Keep 6 months
```

## Remote Backup

Enable remote synchronization for off-site backups:

```yaml
backup_remote_enabled: true
backup_remote_host: "backup.example.com"
backup_remote_user: "backup"
backup_remote_path: "/backup/proxmox"
```

Requirements:
- SSH key authentication configured
- rsync installed on both systems
- Sufficient storage on remote host

## Verification

Backups are automatically verified:

1. **PostgreSQL**: File existence and size checks
2. **Containers**: vzdump exit status
3. **Files**: Checksum verification (optional)

Enable/disable verification:
```yaml
backup_verify_enabled: true
backup_verify_postgresql: true
backup_verify_container_backups: true
```

## Restoration

See [restore_infrastructure](../restore_infrastructure/README.md) role for restoration procedures.

Quick restore:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=20250123T120000 \
  -e restore_dry_run=true  # Test first!
```

## Automation

### Scheduled Backups

Add to crontab on Proxmox host:

```bash
# Daily backup at 2 AM
0 2 * * * cd /root/Proxmox_config && ansible-playbook -i inventory/hosts.yml playbooks/backup-infrastructure.yml >> /var/log/backup-infrastructure.log 2>&1
```

### Pre-deployment Backup

Run before major changes:

```bash
# Backup before deployment
ansible-playbook playbooks/backup-infrastructure.yml

# Deploy changes
ansible-playbook playbooks/full-deployment.yml

# If issues, restore
ansible-playbook playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=<TIMESTAMP>
```

## Monitoring

Check backup logs:

```bash
# View backup summary
cat /var/backups/infrastructure/<TIMESTAMP>/BACKUP_SUMMARY.txt

# View backup manifest
cat /var/backups/infrastructure/<TIMESTAMP>/MANIFEST.yml

# Check backup size
du -sh /var/backups/infrastructure/<TIMESTAMP>/
```

## Troubleshooting

### Backup Fails

1. Check disk space:
   ```bash
   df -h /var/backups
   ```

2. Verify PostgreSQL connectivity:
   ```bash
   PGPASSWORD='password' psql -h 172.16.10.150 -U postgres -l
   ```

3. Check container status:
   ```bash
   pct list
   ```

### Slow Backups

- Container backups: Normal, snapshots are fast
- PostgreSQL dumps: Depends on database size
- Docker volumes: Depends on volume size

Optimize:
- Adjust compression level
- Use faster storage for backups
- Run during off-peak hours

## Security

- Backup files contain sensitive data
- Directory permissions: 0700 (root only)
- PostgreSQL passwords handled via vault
- Remote backups use SSH key authentication

## See Also

- [restore_infrastructure role](../restore_infrastructure/README.md)
- [Backup playbook](../../playbooks/backup-infrastructure.yml)
- [Restore playbook](../../playbooks/restore-infrastructure.yml)
- [Disaster Recovery Guide](../../docs/operations/disaster-recovery.md)
