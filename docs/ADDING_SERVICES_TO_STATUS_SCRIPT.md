# Adding New Services to the Infrastructure Status Script

**Script**: `scripts/check-infrastructure-status.sh`

When you deploy a new service, you must add it to the status check script to ensure it's monitored.

## Quick Reference

### 1. Add to SERVICES Array

For services with external domains:

```bash
SERVICES=(
    "ServiceName:ContainerID:InternalPort:Domain"
    # Example:
    "Mattermost:163:8065:mattermost.viljo.se"
)
```

For infrastructure services without domains:

```bash
INFRA_CONTAINERS=(
    "ServiceName:ContainerID"
    # Example:
    "PostgreSQL:150"
)
```

## Adding Service-Specific Health Checks

### API Health Checks (Section 8)

Add to the "Advanced Service Health Checks" section:

```bash
# Your Service API check
SERVICE_API=$(curl -s --connect-timeout 5 http://172.16.10.XXX:PORT/health 2>/dev/null | grep -o 'healthy')
if [ -n "$SERVICE_API" ]; then
    print_result "YourService API" "PASS" "(endpoint responding)"
else
    print_result "YourService API" "FAIL" "(no response)"
fi
```

### Common API Endpoints by Service Type

**GitLab-like (DevOps platforms)**:
- Health: `/api/v4/version`
- Example: `curl http://172.16.10.153/api/v4/version`

**Nextcloud-like (File storage)**:
- Health: `/status.php`
- Example: `curl http://172.16.10.155/status.php`

**Mattermost-like (Chat platforms)**:
- Health: `/api/v4/system/ping`
- Example: `curl http://172.16.10.163:8065/api/v4/system/ping`

**Keycloak-like (Auth systems)**:
- Health: `/realms/master`
- Example: `curl http://172.16.10.151:8080/realms/master`

**Custom applications**:
- Create a `/health` or `/status` endpoint that returns JSON with service status

## Example: Adding Portainer

### Step 1: Add to SERVICES array

```bash
SERVICES=(
    # ... existing services ...
    "Portainer:165:9000:portainer.viljo.se"
)
```

### Step 2: Add API health check

```bash
# Portainer API check
PORTAINER_API=$(curl -s --connect-timeout 5 http://172.16.10.165:9000/api/status 2>/dev/null | grep -o '"Version"')
if [ -n "$PORTAINER_API" ]; then
    print_result "Portainer API" "PASS" "(API responding)"
else
    print_result "Portainer API" "FAIL" "(no response)"
fi
```

### Step 3: Verify Docker container (automatic)

The Docker health check (Section 9) will automatically check if Docker is running in the container.

### Step 4: Certificate check (automatic)

The SSL certificate expiration check (Section 10) will automatically check the domain certificate.

## Testing Your Changes

```bash
# Run the script
./scripts/check-infrastructure-status.sh

# Check that your service appears in:
# - Section 5: DNS Resolution
# - Section 6: Container Status  
# - Section 7: External Service Access
# - Section 8: Advanced Health Checks (if you added custom check)
# - Section 9: Docker Container Health (if uses Docker)
# - Section 10: SSL Certificate Expiration
```

## Service-Specific Examples

### Database Services (PostgreSQL, MySQL, MongoDB)

```bash
# PostgreSQL
PG_VERSION=$(ssh root@192.168.1.3 "pct exec 150 -- su - postgres -c 'psql -c \"SELECT version()\"' 2>/dev/null | grep -c PostgreSQL" 2>/dev/null)
if [ "$PG_VERSION" -gt 0 ]; then
    print_result "PostgreSQL Connection" "PASS" "(accepting connections)"
else
    print_result "PostgreSQL Connection" "FAIL" "(not responding)"
fi

# MongoDB (if you add it)
MONGO_STATUS=$(ssh root@192.168.1.3 "pct exec XXX -- mongosh --eval 'db.adminCommand({ ping: 1 })' 2>/dev/null | grep -c '{ ok: 1 }'")
if [ "$MONGO_STATUS" -gt 0 ]; then
    print_result "MongoDB Connection" "PASS" "(accepting connections)"
else
    print_result "MongoDB Connection" "FAIL" "(not responding)"
fi
```

### Cache Services (Redis, Memcached)

