# Research & Technical Decisions: GitLab CI/CD Platform

**Feature**: GitLab CI/CD Platform
**Branch**: `007-gitlab-ci-runner`
**Date**: 2025-10-20

## Overview

This document consolidates research findings and technical decisions for deploying GitLab CE and GitLab Runners in the Proxmox infrastructure. All "NEEDS CLARIFICATION" items from the Technical Context have been resolved through research.

---

## Decision 1: GitLab Version Selection

**Decision**: Use GitLab CE 16.x (latest stable 16.11.x or 17.x if available)

**Rationale**:
- GitLab 16.x is the current stable release as of January 2025
- GitLab 17.x may be available and is the next LTS candidate
- CE (Community Edition) meets all functional requirements without enterprise features
- Package installation via official GitLab repository ensures automatic updates
- Version 16.x+ includes:
  - Native support for runner registration tokens (replacing deprecated registration workflow)
  - Container registry with garbage collection
  - Built-in OIDC provider support (for Keycloak integration)
  - Improved runner-to-GitLab communication protocols

**Alternatives Considered**:
- GitLab 15.x: Rejected - older version approaching EOL, missing improved runner registration
- GitLab EE (Enterprise Edition): Rejected - unnecessary premium features, licensing costs
- Self-compiled GitLab: Rejected - complicates updates and maintenance
- Docker Omnibus: Considered but native package preferred for LXC integration

**Implementation Notes**:
- Use official GitLab package repository: `packages.gitlab.com/gitlab/gitlab-ce`
- Pin to major version 16.x or 17.x, allow automatic minor/patch updates
- Installation method: Omnibus package (all-in-one with PostgreSQL, Redis, etc.)

---

## Decision 2: GitLab Runner Executor Strategy

**Decision**: Implement Docker executor as primary, Shell executor as fallback

**Rationale**:
- Docker executor provides isolation and consistent build environments
- Supports building and pushing Docker images to container registry
- Shell executor provides fallback for simple scripts and non-containerized workflows
- Kubernetes executor not needed for current scale (2-5 runners, 10-50 users)

**Alternatives Considered**:
- Shell executor only: Rejected - insufficient isolation between pipeline jobs
- Kubernetes executor: Rejected - overkill for current scale, adds complexity
- Docker-in-Docker (DinD): Considered - required for Docker executor, will implement
- Custom executor: Rejected - unnecessary complexity for standard use cases

**Implementation Notes**:
- LXC containers for runners must be privileged if using Docker executor (IR-007)
- Mount Docker socket or use Docker-in-Docker pattern
- Configure resource limits per executor (CPU, memory, concurrent jobs)
- Support both `docker` and `shell` executor types via Ansible variables

---

## Decision 3: LXC Container Base Image

**Decision**: Debian 12 (Bookworm) for both GitLab and Runner containers

**Rationale**:
- Debian is GitLab's officially supported distribution
- Debian 12 is current stable with long-term support (until 2026+)
- Consistent with Proxmox host OS (Debian-based)
- GitLab Omnibus package has first-class Debian support
- GitLab Runner has official Debian packages

**Alternatives Considered**:
- Ubuntu 22.04 LTS: Considered - also officially supported, but Debian preferred for consistency
- Alpine Linux: Rejected - not officially supported by GitLab Omnibus
- CentOS/RHEL: Rejected - moving away from CentOS, different package ecosystem

**Implementation Notes**:
- Use Proxmox CT templates: `debian-12-standard`
- Configure AppArmor profiles for additional container security
- Enable nftables firewall rules for network isolation

---

## Decision 4: Persistent Storage Strategy

**Decision**: ZFS datasets with bind mounts for GitLab data directories

**Rationale**:
- ZFS provides snapshots for backup and rollback capability
- Efficient compression and deduplication for repository storage
- Integration with Proxmox Backup Server for automated backups
- Separate datasets allow independent snapshot schedules:
  - `/var/opt/gitlab/git-data` (repositories) - frequent snapshots
  - `/var/opt/gitlab/gitlab-rails/uploads` (user uploads) - daily snapshots
  - `/var/opt/gitlab/registry` (container registry) - configurable retention

**Alternatives Considered**:
- LVM volumes: Considered - works but lacks ZFS snapshot efficiency
- Local directory storage: Rejected - no snapshot capability, harder to backup
- NFS/CIFS mounts: Rejected - adds network dependency, performance impact for Git operations
- Ceph: Rejected - overkill for single-node deployment

**Implementation Notes**:
- Create ZFS datasets on Proxmox host: `rpool/gitlab-data`, `rpool/gitlab-registry`
- Bind mount into LXC containers via `pct set` commands
- Configure Proxmox Backup Server (PBS) to snapshot ZFS datasets
- Document backup retention policy in role README

---

## Decision 5: OIDC Integration Pattern

**Decision**: GitLab OIDC provider with Keycloak as identity source

**Rationale**:
- GitLab has native OIDC/OAuth2 support since version 10.x
- Keycloak provides centralized identity management (existing infrastructure)
- Automatic user provisioning on first login
- Supports group mapping from Keycloak to GitLab roles

