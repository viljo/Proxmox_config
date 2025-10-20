# Data Model: GitLab CI/CD Platform

**Phase**: 1 (Design & Contracts)
**Date**: 2025-10-20
**Feature**: Self-hosted Git version control and CI/CD automation platform

## Entity Definitions

### 1. GitLab Server Container (LXC)

**Purpose**: LXC container hosting GitLab Omnibus installation with all services

**Attributes**:
- `container_id` (integer): Proxmox CT ID (e.g., 53)
- `hostname` (string): Container hostname (default: "gitlab")
- `domain` (string): DNS domain (default: "infra.local")
- `fqdn` (string): Full qualified domain name (e.g., "gitlab.infra.local")
- `ip_address` (IPv4): Static IP on management network
- `bridge` (string): Network bridge interface (default: "vmbr0")
- `memory_mb` (integer): RAM allocation in MB (default: 4096)
- `cpu_cores` (integer): CPU core count (default: 4)
- `disk_gb` (integer): Root disk size in GB (default: 100)
- `swap_mb` (integer): Swap allocation in MB (default: 1024)
- `storage_pool` (string): Proxmox storage backend (default: "local-lvm")
- `unprivileged` (boolean): Unprivileged container flag (true, immutable)
- `nesting` (boolean): Container nesting support (true, for Docker support)
- `onboot` (boolean): Auto-start on host boot (true)

**State Transitions**:
```
[Created] → [Stopped] → [Running] → [Stopped] → [Destroyed]
                ↓            ↑
                └────────────┘
                  (restart)
```

**Validation Rules**:
- `container_id` must be unique across Proxmox cluster
- `memory_mb` >= 4096 (GitLab minimum)
- `cpu_cores` >= 2 (minimum 4 recommended)
- `disk_gb` >= 50 (100GB recommended for repositories)
- `unprivileged` must be true (constitutional requirement)
- `nesting` must be true (for GitLab Runner registration if needed)

**Relationships**:
- Deployed on: Proxmox Host
- Registered in: NetBox (CMDB)
- Monitored by: Zabbix
- Backed up by: PBS (Proxmox Backup Server)
- Proxied by: Traefik (reverse proxy)
- Authenticated via: Keycloak (OIDC)

---

### 2. GitLab Application

**Purpose**: Omnibus installation of GitLab CE providing Git hosting, CI/CD, web UI, API

**Attributes**:
- `external_url` (URL): Public-facing URL (e.g., "https://gitlab.infra.local")
- `version` (semver): GitLab version (e.g., "16.8.1")
- `edition` (enum): GitLab edition (CE = Community Edition)
- `root_password` (string): Initial root password (stored in Ansible Vault)
- `database_adapter` (string): Database type (postgresql)
- `redis_socket` (path): Redis connection socket
- `ssh_port` (integer): Git SSH port (default: 22)
- `http_port` (integer): Internal HTTP port (default: 80)
- `registry_port` (integer): Container registry port (default: 5000)
- `storage_path` (path): Repository storage location (/var/opt/gitlab)

**Service Components**:
- `gitaly`: Git RPC service
- `gitlab-workhorse`: Smart HTTP gateway
- `gitlab-rails`: Ruby on Rails application
- `sidekiq`: Background job processor
- `nginx`: Internal web server
- `postgresql`: Database server
- `redis`: Cache and queue server

**Configuration File**: `/etc/gitlab/gitlab.rb`

**Validation Rules**:
- `external_url` must be HTTPS (unless internal-only)
- `version` must match runner version for compatibility
- `root_password` minimum 8 characters
- `ssh_port` must not conflict with host SSH

**Relationships**:
- Hosts: Projects (repositories)
- Manages: Users (authenticated via Keycloak)
- Orchestrates: CI/CD Pipelines
- Provides: Container Registry
- Exposes: REST API

---

### 3. GitLab Runner Container (LXC)

**Purpose**: LXC container hosting GitLab Runner agent for CI/CD job execution

