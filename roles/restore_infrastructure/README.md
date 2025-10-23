# Infrastructure Restore Role

Comprehensive restore role for populating recreated containers and VMs with backed-up data. This role restores PostgreSQL databases, Redis data, and Docker volumes to running containers.

## Overview

This role performs automated restoration of:
- **PostgreSQL databases** (4 databases: Keycloak, GitLab, Nextcloud, Mattermost)
- **Redis data** (dump.rdb restoration)
- **Docker volumes** (application data from 5 containers)

**Important:** This role assumes containers are already created and running. It restores *data* to existing infrastructure, not the containers themselves.

## Prerequisites

Before running restore:

1. ✅ **Containers must exist and be running**
   - Use `playbooks/full-deployment.yml` to create containers first
   - Or manually create containers with correct IDs

2. ✅ **Services must be accessible**
   - PostgreSQL container (150) must be running
   - Redis container (158) must be running
   - Docker containers (151, 153, 155, 163, 170) must be running

3. ✅ **Backup must exist**
   - Have a valid backup timestamp
   - Backup directory must be intact at `/var/backups/infrastructure/<TIMESTAMP>`

4. ✅ **Test with dry-run first**
   - Always run with `-e restore_dry_run=true` first
   - Verify the restore plan before executing

## Quick Start

### 1. Test Restore (Dry Run)

```bash
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=20250123T120000 \
  -e restore_dry_run=true
```

This shows what *would* be restored without making changes.

### 2. Restore All Data

```bash
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=20250123T120000
```

### 3. Selective Restore

Restore only specific components:

```bash
# Only PostgreSQL databases
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=20250123T120000 \
  -e restore_redis_enabled=false \
  -e restore_docker_volumes_enabled=false

# Only Docker volumes
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=20250123T120000 \
  -e restore_postgresql_enabled=false \
  -e restore_redis_enabled=false
```

### 4. Restore Without Stopping Services

```bash
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=20250123T120000 \
  -e restore_stop_services_first=false
```

**Warning:** May cause data inconsistency if services are writing during restore.

## What Gets Restored

### PostgreSQL Databases

Restored to container 150 (172.16.10.150:5432):

| Database | Used By | Tables Expected |
|----------|---------|-----------------|
| keycloak | Keycloak SSO | ~50+ tables |
| gitlab | GitLab CE | ~400+ tables |
| nextcloud | Nextcloud | ~100+ tables |
| mattermost | Mattermost | ~100+ tables |

**Process:**
1. Stop Docker services using the database (if `restore_stop_services_first=true`)
2. Drop and recreate database objects (`pg_restore --clean --if-exists`)
3. Restore all data using custom format dumps
4. Restart Docker services
5. Verify table counts

### Redis Data

Restored to container 158 (172.16.10.158:6379):

- **File**: dump.rdb
- **Process**:
  1. Stop redis-server service
  2. Push dump.rdb to /var/lib/redis/dump.rdb
  3. Set correct ownership (redis:redis) and permissions (640)
  4. Start redis-server service
  5. Verify service is active

### Docker Volumes

Restored to containers 151, 153, 155, 163, 170:

| Container | Service | Volumes Restored |
|-----------|---------|------------------|
| 151 | Keycloak | /opt/keycloak |
| 153 | GitLab | /opt/gitlab/config, /opt/gitlab/data, /opt/gitlab/logs |
| 155 | Nextcloud | /opt/nextcloud |
| 163 | Mattermost | /opt/mattermost/config, /opt/mattermost/data, /opt/mattermost/logs |
| 170 | Webtop | /opt/webtop |

**Process:**
1. Stop Docker service in containers
2. Push tar.gz archive to container /tmp
3. Extract archive in place (overwrites existing data)
4. Delete temporary archive
5. Restart Docker service

## Configuration

### Default Variables

See [defaults/main.yml](defaults/main.yml) for all options.

Key variables:

```yaml
# Required
restore_backup_timestamp: "20250123T120000"

# What to restore
restore_postgresql_enabled: true
restore_redis_enabled: true
restore_docker_volumes_enabled: true

# Safety
restore_require_confirmation: true
restore_dry_run: false
restore_stop_services_first: true
restore_verify_after_restore: true
```

### Container ID Mapping

The role uses container ID mappings to route data to the correct containers:

```yaml
restore_container_id_map:
  keycloak: 151
  gitlab: 153
  nextcloud: 155
  mattermost: 163
  webtop: 170
```

If your container IDs differ, override these in your inventory or playbook.

### Volume Path Mapping

Customize where volumes are restored:

```yaml
restore_volume_path_map:
  gitlab:
    config: "/opt/gitlab/config"
    data: "/opt/gitlab/data"
    logs: "/opt/gitlab/logs"
```

## Safety Features

### Dry Run Mode

Always test first:
```bash
-e restore_dry_run=true
```

Shows exactly what would be done without making changes.

### Confirmation Prompt

