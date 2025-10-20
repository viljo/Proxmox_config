# Quickstart: GitLab CI/CD Platform Deployment

**Feature**: Self-hosted Git version control and CI/CD automation
**Deployment Time**: ~45-60 minutes
**Prerequisites**: Proxmox VE 8.x, Ansible 2.15+, Keycloak deployed, Traefik configured

---

## Prerequisites Checklist

Before deploying, verify these requirements:

- [ ] **Proxmox Host**: Access to Proxmox VE host (SSH or web UI)
- [ ] **Network**: Management network (vmbr0) configured
- [ ] **Resources**: At least 6GB RAM available (4GB GitLab + 2GB per runner)
- [ ] **Storage**: Minimum 150GB available (100GB GitLab + 20GB per runner)
- [ ] **Keycloak**: Keycloak instance running and accessible
- [ ] **Traefik**: Traefik reverse proxy configured
- [ ] **DNS**: Ability to create DNS records (gitlab.infra.local, registry.gitlab.infra.local)
- [ ] **Ansible**: Ansible 2.15+ installed on control node
- [ ] **Inventory**: Proxmox host in Ansible inventory
- [ ] **Vault**: Ansible Vault password available
- [ ] **NetBox**: NetBox CMDB accessible (optional but recommended)
- [ ] **Zabbix**: Zabbix monitoring system accessible (optional but recommended)

---

## Part 1: GitLab Server Deployment

### Step 1: Configure Keycloak OIDC Client

Before deploying GitLab, create an OIDC client in Keycloak:

1. Log in to Keycloak admin console (https://keycloak.infra.local/admin)
2. Navigate to **Clients** → **Create Client**
3. Configure client:
   - **Client ID**: `gitlab`
   - **Client Protocol**: `openid-connect`
   - **Access Type**: `confidential`
   - **Valid Redirect URIs**: `https://gitlab.infra.local/*`
   - **Web Origins**: `https://gitlab.infra.local`
4. Save and note the **Client Secret** from the **Credentials** tab
5. Under **Client Scopes**, ensure `openid`, `profile`, `email` are included

### Step 2: Configure Ansible Secrets

Store GitLab credentials in Ansible Vault:

```bash
# Edit vault file
ansible-vault edit group_vars/all/secrets.yml
```

Add these variables:

```yaml
# GitLab Root Password (initial admin account)
vault_gitlab_root_password: "YOUR_STRONG_PASSWORD_HERE"

# Keycloak OIDC Client Secret
vault_keycloak_gitlab_client_secret: "CLIENT_SECRET_FROM_KEYCLOAK"

# SMTP Password (if using email notifications)
vault_gitlab_smtp_password: "SMTP_PASSWORD_HERE"
```

**Security Note**: Ensure vault file is encrypted before committing!

### Step 3: Configure GitLab Variables

Create or edit `inventory/group_vars/all/gitlab.yml`:

```yaml
---
# GitLab Server Configuration

# Container Configuration
gitlab_container_id: 53
gitlab_hostname: gitlab
gitlab_domain: infra.local
gitlab_external_url: "https://gitlab.infra.local"

# Resources
gitlab_memory: 4096  # MB (4GB minimum)
gitlab_cores: 4
gitlab_disk: 100  # GB
gitlab_swap: 1024  # MB

# Network
gitlab_bridge: "vmbr0"
gitlab_ip_config: "dhcp"  # Or static: "192.168.x.x/24"

# GitLab Configuration
gitlab_edition: "ce"  # Community Edition
gitlab_version: "16.8.1"  # Or "latest"

# Email Configuration
gitlab_smtp_enabled: true
gitlab_smtp_address: "smtp.infra.local"
gitlab_smtp_port: 587
gitlab_smtp_user: "gitlab@infra.local"
gitlab_smtp_domain: "infra.local"
gitlab_email_from: "gitlab@infra.local"
gitlab_email_reply_to: "noreply@infra.local"

# Keycloak OIDC Integration
gitlab_oidc_enabled: true
gitlab_oidc_issuer: "https://keycloak.infra.local/realms/infrastructure"
gitlab_oidc_client_id: "gitlab"
gitlab_oidc_label: "Keycloak SSO"

# Container Registry
gitlab_registry_enabled: true
gitlab_registry_external_url: "https://registry.gitlab.infra.local"
gitlab_registry_port: 5000

# Artifacts and Storage
gitlab_artifacts_enabled: true
gitlab_artifacts_expire_in: "30 days"
gitlab_lfs_enabled: true

# Performance Tuning
gitlab_puma_workers: 4
gitlab_sidekiq_concurrency: 50
gitlab_postgresql_shared_buffers: "512MB"

# Backup
gitlab_backup_keep_time: 604800  # 7 days in seconds
```

### Step 4: Create GitLab Deployment Playbook

Create `playbooks/gitlab-deploy.yml`:

```yaml
---
- name: Deploy GitLab CI/CD Server
  hosts: proxmox_hosts
  become: true
  roles:
    - gitlab

  post_tasks:
    - name: Display GitLab Access Information
      debug:
        msg: |
          GitLab deployment complete!

          Access URL: {{ gitlab_external_url }}
          Root Username: root
          Root Password: (stored in Ansible Vault)

          Next steps:
          1. Visit {{ gitlab_external_url }} and log in as root
          2. Change root password if desired
          3. Create your first project
          4. Deploy GitLab Runners (Part 2)
```

### Step 5: Deploy GitLab Server

Execute the deployment:

```bash
# Run deployment playbook
ansible-playbook playbooks/gitlab-deploy.yml --ask-vault-pass
```

**Expected Output**:
```
PLAY [Deploy GitLab CI/CD Server] *************************************

TASK [gitlab : Create GitLab LXC container] ***************************
changed: [proxmox-host]

TASK [gitlab : Wait for container to start] **************************
ok: [proxmox-host]

TASK [gitlab : Install GitLab Omnibus package] ***********************
changed: [proxmox-host]

TASK [gitlab : Configure GitLab (gitlab.rb)] *************************
changed: [proxmox-host]

TASK [gitlab : Run gitlab-ctl reconfigure] ***************************
changed: [proxmox-host]

TASK [gitlab : Set root password] ************************************
changed: [proxmox-host]

TASK [gitlab : Configure Traefik routing] ****************************
changed: [proxmox-host]

PLAY RECAP ************************************************************
proxmox-host : ok=15   changed=10   unreachable=0    failed=0
```

**Deployment Time**: ~20-30 minutes (includes package installation and initial configuration)

### Step 6: Verify GitLab Installation

Check GitLab status:

```bash
# SSH into GitLab container
pct exec 53 -- bash

# Check all services are running
gitlab-ctl status

# Expected output: all services should show "run"
run: gitaly: (pid 1234) 120s; run: log: (pid 1233) 120s
run: gitlab-workhorse: (pid 1235) 120s; run: log: (pid 1234) 120s
run: logrotate: (pid 1236) 120s; run: log: (pid 1235) 120s
run: nginx: (pid 1237) 120s; run: log: (pid 1236) 120s
run: postgresql: (pid 1238) 120s; run: log: (pid 1237) 120s
run: redis: (pid 1239) 120s; run: log: (pid 1238) 120s
run: sidekiq: (pid 1240) 120s; run: log: (pid 1239) 120s
```

Access GitLab web UI:

1. Open browser to https://gitlab.infra.local
2. Log in with username `root` and vault password
3. You should see the GitLab dashboard

---

## Part 2: GitLab Runner Deployment

### Step 1: Get Runner Registration Token

From GitLab UI:

1. Log in as root or admin
2. Navigate to **Admin Area** → **CI/CD** → **Runners**
3. Click **New instance runner** (or use existing registration token)
4. Copy the **Registration token** (starts with `GR1348941...`)

Store token in Ansible Vault:

```bash
ansible-vault edit group_vars/all/secrets.yml
```

Add:

```yaml
# GitLab Runner Registration Token
vault_gitlab_runner_token: "GR1348941YOUR_TOKEN_HERE"
```

### Step 2: Configure Runner Variables

Create or edit `inventory/group_vars/all/gitlab_runners.yml`:

```yaml
---
# GitLab Runner Configuration

# Runner Instances (list of runners to deploy)
gitlab_runners:
  - name: "docker-runner-01"
    container_id: 54
    hostname: "gitlab-runner-01"
    memory: 2048  # MB
    cores: 2
    disk: 20  # GB
    executor: "docker"
    docker_image: "debian:12"
    concurrent: 1
    tags: ["docker", "debian", "shared"]

  - name: "docker-runner-02"
    container_id: 55
    hostname: "gitlab-runner-02"
    memory: 2048  # MB
    cores: 2
    disk: 20  # GB
    executor: "docker"
    docker_image: "debian:12"
    concurrent: 1
    tags: ["docker", "debian", "shared"]

# GitLab Server URL
gitlab_url: "https://gitlab.infra.local"

# Registration Token (from Ansible Vault)
gitlab_runner_registration_token: "{{ vault_gitlab_runner_token }}"

# Docker Configuration
gitlab_runner_docker_privileged: false  # Unprivileged for security
gitlab_runner_docker_volumes: ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
```

### Step 3: Deploy GitLab Runners

Create `playbooks/gitlab-runner-deploy.yml`:

```yaml
---
- name: Deploy GitLab Runners
  hosts: proxmox_hosts
  become: true
  roles:
    - gitlab_runner

  post_tasks:
    - name: Display Runner Information
      debug:
        msg: |
          GitLab Runners deployed!

          Runners:
          {% for runner in gitlab_runners %}
          - {{ runner.name }} (CT {{ runner.container_id }})
            Tags: {{ runner.tags | join(', ') }}
            Concurrent: {{ runner.concurrent }}
          {% endfor %}

          Verify in GitLab: Admin Area → CI/CD → Runners
```

Execute deployment:

```bash
ansible-playbook playbooks/gitlab-runner-deploy.yml --ask-vault-pass
```

**Expected Output**:
```
PLAY [Deploy GitLab Runners] ******************************************

TASK [gitlab_runner : Create runner LXC containers] *******************
changed: [proxmox-host] => (item=docker-runner-01)
changed: [proxmox-host] => (item=docker-runner-02)

TASK [gitlab_runner : Install Docker] *********************************
changed: [proxmox-host] => (item=docker-runner-01)
changed: [proxmox-host] => (item=docker-runner-02)

TASK [gitlab_runner : Install GitLab Runner] **************************
changed: [proxmox-host] => (item=docker-runner-01)
changed: [proxmox-host] => (item=docker-runner-02)

TASK [gitlab_runner : Register runners] *******************************
changed: [proxmox-host] => (item=docker-runner-01)
changed: [proxmox-host] => (item=docker-runner-02)

PLAY RECAP ************************************************************
proxmox-host : ok=12   changed=8   unreachable=0    failed=0
```

### Step 4: Verify Runners

Check runners in GitLab UI:

1. Navigate to **Admin Area** → **CI/CD** → **Runners**
2. You should see both runners listed as "online" with green status
3. Each runner shows tags: `docker, debian, shared`

Verify runner service:

```bash
# SSH into runner container
pct exec 54 -- bash

# Check runner status
gitlab-runner verify

# Expected output:
Verifying runner... is alive                        runner=GR1348941
```

---

## Part 3: First Project and CI/CD Pipeline

### Step 1: Create Test Project

1. Log in to GitLab (https://gitlab.infra.local)
2. Click **New project** → **Create blank project**
3. Configure project:
   - **Project name**: `test-project`
   - **Visibility**: Private
   - **Initialize repository with README**: ✓ checked
4. Click **Create project**

### Step 2: Create CI/CD Pipeline

1. In your test project, click **+** → **New file**
2. Filename: `.gitlab-ci.yml`
3. Paste this content:

```yaml
stages:
  - build
  - test

variables:
  MESSAGE: "Hello from GitLab CI!"

build-job:
  stage: build
  image: debian:12
  script:
    - echo "Building project..."
    - echo $MESSAGE
    - mkdir -p build
    - echo "Build complete" > build/output.txt
  artifacts:
    paths:
      - build/
    expire_in: 1 week

test-job:
  stage: test
  image: debian:12
  dependencies:
    - build-job
  script:
    - echo "Running tests..."
    - cat build/output.txt
    - echo "Tests passed!"
```

4. **Commit message**: `Add CI/CD pipeline`
5. Click **Commit changes**

### Step 3: Verify Pipeline Execution

1. Pipeline should trigger automatically
2. Navigate to **CI/CD** → **Pipelines**
3. Click on the pipeline ID
4. You should see:
   - `build-job` running or complete
   - `test-job` waiting or running
5. Click on each job to view logs

**Expected Timeline**:
- Pipeline triggers: <30 seconds after commit
- Build job starts: ~5-10 seconds (Docker image pull)
- Build job completes: ~15 seconds
- Test job starts: immediately after build
- Test job completes: ~10 seconds
- **Total pipeline time**: ~40-60 seconds

### Step 4: Verify Keycloak SSO

Test single sign-on:

1. Sign out of GitLab (click profile → Sign out)
2. On login page, click **Keycloak SSO** button
3. Redirected to Keycloak login
4. Log in with your Keycloak/LDAP credentials
5. Redirected back to GitLab, logged in automatically
6. New user account auto-provisioned from Keycloak

**Note**: First-time Keycloak users are auto-created in GitLab with email and name from Keycloak.

---

## Part 4: Container Registry (Optional)

### Step 1: Build and Push Docker Image

Create a simple Dockerfile in your project:

```dockerfile
FROM debian:12
RUN echo "Hello from GitLab Registry" > /hello.txt
CMD ["cat", "/hello.txt"]
```

Update `.gitlab-ci.yml` to add docker build stage:

```yaml
stages:
  - build
  - test
  - docker

# ... existing build and test jobs ...

docker-build:
  stage: docker
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
    - docker tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA $CI_REGISTRY_IMAGE:latest
    - docker push $CI_REGISTRY_IMAGE:latest
  only:
    - main
```

Commit and push - pipeline will build and push image to GitLab registry.

### Step 2: Verify Container Registry

1. Navigate to **Packages & Registries** → **Container Registry**
2. You should see your image with tags: `latest` and commit SHA
3. Click on image for pull instructions

Pull image from another host:

```bash
# Log in to GitLab registry
docker login registry.gitlab.infra.local

# Pull image
docker pull registry.gitlab.infra.local/root/test-project:latest

# Run container
docker run --rm registry.gitlab.infra.local/root/test-project:latest
```

---

## Troubleshooting

### Issue: GitLab Service Not Starting

**Symptoms**: `gitlab-ctl status` shows services as "down"

**Diagnosis**:
```bash
# Check logs
gitlab-ctl tail

# Check specific service
gitlab-ctl tail postgresql
```

**Common Causes**:
- Insufficient memory (need minimum 4GB)
- Disk full
- Port conflicts

**Solution**:
```bash
# Restart services
gitlab-ctl restart

# Reconfigure if needed
gitlab-ctl reconfigure

# Check memory
free -h

# Check disk space
df -h /var/opt/gitlab
```

---

### Issue: Runner Not Connecting

**Symptoms**: Runner shows "offline" in GitLab UI

**Diagnosis**:
```bash
# SSH into runner container
pct exec 54 -- bash

# Check runner status
gitlab-runner verify

# Check logs
journalctl -u gitlab-runner -f
```

**Common Causes**:
- Invalid registration token
- Network connectivity to GitLab server
- Docker daemon not running

**Solution**:
```bash
# Verify Docker is running
systemctl status docker

# Re-register runner
gitlab-runner unregister --all-runners
gitlab-runner register \
  --non-interactive \
  --url https://gitlab.infra.local \
  --registration-token YOUR_TOKEN \
  --executor docker \
  --docker-image debian:12
```

---

### Issue: Pipeline Job Stuck in "Pending"

**Symptoms**: Job shows "This job is stuck because you don't have any active runners"

**Diagnosis**:
```bash
# Check runner availability in GitLab UI
# Admin Area → CI/CD → Runners

# Verify runner tags match job requirements
```

**Solution**:
- Ensure at least one runner is online
- Check job `tags:` match runner tags
- If using specific tags, ensure runner has those tags

---

### Issue: OIDC Authentication Fails

**Symptoms**: "Could not authenticate you from OpenidConnect" error

**Diagnosis**:
```bash
# Check GitLab logs
pct exec 53 -- gitlab-ctl tail gitlab-rails/production.log
```

**Common Causes**:
- Invalid Keycloak issuer URL
- Incorrect client secret
- Keycloak client misconfigured

**Solution**:
1. Verify Keycloak realm URL is correct
2. Check client secret in Ansible Vault matches Keycloak
3. Verify redirect URI in Keycloak includes `https://gitlab.infra.local/*`
4. Reconfigure GitLab: `gitlab-ctl reconfigure`

---

### Issue: Container Registry Push Fails

**Symptoms**: `docker push` fails with authentication error

**Diagnosis**:
```bash
# Check registry is enabled
pct exec 53 -- gitlab-ctl status registry

# Test authentication
docker login registry.gitlab.infra.local
```

**Solution**:
1. Verify registry is enabled in gitlab.rb
2. Check Traefik routing for registry.gitlab.infra.local
3. Ensure user has write access to project
4. Use project access token or personal access token for authentication

---

## Monitoring and Maintenance

### Health Checks

**GitLab Health**:
```bash
# Check application health
curl -f https://gitlab.infra.local/-/health

# Check readiness
curl -f https://gitlab.infra.local/-/readiness

# Check liveness
curl -f https://gitlab.infra.local/-/liveness
```

**Runner Health**:
```bash
# Verify all runners
gitlab-runner verify
```

### Performance Monitoring

**GitLab Metrics** (via Prometheus):
- Access: https://gitlab.infra.local/-/metrics (requires admin)
- Metrics include: request rate, database queries, Redis ops, Sidekiq queues

**Zabbix Integration** (if configured):
- Monitor GitLab health endpoints
- Track runner availability
- Alert on service failures

### Backup and Recovery

**Create Backup**:
```bash
# SSH into GitLab container
pct exec 53 -- bash

# Create GitLab backup
gitlab-rake gitlab:backup:create

# Backups stored in: /var/opt/gitlab/backups/
```

**Restore from Backup**:
```bash
# Stop services except PostgreSQL and Redis
gitlab-ctl stop unicorn
gitlab-ctl stop puma
gitlab-ctl stop sidekiq

# Restore (replace TIMESTAMP with backup filename)
gitlab-rake gitlab:backup:restore BACKUP=TIMESTAMP

# Restart services
gitlab-ctl restart
```

**PBS Container Backup** (Automated):
- Entire LXC containers backed up via PBS schedule
- Includes all repos, database, configuration
- Restore entire container from PBS snapshot for disaster recovery

---

## Success Criteria Verification

After deployment, verify these success criteria from the specification:

- [ ] **SC-001**: Create project, push code, view in UI - completes within 2 minutes
- [ ] **SC-002**: CI/CD pipeline triggers automatically within 30 seconds of commit
- [ ] **SC-003**: System supports 10 concurrent pipelines (add more runners if needed)
- [ ] **SC-004**: Repository clone at 10+ MB/s (test with `git clone`)
- [ ] **SC-005**: GitLab UI pages load in <2 seconds
- [ ] **SC-006**: System achieves 99.5% uptime (monitor over time)
- [ ] **SC-007**: Pipeline logs accessible for 30+ days (check artifact retention)
- [ ] **SC-008**: Git push completes in <10 seconds for 1GB repo
- [ ] **SC-009**: 95% of pipeline failures show clear error messages
- [ ] **SC-010**: Merge request workflow (create, review, merge) completes in <5 minutes

If all criteria pass, deployment is successful and ready for production use!

---

## Next Steps

After successful deployment:

1. **User Onboarding**: Import existing projects, add team members via Keycloak
2. **NetBox Integration**: Register GitLab/runner containers in CMDB (if not automated)
3. **Zabbix Monitoring**: Configure health check monitoring and alerting
4. **Backup Testing**: Verify PBS backups and test restoration procedure
5. **Runner Scaling**: Add more runners as needed for increased concurrency
6. **Documentation**: Document project-specific CI/CD patterns and runner usage
7. **Security Hardening**: Review and implement additional security measures
8. **Performance Tuning**: Adjust GitLab/runner resources based on actual usage

---

## Support and Resources

- **GitLab Documentation**: https://docs.gitlab.com/
- **GitLab Runner Docs**: https://docs.gitlab.com/runner/
- **GitLab CI/CD YAML Reference**: https://docs.gitlab.com/ee/ci/yaml/
- **OIDC Integration**: https://docs.gitlab.com/ee/administration/auth/oidc.html
- **Container Registry**: https://docs.gitlab.com/ee/user/packages/container_registry/
- **GitLab Community Forum**: https://forum.gitlab.com/
- **Internal Documentation**: `docs/gitlab/` (created during deployment)
