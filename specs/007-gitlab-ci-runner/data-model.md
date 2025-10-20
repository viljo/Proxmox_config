# Data Model: GitLab CI/CD Platform

**Feature**: GitLab CI/CD Platform
**Branch**: `007-gitlab-ci-runner`
**Date**: 2025-10-20

## Overview

This document defines the data entities, their relationships, and state transitions for the GitLab CI/CD platform deployment. This is an infrastructure deployment, so the data model focuses on configuration entities, service state, and operational data rather than application-level data models.

---

## Infrastructure Entities

### GitLab Instance

**Description**: The primary GitLab application server hosting repositories, CI/CD orchestration, and web interface.

**Attributes**:
- `hostname`: String - FQDN for GitLab service (e.g., `gitlab.example.com`)
- `lxc_vmid`: Integer - Proxmox LXC container ID (e.g., `200`)
- `internal_ip`: String - Internal network IP address (e.g., `10.0.10.10`)
- `version`: String - GitLab CE version (e.g., `16.11.2-ce.0`)
- `external_url`: String - Public-facing URL (e.g., `https://gitlab.example.com`)
- `ssh_port`: Integer - SSH port for Git operations (default: `2222`)
- `root_password`: Encrypted String - Initial root password (Ansible Vault)
- `registry_enabled`: Boolean - Container registry feature flag
- `oidc_enabled`: Boolean - OIDC authentication feature flag
- `backup_schedule`: String - Cron expression for backups (e.g., `0 2 * * *`)

**Relationships**:
- Has many: GitLab Runners
- Has many: Projects
- Has many: User Accounts
- Integrates with: Keycloak (OIDC provider)
- Integrates with: Traefik (reverse proxy)
- Integrates with: NetBox (CMDB)
- Depends on: PostgreSQL (database)
- Depends on: Redis (cache)

**State Transitions**:
```
[Unprovisioned] → [LXC Created] → [GitLab Installed] → [Configured] → [Running]
                                                                          ↓
                                                                    [Maintenance]
                                                                          ↓
                                                                      [Stopped]
```

**Validation Rules**:
- `hostname` must be a valid FQDN
- `lxc_vmid` must be unique in Proxmox cluster
- `internal_ip` must be within defined subnet range
- `version` must match available GitLab CE package versions
- `root_password` must be encrypted with Ansible Vault
- `ssh_port` must not conflict with existing services

---

### GitLab Runner

**Description**: Worker process that executes CI/CD pipeline jobs, can be registered with either self-hosted GitLab or GitLab.com.

**Attributes**:
- `name`: String - Unique runner identifier (e.g., `runner-docker-01`)
- `lxc_vmid`: Integer - Proxmox LXC container ID (e.g., `201`)
- `internal_ip`: String - Internal network IP address (e.g., `10.0.10.11`)
- `executor_type`: Enum - Execution environment (`docker`, `shell`, `kubernetes`)
- `registration_url`: String - GitLab instance URL (e.g., `https://gitlab.example.com` or `https://gitlab.com`)
- `registration_token`: Encrypted String - Runner authentication token (Ansible Vault)
- `tags`: List[String] - Runner capability tags (e.g., `["docker", "self-hosted"]`)
- `concurrent_jobs`: Integer - Maximum concurrent job limit (default: `3`)
- `max_job_timeout`: String - Maximum job duration (e.g., `1h`, `3600`)
- `privileged_mode`: Boolean - Docker executor privilege flag (required for DinD)
- `is_gitlab_com`: Boolean - Whether registered with GitLab.com vs self-hosted

**Relationships**:
- Belongs to: GitLab Instance (if self-hosted) OR GitLab.com (if remote)
- Executes: Pipeline Jobs
- Integrates with: NetBox (CMDB)

**State Transitions**:
```
[Unprovisioned] → [LXC Created] → [Runner Installed] → [Registered] → [Active]
                                                                          ↓
                                                                       [Paused]
                                                                          ↓
                                                                     [Unregistered]
```

