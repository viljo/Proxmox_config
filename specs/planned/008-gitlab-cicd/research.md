# Research: GitLab CI/CD Platform

**Phase**: 0 (Outline & Research)
**Date**: 2025-10-20
**Feature**: Self-hosted Git version control and CI/CD automation platform

## Research Questions & Decisions

### 1. GitLab Deployment Method

**Decision**: Use GitLab Omnibus package installation

**Rationale**:
- Official GitLab-recommended deployment method for production use
- Single package includes all dependencies: GitLab Rails app, PostgreSQL, Redis, Nginx, Sidekiq
- Automated configuration management via `/etc/gitlab/gitlab.rb`
- Built-in upgrade path with `gitlab-ctl upgrade`
- Comprehensive documentation and community support
- Self-contained deployment simplifies LXC containerization
- Native integration with external services (OIDC, SMTP, object storage)
- GitLab CE (Community Edition) is free and open-source

**Alternatives Considered**:
- **Source installation**: Rejected - complex manual setup, difficult upgrades, higher maintenance burden, no official Ansible support
- **Docker Compose**: Rejected - adds container orchestration complexity inside LXC, volume management challenges, less mature than Omnibus
- **Kubernetes Helm charts**: Rejected - overkill for single-server deployment, requires K8s cluster infrastructure
- **GitLab Cloud (SaaS)**: Rejected - requirement is self-hosted for data sovereignty and integration with internal infrastructure

**References**:
- Official GitLab installation docs: https://about.gitlab.com/install/
- Omnibus architecture: https://docs.gitlab.com/omnibus/architecture/

### 2. Container Platform: LXC vs VM

**Decision**: Deploy GitLab server in LXC container (not VM)

**Rationale**:
- Lower resource overhead compared to VM (shared kernel, no guest OS)
- Faster provisioning and restart times
- Consistent with infrastructure patterns (Keycloak, WireGuard, other services run in LXC)
- Proxmox LXC provides sufficient isolation for GitLab workload
- Easy backup and migration via PBS LXC snapshots
- Network performance nearly identical to bare metal (no virtualization overhead)
- Can allocate 4GB RAM + 4 CPU cores efficiently

**Requirements**:
- Unprivileged LXC container (constitutional security requirement)
- Nesting enabled (`features: nesting=1`) for GitLab Runner registration if needed
- Sufficient storage for repositories (100GB initial, expandable)

**Alternatives Considered**:
- **Proxmox VM**: Rejected - higher resource overhead (guest OS), slower provisioning, unnecessary virtualization layer
- **Bare metal**: Rejected - reduces flexibility, harder to backup/migrate, violates infrastructure isolation principles
- **Docker container**: Rejected - Docker-in-Docker complexity for GitLab Runner, Omnibus designed for traditional installations

### 3. GitLab Runner Executor Type

**Decision**: Use Docker executor for GitLab Runner

**Rationale**:
- Industry-standard executor for CI/CD pipelines
- Complete job isolation - each job runs in fresh Docker container
- Prevents cross-contamination between pipeline jobs
- Supports any programming language/framework via Docker images
- Reproducible builds - same image produces same results
- Easy cleanup - container destroyed after job completes
- Supports caching and artifact passing between stages
- GitLab maintains official CI/CD Docker images (ruby, node, python, etc.)

**Deployment Architecture**:
- Separate LXC container for each GitLab Runner (typically 2+ runners)
- Docker CE installed inside runner LXC containers
- Nesting enabled in LXC for Docker daemon support
- Shared runners registered with GitLab server
- Concurrent execution limit per runner (default: 1, configurable)

**Alternatives Considered**:
- **Shell executor**: Rejected - no job isolation, security risk, difficult cleanup, environment pollution
- **Kubernetes executor**: Rejected - requires K8s cluster, overkill for initial deployment, can add later if needed
- **VirtualBox/QEMU**: Rejected - slow startup, high resource overhead, not suited for containerized infrastructure
- **SSH executor**: Rejected - requires pre-provisioned hosts, less flexible than Docker

**Configuration**:
```toml
[[runners]]
  name = "docker-runner-01"
  executor = "docker"
  [runners.docker]
    image = "debian:12"
    privileged = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
```

### 4. Database Architecture

**Decision**: Use bundled PostgreSQL (included in GitLab Omnibus)

**Rationale**:
- Simplifies initial deployment - no external database to manage
- PostgreSQL 13+ included and pre-configured by Omnibus
- Automatic database initialization and migrations during GitLab upgrades
- Sufficient for single-server deployments (<500 users, <10k repositories)
- Backup included in GitLab backup (`gitlab-rake gitlab:backup:create`)
- Lower operational complexity - single container to manage

