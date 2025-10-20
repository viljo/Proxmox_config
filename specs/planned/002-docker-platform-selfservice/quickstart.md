# Quickstart Guide: Self-Service Docker Platform

**Feature**: 002-docker-platform-selfservice
**Audience**: Infrastructure administrators deploying the platform
**Time to Complete**: 60-90 minutes

## Prerequisites

Before starting, ensure you have:

- [x] Proxmox VE 9.0.3+ cluster with at least one node
- [x] Ansible 2.15+ installed on control machine
- [x] Proxmox API access (user with VM.Allocate, Datastore.Allocate permissions)
- [x] DNS control for domain (e.g., `*.docker.example.com`)
- [x] Let's Encrypt DNS provider credentials (Cloudflare, Route53, etc.)
- [x] OpenLDAP server with user/group directory
- [x] PostgreSQL 16+ database server
- [x] NetBox instance for inventory management
- [x] GitLab 17.x instance (for CI/CD integration)
- [x] Storage configured on Proxmox (local-lvm, NFS, or Ceph)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Proxmox VE Cluster                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ LXC: Env-A │  │ LXC: Env-B │  │ LXC: Env-C │  ...       │
│  │ Docker CE  │  │ Docker CE  │  │ Docker CE  │            │
│  │ Portainer  │  │ Portainer  │  │ Portainer  │            │
│  │   Agent    │  │   Agent    │  │   Agent    │            │
│  └────────────┘  └────────────┘  └────────────┘            │
└─────────────────────────────────────────────────────────────┘
         ▲                    ▲                   ▲
         │                    │                   │
         └────────────────────┼───────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Traefik Proxy    │
                    │  (HTTPS Routing)  │
                    │  Let's Encrypt    │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Portainer Server  │
                    │  (Management UI)  │
                    │  LDAP Auth        │
                    └─────────┬─────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
    ┌────▼────┐         ┌────▼────┐         ┌────▼────┐
    │ LDAP    │         │ NetBox  │         │ GitLab  │
    │ (Auth)  │         │ (CMDB)  │         │ (CI/CD) │
    └─────────┘         └─────────┘         └─────────┘
```

## Step 1: Clone Repository and Configure Inventory

```bash
# Clone the repository
git clone https://github.com/yourusername/proxmox-config.git
cd proxmox-config

# Create inventory file
cp inventory/group_vars/all/main.yml.example inventory/group_vars/all/main.yml

# Edit inventory with your environment details
vi inventory/group_vars/all/main.yml
```

**Key variables to configure**:

```yaml
# Proxmox connection
proxmox_api_host: "pve.example.com"
proxmox_api_user: "automation@pve"
proxmox_api_token_id: "automation-token"
proxmox_node: "pve-node1"  # Default node for deployments

# Domain configuration
docker_platform_domain: "docker.example.com"
docker_platform_wildcard_cert: true

# LDAP connection
ldap_url: "ldap://ldap.example.com"
ldap_bind_dn: "cn=readonly,dc=example,dc=com"
ldap_user_base_dn: "ou=users,dc=example,dc=com"
ldap_group_base_dn: "ou=groups,dc=example,dc=com"

# NetBox integration
netbox_url: "https://netbox.example.com"
netbox_api_token: "your-token-here"

# Resource quotas (defaults)
docker_platform_default_quotas:
  cpu_cores: 4
  memory_mb: 8192
  disk_gb: 50
  max_containers_per_env: 20
  max_environments_per_user: 5
  max_environments_per_team: 10
```

## Step 2: Configure Secrets with Ansible Vault

```bash
# Create encrypted secrets file
ansible-vault create group_vars/all/secrets.yml
```

**Add secrets** (file will be encrypted):

```yaml
# Proxmox API token secret
proxmox_api_token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# LDAP bind password
ldap_bind_password: "your-secure-password"

# Portainer admin password
portainer_admin_password: "your-portainer-password"

# Portainer API key (generated after first deployment)
portainer_api_key: "ptr_xxxxxxxxxxxxxxxxxxxxx"

# Portainer agent shared secret
portainer_agent_secret: "random-secure-secret-32-chars-long"