**Validation Rules**:
- `name` must be unique across all runners
- `lxc_vmid` must be unique in Proxmox cluster
- `executor_type` must be one of: `docker`, `shell`, `kubernetes`
- `registration_token` must be encrypted with Ansible Vault
- `tags` must not be empty (at least one tag required)
- `concurrent_jobs` must be ≥ 1
- If `executor_type == "docker"`, `privileged_mode` should be `true` for Docker builds

---

### Project

**Description**: Git repository with associated CI/CD configuration, managed within GitLab.

**Attributes**:
- `id`: Integer - GitLab project ID (auto-assigned)
- `name`: String - Project name (e.g., `my-app`)
- `namespace`: String - Group or user namespace (e.g., `engineering/backend`)
- `repository_size_mb`: Integer - Git repository size in megabytes
- `visibility`: Enum - Access level (`private`, `internal`, `public`)
- `ci_enabled`: Boolean - CI/CD pipeline feature flag
- `registry_enabled`: Boolean - Container registry feature flag
- `default_branch`: String - Primary branch name (default: `main`)

**Relationships**:
- Belongs to: User Account OR Group
- Has many: Pipelines
- Has one: Container Registry (if enabled)
- Uses: GitLab Runners (for pipeline execution)

**State Transitions**:
```
[Created] → [Active] → [Archived]
                ↓
           [Forked] → [Active]
```

**Validation Rules**:
- `name` must be unique within namespace
- `namespace` must exist in GitLab
- `repository_size_mb` must not exceed configured limit
- `visibility` must be one of: `private`, `internal`, `public`
- `default_branch` must exist in repository

---

### Pipeline

**Description**: Automated CI/CD workflow defined in `.gitlab-ci.yml`, consisting of stages and jobs.

**Attributes**:
- `id`: Integer - Pipeline ID (auto-assigned)
- `project_id`: Integer - Associated project ID
- `ref`: String - Git reference (branch, tag, commit SHA)
- `status`: Enum - Pipeline state (`pending`, `running`, `passed`, `failed`, `canceled`)
- `created_at`: DateTime - Pipeline creation timestamp
- `started_at`: DateTime - Pipeline start timestamp (nullable)
- `finished_at`: DateTime - Pipeline completion timestamp (nullable)
- `duration_seconds`: Integer - Total execution time in seconds
- `user_id`: Integer - User who triggered the pipeline
- `trigger_source`: Enum - Pipeline trigger (`push`, `merge_request`, `schedule`, `api`)

**Relationships**:
- Belongs to: Project
- Has many: Jobs
- Triggered by: User Account
- Produces: Artifacts (optional)

**State Transitions**:
```
[Created] → [Pending] → [Running] → [Passed]
                           ↓           ↓
                      [Canceled]   [Failed]
```

**Validation Rules**:
- `ref` must exist in the repository
- `status` must be one of: `pending`, `running`, `passed`, `failed`, `canceled`
- `duration_seconds` must be ≥ 0
- `finished_at` must be after `started_at` (if both present)
- `trigger_source` must be one of: `push`, `merge_request`, `schedule`, `api`

---

### Job

**Description**: Individual task within a pipeline, executed on a GitLab Runner.

**Attributes**:
- `id`: Integer - Job ID (auto-assigned)
- `pipeline_id`: Integer - Parent pipeline ID
- `name`: String - Job name from `.gitlab-ci.yml` (e.g., `build`, `test`, `deploy`)
- `stage`: String - Pipeline stage (e.g., `build`, `test`, `deploy`)
- `status`: Enum - Job state (`pending`, `running`, `success`, `failed`, `canceled`)
- `runner_id`: Integer - Assigned runner ID (nullable if pending)
- `created_at`: DateTime - Job creation timestamp
- `started_at`: DateTime - Job start timestamp (nullable)
- `finished_at`: DateTime - Job completion timestamp (nullable)
- `duration_seconds`: Integer - Execution time in seconds
- `log_output`: Text - Job execution logs
- `artifacts_file`: String - Path to artifacts archive (nullable)
- `artifacts_expire_at`: DateTime - Artifact expiration timestamp (nullable)