**Attributes**:
- `container_id` (integer): Proxmox CT ID (e.g., 54, 55)
- `hostname` (string): Container hostname (e.g., "gitlab-runner-01")
- `runner_name` (string): Human-readable name (e.g., "docker-runner-01")
- `ip_address` (IPv4): Static IP on management network
- `memory_mb` (integer): RAM allocation (default: 2048)
- `cpu_cores` (integer): CPU core count (default: 2)
- `disk_gb` (integer): Root disk size (default: 20)
- `executor_type` (enum): Executor type (docker, shell, kubernetes)
- `concurrent_jobs` (integer): Max concurrent jobs (default: 1)
- `registration_token` (string): Token for registering with GitLab (Ansible Vault)
- `runner_token` (string): Authentication token after registration

**State Transitions**:
```
[Created] → [Stopped] → [Running] → [Idle] → [Executing Job] → [Idle]
                ↓            ↑
                └────────────┘
```

**Validation Rules**:
- `memory_mb` >= 1024 (minimum for Docker executor)
- `executor_type` must be "docker" (per design decision)
- `concurrent_jobs` >= 1
- `registration_token` must be valid GitLab token

**Relationships**:
- Registered with: GitLab Server
- Executes: Pipeline Jobs
- Uses: Docker (for executor)
- Registered in: NetBox
- Monitored by: Zabbix

---

### 4. Git Repository

**Purpose**: Version-controlled code storage with branches, tags, commits, history

**Attributes**:
- `project_id` (integer): Unique project identifier
- `project_name` (string): Human-readable name (e.g., "myapp")
- `namespace` (string): Group or user namespace (e.g., "devops/myapp")
- `repository_path` (path): Filesystem location (/var/opt/gitlab/git-data/repositories)
- `size_bytes` (integer): Repository size in bytes
- `default_branch` (string): Default branch name (e.g., "main", "master")
- `visibility` (enum): Access level (private, internal, public)
- `ssh_url` (string): SSH clone URL (e.g., "git@gitlab.infra.local:devops/myapp.git")
- `https_url` (string): HTTPS clone URL (e.g., "https://gitlab.infra.local/devops/myapp.git")
- `created_at` (timestamp): Repository creation time
- `last_activity_at` (timestamp): Last commit or push time

**Git Objects**:
- Commits: SHA-1 hashes with author, message, timestamp
- Branches: Named pointers to commits
- Tags: Named releases or milestones
- Tree: Directory structure
- Blob: File contents

**Validation Rules**:
- `project_name` must be URL-safe (alphanumeric, hyphens, underscores)
- `namespace` must follow GitLab group/user structure
- `default_branch` must exist in repository
- `visibility` controls who can clone/view

**Relationships**:
- Belongs to: Project
- Contains: Commits, Branches, Tags
- Triggers: CI/CD Pipelines (on push)
- Source of: Merge Requests

---

### 5. Project

**Purpose**: GitLab entity containing repository, pipelines, settings, access control

**Attributes**:
- `project_id` (integer): Unique identifier
- `project_name` (string): Display name
- `description` (text): Project description
- `namespace_id` (integer): Group or user namespace
- `visibility_level` (integer): 0=private, 10=internal, 20=public
- `creator_id` (integer): User who created project
- `created_at` (timestamp): Creation time
- `issues_enabled` (boolean): Issue tracker enabled
- `merge_requests_enabled` (boolean): MR feature enabled
- `wiki_enabled` (boolean): Wiki feature enabled
- `snippets_enabled` (boolean): Code snippets enabled
- `container_registry_enabled` (boolean): Docker registry enabled
- `ci_cd_enabled` (boolean): CI/CD pipelines enabled

**Settings**:
- `default_branch_protection` (enum): none, partial, full
- `ci_config_path` (string): Path to .gitlab-ci.yml
- `build_timeout` (integer): Max pipeline duration (seconds)
- `auto_cancel_pending_pipelines` (enum): disabled, enabled
- `shared_runners_enabled` (boolean): Allow shared runners

**Validation Rules**:
- `project_name` unique within namespace
- `visibility_level` respects namespace visibility
- `ci_config_path` default ".gitlab-ci.yml"

**Relationships**:
- Contains: Git Repository
- Owns: CI/CD Pipelines
- Has: Members (users with roles)
- Belongs to: Namespace (group or user)
- Stores: Build Artifacts
- Has: Container Registry

---

### 6. CI/CD Pipeline

**Purpose**: Automated workflow defined in .gitlab-ci.yml with stages, jobs, dependencies