# Let's Encrypt DNS provider credentials
letsencrypt_dns_provider: "cloudflare"  # or route53, etc.
letsencrypt_cloudflare_email: "admin@example.com"
letsencrypt_cloudflare_api_token: "your-cloudflare-api-token"

# Database connection
postgres_host: "db.example.com"
postgres_port: 5432
postgres_database: "docker_platform"
postgres_user: "docker_platform"
postgres_password: "your-db-password"

# NetBox API token
netbox_api_token: "your-netbox-token"
```

**Save vault password**:

```bash
echo "your-vault-password" > .vault_pass
chmod 600 .vault_pass

# Configure ansible to use vault password file
echo "vault_password_file = .vault_pass" >> ansible.cfg
```

## Step 3: Deploy Core Infrastructure

### 3.1 Deploy PostgreSQL Database

```bash
# Create database and user
ansible-playbook playbooks/setup_database.yml

# Verify connection
ansible-playbook playbooks/test_database.yml
```

### 3.2 Deploy Traefik Reverse Proxy

```bash
# Deploy Traefik in LXC container
ansible-playbook playbooks/deploy_traefik.yml \
  -e "traefik_lxc_vmid=100" \
  -e "traefik_lxc_hostname=traefik"

# Verify Traefik dashboard
curl -k https://traefik.docker.example.com/dashboard/
```

**Expected output**: Traefik dashboard showing entrypoints (web, websecure)

### 3.3 Deploy Portainer Server

```bash
# Deploy Portainer in LXC container
ansible-playbook playbooks/deploy_portainer.yml \
  -e "portainer_lxc_vmid=101" \
  -e "portainer_lxc_hostname=portainer"

# Wait for Portainer to start (30 seconds)
sleep 30

# Configure LDAP authentication
ansible-playbook playbooks/configure_portainer_ldap.yml
```

**Verify Portainer**:

1. Visit: https://portainer.docker.example.com
2. Login with LDAP credentials
3. Confirm dashboard loads

## Step 4: Create First Docker Environment (Manual Test)

```bash
# Provision test environment
ansible-playbook playbooks/provision_docker_env.yml \
  -e "environment_name=test-env" \
  -e "owner_type=user" \
  -e "owner_id=uid=testuser,ou=users,dc=example,dc=com" \
  -e "environment_cpu_cores=2" \
  -e "environment_memory_mb=4096" \
  -e "environment_disk_size=20" \
  -e "environment_description='Test environment for validation'"
```

**Provisioning steps (automated)**:

1. ✓ Validate quota (2 cores, 4GB RAM, 20GB disk - within defaults)
2. ✓ Auto-approve (within quota)
3. ✓ Create LXC container (VMID auto-assigned)
4. ✓ Install Docker Engine 27.x
5. ✓ Deploy Portainer Agent
6. ✓ Register Portainer endpoint
7. ✓ Register in NetBox
8. ✓ Send notification email

**Expected completion time**: 3-5 minutes

**Verify environment**:

```bash
# Check LXC status
ssh root@pve-node1 "pct list | grep test-env"

# Check Portainer endpoint
curl -H "X-API-Key: ${portainer_api_key}" \
  https://portainer.docker.example.com/api/endpoints | jq '.[] | select(.Name=="test-env")'

# Check NetBox registration
curl -H "Authorization: Token ${netbox_api_token}" \
  https://netbox.example.com/api/dcim/devices/?name=test-env | jq .
```

## Step 5: Deploy Test Container with HTTPS

```bash
# Deploy nginx test container
ansible-playbook playbooks/deploy_container.yml \
  -e "environment_name=test-env" \
  -e "container_name=nginx-test" \
  -e "container_image=nginx" \
  -e "container_tag=1.25" \
  -e "container_port=80" \
  -e "container_hostname=nginx-test.docker.example.com"
```

**Deployment steps (automated)**:

1. ✓ Pull nginx:1.25 image
2. ✓ Start container
3. ✓ Health check (GET http://localhost:80/)
4. ✓ Generate Traefik route config
5. ✓ Deploy route to Traefik
6. ✓ Request Let's Encrypt certificate
7. ✓ HTTPS route active

**Verify HTTPS access**:

```bash
# Test HTTPS access (may take 2-3 minutes for cert issuance)
curl https://nginx-test.docker.example.com