**Alternatives Considered**:
- LDAP direct bind: Considered - simpler but less flexible than OIDC
- SAML: Rejected - OIDC is more modern and easier to configure
- Local accounts only: Rejected - violates SR-001 (centralized auth requirement)
- Crowd/CAS integration: Rejected - not relevant to existing infrastructure

**Implementation Notes**:
- Configure GitLab as OIDC client in Keycloak
- Create Keycloak client with appropriate scopes: `openid`, `profile`, `email`
- Map Keycloak groups to GitLab roles via OIDC claims
- GitLab configuration in `gitlab.rb`:
  ```ruby
  gitlab_rails['omniauth_providers'] = [
    {
      name: 'openid_connect',
      label: 'Keycloak SSO',
      args: {
        name: 'openid_connect',
        scope: ['openid', 'profile', 'email'],
        response_type: 'code',
        issuer: 'https://keycloak.example.com/realms/main',
        discovery: true,
        client_auth_method: 'query',
        uid_field: 'preferred_username',
        client_options: {
          identifier: 'gitlab',
          secret: '<vault-encrypted>',
          redirect_uri: 'https://gitlab.example.com/users/auth/openid_connect/callback'
        }
      }
    }
  ]
  ```

---

## Decision 6: Traefik Integration Approach

**Decision**: Use Docker labels pattern for dynamic Traefik configuration

**Rationale**:
- Existing infrastructure uses Traefik as reverse proxy
- Dynamic configuration via labels enables automatic service discovery
- HTTPS termination handled by Traefik with Let's Encrypt
- Middleware support for security headers, rate limiting

**Alternatives Considered**:
- Static Traefik configuration files: Rejected - less flexible, requires Traefik restart
- Direct NGINX proxy: Rejected - duplicate reverse proxy, conflicts with Traefik
- GitLab built-in NGINX: Considered - will use for internal routing, Traefik for external

**Implementation Notes**:
- GitLab LXC container exposes port 80 (HTTP) internally
- Traefik labels configured via Ansible template:
  ```yaml
  traefik.enable: "true"
  traefik.http.routers.gitlab.rule: "Host(`gitlab.example.com`)"
  traefik.http.routers.gitlab.entrypoints: "websecure"
  traefik.http.routers.gitlab.tls.certresolver: "letsencrypt"
  traefik.http.services.gitlab.loadbalancer.server.port: "80"
  ```
- SSH access for Git operations exposed directly on port 2222 (bypasses Traefik)
- Container registry accessible via subdomain: `registry.example.com`

---

## Decision 7: GitLab.com Runner Registration Method

**Decision**: Use runner authentication tokens with GitLab.com API

**Rationale**:
- GitLab 16.x introduced runner authentication tokens (replacing legacy registration tokens)
- Tokens can be scoped to specific projects, groups, or instance-wide
- Secure token storage in Ansible Vault
- Same runner binary supports both self-hosted and GitLab.com registration

**Alternatives Considered**:
- Legacy registration tokens: Deprecated in GitLab 16.x, will be removed
- Manual registration via web UI: Rejected - not automatable via Ansible
- GitLab Runner Operator (Kubernetes): Rejected - not applicable for LXC deployment

**Implementation Notes**:
- Obtain runner authentication token from GitLab.com project settings
- Store token in Ansible Vault: `gitlab_runner_token_gitlab_com`
- Register runner using `gitlab-runner register` command with `--token` flag
- Configure runner tags for job filtering: `self-hosted`, `docker`, `on-premise`
- Ensure outbound HTTPS connectivity to `gitlab.com` (IR-009)

---

## Decision 8: Backup Automation Strategy

**Decision**: PBS (Proxmox Backup Server) for LXC snapshots + GitLab native backup for repositories

**Rationale**:
- Proxmox Backup Server provides deduplicated, encrypted backups
- LXC snapshots capture entire container state
- GitLab native backup (`gitlab-rake gitlab:backup:create`) provides application-consistent backups
- Dual approach ensures both infrastructure and data recovery options

**Alternatives Considered**:
- PBS only: Considered - fast recovery but less granular for data restoration
- GitLab backup only: Rejected - doesn't capture container configuration
- rsync to remote storage: Considered - fallback if PBS unavailable
- BorgBackup: Rejected - PBS is infrastructure standard

**Implementation Notes**:
- Schedule GitLab native backups via cron: daily at 2 AM
- Store backups in `/var/opt/gitlab/backups` (separate ZFS dataset)
- PBS snapshots: daily LXC container snapshots, 7-day retention
- Backup verification: monthly restore test to staging environment
- Document restore procedures in `docs/gitlab-restore.md`

---

## Decision 9: Monitoring and Health Checks

**Decision**: GitLab health endpoints + Zabbix integration for metrics

**Rationale**:
- GitLab exposes health endpoints: `/-/health`, `/-/readiness`, `/-/liveness`
- Zabbix is existing monitoring infrastructure (IR-004)
- Prometheus metrics available from GitLab for detailed observability
- Runner health monitored via systemd service status

**Alternatives Considered**:
- Prometheus only: Considered - can be added later for detailed metrics
- Nagios/Icinga: Rejected - Zabbix is infrastructure standard
- GitLab built-in monitoring: Considered - requires Grafana setup, defer to phase 2