**Attributes**:
- `pipeline_id` (integer): Unique pipeline identifier
- `project_id` (integer): Associated project
- `ref` (string): Git branch or tag (e.g., "main", "feature-x")
- `sha` (string): Git commit SHA triggering pipeline
- `status` (enum): created, waiting_for_resource, preparing, pending, running, success, failed, canceled, skipped
- `source` (enum): push, web, trigger, schedule, api, pipeline, merge_request_event
- `created_at` (timestamp): Pipeline creation time
- `started_at` (timestamp): Execution start time
- `finished_at` (timestamp): Completion time
- `duration` (integer): Total runtime in seconds
- `user_id` (integer): User who triggered pipeline

**Pipeline Structure** (from .gitlab-ci.yml):
- `stages`: Ordered list of stages (e.g., [build, test, deploy])
- `jobs`: Individual tasks within stages
- `variables`: Environment variables
- `cache`: Cached dependencies
- `artifacts`: Build outputs

**State Transitions**:
```
[Created] → [Pending] → [Running] → [Success]
                 ↓           ↓           ↓
                 └──────> [Failed] ──> [Canceled]
```

**Validation Rules**:
- `ref` must exist in repository
- `status` transitions follow DAG (directed acyclic graph)
- `duration` calculated from started_at to finished_at
- Pipeline fails if any required job fails

**Relationships**:
- Belongs to: Project
- Triggered by: Git Push, Merge Request, Schedule, API
- Contains: Pipeline Jobs
- Produces: Build Artifacts
- Reports to: User (via notification)

---

### 7. Pipeline Job

**Purpose**: Individual task executed by runner (build, test, deploy) with logs and artifacts

**Attributes**:
- `job_id` (integer): Unique job identifier
- `pipeline_id` (integer): Parent pipeline
- `stage` (string): Pipeline stage (e.g., "build", "test", "deploy")
- `job_name` (string): Job name from .gitlab-ci.yml (e.g., "compile", "unit-tests")
- `status` (enum): created, pending, running, success, failed, canceled, skipped, manual
- `runner_id` (integer): Runner executing job (null if pending)
- `created_at` (timestamp): Job creation time
- `started_at` (timestamp): Execution start time
- `finished_at` (timestamp): Completion time
- `duration` (integer): Runtime in seconds
- `retry_count` (integer): Number of retries
- `allow_failure` (boolean): Pipeline continues if job fails

**Job Configuration** (from .gitlab-ci.yml):
- `script`: Commands to execute
- `image`: Docker image for executor
- `before_script`: Setup commands
- `after_script`: Cleanup commands
- `variables`: Job-specific environment variables
- `cache`: Cached dependencies (paths)
- `artifacts`: Output files to preserve
- `dependencies`: Jobs this job depends on
- `only` / `except`: Branch/tag filters
- `tags`: Runner tag requirements

**State Transitions**:
```
[Created] → [Pending] → [Running] → [Success]
                 ↓           ↓
                 └──────> [Failed] → [Retrying]
                             ↓
                        [Canceled]
```

**Validation Rules**:
- `stage` must be defined in pipeline stages
- `runner_id` must be registered and available
- `script` cannot be empty
- `artifacts` expire after configured retention period

**Relationships**:
- Belongs to: Pipeline
- Executed by: GitLab Runner
- Produces: Build Artifacts, Logs
- Depends on: Other Jobs (in same pipeline)

---

### 8. Build Artifact

**Purpose**: Output files from pipeline jobs (binaries, packages, reports) for download or deployment

**Attributes**:
- `artifact_id` (integer): Unique identifier
- `job_id` (integer): Job that produced artifact
- `project_id` (integer): Associated project
- `file_type` (enum): archive, metadata, trace, junit, coverage, codequality
- `file_format` (enum): zip, gzip, raw
- `size_bytes` (integer): Artifact size
- `expire_at` (timestamp): Expiration time (null = never)
- `storage_path` (path): Filesystem location (/var/opt/gitlab/gitlab-rails/shared/artifacts)
- `download_url` (URL): Direct download link

**Artifact Types**:
- **Archive**: Compiled binaries, packages (zip/tar.gz)
- **Reports**: Test results (JUnit XML), coverage (Cobertura), code quality
- **Trace**: Job execution logs
- **Metadata**: Job environment variables, timestamps

**Validation Rules**:
- `expire_at` defaults to 30 days (configurable)
- `size_bytes` limited by disk space
- Artifacts deleted automatically after expiration