**Relationships**:
- Belongs to: Pipeline
- Executed by: GitLab Runner
- Produces: Artifacts (optional)

**State Transitions**:
```
[Created] → [Pending] → [Running] → [Success]
                           ↓           ↓
                      [Canceled]   [Failed]
```

**Validation Rules**:
- `name` must be unique within pipeline
- `stage` must be defined in `.gitlab-ci.yml`
- `status` must be one of: `pending`, `running`, `success`, `failed`, `canceled`
- `duration_seconds` must be ≥ 0
- `finished_at` must be after `started_at` (if both present)
- `artifacts_expire_at` must be after `finished_at` (if artifacts exist)

---

### User Account

**Description**: Authentication entity for GitLab access, can be local or federated via OIDC.

**Attributes**:
- `id`: Integer - User ID (auto-assigned)
- `username`: String - Unique username (e.g., `jdoe`)
- `email`: String - User email address
- `full_name`: String - Display name (e.g., `John Doe`)
- `auth_provider`: Enum - Authentication source (`local`, `oidc`, `ldap`)
- `external_uid`: String - OIDC/LDAP external identifier (nullable)
- `role`: Enum - Global role (`admin`, `developer`, `reporter`, `guest`)
- `state`: Enum - Account state (`active`, `blocked`, `deactivated`)
- `created_at`: DateTime - Account creation timestamp
- `last_sign_in_at`: DateTime - Last authentication timestamp (nullable)

**Relationships**:
- Owns: Projects
- Member of: Groups
- Triggers: Pipelines
- Authenticates via: Keycloak (if OIDC) OR LDAP (if ldap)

**State Transitions**:
```
[Provisioned] → [Active] → [Blocked]
                    ↓           ↓
              [Deactivated] ← [Active]
```

**Validation Rules**:
- `username` must be unique
- `email` must be valid email format and unique
- `auth_provider` must be one of: `local`, `oidc`, `ldap`
- If `auth_provider == "oidc" OR "ldap"`, `external_uid` must not be null
- `role` must be one of: `admin`, `developer`, `reporter`, `guest`
- `state` must be one of: `active`, `blocked`, `deactivated`

---

### Container Registry

**Description**: Storage for Docker images built and published by CI/CD pipelines.

**Attributes**:
- `project_id`: Integer - Associated project ID
- `enabled`: Boolean - Registry feature flag for project
- `hostname`: String - Registry URL (e.g., `registry.example.com`)
- `total_size_mb`: Integer - Total storage used by images
- `image_count`: Integer - Number of images in registry
- `cleanup_policy`: Object - Garbage collection configuration
  - `enabled`: Boolean
  - `keep_n`: Integer - Number of tags to retain
  - `older_than`: String - Age threshold (e.g., `30d`)

**Relationships**:
- Belongs to: Project
- Stores: Docker Images
- Accessed by: GitLab Runners (for push/pull operations)

**State Transitions**:
```
[Disabled] → [Enabled] → [Active]
                ↓
           [Cleanup Running] → [Active]
```

**Validation Rules**:
- `hostname` must be a valid FQDN
- `total_size_mb` must be ≥ 0
- `image_count` must be ≥ 0
- If `cleanup_policy.enabled == true`, `keep_n` must be ≥ 1
- `older_than` must match format: `\d+[dhm]` (e.g., `30d`, `12h`)

---

### Registration Token

**Description**: Credential used to register GitLab Runners with GitLab instances or GitLab.com projects.

**Attributes**:
- `token`: Encrypted String - Authentication token (Ansible Vault)
- `type`: Enum - Token scope (`instance`, `group`, `project`)
- `gitlab_url`: String - Target GitLab URL (e.g., `https://gitlab.example.com` or `https://gitlab.com`)
- `description`: String - Human-readable token description
- `created_at`: DateTime - Token creation timestamp
- `expires_at`: DateTime - Token expiration timestamp (nullable)
- `active`: Boolean - Token validity status