# Expected output: nginx welcome page HTML
```

## Step 6: Test Team-Based Environment

```bash
# Create team-owned environment
ansible-playbook playbooks/provision_docker_env.yml \
  -e "environment_name=team-alpha-dev" \
  -e "owner_type=team" \
  -e "owner_id=cn=team-alpha,ou=groups,dc=example,dc=com" \
  -e "environment_cpu_cores=4" \
  -e "environment_memory_mb=8192" \
  -e "environment_disk_size=30"
```

**Verify team access**:

1. Login to Portainer as member of `team-alpha` LDAP group
2. Confirm `team-alpha-dev` endpoint is visible
3. Confirm other environments are NOT visible
4. Deploy a test container
5. Confirm team members can manage containers

## Step 7: Configure GitLab CI/CD Integration

### 7.1 Create GitLab Project Variables

In GitLab project settings, add CI/CD variables:

```
PORTAINER_URL = https://portainer.docker.example.com
PORTAINER_API_KEY = <your-api-key> (masked)
DOCKER_ENVIRONMENT = <environment-name>
```

### 7.2 Create .gitlab-ci.yml

```yaml
# .gitlab-ci.yml example for container deployment
stages:
  - build
  - deploy

build_image:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  only:
    - main

deploy_to_docker_platform:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache curl jq
  script:
    # Get endpoint ID for environment
    - |
      ENDPOINT_ID=$(curl -s -H "X-API-Key: ${PORTAINER_API_KEY}" \
        "${PORTAINER_URL}/api/endpoints" | \
        jq -r ".[] | select(.Name==\"${DOCKER_ENVIRONMENT}\") | .Id")

    # Deploy container via Portainer API
    - |
      curl -X POST \
        -H "X-API-Key: ${PORTAINER_API_KEY}" \
        -H "Content-Type: application/json" \
        "${PORTAINER_URL}/api/endpoints/${ENDPOINT_ID}/docker/containers/create?name=myapp" \
        -d '{
          "Image": "'${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHA}'",
          "ExposedPorts": {"8080/tcp": {}},
          "HostConfig": {
            "PortBindings": {"8080/tcp": [{"HostPort": "8080"}]},
            "RestartPolicy": {"Name": "unless-stopped"}
          },
          "Labels": {
            "com.gitlab.project": "'${CI_PROJECT_NAME}'",
            "com.gitlab.commit": "'${CI_COMMIT_SHA}'"
          }
        }'

    # Start container
    - |
      curl -X POST \
        -H "X-API-Key: ${PORTAINER_API_KEY}" \
        "${PORTAINER_URL}/api/endpoints/${ENDPOINT_ID}/docker/containers/myapp/start"
  only:
    - main
  environment:
    name: production
    url: https://myapp.docker.example.com
```

### 7.3 Test CI/CD Pipeline

```bash
# Commit and push to trigger pipeline
git add .gitlab-ci.yml
git commit -m "Add Docker platform deployment"
git push origin main

# Monitor pipeline in GitLab UI
# Pipeline should: Build image → Push to registry → Deploy to environment
```

## Step 8: Enable Monitoring and Notifications

### 8.1 Configure Zabbix Monitoring

```bash
# Deploy Zabbix monitoring templates
ansible-playbook playbooks/configure_monitoring.yml
```

**Monitored metrics**:
- LXC container CPU, memory, disk usage
- Docker daemon health
- Portainer agent connectivity
- Container count per environment
- Traefik route health

### 8.2 Configure Email Notifications

```yaml
# Add to group_vars/all/main.yml
docker_platform_notifications:
  email_enabled: true
  smtp_host: "smtp.example.com"
  smtp_port: 587
  smtp_user: "notifications@example.com"
  smtp_from: "Docker Platform <noreply@example.com>"
  admin_emails:
    - admin@example.com
```

### 8.3 Test Webhook Notifications

```bash
# Configure webhook for environment
ansible-playbook playbooks/update_environment.yml \
  -e "environment_name=test-env" \
  -e "webhook_urls=['https://hooks.slack.com/services/xxx']"