**Relationships**:
- Produced by: Pipeline Job
- Belongs to: Project
- Downloaded by: Users, Subsequent Jobs
- Stored in: Artifact Storage

---

### 9. Merge Request

**Purpose**: Code change proposal with diff, review comments, approvals, merge status

**Attributes**:
- `merge_request_id` (integer): Unique identifier (IID per project)
- `project_id` (integer): Target project
- `title` (string): MR title
- `description` (text): MR description (markdown)
- `author_id` (integer): User who created MR
- `source_branch` (string): Branch with changes
- `target_branch` (string): Branch to merge into (usually main)
- `source_project_id` (integer): Source project (for forks)
- `state` (enum): opened, closed, merged
- `merge_status` (enum): can_be_merged, cannot_be_merged, checking
- `work_in_progress` (boolean): Draft/WIP status
- `created_at` (timestamp): MR creation time
- `updated_at` (timestamp): Last update time
- `merged_at` (timestamp): Merge completion time
- `merged_by_id` (integer): User who merged

**Merge Request Features**:
- **Diff**: Line-by-line changes between branches
- **Comments**: Inline code comments and discussions
- **Approvals**: Required approvals before merge
- **Pipeline**: CI/CD pipeline for MR branch
- **Conflict Resolution**: Detect and resolve merge conflicts

**State Transitions**:
```
[Opened] → [Approved] → [Merged] → [Closed]
    ↓           ↓
    └────> [Closed without merge]
```

**Validation Rules**:
- `source_branch` must exist
- `target_branch` must exist
- `merge_status` = can_be_merged required to merge
- Pipeline must pass if "merge when pipeline succeeds" enabled

**Relationships**:
- Belongs to: Project
- Created by: User (author)
- Reviewed by: Users (reviewers)
- Approved by: Users (approvers)
- Triggers: CI/CD Pipeline
- Contains: Diff, Comments, Discussions

---

### 10. Container Image

**Purpose**: Docker image built in CI pipeline and stored in GitLab container registry

**Attributes**:
- `image_id` (integer): Unique identifier
- `project_id` (integer): Associated project
- `repository_path` (string): Registry path (e.g., "gitlab.infra.local/devops/myapp")
- `tag` (string): Image tag (e.g., "latest", "v1.2.3", commit SHA)
- `digest` (string): Image SHA256 digest
- `size_bytes` (integer): Compressed image size
- `layers` (array): List of layer SHAs
- `created_at` (timestamp): Image creation time
- `created_by_job_id` (integer): CI job that built image

**Registry Configuration**:
- **Registry URL**: https://registry.gitlab.infra.local
- **Authentication**: GitLab credentials (deploy tokens, personal access tokens)
- **Storage**: /var/opt/gitlab/gitlab-rails/shared/registry
- **Cleanup Policy**: Auto-delete old tags based on rules

**Validation Rules**:
- `tag` must be valid Docker tag format
- `digest` unique per image content
- Authentication required for push/pull

**Relationships**:
- Belongs to: Project
- Built by: CI/CD Pipeline Job
- Stored in: Container Registry
- Pulled by: External hosts (with authentication)

---

### 11. User Account

**Purpose**: Developer or admin with authentication, SSH keys, tokens, project permissions

**Attributes**:
- `user_id` (integer): Unique identifier
- `username` (string): Login username
- `email` (string): Email address
- `name` (string): Full name
- `state` (enum): active, blocked, ldap_blocked
- `external` (boolean): External user (via OIDC/LDAP)
- `admin` (boolean): Admin privileges
- `created_at` (timestamp): Account creation
- `last_sign_in_at` (timestamp): Last login time
- `confirmed_at` (timestamp): Email confirmation

**Authentication Methods**:
- **OIDC**: Keycloak SSO (primary method)
- **SSH Keys**: For Git operations
- **Personal Access Tokens**: For API/Git HTTPS
- **Deploy Tokens**: For registry and repository access

**Permissions** (role-based):
- **Guest**: Read-only access
- **Reporter**: Can view code, issues, MRs
- **Developer**: Can push code, create MRs
- **Maintainer**: Can merge, manage CI/CD
- **Owner**: Full project control

**Validation Rules**:
- `username` unique across GitLab
- `email` unique across GitLab
- `external` users managed by OIDC (no local password)