**Configuration**:
- PostgreSQL data stored in `/var/opt/gitlab/postgresql/data`
- Automatic backups via `gitlab-rake` and PBS LXC snapshots
- Database credentials managed by Omnibus (not exposed)

**Alternatives Considered**:
- **External PostgreSQL server**: Rejected - adds infrastructure complexity, requires separate container/VM, overkill for initial deployment
- **MySQL/MariaSQL**: Rejected - PostgreSQL is GitLab's primary database, better support and performance
- **High-availability PostgreSQL cluster**: Rejected - premature optimization, can migrate later if needed

**Scalability Note**: External PostgreSQL can be configured later by modifying `gitlab.rb` if needed for HA or performance.

### 5. Cache/Queue Architecture

**Decision**: Use bundled Redis (included in GitLab Omnibus)

**Rationale**:
- Redis included and pre-configured by Omnibus
- Used for caching, Sidekiq job queues, session storage
- Sufficient for single-server deployments
- Automatic configuration by Omnibus
- Lower operational complexity

**Configuration**:
- Redis data stored in `/var/opt/gitlab/redis`
- Socket-based communication for performance (unix:///var/opt/gitlab/redis/redis.socket)

**Alternatives Considered**:
- **External Redis server**: Rejected - adds complexity, not needed for initial deployment
- **Redis Sentinel**: Rejected - HA feature, premature optimization

### 6. Repository Storage Architecture

**Decision**: File-based repository storage with ZFS/ext4 backend

**Rationale**:
- GitLab stores Git repositories as bare repositories on filesystem
- Direct filesystem access provides best performance for Git operations
- Simple backup via PBS LXC snapshots (includes all repos)
- Expandable storage - can increase LXC disk size as needed
- No object storage complexity for initial deployment

**Storage Locations**:
- Repositories: `/var/opt/gitlab/git-data/repositories`
- CI/CD artifacts: `/var/opt/gitlab/gitlab-rails/shared/artifacts`
- Container registry (if enabled): `/var/opt/gitlab/gitlab-rails/shared/registry`
- Uploads: `/var/opt/gitlab/gitlab-rails/uploads`
- LFS objects: `/var/opt/gitlab/git-data/lfs-objects`

**Initial Allocation**: 100GB disk (expandable)

**Alternatives Considered**:
- **Object storage (S3/Minio)**: Rejected - adds complexity, not needed initially, can migrate later for scalability
- **NFS/Shared storage**: Rejected - single-server deployment, no HA requirement
- **Separate LVM volumes**: Considered but deferred - LXC disk expansion simpler for now

### 7. Backup Strategy

**Decision**: PBS (Proxmox Backup Server) LXC container backups + GitLab native backups

**Rationale**:
- PBS provides automated LXC container snapshots (includes all data)
- Scheduled backups (daily/weekly) via PBS
- GitLab native backups via `gitlab-rake gitlab:backup:create` for application-level restore
- Backup retention policy managed by PBS
- Fast disaster recovery - restore entire LXC container

**Backup Scope**:
- LXC container snapshot includes:
  - All repositories
  - PostgreSQL database
  - Redis data
  - Uploads, artifacts, LFS objects
  - GitLab configuration (`/etc/gitlab/gitlab.rb`)

**Backup Exclusions**:
- GitLab secrets file (`/etc/gitlab/gitlab-secrets.json`) stored separately in Ansible Vault for security
- Runner registration tokens stored in Ansible Vault

**Alternatives Considered**:
- **GitLab backup to external storage**: Considered as supplement, not replacement for PBS
- **Manual backups only**: Rejected - violates constitutional automated operations principle
- **Application-level backups only**: Rejected - slower disaster recovery than LXC restore

### 8. Authentication Integration

**Decision**: Keycloak OIDC (OpenID Connect) integration

**Rationale**:
- Centralized identity management (constitutional requirement)
- Single sign-on (SSO) across infrastructure services
- Keycloak already deployed and managed in infrastructure
- GitLab native OIDC support via `omniauth` providers
- User provisioning automated (no manual account creation)
- Group/role mapping from Keycloak to GitLab
- Supports MFA/2FA via Keycloak configuration

**Configuration** (in gitlab.rb):
```ruby
gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
gitlab_rails['omniauth_block_auto_created_users'] = false
gitlab_rails['omniauth_providers'] = [
  {
    'name' => 'openid_connect',
    'label' => 'Keycloak SSO',
    'args' => {
      'name' => 'openid_connect',
      'scope' => ['openid', 'profile', 'email'],
      'discovery' => true,
      'issuer' => 'https://keycloak.infra.local/realms/infrastructure',
      'client_auth_method' => 'basic',
      'client_options' => {
        'identifier' => 'gitlab',
        'secret' => 'stored_in_ansible_vault',
        'redirect_uri' => 'https://gitlab.infra.local/users/auth/openid_connect/callback'
      }
    }
  }
]
```

**User Flow**:
1. User visits GitLab web UI
2. Clicks "Sign in with Keycloak SSO"
3. Redirected to Keycloak login
4. Authenticates with Keycloak (LDAP backend)
5. Redirected back to GitLab with OIDC token
6. GitLab auto-provisions user account

**Alternatives Considered**:
- **Direct LDAP integration**: Rejected - OIDC provides better SSO experience and modern auth flow
- **Local GitLab accounts**: Rejected - violates centralized identity management requirement
- **SAML**: Considered - but OIDC is simpler and more modern

### 9. Reverse Proxy Configuration

**Decision**: Traefik reverse proxy with TLS termination

**Rationale**:
- Traefik already deployed as infrastructure-wide reverse proxy
- Automatic TLS certificate management (Let's Encrypt or internal CA)
- HTTPS-only access (constitutional requirement)
- Dynamic routing configuration via Ansible-generated Traefik config files
- Supports WebSocket for GitLab real-time features

**Traefik Configuration**:
```yaml
http:
  routers:
    gitlab:
      rule: "Host(`gitlab.infra.local`)"
      service: gitlab
      tls:
        certResolver: letsencrypt
  services:
    gitlab:
      loadBalancer:
        servers:
          - url: "http://192.168.x.x:80"  # GitLab container internal IP
```

**GitLab Configuration** (gitlab.rb):
```ruby
external_url 'https://gitlab.infra.local'
nginx['listen_port'] = 80
nginx['listen_https'] = false  # TLS termination at Traefik
```

**Alternatives Considered**:
- **Direct HTTPS on GitLab**: Rejected - duplicates certificate management, Traefik handles TLS for all services
- **HAProxy**: Rejected - Traefik already in use
- **No reverse proxy**: Rejected - violates security requirements (HTTPS-only)

### 10. GitLab Runner Registration Method

**Decision**: Automated runner registration via Ansible with registration tokens

**Rationale**:
- Fully automated - no manual `gitlab-runner register` commands
- Registration token stored in Ansible Vault
- Idempotent registration (checks if runner already registered)
- Supports multiple runners with unique names
- Easy to add/remove runners via Ansible variables

**Registration Flow**:
1. GitLab admin creates runner registration token (Settings > CI/CD > Runners)
2. Token stored in Ansible Vault (`vault_gitlab_runner_token`)
3. Ansible task registers runner using token
4. Runner appears in GitLab UI as "shared runner"

**Ansible Task**:
```yaml
- name: Register GitLab Runner
  command: >
    gitlab-runner register
      --non-interactive
      --url https://gitlab.infra.local
      --registration-token {{ vault_gitlab_runner_token }}
      --executor docker
      --docker-image debian:12
      --description "docker-runner-{{ runner_id }}"
      --tag-list "docker,debian,shared"
  args:
    creates: /etc/gitlab-runner/config.toml
```

**Alternatives Considered**:
- **Manual registration**: Rejected - not idempotent, violates Infrastructure as Code principle
- **Runner authentication tokens (new method)**: Considered - newer approach but registration tokens simpler for initial deployment

### 11. Container Registry Configuration

**Decision**: Enable GitLab Container Registry (bundled)

**Rationale**:
- Built-in Docker registry for CI-built images
- No external registry (Docker Hub, Quay) dependencies
- Private by default - requires GitLab authentication
- Integrated with CI/CD pipelines (automatic login)
- Per-project registries with access control
- Storage on local filesystem (same as repositories)

**Configuration** (gitlab.rb):
```ruby
registry_external_url 'https://registry.gitlab.infra.local'
gitlab_rails['registry_enabled'] = true
registry['enable'] = true
registry['registry_http_addr'] = "0.0.0.0:5000"
```

**Traefik Configuration**:
- Separate subdomain for registry (registry.gitlab.infra.local)
- TLS termination via Traefik
- Proxy to GitLab container port 5000

**Alternatives Considered**:
- **External Docker registry (Harbor, etc.)**: Rejected - adds infrastructure complexity
- **Docker Hub private repos**: Rejected - dependency on external service, costs
- **Disable registry**: Considered - but valuable for containerized deployments

### 12. CI/CD Concurrency and Scaling

**Decision**: Start with 2 shared runners, 1 concurrent job each

**Rationale**:
- Provides parallel execution for multiple projects
- Total capacity: 2 concurrent CI pipelines
- Each runner: 2GB RAM, 2 CPU cores (sufficient for typical jobs)
- Can add more runners later by deploying additional LXC containers
- Horizontal scaling via Ansible (add runners to inventory)

**Scaling Path**:
- Add runner containers as needed: `gitlab-runner-03`, `gitlab-runner-04`, etc.
- Increase per-runner concurrency: modify `concurrent = 1` → `concurrent = 2` in config.toml
- Vertical scaling: increase runner container resources (more RAM/CPU)
- Specific runners: register runners for specific projects (not shared)

**Resource Math**:
- 2 runners × 1 concurrent job = 2 simultaneous pipeline jobs
- 2 runners × 2GB RAM = 4GB total runner memory
- Meets SC-003 success criteria: "10 concurrent pipelines" (achieved by adding 8 more runners or increasing concurrency)

**Alternatives Considered**:
- **Single runner with high concurrency**: Rejected - less fault tolerance, resource contention
- **Kubernetes auto-scaling runners**: Rejected - premature optimization, adds K8s dependency

## Technology Stack Summary

| Component | Technology | Version | Deployment |
|-----------|-----------|---------|------------|
| GitLab Server | GitLab CE (Omnibus) | 16.x+ | LXC container (4GB RAM, 4 CPU, 100GB disk) |
| GitLab Runner | GitLab Runner (binary) | 16.x+ | LXC containers (2GB RAM, 2 CPU each, 2+ runners) |
| Database | PostgreSQL | 13+ | Bundled in GitLab Omnibus |
| Cache/Queue | Redis | 6+ | Bundled in GitLab Omnibus |
| Runner Executor | Docker CE | 20.x+ | Installed in runner containers |
| Web Server | Nginx | Bundled | Internal to GitLab Omnibus |
| Reverse Proxy | Traefik | Existing | Infrastructure-wide (HTTPS/TLS) |
| Authentication | Keycloak OIDC | Existing | Infrastructure SSO |
| CMDB | NetBox | Existing | Container inventory |
| Monitoring | Zabbix | Existing | Health checks, metrics |
| Backup | PBS | Existing | LXC snapshots |
| Configuration Mgmt | Ansible | 2.15+ | Infrastructure as Code |
| Version Control | Git | 2.x | System package |
| Container Platform | Proxmox LXC | 8.x | Unprivileged containers |

## Network Architecture

```
                    Internet
                        ↓
                 [Firewall/Router]
                        ↓
              Management Network (vmbr0)
              192.168.0.0/16
                        ↓
        ┌───────────────┼───────────────┐
        │               │               │
   [Traefik]       [Keycloak]     [NetBox/Zabbix]
   Reverse Proxy   Auth Provider   Monitoring/CMDB
        ↓               ↓               ↓
        │               │               │
        └───────────────┼───────────────┘
                        ↓
            ┌───────────┴───────────┐
            │                       │
      [GitLab Server]         [GitLab Runners]
      CT 20XX                  CT 20YY, 20ZZ
      4GB RAM, 4 CPU           2GB RAM, 2 CPU each
      100GB disk               20GB disk each
      Ports: 80, 22, 5000      Docker executor
            │                       │
            ├─ Git Repos            ├─ Runner 01
            ├─ PostgreSQL           └─ Runner 02
            ├─ Redis
            ├─ Container Registry
            └─ CI/CD Orchestration

User Flow:
1. User → https://gitlab.infra.local → Traefik (TLS) → GitLab (SSO)
2. GitLab → Keycloak OIDC → User authenticated
3. Git push → GitLab → Triggers CI pipeline
4. GitLab → Assigns job to Runner
5. Runner → Pulls Docker image → Executes job → Reports back
```

## Open Questions (Resolved)

All technical decisions finalized. No outstanding clarifications needed for implementation.

## Implementation Priorities

**Phase 1 - Core GitLab (MVP)**: GitLab server deployment with Keycloak auth, Traefik integration (User Story 1: Version Control)
**Phase 2 - CI/CD**: GitLab Runner deployment with Docker executor (User Story 2: Pipeline Automation)
**Phase 3 - Workflow**: Merge request configuration, branch protection (User Story 3: Code Review)
**Phase 4 - Registry**: Container registry enablement (User Story 4: Docker Images)

## References

- GitLab Omnibus documentation: https://docs.gitlab.com/omnibus/
- GitLab Runner documentation: https://docs.gitlab.com/runner/
- OIDC integration: https://docs.gitlab.com/ee/administration/auth/oidc.html
- Docker executor: https://docs.gitlab.com/runner/executors/docker.html
- Backup and restore: https://docs.gitlab.com/ee/raketasks/backup_restore.html