**Implementation Notes**:
- Create Zabbix host entries for GitLab and runner containers (via NetBox sync)
- Configure HTTP checks for GitLab health endpoints:
  - `GET https://gitlab.example.com/-/health` (expect 200)
  - `GET https://gitlab.example.com/-/readiness` (expect 200, JSON response)
- Monitor GitLab Runner systemd service: `gitlab-runner.service`
- Alert thresholds:
  - GitLab health check failure: immediate alert
  - Runner offline >5 minutes: warning
  - Disk space >80%: warning, >90%: critical

---

## Decision 10: Network Architecture

**Decision**: Internal network for GitLab-Runner communication, Traefik for external access

**Rationale**:
- GitLab instance on internal network (e.g., 10.0.10.0/24)
- Runners on same internal network for low-latency communication
- Traefik reverse proxy bridges internal and external networks
- Firewall rules restrict access to GitLab services

**Alternatives Considered**:
- DMZ placement for GitLab: Considered - adds security but complicates runner communication
- Direct external access: Rejected - violates security requirements (SR-004)
- VPN requirement for all access: Rejected - impractical for developer workflows

**Implementation Notes**:
- GitLab LXC container IP: assigned from internal network range
- Runner LXC containers: assigned from same internal network range
- Firewall rules (nftables):
  - Allow runners → GitLab: TCP/80, TCP/443
  - Allow Traefik → GitLab: TCP/80
  - Allow external → Traefik: TCP/443
  - Allow SSH for Git operations: TCP/2222 (GitLab SSH)
- Document network topology in `docs/gitlab-architecture.md`

---

## Best Practices Summary

### GitLab Administration
- Enable automatic backups with verified restore procedures
- Configure email notifications for pipeline failures and system events
- Implement repository size limits to prevent storage exhaustion
- Enable container registry garbage collection for storage management
- Regular security updates via `apt upgrade` (automated via Ansible)

### Runner Management
- Use tags to organize runners by capability (`docker`, `shell`, `gpu`, etc.)
- Limit concurrent jobs per runner based on resource allocation
- Implement job timeout limits to prevent runaway pipelines
- Monitor runner disk space and implement cleanup policies
- Separate runners for GitLab.com and self-hosted to prevent resource contention

### Security Practices
- Rotate runner authentication tokens annually
- Enable audit logging for administrative actions
- Implement IP allowlisting for administrative access
- Regular security scans of container images in registry
- Review and prune inactive user accounts quarterly

### Performance Optimization
- Enable GitLab caching (Redis) for improved response times
- Configure Git pack optimization for repository storage efficiency
- Use GitLab Pages and CDN for static content delivery (future enhancement)
- Monitor PostgreSQL query performance and optimize indexes
- Implement rate limiting for API endpoints to prevent abuse

---

## Integration Patterns

### Keycloak → GitLab User Provisioning
1. User authenticates via Keycloak OIDC
2. GitLab receives OIDC token with user claims (username, email, groups)
3. GitLab creates local user account on first login (if not exists)
4. Group membership mapped from Keycloak groups to GitLab roles:
   - `gitlab-admin` Keycloak group → `Administrator` role in GitLab
   - `gitlab-developer` Keycloak group → `Developer` role in GitLab
   - Default role: `Reporter` for authenticated users

### NetBox → GitLab Service Registration
1. Ansible role registers GitLab service in NetBox via API
2. Service metadata includes:
   - Service name: "GitLab CE"
   - URL: `https://gitlab.example.com`
   - Container ID: LXC VMID
   - IP address: Internal IP assignment
   - Status: Active
3. Runner containers registered as dependent services
4. NetBox webhook triggers Zabbix host creation (future enhancement)

### GitLab → Traefik Dynamic Routing
1. GitLab LXC container started with Docker labels
2. Traefik discovers service via Docker provider
3. Traefik creates HTTPS route with Let's Encrypt certificate
4. Middleware applied: security headers, rate limiting
5. Traefik forwards requests to GitLab on port 80

### PBS → GitLab Backup Workflow
1. Daily cron job triggers `gitlab-rake gitlab:backup:create`
2. Backup stored in `/var/opt/gitlab/backups` (ZFS dataset)
3. PBS snapshots ZFS dataset after backup completes
4. PBS transfers backup to remote storage with deduplication
5. Retention policy: 7 daily, 4 weekly, 12 monthly backups

---

## Open Questions (None Remaining)

All technical unknowns from the planning phase have been resolved. No blockers for Phase 1 design.

---

## References

- [GitLab CE Official Documentation](https://docs.gitlab.com/ee/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [GitLab OIDC Integration Guide](https://docs.gitlab.com/ee/administration/auth/oidc.html)
- [Proxmox LXC Container Management](https://pve.proxmox.com/wiki/Linux_Container)
- [Ansible Vault Best Practices](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Traefik Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
- [GitLab Runner Autoscaling](https://docs.gitlab.com/runner/configuration/autoscale.html)

---

**Status**: ✅ Research Complete - Ready for Phase 1 Design