**Relationships**:
- Member of: Projects (with roles)
- Member of: Groups (with roles)
- Authenticated via: Keycloak (OIDC)
- Owns: SSH Keys, Access Tokens
- Creates: Commits, Merge Requests, Issues

---

## Data Relationships Diagram

```
┌──────────────────────────────────────────────┐
│   Proxmox Host (vmbr0)                       │
│                                              │
│  ┌─────────────────────────────────────┐    │
│  │ GitLab Server LXC (CT 53)         │    │
│  │                                      │    │      ┌─────────────────┐
│  │  ┌────────────────────────────────┐ │    │      │  Keycloak       │
│  │  │ GitLab Application             │◄┼────┼──────┤  (OIDC Auth)    │
│  │  │ - Omnibus (GitLab CE)          │ │    │      └─────────────────┘
│  │  │ - PostgreSQL (metadata)        │ │    │
│  │  │ - Redis (cache/queue)          │ │    │      ┌─────────────────┐
│  │  │ - Nginx (web server)           │ │    │      │  Traefik        │
│  │  │ - Container Registry           │ │    │◄─────┤  (Reverse Proxy)│
│  │  └─────┬──────────────────────────┘ │    │      └─────────────────┘
│  │        │                            │    │
│  │        │ Triggers                   │    │
│  │        ▼                            │    │
│  │  ┌────────────────────────────────┐ │    │
│  │  │ Projects                       │ │    │
│  │  │ ├─ Repository 1                │ │    │
│  │  │ ├─ Repository 2                │ │    │
│  │  │ └─ Repository N                │ │    │
│  │  └─────┬──────────────────────────┘ │    │
│  │        │ Contains                   │    │
│  │        ▼                            │    │
│  │  ┌────────────────────────────────┐ │    │
│  │  │ CI/CD Pipelines                │ │    │
│  │  │ ├─ Pipeline 1                  │ │    │
│  │  │ ├─ Pipeline 2                  │ │    │
│  │  │ └─ Pipeline N                  │ │    │
│  │  └─────┬──────────────────────────┘ │    │
│  │        │ Assigns                    │    │
│  └────────┼────────────────────────────┘    │
│           │                                 │
│           │ Job Execution                   │
│           ▼                                 │
│  ┌─────────────────────────────────────┐    │
│  │ GitLab Runners (CT 54, 55)      │    │
│  │  ┌───────────────────────────────┐  │    │
│  │  │ Runner 01                     │  │    │
│  │  │ - Docker Executor             │  │    │
│  │  │ - Executes Jobs               │  │    │
│  │  └───────────────────────────────┘  │    │
│  │  ┌───────────────────────────────┐  │    │
│  │  │ Runner 02                     │  │    │
│  │  │ - Docker Executor             │  │    │
│  │  │ - Executes Jobs               │  │    │
│  │  └───────────────────────────────┘  │    │
│  └─────────────────────────────────────┘    │
│                                              │
└──────────────────────────────────────────────┘
         │                   │
         ▼                   ▼
    ┌─────────┐        ┌─────────┐
    │ NetBox  │        │ Zabbix  │
    │ (CMDB)  │        │ (Monitor)│
    └─────────┘        └─────────┘

User Journey:
1. User → Keycloak OIDC → GitLab (authenticated)
2. User → git push → GitLab Repository
3. GitLab → Triggers CI/CD Pipeline
4. GitLab → Assigns Job to Available Runner
5. Runner → Pulls Docker Image → Executes Job in Container
6. Job → Produces Artifacts → Stored in GitLab
7. Job → Completes → Updates Pipeline Status
8. User → Views Results in GitLab UI
```

## Entity Lifecycle Management

### GitLab Server Deployment

1. Create LXC container on Proxmox host
2. Download Debian template if not cached
3. Start container and wait for boot
4. Install GitLab Omnibus package
5. Configure gitlab.rb (external_url, database, Redis, OIDC)
6. Run `gitlab-ctl reconfigure`
7. Set root password from Ansible Vault
8. Configure Traefik routing
9. Register in NetBox CMDB
10. Configure Zabbix monitoring
11. Add to PBS backup schedule

### GitLab Runner Deployment