**Relationships**:
- Used by: GitLab Runners (for registration)
- Scoped to: GitLab Instance OR Project OR Group

**State Transitions**:
```
[Created] → [Active] → [Expired]
               ↓
           [Revoked]
```

**Validation Rules**:
- `token` must be encrypted with Ansible Vault
- `type` must be one of: `instance`, `group`, `project`
- `gitlab_url` must be a valid HTTPS URL
- `expires_at` must be after `created_at` (if set)
- `active` must be `false` if `expires_at` is in the past

---

## Configuration Entities

### Ansible Variables

**Description**: Configuration parameters for GitLab and Runner Ansible roles, stored in `defaults/main.yml` and group_vars.

**GitLab Role Variables**:
```yaml
# LXC Container Configuration
gitlab_lxc_vmid: 200
gitlab_lxc_hostname: "gitlab"
gitlab_lxc_cores: 4
gitlab_lxc_memory_mb: 8192
gitlab_lxc_disk_size_gb: 50
gitlab_lxc_template: "debian-12-standard"

# GitLab Application Configuration
gitlab_version: "16.11"  # Major.minor version pin
gitlab_external_url: "https://gitlab.example.com"
gitlab_ssh_port: 2222
gitlab_root_password: "{{ vault_gitlab_root_password }}"

# Feature Flags
gitlab_registry_enabled: true
gitlab_oidc_enabled: true
gitlab_backup_enabled: true

# OIDC Configuration
gitlab_oidc_issuer: "https://keycloak.example.com/realms/main"
gitlab_oidc_client_id: "gitlab"
gitlab_oidc_client_secret: "{{ vault_gitlab_oidc_secret }}"

# Storage Configuration
gitlab_data_zfs_dataset: "rpool/gitlab-data"
gitlab_registry_zfs_dataset: "rpool/gitlab-registry"

# Backup Configuration
gitlab_backup_schedule: "0 2 * * *"  # 2 AM daily
gitlab_backup_keep_time: 604800  # 7 days in seconds
```

**GitLab Runner Role Variables**:
```yaml
# LXC Container Configuration
gitlab_runner_lxc_vmid_start: 201  # Auto-increment for multiple runners
gitlab_runner_lxc_hostname_prefix: "runner"
gitlab_runner_lxc_cores: 2
gitlab_runner_lxc_memory_mb: 4096
gitlab_runner_lxc_disk_size_gb: 20
gitlab_runner_lxc_template: "debian-12-standard"

# Runner Configuration
gitlab_runner_count: 2  # Number of runners to deploy
gitlab_runner_executor: "docker"  # or "shell"
gitlab_runner_concurrent_jobs: 3
gitlab_runner_max_job_timeout: "1h"

# Registration Configuration
gitlab_runner_registration_url: "https://gitlab.example.com"
gitlab_runner_registration_token: "{{ vault_gitlab_runner_token }}"
gitlab_runner_tags: ["docker", "self-hosted", "on-premise"]

# GitLab.com Registration (optional)
gitlab_runner_gitlab_com_enabled: false
gitlab_runner_gitlab_com_token: "{{ vault_gitlab_com_runner_token }}"
gitlab_runner_gitlab_com_tags: ["self-hosted", "gitlab-com"]

# Docker Executor Configuration
gitlab_runner_docker_privileged: true  # Required for Docker-in-Docker
gitlab_runner_docker_volumes: ["/cache"]
```

---

## Entity Relationship Diagram