# Trigger test notification
ansible-playbook playbooks/test_notifications.yml \
  -e "environment_name=test-env"

# Verify webhook delivery in Slack/Mattermost/Teams
```

## Step 9: Backup Configuration

```bash
# Configure automated backups for LXC containers
ansible-playbook playbooks/configure_backups.yml \
  -e "backup_schedule='0 2 * * *'"  # Daily at 2 AM \
  -e "backup_retention_days=7"

# Test manual backup
ansible-playbook playbooks/backup_environment.yml \
  -e "environment_name=test-env"

# Verify backup in Proxmox
ssh root@pve-node1 "ls -lh /var/lib/vz/dump/ | grep test-env"
```

## Step 10: Cleanup Test Environment (Optional)

```bash
# Delete test environment
ansible-playbook playbooks/delete_environment.yml \
  -e "environment_name=test-env" \
  -e "confirm_delete=yes" \
  --extra-vars="force=true"

# Verify deletion
# - LXC container removed from Proxmox
# - Portainer endpoint removed
# - NetBox device marked as decommissioned
# - Traefik routes removed
# - Database record status=deleted
```

## Validation Checklist

After completing quickstart, verify:

- [ ] Traefik dashboard accessible at https://traefik.docker.example.com
- [ ] Portainer accessible at https://portainer.docker.example.com
- [ ] LDAP authentication works in Portainer
- [ ] Can provision new environment in <5 minutes
- [ ] Environment appears in Portainer with correct team assignment
- [ ] Can deploy container via Portainer UI
- [ ] Container accessible via HTTPS with valid Let's Encrypt certificate
- [ ] GitLab CI/CD pipeline deploys containers successfully
- [ ] Notifications sent to email and webhooks
- [ ] Zabbix monitoring shows environment metrics
- [ ] NetBox shows environment device with custom fields
- [ ] Environment deletion works and cleans up all resources

## Troubleshooting

### Issue: LXC provisioning fails with "template not found"

**Solution**: Download Debian 12 template on Proxmox node

```bash
ssh root@pve-node1
pveam update
pveam download local debian-12-standard_12.2-1_amd64.tar.zst
```

### Issue: Let's Encrypt certificate fails with DNS challenge error

**Solution**: Verify DNS provider API credentials

```bash
# Test Cloudflare API access
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer ${letsencrypt_cloudflare_api_token}" | jq .

# Ensure DNS record exists for wildcard
# Create TXT record: _acme-challenge.docker.example.com
```

### Issue: Portainer endpoint shows "offline"

**Solution**: Check Portainer Agent connectivity

```bash
# SSH into LXC
pct enter <vmid>

# Check agent status
docker ps -a | grep portainer-agent

# Check logs
docker logs portainer-agent

# Verify port 9001 accessible from Portainer server
telnet <lxc-ip> 9001
```

### Issue: Container health checks always fail

**Solution**: Verify health check endpoint exists

```bash
# SSH into LXC
pct enter <vmid>

# Test health endpoint from inside container
docker exec <container-name> curl http://localhost:8080/health

# If 404, adjust health_check_endpoint or disable health checks
```

### Issue: Quota validation fails with "cannot connect to database"

**Solution**: Verify PostgreSQL connection

```bash
# Test database connection
ansible-playbook playbooks/test_database.yml -v

# Check PostgreSQL allows connections from Ansible control machine
psql -h db.example.com -U docker_platform -d docker_platform -c "SELECT 1"
```

## Next Steps

1. **Create user documentation** for requesting environments and deploying containers
2. **Set up Grafana dashboards** for platform metrics and usage tracking
3. **Configure resource alerts** in Zabbix for quota thresholds
4. **Implement web UI** for environment requests (optional, can use GitLab issues)
5. **Enable advanced features**:
   - Container auto-scaling based on load
   - Multi-region deployments across Proxmox clusters
   - Custom domain support (not just `*.docker.example.com`)
   - Docker Compose stack deployments
   - Volume backup automation

## Support

For issues or questions:
- Check logs: `/var/log/ansible.log` on control machine
- Review Proxmox task log: Web UI → Node → Tasks
- Consult documentation: `docs/` directory
- Open GitLab issue with logs and error messages