By default, requires manual confirmation before restore:
```
⚠️  CRITICAL WARNING ⚠️

You are about to restore data to running containers.
This operation will:
  - Stop services temporarily (if enabled)
  - Overwrite existing data
  - Replace databases with backup data

Press ENTER to continue or Ctrl+C then A to abort
```

Disable with:
```bash
-e restore_require_confirmation=false
```

### Service Stopping

Services are stopped during restore to prevent data corruption:
```yaml
restore_stop_services_first: true  # Recommended
```

### Verification

Automatic post-restore verification:
```yaml
restore_verify_after_restore: true
```

Checks:
- ✓ PostgreSQL: Count tables in each database
- ✓ Redis: Verify service is active
- ✓ Docker: Services restarted successfully

## Restore Workflow

### Complete Disaster Recovery

Full infrastructure recovery from scratch:

```bash
# 1. Deploy infrastructure (containers only)
ansible-playbook -i inventory/hosts.yml playbooks/full-deployment.yml

# Wait for deployment to complete (~30-45 minutes)

# 2. Restore data to containers
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=<TIMESTAMP>
```

### Selective Service Recovery

Restore single service:

```bash
# Example: Restore only GitLab data
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=20250123T120000 \
  -e restore_postgresql_enabled=true \
  -e restore_redis_enabled=false \
  -e restore_docker_volumes_enabled=true \
  -e restore_container_id_map="{'gitlab': 153}" \
  -e restore_volume_path_map="{'gitlab': {'config': '/opt/gitlab/config', 'data': '/opt/gitlab/data', 'logs': '/opt/gitlab/logs'}}"
```

### Point-in-Time Recovery

Restore to specific backup:

```bash
# List available backups
ls -1 /var/backups/infrastructure/

# Restore from specific point in time
ansible-playbook -i inventory/hosts.yml playbooks/restore-infrastructure.yml \
  -e restore_backup_timestamp=20250120T020000  # 2AM backup from Jan 20
```

## Troubleshooting

### Issue: Container doesn't exist

**Error:** `container does not exist`

**Solution:** Create the container first:
```bash
# Deploy all infrastructure
ansible-playbook -i inventory/hosts.yml playbooks/full-deployment.yml

# Or deploy specific service
ansible-playbook -i inventory/hosts.yml playbooks/gitlab-deploy.yml
```

### Issue: PostgreSQL connection failed

**Error:** `could not connect to server`

**Solution:** Verify PostgreSQL container is running:
```bash
pct status 150
pct exec 150 -- systemctl status postgresql
```

### Issue: Permission denied on volume restore

**Error:** `Permission denied` during tar extraction

**Solution:** Ensure target directories exist and are writable:
```bash
pct exec 153 -- mkdir -p /opt/gitlab/data
pct exec 153 -- chown -R root:root /opt/gitlab
```

### Issue: Service won't start after restore

**Symptoms:** Docker container fails to start

**Solution:**
1. Check Docker logs:
   ```bash
   pct exec 153 -- docker logs gitlab
   ```

2. Verify volume permissions:
   ```bash
   pct exec 153 -- ls -la /opt/gitlab/
   ```

3. Manually restart:
   ```bash
   pct exec 153 -- cd /opt/gitlab && docker compose up -d
   ```

### Issue: Database restore warnings

**Symptoms:** Many `WARNING` messages during pg_restore

**Expected:** Warnings about missing roles/tablespaces are normal and filtered out:
- `role "xxx" does not exist`
- `no privileges could be revoked`

These are expected when restoring with `--no-owner --no-acl`.

## Verification

### Verify PostgreSQL Restore

```bash
# Check database sizes
pct exec 150 -- su - postgres -c "psql -c '\l+'"

# Count tables
pct exec 150 -- su - postgres -c "psql -d gitlab -c 'SELECT count(*) FROM pg_tables WHERE schemaname='\''public'\'';'"

# Test connection from application
pct exec 153 -- docker exec gitlab gitlab-rake gitlab:check
```

### Verify Redis Restore

```bash
# Check Redis is running
pct exec 158 -- systemctl status redis-server

# Test Redis connection
pct exec 158 -- redis-cli ping

# Check data size
pct exec 158 -- redis-cli INFO memory
```

### Verify Docker Volumes

```bash
# Check volume size
pct exec 153 -- du -sh /opt/gitlab/data

# Check file ownership
pct exec 153 -- ls -la /opt/gitlab/

# Verify application can access data
pct exec 153 -- docker logs gitlab | tail -20
```

## Recovery Time Objective (RTO)

Typical restore times:

- **PostgreSQL databases**: 5-15 minutes (depends on size)
- **Redis data**: < 1 minute
- **Docker volumes**: 10-30 minutes (depends on size)
- **Total RTO**: 15-45 minutes for full restore

## See Also

- [Backup Role](../backup_infrastructure/README.md) - Create backups
- [Full Deployment Playbook](../../playbooks/full-deployment.yml) - Deploy infrastructure
- [Backup Playbook](../../playbooks/backup-infrastructure.yml) - Create backups
- [Restore Playbook](../../playbooks/restore-infrastructure.yml) - This role's playbook