```
┌─────────────────┐         ┌──────────────────┐
│ Keycloak (OIDC) │────────>│ GitLab Instance  │
└─────────────────┘         └──────────────────┘
                                     │
                                     │ has many
                                     ↓
                            ┌──────────────────┐
                            │  User Account    │
                            └──────────────────┘
                                     │
                                     │ owns
                                     ↓
                            ┌──────────────────┐
                            │    Project       │
                            └──────────────────┘
                                     │
                                     │ has many
                                     ↓
                            ┌──────────────────┐
                            │    Pipeline      │
                            └──────────────────┘
                                     │
                                     │ has many
                                     ↓
                            ┌──────────────────┐         ┌──────────────────┐
                            │      Job         │────────>│ GitLab Runner    │
                            └──────────────────┘ exec by └──────────────────┘
                                     │                            │
                                     │ produces                   │ uses
                                     ↓                            ↓
                            ┌──────────────────┐         ┌──────────────────┐
                            │    Artifacts     │         │ Registration     │
                            └──────────────────┘         │      Token       │
                                                          └──────────────────┘
┌─────────────────┐         ┌──────────────────┐
│ Traefik Proxy   │────────>│ GitLab Instance  │
└─────────────────┘  routes └──────────────────┘
                                     │
                                     │ stores data
                                     ↓
                            ┌──────────────────┐
                            │   PostgreSQL     │
                            │     Redis        │
                            │   ZFS Storage    │
                            └──────────────────┘

┌─────────────────┐         ┌──────────────────┐
│  NetBox (CMDB)  │<────────│ GitLab Instance  │
└─────────────────┘ registers└──────────────────┘
         ↑
         │ registers
         │
┌──────────────────┐
│ GitLab Runner    │
└──────────────────┘
```

---

## Data Storage Locations

### GitLab Instance
- **Repositories**: `/var/opt/gitlab/git-data/repositories` (ZFS bind mount)
- **Uploads**: `/var/opt/gitlab/gitlab-rails/uploads` (ZFS bind mount)
- **Container Registry**: `/var/opt/gitlab/gitlab-rails/shared/registry` (ZFS bind mount)
- **Backups**: `/var/opt/gitlab/backups` (ZFS bind mount)
- **PostgreSQL Data**: `/var/opt/gitlab/postgresql/data`
- **Redis Data**: `/var/opt/gitlab/redis`
- **Configuration**: `/etc/gitlab/gitlab.rb`
- **Logs**: `/var/log/gitlab`

### GitLab Runner
- **Configuration**: `/etc/gitlab-runner/config.toml`
- **Cache**: `/var/lib/gitlab-runner/cache`
- **Docker Volumes**: `/var/lib/docker/volumes` (if Docker executor)
- **Logs**: `/var/log/gitlab-runner`

### Ansible Vault Secrets
- **GitLab Root Password**: `group_vars/all/secrets.yml:vault_gitlab_root_password`
- **OIDC Client Secret**: `group_vars/all/secrets.yml:vault_gitlab_oidc_secret`
- **Runner Token (Self-hosted)**: `group_vars/all/secrets.yml:vault_gitlab_runner_token`
- **Runner Token (GitLab.com)**: `group_vars/all/secrets.yml:vault_gitlab_com_runner_token`

---

## Data Lifecycle

### GitLab Instance Lifecycle
1. **Provisioning**: LXC container created, GitLab package installed
2. **Configuration**: `gitlab.rb` templated, OIDC configured, Traefik labels applied
3. **Initialization**: `gitlab-ctl reconfigure` runs, PostgreSQL migrations applied
4. **Operation**: Users authenticate, projects created, pipelines executed
5. **Backup**: Daily backups to ZFS dataset, PBS snapshots
6. **Maintenance**: Security updates applied, configuration changes re-applied
7. **Decommission**: Backup verification, container stopped, ZFS datasets preserved

### Pipeline Data Lifecycle
1. **Creation**: Commit pushed, pipeline triggered
2. **Execution**: Jobs scheduled to runners, logs streamed
3. **Completion**: Artifacts stored, notifications sent
4. **Retention**: Artifacts expire per policy (default: 30 days)
5. **Cleanup**: Expired artifacts deleted, logs archived

### Container Registry Lifecycle
1. **Image Push**: CI/CD job builds and pushes Docker image
2. **Storage**: Image layers stored in registry filesystem
3. **Pull**: Deployment jobs pull images for container deployment
4. **Garbage Collection**: Cleanup policy deletes old tags (configurable)
5. **Archival**: Long-term images tagged and exempt from cleanup

---

**Status**: ✅ Data Model Complete - Ready for Contract Generation
