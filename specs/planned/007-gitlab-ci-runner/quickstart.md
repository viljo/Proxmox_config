# Quickstart Guide: GitLab CI/CD Platform

**Feature**: GitLab CI/CD Platform
**Branch**: `007-gitlab-ci-runner`
**Date**: 2025-10-20

## Overview

This quickstart guide provides step-by-step instructions for deploying a GitLab CE instance and GitLab Runners in your Proxmox infrastructure using Ansible automation.

**Time to Complete**: 30-45 minutes
**Difficulty**: Intermediate
**Prerequisites**: Proxmox VE cluster, Ansible 2.15+, existing Keycloak/LDAP infrastructure

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Deploy GitLab Instance](#deploy-gitlab-instance)
4. [Deploy GitLab Runners](#deploy-gitlab-runners)
5. [Configure OIDC Authentication](#configure-oidc-authentication)
6. [Register GitLab.com Runner](#register-gitlabcom-runner)
7. [Verification](#verification)
8. [Common Issues](#common-issues)

---

## Prerequisites

### Infrastructure Requirements

- **Proxmox VE**: Version 8.x with at least one node
- **Network**: Internal network range (e.g., `10.0.10.0/24`)
- **Storage**: ZFS pool with at least 100GB available space
- **DNS**: A records for GitLab and container registry
  - `gitlab.example.com` → Traefik IP
  - `registry.example.com` → Traefik IP

### Service Dependencies

- **Traefik**: Reverse proxy for HTTPS termination
- **Keycloak**: OIDC provider (or LDAP server)
- **NetBox** (optional): CMDB for inventory management
- **Proxmox Backup Server** (optional): Automated backups

### Local Tools

- **Ansible**: Version 2.15 or later
- **ansible-vault**: For secret encryption
- **SSH access**: To Proxmox host(s)

### Permissions

- Proxmox API access with PVEAdmin role
- Sudo access on Proxmox host for ZFS operations
- Keycloak realm admin access (for OIDC setup)

---

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/proxmox_config.git
cd proxmox_config
git checkout 007-gitlab-ci-runner
```

### 2. Install Ansible Dependencies

```bash
# Install required Ansible collections
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix

# Install Proxmox Python SDK (required for LXC management)
pip3 install proxmoxer requests
```

### 3. Configure Inventory

Edit `inventory/hosts.yml` to define your Proxmox infrastructure:

```yaml
all:
  children:
    proxmox:
      hosts:
        pve-node1:
          ansible_host: 192.168.1.10
          ansible_user: root
          ansible_python_interpreter: /usr/bin/python3
```

### 4. Create Ansible Vault for Secrets

```bash
# Create a new vault file
ansible-vault create group_vars/all/secrets.yml
```

Add the following secrets (replace with your actual values):

```yaml
---
# GitLab Root Password (initial admin account)
vault_gitlab_root_password: "YourStrongPasswordHere123!"

# Keycloak OIDC Client Secret
vault_gitlab_oidc_secret: "keycloak-client-secret-from-admin-console"

# GitLab Runner Registration Token (from GitLab instance)
vault_gitlab_runner_token: "glrt-xxxxxxxxxxxxxxxxxxxx"

# GitLab.com Runner Token (from GitLab.com project settings - optional)
vault_gitlab_com_runner_token: "glrt-yyyyyyyyyyyyyyyyyyyy"
```

**Save and exit** (`:wq` in vim, or your editor's save command).

### 5. Configure Group Variables

Create or edit `inventory/group_vars/all/main.yml`:

```yaml
---
# Proxmox Configuration
proxmox_api_host: "192.168.1.10"
proxmox_api_port: 8006
proxmox_node: "pve-node1"

# Network Configuration
internal_network_cidr: "10.0.10.0/24"
internal_gateway: "10.0.10.1"

# GitLab Configuration
gitlab_external_url: "https://gitlab.example.com"
gitlab_lxc_vmid: 200
gitlab_lxc_hostname: "gitlab"
gitlab_lxc_cores: 4
gitlab_lxc_memory_mb: 8192
gitlab_lxc_disk_size_gb: 50
gitlab_ssh_port: 2222
gitlab_version: "16.11"
gitlab_registry_enabled: true
gitlab_oidc_enabled: true

# Keycloak OIDC Configuration
gitlab_oidc_issuer: "https://keycloak.example.com/realms/main"
gitlab_oidc_client_id: "gitlab"

# GitLab Runner Configuration
gitlab_runner_lxc_vmid_start: 201
gitlab_runner_count: 2
gitlab_runner_executor: "docker"
gitlab_runner_concurrent_jobs: 3
gitlab_runner_tags: ["docker", "self-hosted", "linux"]

# ZFS Storage Configuration
gitlab_data_zfs_dataset: "rpool/gitlab-data"
gitlab_registry_zfs_dataset: "rpool/gitlab-registry"

# Backup Configuration
gitlab_backup_enabled: true
gitlab_backup_schedule: "0 2 * * *"  # Daily at 2 AM
gitlab_backup_keep_time: 604800      # 7 days
```

---

## Deploy GitLab Instance

### Step 1: Prepare ZFS Datasets

On your Proxmox host, create ZFS datasets for GitLab data:

```bash
# SSH to Proxmox host
ssh root@pve-node1

# Create ZFS datasets
zfs create rpool/gitlab-data
zfs create rpool/gitlab-registry

# Set appropriate permissions
zfs set compression=lz4 rpool/gitlab-data
zfs set compression=lz4 rpool/gitlab-registry

# Verify creation
zfs list | grep gitlab
```

### Step 2: Run GitLab Deployment Playbook

```bash
# From your local machine (in the proxmox_config directory)
ansible-playbook playbooks/gitlab_deploy.yml \
  --ask-vault-pass \
  --tags gitlab \
  --limit proxmox
```

**Expected Output**:
```
PLAY [Deploy GitLab Instance] **************************************************

TASK [gitlab : Create GitLab LXC container] ***********************************
changed: [pve-node1]

TASK [gitlab : Install GitLab CE package] *************************************
changed: [pve-node1]

TASK [gitlab : Configure GitLab (gitlab.rb)] **********************************
changed: [pve-node1]

TASK [gitlab : Run gitlab-ctl reconfigure] ************************************
changed: [pve-node1]

PLAY RECAP *********************************************************************
pve-node1                  : ok=15   changed=8    unreachable=0    failed=0
```

**Duration**: 10-15 minutes (GitLab package installation and initial configuration)

### Step 3: Verify GitLab Installation

```bash
# Check LXC container status
pct list | grep 200

# Check GitLab services inside container
pct exec 200 -- gitlab-ctl status

# Expected output:
# run: gitaly: (pid 1234) 567s; run: log: (pid 1235) 567s
# run: gitlab-workhorse: (pid 1236) 567s; run: log: (pid 1237) 567s
# run: logrotate: (pid 1238) 567s; run: log: (pid 1239) 567s
# ...
```

### Step 4: Access GitLab Web Interface

1. Open your browser and navigate to `https://gitlab.example.com`
2. Log in with:
   - **Username**: `root`
   - **Password**: `YourStrongPasswordHere123!` (from vault_gitlab_root_password)
3. You should see the GitLab dashboard

**First Login Tasks**:
- [ ] Change root password (recommended)
- [ ] Disable public signups (Admin Area > Settings > General > Sign-up restrictions)
- [ ] Configure email settings (Admin Area > Settings > Email)
- [ ] Review installed GitLab version (Admin Area > Overview)

---

## Deploy GitLab Runners

### Step 1: Obtain Runner Registration Token

From the GitLab web interface:

1. Navigate to **Admin Area** (wrench icon) → **CI/CD** → **Runners**
2. Click **"New instance runner"**
3. Select platform: **Linux**
4. Copy the **registration token** (starts with `glrt-`)
5. Store in Ansible Vault:

```bash
ansible-vault edit group_vars/all/secrets.yml

# Add or update:
vault_gitlab_runner_token: "glrt-xxxxxxxxxxxxxxxxxxxx"
```

### Step 2: Run Runner Deployment Playbook

```bash
ansible-playbook playbooks/gitlab_runner_deploy.yml \
  --ask-vault-pass \
  --tags runner \
  --limit proxmox
```

**Expected Output**:
```
PLAY [Deploy GitLab Runners] **************************************************

TASK [gitlab_runner : Create runner LXC containers] ***************************
changed: [pve-node1] => (item=1)
changed: [pve-node1] => (item=2)

TASK [gitlab_runner : Install GitLab Runner binary] ***************************
changed: [pve-node1]

TASK [gitlab_runner : Register runners] ***************************************
changed: [pve-node1] => (item=1)
changed: [pve-node1] => (item=2)

PLAY RECAP *********************************************************************
pve-node1                  : ok=12   changed=6    unreachable=0    failed=0
```

**Duration**: 5-10 minutes

### Step 3: Verify Runners in GitLab

1. In GitLab web interface, go to **Admin Area** → **CI/CD** → **Runners**
2. You should see 2 runners listed as **"online"** (green dot)
3. Click on each runner to view details:
   - Status: Active
   - Tags: `docker`, `self-hosted`, `linux`
   - Executor: docker
   - Assigned projects: None (instance-wide runners)

### Step 4: Test Pipeline Execution

Create a test project and pipeline:

1. Create a new project: **"test-ci"**
2. Add a file `.gitlab-ci.yml` with the following content:

```yaml
stages:
  - test

hello_world:
  stage: test
  tags:
    - docker
  script:
    - echo "Hello from GitLab Runner!"
    - uname -a
    - docker --version
```

3. Commit the file (this will trigger a pipeline)
4. Navigate to **CI/CD** → **Pipelines**
5. Click on the running pipeline to view logs
6. Verify job completes successfully with green checkmark

---

## Configure OIDC Authentication

### Step 1: Create Keycloak Client

In Keycloak admin console:

1. Navigate to your realm (e.g., "main")
2. Click **Clients** → **Create client**
3. **Client ID**: `gitlab`
4. **Client Protocol**: `openid-connect`
5. **Client Authentication**: Enabled
6. **Valid Redirect URIs**: `https://gitlab.example.com/users/auth/openid_connect/callback`
7. **Web Origins**: `https://gitlab.example.com`
8. Click **Save**

### Step 2: Configure Client Scopes

1. Go to **Clients** → `gitlab` → **Client scopes**
2. Ensure the following scopes are assigned:
   - `openid` (required)
   - `profile` (required)
   - `email` (required)
3. Add custom mappers (optional):
   - **Mapper Type**: Group Membership
   - **Token Claim Name**: `groups`
   - **Add to ID token**: ON
   - **Add to access token**: ON
   - **Add to userinfo**: ON

### Step 3: Obtain Client Secret

1. Go to **Clients** → `gitlab` → **Credentials**
2. Copy the **Client Secret**
3. Store in Ansible Vault:

```bash
ansible-vault edit group_vars/all/secrets.yml

# Add or update:
vault_gitlab_oidc_secret: "paste-client-secret-here"
```

### Step 4: Re-run GitLab Configuration

```bash
ansible-playbook playbooks/gitlab_deploy.yml \
  --ask-vault-pass \
  --tags gitlab,configure \
  --limit proxmox
```

This will update `gitlab.rb` with OIDC settings and reconfigure GitLab.

### Step 5: Test OIDC Login

1. Log out of GitLab (or open incognito window)
2. Navigate to `https://gitlab.example.com`
3. Click **"Sign in with Keycloak SSO"** button
4. You should be redirected to Keycloak login page
5. Enter your Keycloak credentials
6. After successful authentication, you should be redirected back to GitLab
7. A new user account should be automatically created

**Verify OIDC User**:
- Admin Area → Overview → Users
- Find your Keycloak user (external identity linked)

---

## Register GitLab.com Runner

This section is optional if you want to use self-hosted runners with GitLab.com projects.

### Step 1: Obtain GitLab.com Runner Token

1. Go to your GitLab.com project
2. Navigate to **Settings** → **CI/CD** → **Runners**
3. Expand **"Project runners"** section
4. Click **"New project runner"**
5. Select **Linux** as the operating system
6. Copy the **registration token** (starts with `glrt-`)
7. Store in Ansible Vault:

```bash
ansible-vault edit group_vars/all/secrets.yml

# Add:
vault_gitlab_com_runner_token: "glrt-yyyyyyyyyyyyyyyyyyyy"
```

### Step 2: Update Group Variables

Edit `inventory/group_vars/all/main.yml` and add:

```yaml
# GitLab.com Runner Configuration
gitlab_runner_gitlab_com_enabled: true
gitlab_runner_gitlab_com_tags: ["self-hosted", "gitlab-com", "docker"]
```

### Step 3: Deploy GitLab.com Runner

```bash
ansible-playbook playbooks/gitlab_runner_deploy.yml \
  --ask-vault-pass \
  --tags runner,gitlab-com \
  --limit proxmox
```

This will create an additional runner container (VMID 203) registered with GitLab.com.

### Step 4: Verify in GitLab.com

1. In GitLab.com, go to your project → **Settings** → **CI/CD** → **Runners**
2. You should see a runner with tags `self-hosted`, `gitlab-com`, `docker`
3. Status should show as **online** (green dot)

### Step 5: Test GitLab.com Pipeline

In your GitLab.com project, create `.gitlab-ci.yml`:

```yaml
stages:
  - test

test_self_hosted:
  stage: test
  tags:
    - self-hosted
    - gitlab-com
  script:
    - echo "Running on self-hosted runner!"
    - hostname
    - ip addr show
```

Commit and push to trigger pipeline. Verify it runs on your self-hosted runner (check job logs for hostname).

---

## Verification

### Health Check Endpoints

GitLab exposes several health check endpoints:

```bash
# Health check (basic)
curl -k https://gitlab.example.com/-/health
# Expected: {"status":"ok"}

# Readiness check (detailed)
curl -k https://gitlab.example.com/-/readiness
# Expected: JSON with service statuses

# Liveness check
curl -k https://gitlab.example.com/-/liveness
# Expected: {"status":"ok"}
```

### Runner Verification

```bash
# SSH to runner container
pct exec 201 -- bash

# Verify runner service
systemctl status gitlab-runner

# Verify runner connectivity
gitlab-runner verify

# Expected output:
# Verifying runner... is alive                        runner=xxxxxx
```

### Container Registry Verification

```bash
# Test container registry authentication
docker login registry.example.com
# Username: (your GitLab username)
# Password: (your GitLab password or personal access token)

# Build and push test image
docker build -t registry.example.com/test-ci/hello:latest .
docker push registry.example.com/test-ci/hello:latest

# Verify in GitLab: Project → Packages & Registries → Container Registry
```

### Backup Verification

```bash
# Trigger manual backup
pct exec 200 -- gitlab-rake gitlab:backup:create

# Verify backup file exists
pct exec 200 -- ls -lh /var/opt/gitlab/backups/

# Expected: File named like: 1729449600_2025_10_20_16.11.2_gitlab_backup.tar
```

---

## Common Issues

### Issue: GitLab container fails to start

**Symptoms**: LXC container status shows "stopped", `pct start 200` fails

**Possible Causes**:
- Insufficient memory allocated
- ZFS dataset not mounted
- Network configuration issue

**Solution**:
```bash
# Check container logs
pct enter 200
journalctl -xe

# Verify ZFS mounts
zfs list | grep gitlab
pct mount 200

# Check memory allocation
pct config 200 | grep memory

# Increase memory if needed
pct set 200 --memory 8192
```

---

### Issue: Runner registration fails

**Symptoms**: `gitlab-runner register` command fails with authentication error

**Possible Causes**:
- Invalid registration token
- Network connectivity issue
- GitLab URL unreachable from runner container

**Solution**:
```bash
# Verify network connectivity
pct exec 201 -- ping -c 3 gitlab.example.com
pct exec 201 -- curl -k https://gitlab.example.com/-/health

# Re-obtain registration token from GitLab UI
# Update Ansible Vault with new token

# Re-run runner registration
ansible-playbook playbooks/gitlab_runner_deploy.yml \
  --ask-vault-pass \
  --tags runner,register \
  --limit proxmox
```

---

### Issue: OIDC login redirects to error page

**Symptoms**: After clicking "Sign in with Keycloak SSO", user sees error or redirect loop

**Possible Causes**:
- Invalid Keycloak client secret
- Incorrect redirect URI configured
- Keycloak realm not accessible

**Solution**:
```bash
# Verify OIDC configuration in GitLab
pct exec 200 -- grep -A 20 "omniauth_providers" /etc/gitlab/gitlab.rb

# Check redirect URI matches Keycloak client config
# Should be: https://gitlab.example.com/users/auth/openid_connect/callback

# Test Keycloak discovery endpoint
curl https://keycloak.example.com/realms/main/.well-known/openid-configuration

# Re-verify client secret in Ansible Vault
ansible-vault view group_vars/all/secrets.yml

# Reconfigure GitLab
pct exec 200 -- gitlab-ctl reconfigure
pct exec 200 -- gitlab-ctl restart
```

---

### Issue: Container registry push fails

**Symptoms**: `docker push` fails with authentication or permission error

**Possible Causes**:
- Registry not enabled in GitLab
- DNS not resolving `registry.example.com`
- Traefik routing issue

**Solution**:
```bash
# Verify registry is enabled
pct exec 200 -- grep "registry_external_url" /etc/gitlab/gitlab.rb
# Should show: registry_external_url 'https://registry.example.com'

# Check DNS resolution
nslookup registry.example.com

# Verify Traefik routing
curl -k https://registry.example.com/v2/
# Expected: {"errors":[{"code":"UNAUTHORIZED"...}]}  (this is normal - registry requires auth)

# Re-run GitLab configuration with registry enabled
ansible-playbook playbooks/gitlab_deploy.yml \
  --ask-vault-pass \
  --tags gitlab,registry \
  --limit proxmox
```

---

### Issue: Pipeline jobs stuck in "pending" state

**Symptoms**: Pipeline jobs never start, remain in "pending" status indefinitely

**Possible Causes**:
- No runners available with matching tags
- Runners offline or paused
- Runner reached concurrent job limit

**Solution**:
```bash
# Check runner status in GitLab UI
# Admin Area → CI/CD → Runners

# Verify runner service is running
pct exec 201 -- systemctl status gitlab-runner

# Check runner logs
pct exec 201 -- journalctl -u gitlab-runner -f

# Verify job tags match runner tags
# In .gitlab-ci.yml, ensure tags match runners (e.g., "docker", "self-hosted")

# Increase concurrent job limit if needed
ansible-playbook playbooks/gitlab_runner_deploy.yml \
  --ask-vault-pass \
  --extra-vars "gitlab_runner_concurrent_jobs=5" \
  --tags runner,configure \
  --limit proxmox
```

---

## Next Steps

After successful deployment, consider these enhancements:

1. **Enable Advanced Monitoring**
   - Configure Prometheus metrics export
   - Set up Grafana dashboards for GitLab and runner metrics
   - Integrate with Zabbix for alerting

2. **Implement Advanced CI/CD Features**
   - Configure deployment keys for external services
   - Set up CI/CD variables and secrets
   - Create pipeline templates for common workflows

3. **Optimize Performance**
   - Enable GitLab caching with Redis Sentinel
   - Configure Gitaly cluster for repository storage HA
   - Implement runner autoscaling with Docker Machine

4. **Enhance Security**
   - Enable 2FA for all users (Admin Area → Settings → Sign-in restrictions)
   - Configure IP allowlisting for admin access
   - Implement regular security scans of container images

5. **Backup & Disaster Recovery**
   - Test GitLab backup restoration procedure
   - Configure off-site backup replication
   - Document recovery time objectives (RTO)

---

## Additional Resources

- [GitLab Official Documentation](https://docs.gitlab.com/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [GitLab CI/CD Examples](https://docs.gitlab.com/ee/ci/examples/)
- [Proxmox LXC Management](https://pve.proxmox.com/wiki/Linux_Container)
- [Ansible Vault Best Practices](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

---

## Support

For issues specific to this deployment:
- Check `roles/gitlab/README.md` and `roles/gitlab_runner/README.md`
- Review Ansible playbook logs in `/var/log/ansible.log`
- Consult `docs/gitlab-architecture.md` for architecture details

For GitLab-specific issues:
- GitLab Community Forum: https://forum.gitlab.com/
- GitLab Issue Tracker: https://gitlab.com/gitlab-org/gitlab/-/issues

---

**Status**: ✅ Quickstart Guide Complete