1. Create LXC container for runner
2. Start container and wait for boot
3. Install Docker CE
4. Install GitLab Runner package
5. Register runner with GitLab server (using token)
6. Configure runner executor (Docker)
7. Start gitlab-runner service
8. Verify runner appears in GitLab UI
9. Register in NetBox
10. Configure Zabbix monitoring

### Project Creation Workflow

1. User logs in via Keycloak OIDC
2. User creates new project in GitLab UI
3. GitLab creates project record in database
4. GitLab initializes bare Git repository on filesystem
5. User clones repository locally (SSH or HTTPS)
6. User commits and pushes code
7. GitLab stores commits in repository
8. Project visible in GitLab UI

### CI/CD Pipeline Execution Workflow

1. User pushes code to repository
2. GitLab detects .gitlab-ci.yml in repository
3. GitLab creates pipeline record with jobs
4. Pipeline enters "pending" state
5. GitLab assigns job to available runner
6. Runner pulls Docker image for job
7. Runner executes job commands in container
8. Job logs streamed to GitLab in real-time
9. Job completes (success or failure)
10. Artifacts uploaded to GitLab
11. Pipeline status updated
12. User notified of pipeline result

### Merge Request Workflow

1. Developer creates feature branch
2. Developer commits changes to feature branch
3. Developer pushes feature branch to GitLab
4. Developer opens merge request in GitLab UI
5. GitLab creates MR record with diff
6. CI/CD pipeline triggers for MR branch
7. Reviewers receive notification
8. Reviewers add inline comments
9. Developer responds or updates code
10. Pipeline passes, approvals obtained
11. Maintainer merges MR
12. Feature branch merged to target branch
13. MR marked as merged and closed

## Constraints & Invariants

### Infrastructure Constraints

- LXC containers must remain unprivileged (security requirement)
- GitLab server requires minimum 4GB RAM (Omnibus requirement)
- Runners must have nesting enabled (for Docker executor)
- All containers on management network (vmbr0)
- HTTPS-only access via Traefik (no direct HTTP)

### Data Constraints

- Repository paths must be unique across GitLab
- SSH URLs formatted as `git@hostname:namespace/project.git`
- HTTPS URLs formatted as `https://hostname/namespace/project.git`
- Pipeline jobs cannot execute without available runner
- Artifacts auto-deleted after retention period expires

### Security Constraints

- All users authenticated via Keycloak OIDC (no local passwords)
- SSH keys required for Git SSH operations
- API tokens scoped per-user with expiration
- Container registry requires authentication for push/pull
- GitLab root password stored in Ansible Vault only

### Performance Constraints

- Maximum concurrent pipelines limited by runner count × concurrency
- Repository clone rate limited by network and disk I/O
- Large repositories (>1GB) may slow Git operations
- Docker image pulls impact job startup time

## Monitoring & Observability

### Metrics to Track (Zabbix)

**GitLab Server**:
- Application status (gitlab-ctl status)
- HTTP response time and status codes
- Database connection pool usage
- Redis memory usage
- Disk space utilization
- Repository count and total size

**GitLab Runners**:
- Runner registration status
- Active job count
- Docker daemon status
- Container creation rate
- Disk space for Docker images

**CI/CD Metrics**:
- Pipeline execution rate
- Pipeline success/failure ratio
- Average pipeline duration
- Job queue depth
- Artifact storage usage

### Health Checks

- GitLab: `/-/health` endpoint returns 200 OK
- GitLab: `/-/readiness` endpoint returns 200 OK
- Runner: `gitlab-runner verify` returns "alive"
- Database: PostgreSQL accepts connections
- Redis: PING responds with PONG

## Backup & Recovery

### Backup Scope (PBS)

- Entire LXC container snapshots (GitLab + runners)
- Includes all repositories, database, Redis, artifacts
- Scheduled daily backups with 7-day retention

### Application-Level Backup

- GitLab backup via `gitlab-rake gitlab:backup:create`
- Creates tarball in `/var/opt/gitlab/backups`
- Includes: database, repositories, uploads, artifacts, LFS
- Excludes: gitlab.rb config, secrets file (stored in Ansible Vault)

### Recovery Process

1. Restore LXC container from PBS snapshot
2. Start container
3. Verify GitLab services running
4. Test repository access
5. Test pipeline execution
6. If partial restore needed: use `gitlab-rake gitlab:backup:restore`