```bash
# Redis
REDIS_PING=$(ssh root@192.168.1.3 "pct exec 158 -- redis-cli ping 2>/dev/null" 2>/dev/null)
if [ "$REDIS_PING" = "PONG" ]; then
    print_result "Redis Ping" "PASS" "(PONG received)"
else
    print_result "Redis Ping" "FAIL" "(no PONG)"
fi

# Memcached (if you add it)
MEMCACHED_STATS=$(ssh root@192.168.1.3 "pct exec XXX -- echo 'stats' | nc localhost 11211 2>/dev/null | grep -c 'STAT'")
if [ "$MEMCACHED_STATS" -gt 0 ]; then
    print_result "Memcached Connection" "PASS" "(responding to stats)"
else
    print_result "Memcached Connection" "FAIL" "(not responding)"
fi
```

### Web Applications

```bash
# Check for specific content on page
APP_CONTENT=$(curl -s --connect-timeout 5 http://172.16.10.XXX/ 2>/dev/null | grep -c "Expected Content String")
if [ "$APP_CONTENT" -gt 0 ]; then
    print_result "YourApp Content" "PASS" "(page content loaded)"
else
    print_result "YourApp Content" "WARN" "(content not detected)"
fi
```

### Message Queues (RabbitMQ, Kafka)

```bash
# RabbitMQ (if you add it)
RABBIT_HEALTH=$(curl -s --connect-timeout 5 http://172.16.10.XXX:15672/api/healthchecks/node 2>/dev/null | grep -o '"status":"ok"')
if [ -n "$RABBIT_HEALTH" ]; then
    print_result "RabbitMQ Health" "PASS" "(healthy)"
else
    print_result "RabbitMQ Health" "FAIL" "(unhealthy)"
fi
```

## What Checks Are Added Automatically

When you add a service to the SERVICES array, these checks run automatically:

1. **DNS Resolution** (Section 5) - Checks if domain resolves to firewall WAN IP
2. **Container Status** (Section 6) - Checks if LXC container is running
3. **External HTTP Access** (Section 7) - Tests HTTP connectivity via WAN IP
4. **Docker Health** (Section 9) - If container uses Docker, checks if containers running
5. **SSL Certificate** (Section 10) - Checks certificate expiration for the domain

## What You Need to Add Manually

1. **Service-Specific API Checks** (Section 8) - Add health endpoint checks unique to your service
2. **Database Connectivity** (Section 8) - If it's a database, add connection test
3. **Custom Content Checks** (Section 8) - If you need to verify specific functionality

## Standard for All New Services

**MANDATORY**: When deploying a new service, you MUST:

1. Add service to `inventory/group_vars/all/services.yml` (single source of truth)
2. Regenerate links portal: `ansible-playbook playbooks/links-portal-deploy.yml`
3. Add service to SERVICES or INFRA_CONTAINERS array in status script
4. Test that all automatic checks work (run the script)
5. Add service-specific API health check if service has APIs
6. Add database connectivity check if service is a database
7. Document any custom checks in this file
8. Commit changes to the script with the service deployment

**Example commit message**:
```
Add MyService to infrastructure

- Added MyService to services.yml
- Regenerated links portal
- Added MyService:165:8080:myservice.viljo.se to SERVICES array
- Added /api/health endpoint check in Section 8
- Verified all automatic checks pass
```

## Troubleshooting

**Service not appearing in checks**:
- Verify SERVICES array syntax: `"Name:ID:Port:Domain"`
- Check for trailing commas or syntax errors
- Run `bash -n scripts/check-infrastructure-status.sh` to check syntax

**API check always fails**:
- Test API manually: `curl -v http://172.16.10.XXX:PORT/endpoint`
- Check if service is actually running: `pct exec XXX -- docker ps`
- Verify internal port number is correct
- Check if service requires authentication

**Certificate check fails**:
- Verify DNS is correctly configured
- Check Traefik dynamic config exists: `ls /etc/traefik/dynamic/`
- Verify certificate was issued: `journalctl -u traefik | grep acme`

## Monitoring Integration

This script can be integrated with monitoring systems:

**Cron (run every 5 minutes)**:
```bash
*/5 * * * * /root/Proxmox_config/scripts/check-infrastructure-status.sh > /var/log/infrastructure-status.log 2>&1
```

**Exit codes**:
- `0`: HEALTHY (≥90%) or DEGRADED (≥70%)
- `1`: CRITICAL (<70%)

**Parse for alerts**:
```bash
# Alert if critical
if ! ./scripts/check-infrastructure-status.sh; then
    mail -s "Infrastructure CRITICAL" admin@example.com < /var/log/infrastructure-status.log
fi
```

## See Also

- [New Service Workflow](NEW_SERVICE_WORKFLOW.md) - Complete service deployment procedure
- [TDD Workflow Status](TDD_WORKFLOW_STATUS.md) - Current deployment status
- [DR Runbook](DR_RUNBOOK.md) - Disaster recovery procedures
