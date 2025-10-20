# Tasks: Self-Service Docker Platform

**Input**: Design documents from `/specs/002-docker-platform-selfservice/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are NOT explicitly requested in the specification, so no test tasks are included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
- **Ansible roles**: `roles/<service>/tasks/`, `roles/<service>/templates/`
- **Playbooks**: `playbooks/` for orchestration
- **Configuration**: `group_vars/`, `host_vars/`, `inventory/`
- **Documentation**: `docs/` for architecture and operations guides

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create Ansible project structure per implementation plan in plan.md
- [ ] T002 Initialize Ansible configuration file ansible.cfg with defaults and inventory paths
- [ ] T003 [P] Create inventory structure in inventory/hosts with Proxmox and management hosts
- [ ] T004 [P] Create group_vars/all/main.yml with non-secret variables (Proxmox host, domain, quotas)
- [ ] T005 Create encrypted group_vars/all/secrets.yml using Ansible Vault for API tokens and credentials
- [ ] T006 [P] Create roles/ directory structure for docker_platform, portainer, traefik_docker, netbox_integration
- [ ] T007 [P] Create playbooks/ directory for main orchestration playbooks
- [ ] T008 [P] Create tests/ directory structure for molecule/, integration/, and unit/ tests
- [ ] T009 [P] Create docs/ directory for architecture and operations documentation
- [ ] T010 Install required Ansible collections in requirements.yml (community.general, community.docker, ansible.posix)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### NetBox Integration

- [ ] T011 [P] Create custom Ansible module roles/netbox_integration/library/netbox_device.py for device registration
- [ ] T012 [P] Create custom Ansible module roles/netbox_integration/library/netbox_cf.py for custom field management
- [ ] T013 Create roles/netbox_integration/tasks/main.yml for NetBox device registration workflow
- [ ] T014 Create roles/netbox_integration/defaults/main.yml with NetBox URL and custom field definitions

### Traefik Reverse Proxy

- [ ] T015 [P] Create roles/traefik_docker/tasks/main.yml for Traefik LXC deployment
- [ ] T016 [P] Create roles/traefik_docker/tasks/tls_config.yml for Let's Encrypt certificate configuration
- [ ] T017 [P] Create roles/traefik_docker/tasks/dynamic_config.yml for file provider setup
- [ ] T018 [P] Create roles/traefik_docker/templates/traefik.yml.j2 for static Traefik configuration
- [ ] T019 [P] Create roles/traefik_docker/templates/dynamic/ directory and base route template
- [ ] T020 Create roles/traefik_docker/defaults/main.yml with Traefik version, Let's Encrypt email, DNS provider
- [ ] T021 Create roles/traefik_docker/handlers/main.yml for Traefik config reload handler
- [ ] T022 Create playbook playbooks/deploy_traefik.yml to deploy Traefik on dedicated LXC

### Portainer Server

- [ ] T023 [P] Create roles/portainer/tasks/main.yml for Portainer CE server installation
- [ ] T024 [P] Create roles/portainer/tasks/ldap_config.yml for LDAP authentication setup
- [ ] T025 [P] Create roles/portainer/tasks/environments.yml for environment endpoint management
- [ ] T026 [P] Create roles/portainer/templates/portainer-compose.yml.j2 for Docker Compose deployment
- [ ] T027 Create roles/portainer/defaults/main.yml with Portainer version, admin credentials, LDAP settings
- [ ] T028 Create playbook playbooks/deploy_portainer.yml to deploy Portainer server on dedicated LXC

### Database Setup

- [ ] T029 Create playbook playbooks/setup_database.yml to create PostgreSQL database and schema for platform metadata
- [ ] T030 Create database schema SQL in roles/docker_platform/files/schema.sql for docker_environments, provisioning_requests, traefik_routes tables

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Request New Docker Environment (Priority: P1) 🎯 MVP

**Goal**: Enable authenticated users to request new isolated Docker environments with auto-approval within quotas, automatic provisioning of LXC containers with Docker and Portainer Agent, and HTTPS access via Traefik.

**Independent Test**: User logs in, clicks "Create New Environment", enters project name "test-project", submits request. Within 5 minutes, receives email with URL `https://test-project.docker.example.com` and Portainer credentials. User can access Portainer and deploy containers.

### Core Platform Role (Docker Environment Provisioning)

- [ ] T031 [P] [US1] Create roles/docker_platform/defaults/main.yml with default resource quotas and LXC template settings
- [ ] T032 [P] [US1] Create roles/docker_platform/templates/lxc.conf.j2 for unprivileged LXC configuration with nesting
- [ ] T033 [P] [US1] Create roles/docker_platform/templates/docker-compose.yml.j2 for Portainer Agent deployment
- [ ] T034 [P] [US1] Create roles/docker_platform/templates/traefik-route.yml.j2 for dynamic Traefik route configuration
- [ ] T035 [US1] Create roles/docker_platform/tasks/lxc_create.yml for Proxmox LXC creation via API with quota validation
- [ ] T036 [US1] Create roles/docker_platform/tasks/docker_install.yml for Docker Engine installation in LXC
- [ ] T037 [US1] Create roles/docker_platform/tasks/portainer_agent.yml for Portainer Agent deployment via Docker Compose
- [ ] T038 [US1] Create roles/docker_platform/tasks/traefik_register.yml for Traefik route registration and TLS cert request
- [ ] T039 [US1] Create roles/docker_platform/tasks/netbox_register.yml for NetBox inventory registration
- [ ] T040 [US1] Create roles/docker_platform/tasks/main.yml to orchestrate provisioning workflow (quota check, LXC create, Docker install, Portainer, Traefik, NetBox)
- [ ] T041 [US1] Create roles/docker_platform/handlers/main.yml for Traefik reload and NetBox sync handlers
- [ ] T042 [US1] Create roles/docker_platform/README.md documenting role variables, usage, and quota configuration

### Provisioning Orchestration

- [ ] T043 [US1] Create playbook playbooks/provision_docker_env.yml for main provisioning workflow with quota validation and approval logic
- [ ] T044 [US1] Add quota validation logic to playbooks/provision_docker_env.yml to check CPU, memory, disk against defaults
- [ ] T045 [US1] Add auto-approval logic to playbooks/provision_docker_env.yml to provision immediately if within quotas
- [ ] T046 [US1] Add approval request logic to playbooks/provision_docker_env.yml to create pending request in PostgreSQL if exceeds quotas

### LDAP Group Ownership

- [ ] T047 [US1] Add LDAP group ownership support to roles/docker_platform/tasks/main.yml to query LDAP group members
- [ ] T048 [US1] Add Portainer team mapping to roles/portainer/tasks/environments.yml to create team and assign endpoint access
- [ ] T049 [US1] Add access control validation to playbooks/provision_docker_env.yml to verify user is owner or group member

### Notification System

- [ ] T050 [P] [US1] Create roles/docker_platform/tasks/notifications.yml for email and webhook notifications
- [ ] T051 [P] [US1] Create roles/docker_platform/templates/notification_email.j2 for provisioning success email with HTTPS URL
- [ ] T052 [US1] Add notification sending to roles/docker_platform/tasks/main.yml to send email and webhooks after successful provisioning
- [ ] T053 [US1] Add webhook delivery logic to roles/docker_platform/tasks/notifications.yml with retry and 95% success rate target

### Environment Validation

- [ ] T054 [US1] Add project name validation to playbooks/provision_docker_env.yml to enforce uniqueness and character constraints (3-32 chars, alphanumeric, hyphens)
- [ ] T055 [US1] Add environment status tracking to roles/docker_platform/tasks/main.yml to update PostgreSQL with provisioning, ready, failed states
- [ ] T056 [US1] Add failure handling to roles/docker_platform/tasks/main.yml to rollback LXC creation on Docker install failure

**Checkpoint**: At this point, User Story 1 should be fully functional - users can request environments, get auto-approved within quotas, receive provisioned LXC with Docker/Portainer/Traefik, and access via HTTPS.

---

## Phase 4: User Story 2 - Deploy Containers via GUI (Priority: P2)

**Goal**: Enable users to deploy and manage Docker containers through Portainer web interface, pull images from public and GitLab Container Registry, configure containers, and access them via Traefik routing.

**Independent Test**: User accesses Portainer dashboard at `https://test-project.docker.example.com`, clicks "Add container", enters image `gitlab.example.com:5050/team/app:latest` with registry credentials, configures ports, deploys container, and accesses it via Traefik route.

### GitLab Container Registry Integration

- [ ] T057 [P] [US2] Create roles/portainer/tasks/registry_config.yml for GitLab Container Registry authentication setup
- [ ] T058 [P] [US2] Add registry credentials management to roles/portainer/tasks/main.yml to store GitLab registry credentials in Portainer
- [ ] T059 [US2] Create roles/docker_platform/templates/registry_secret.j2 for Docker registry secret generation

### Traefik Dynamic Routing

- [ ] T060 [P] [US2] Create roles/traefik_docker/templates/dynamic/container_route.yml.j2 for per-container Traefik routes
- [ ] T061 [US2] Add dynamic route generation to roles/docker_platform/tasks/traefik_register.yml to create routes when containers are deployed
- [ ] T062 [US2] Add path-based routing support to roles/traefik_docker/templates/dynamic/container_route.yml.j2 for `/api` style paths
- [ ] T063 [US2] Add route cleanup to roles/docker_platform/handlers/main.yml to remove Traefik routes when containers are deleted

### Container Health Monitoring

- [ ] T064 [P] [US2] Add container health check configuration to roles/portainer/tasks/main.yml to enable Portainer health checks
- [ ] T065 [US2] Add health status tracking to roles/docker_platform/tasks/main.yml to monitor container health via Portainer API

### Portainer UI Enhancements

- [ ] T066 [US2] Document Portainer container deployment workflow in docs/portainer_usage.md for users
- [ ] T067 [US2] Document GitLab Container Registry integration in docs/gitlab_registry.md with authentication steps

**Checkpoint**: At this point, User Story 2 should be fully functional - users can deploy containers via Portainer GUI, pull from GitLab registry, access via Traefik HTTPS routes.

---

## Phase 5: User Story 3 - CI/CD Integration with GitLab (Priority: P3)

**Goal**: Enable users to configure GitLab pipelines to build, push, and deploy container images automatically with deployment tokens, rolling updates with health checks, and automatic rollback on failure.

**Independent Test**: User creates `.gitlab-ci.yml` in repository with build and deploy stages, commits code, GitLab pipeline runs, builds image, pushes to registry, triggers deployment via API, new container version appears in Portainer, old version removed after health check passes.

### Deployment API

- [ ] T068 [P] [US3] Create playbook playbooks/deploy_container.yml for container deployment with rolling update and health checks
- [ ] T069 [US3] Add image pull logic to playbooks/deploy_container.yml to pull new image from registry
- [ ] T070 [US3] Add blue-green deployment to playbooks/deploy_container.yml to start new container with `-new` suffix
- [ ] T071 [US3] Add health check loop to playbooks/deploy_container.yml to validate new container health (HTTP endpoint check with 12 retries × 5s)
- [ ] T072 [US3] Add traffic switch logic to playbooks/deploy_container.yml to update Traefik route to new container after health check passes
- [ ] T073 [US3] Add old container cleanup to playbooks/deploy_container.yml to stop and remove old container after 30s grace period
- [ ] T074 [US3] Add rollback logic to playbooks/deploy_container.yml to stop new container and keep old running if health check fails

### Deployment Tokens

- [ ] T075 [P] [US3] Create roles/docker_platform/tasks/deployment_tokens.yml for generating and managing deployment API tokens
- [ ] T076 [US3] Add token validation to playbooks/deploy_container.yml to authenticate deployment requests
- [ ] T077 [US3] Add token storage to group_vars/all/secrets.yml using Ansible Vault for secure token management

### GitLab CI Integration

- [ ] T078 [P] [US3] Create docs/gitlab_ci_integration.md with example `.gitlab-ci.yml` for building and deploying
- [ ] T079 [P] [US3] Create example `.gitlab-ci.yml` in docs/examples/ with build, push, deploy stages
- [ ] T080 [US3] Add GitLab runner network access validation to docs/gitlab_ci_integration.md

### Deployment Notifications

- [ ] T081 [US3] Add deployment status notifications to playbooks/deploy_container.yml to send email and webhooks on success/failure
- [ ] T082 [US3] Add deployment failure details to roles/docker_platform/templates/notification_email.j2 for rollback notifications

**Checkpoint**: At this point, User Story 3 should be fully functional - users can configure GitLab CI/CD pipelines to automatically build and deploy containers with rolling updates and automatic rollback.

---

## Phase 6: User Story 4 - Environment Monitoring and Management (Priority: P4)

**Goal**: Enable users to monitor environment resource usage, view container logs, receive alerts, and enable administrators to set and enforce resource quotas.

**Independent Test**: User accesses environment dashboard, views real-time CPU/memory graphs, clicks container to see logs, manually stops container, receives email alert within 2 minutes. Administrator sets quota (4 CPU, 8GB RAM), user attempts to exceed quota, new containers fail with quota error.

### Monitoring Infrastructure

- [ ] T083 [P] [US4] Create roles/docker_platform/tasks/monitoring.yml for Zabbix monitoring template deployment
- [ ] T084 [P] [US4] Create roles/docker_platform/files/zabbix_template.xml for Docker environment monitoring template
- [ ] T085 [US4] Add Zabbix host registration to roles/docker_platform/tasks/netbox_register.yml to register environments in Zabbix
- [ ] T086 [US4] Add Grafana dashboard provisioning to roles/docker_platform/files/grafana_dashboard.json for environment metrics

### Resource Usage Tracking

- [ ] T087 [P] [US4] Add resource usage collection to roles/docker_platform/tasks/monitoring.yml to collect CPU, memory, disk, network metrics
- [ ] T088 [US4] Add resource allocation tracking to roles/docker_platform/tasks/main.yml to record assigned quotas in PostgreSQL and NetBox

### Container Log Access

- [ ] T089 [P] [US4] Document container log viewing in docs/portainer_usage.md for accessing logs via Portainer UI
- [ ] T090 [US4] Add log aggregation to roles/docker_platform/tasks/monitoring.yml for optional Loki integration

### Alerting System

- [ ] T091 [P] [US4] Add container status monitoring to roles/docker_platform/tasks/monitoring.yml to detect stopped containers
- [ ] T092 [US4] Add alert notification to roles/docker_platform/tasks/notifications.yml to send email/webhook when container stops
- [ ] T093 [US4] Add alert rules to roles/docker_platform/files/zabbix_template.xml for container stop, resource threshold alerts

### Quota Management

- [ ] T094 [US4] Add quota enforcement to roles/docker_platform/tasks/lxc_create.yml to enforce cgroup limits at LXC level
- [ ] T095 [US4] Add quota validation to playbooks/deploy_container.yml to check container count against environment quota
- [ ] T096 [US4] Add quota update API to playbooks/update_quotas.yml for administrator quota adjustments
- [ ] T097 [US4] Document quota management in docs/admin_operations.md for administrators

**Checkpoint**: At this point, User Story 4 should be fully functional - users can monitor environments, view logs, receive alerts, and administrators can set and enforce quotas.

---

## Phase 7: User Story 5 - Environment Lifecycle Management (Priority: P5)

**Goal**: Enable users to pause, resume, snapshot, and delete environments with proper cleanup and data retention policies.

**Independent Test**: User clicks "Pause Environment", all containers stop, HTTPS unavailable, status shows "Paused". User clicks "Resume", containers restart, HTTPS accessible within 2 minutes. User creates snapshot "backup-v1", sees snapshot details. User deletes environment with name confirmation, all resources freed within 5 minutes.

### Pause/Resume Operations

- [ ] T098 [P] [US5] Create playbook playbooks/pause_environment.yml to stop all containers and pause LXC
- [ ] T099 [P] [US5] Create playbook playbooks/resume_environment.yml to resume LXC and restart containers
- [ ] T100 [US5] Add container state preservation to playbooks/pause_environment.yml to save running container list
- [ ] T101 [US5] Add container restart logic to playbooks/resume_environment.yml to restart previously running containers
- [ ] T102 [US5] Add Traefik route deactivation to playbooks/pause_environment.yml to make HTTPS unavailable
- [ ] T103 [US5] Add Traefik route reactivation to playbooks/resume_environment.yml to restore HTTPS access

### Snapshot Operations

- [ ] T104 [P] [US5] Create playbook playbooks/create_snapshot.yml to create Proxmox LXC snapshot
- [ ] T105 [US5] Add snapshot metadata tracking to playbooks/create_snapshot.yml to record snapshot in PostgreSQL
- [ ] T106 [US5] Add snapshot retention policy to playbooks/create_snapshot.yml to enforce 30-day retention
- [ ] T107 [US5] Add snapshot cleanup to playbooks/delete_environment.yml to create final snapshot before deletion

### Environment Deletion

- [ ] T108 [US5] Create playbook playbooks/delete_environment.yml to delete Docker environment with cleanup
- [ ] T109 [US5] Add confirmation validation to playbooks/delete_environment.yml to require --force flag and name match
- [ ] T110 [US5] Add container cleanup to playbooks/delete_environment.yml to stop and remove all containers
- [ ] T111 [US5] Add LXC deletion to playbooks/delete_environment.yml to remove LXC container from Proxmox
- [ ] T112 [US5] Add Traefik route cleanup to playbooks/delete_environment.yml to remove dynamic route files
- [ ] T113 [US5] Add NetBox cleanup to playbooks/delete_environment.yml to mark device as decommissioned
- [ ] T114 [US5] Add PostgreSQL cleanup to playbooks/delete_environment.yml to update status to "deleted"
- [ ] T115 [US5] Add audit logging to playbooks/delete_environment.yml to record deletion event

### Deployment Validation for Paused Environments

- [ ] T116 [US5] Add pause status check to playbooks/deploy_container.yml to reject deployments to paused environments
- [ ] T117 [US5] Add error response to playbooks/deploy_container.yml for paused environment with resume instructions

**Checkpoint**: At this point, User Story 5 should be fully functional - users can pause, resume, snapshot, and delete environments with proper cleanup and data retention.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

### Documentation

- [ ] T118 [P] Create docs/architecture.md documenting overall system architecture, components, and data flows
- [ ] T119 [P] Create docs/operations_guide.md for administrators covering deployment, monitoring, quota management
- [ ] T120 [P] Create docs/user_guide.md for end users covering environment creation, container deployment, CI/CD integration
- [ ] T121 [P] Create docs/troubleshooting.md with common issues and solutions (LXC provisioning failures, TLS cert issues, quota errors)
- [ ] T122 [P] Update README.md with project overview, quickstart link, and documentation index

### Security Hardening

- [ ] T123 [P] Add network isolation rules to roles/docker_platform/tasks/lxc_create.yml for nftables firewall per environment
- [ ] T124 [P] Add AppArmor profile enforcement to roles/docker_platform/templates/lxc.conf.j2 for unprivileged LXC security
- [ ] T125 [P] Add API rate limiting to playbooks/deploy_container.yml to prevent abuse (10 requests/user/hour)
- [ ] T126 [P] Add audit logging to playbooks/provision_docker_env.yml for all provisioning requests with user, timestamp, result
- [ ] T127 [P] Validate Ansible Vault usage in group_vars/all/secrets.yml for all secrets (API tokens, passwords, credentials)

### Performance Optimization

- [ ] T128 Optimize LXC provisioning in roles/docker_platform/tasks/lxc_create.yml to meet <5min target
- [ ] T129 Optimize Docker installation in roles/docker_platform/tasks/docker_install.yml to use pre-configured template
- [ ] T130 Optimize Traefik route updates in roles/docker_platform/tasks/traefik_register.yml to use atomic file writes
- [ ] T131 Add connection pooling to NetBox API calls in roles/netbox_integration/library/ modules

### Validation

- [ ] T132 Run quickstart.md validation steps to verify end-to-end deployment workflow
- [ ] T133 Validate ansible-lint passes for all roles and playbooks with no errors
- [ ] T134 Validate yamllint passes for all YAML files with no errors
- [ ] T135 Validate constitution compliance in plan.md (Infrastructure as Code, Security-First, Idempotent, NetBox CMDB, Automated)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - User Story 1 (P1): Can start after Foundational - No dependencies on other stories
  - User Story 2 (P2): Can start after Foundational - Depends on User Story 1 (needs provisioned environments)
  - User Story 3 (P3): Can start after Foundational - Depends on User Story 2 (needs container deployment capability)
  - User Story 4 (P4): Can start after Foundational - Independent of other stories (monitoring)
  - User Story 5 (P5): Can start after Foundational - Depends on User Story 1 (needs environments to pause/resume/delete)
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1) - Request Environment**: Can start after Foundational (Phase 2) - No dependencies on other stories - **MVP candidate**
- **User Story 2 (P2) - Deploy Containers**: Depends on User Story 1 (needs provisioned environments to deploy to)
- **User Story 3 (P3) - CI/CD Integration**: Depends on User Story 2 (needs container deployment capability to automate)
- **User Story 4 (P4) - Monitoring**: Can start after Foundational - Independent (can monitor any environment)
- **User Story 5 (P5) - Lifecycle**: Depends on User Story 1 (needs environments to manage lifecycle)

### Recommended Implementation Order

1. **Phase 1 + Phase 2** (Setup + Foundational) - CRITICAL foundation
2. **Phase 3** (User Story 1) - MVP: Environment provisioning with auto-approval and HTTPS access
3. **Phase 4** (User Story 2) - Container deployment via Portainer GUI
4. **Phase 6** (User Story 4) - Monitoring (can be done in parallel with User Story 2/3)
5. **Phase 5** (User Story 3) - CI/CD automation
6. **Phase 7** (User Story 5) - Lifecycle management (pause, resume, snapshot, delete)
7. **Phase 8** (Polish) - Documentation, security, performance, validation

### Within Each User Story

- Templates before tasks (templates are referenced in tasks)
- Defaults before tasks (defaults define variables used in tasks)
- Tasks in dependency order (lxc_create before docker_install before portainer_agent)
- Handlers after tasks (handlers are triggered by tasks)
- Playbooks orchestrate roles (playbooks come after role implementation)

### Parallel Opportunities

**Phase 1 (Setup)**: All tasks marked [P] can run in parallel (T003, T004, T006, T007, T008, T009)

**Phase 2 (Foundational)**: Within each subsystem, [P] tasks can run in parallel:
- NetBox: T011, T012 can run in parallel
- Traefik: T015-T019 can run in parallel (templates and tasks for different files)
- Portainer: T023-T026 can run in parallel

**Phase 3 (User Story 1)**: T031-T034 (templates) can run in parallel, T050-T051 (notifications) can run in parallel

**Phase 4 (User Story 2)**: T057-T059 (registry config) can run in parallel, T060 independent of T064

**Phase 5 (User Story 3)**: T068 independent of T075, T078-T079 (docs) can run in parallel

**Phase 6 (User Story 4)**: T083-T084 (monitoring), T087, T089, T091 can all run in parallel (different files)

**Phase 7 (User Story 5)**: T098-T099 (pause/resume) can run in parallel, T104 (snapshot) independent

**Phase 8 (Polish)**: All documentation tasks (T118-T122) can run in parallel, all security tasks (T123-T127) can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all template tasks for User Story 1 together:
Task: T031 "Create roles/docker_platform/defaults/main.yml"
Task: T032 "Create roles/docker_platform/templates/lxc.conf.j2"
Task: T033 "Create roles/docker_platform/templates/docker-compose.yml.j2"
Task: T034 "Create roles/docker_platform/templates/traefik-route.yml.j2"

# After templates, launch notification tasks in parallel:
Task: T050 "Create roles/docker_platform/tasks/notifications.yml"
Task: T051 "Create roles/docker_platform/templates/notification_email.j2"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (~2-3 hours)
2. Complete Phase 2: Foundational (~8-12 hours) - CRITICAL, blocks all stories
3. Complete Phase 3: User Story 1 (~12-16 hours)
4. **STOP and VALIDATE**: Test User Story 1 independently
   - Create environment request
   - Verify LXC provisioned on Proxmox
   - Verify Docker installed in LXC
   - Verify Portainer Agent deployed
   - Verify Traefik route created
   - Verify HTTPS access with valid TLS cert
   - Verify NetBox registration
   - Verify email notification sent
5. Deploy/demo if ready - **This is a functional MVP!**

**MVP Scope**: Setup + Foundational + User Story 1 = ~22-31 hours total

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (~10-15 hours)
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!) (~12-16 hours, total ~22-31 hours)
3. Add User Story 2 → Test independently → Deploy/Demo (~6-8 hours, total ~28-39 hours)
4. Add User Story 4 → Test independently → Deploy/Demo (monitoring can be parallel) (~8-10 hours, total ~36-49 hours)
5. Add User Story 3 → Test independently → Deploy/Demo (CI/CD automation) (~10-12 hours, total ~46-61 hours)
6. Add User Story 5 → Test independently → Deploy/Demo (lifecycle management) (~8-10 hours, total ~54-71 hours)
7. Add Polish → Final validation (~6-8 hours, total ~60-79 hours)

Each story adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. **Team completes Setup + Foundational together** (~10-15 hours)
2. **Once Foundational is done**, assign in dependency order:
   - **Developer A**: User Story 1 (P1) - Required first, MVP
   - **Developer B**: User Story 4 (P4) - Can start after Foundational (monitoring is independent)
3. **After User Story 1 complete**:
   - **Developer C**: User Story 2 (P2) - Needs provisioned environments
   - **Developer D**: User Story 5 (P5) - Needs environments to manage
4. **After User Story 2 complete**:
   - **Developer E**: User Story 3 (P3) - Needs container deployment capability
5. **All complete** → **Team does Polish together**

This approach allows 2-3 developers to work in parallel after Foundational phase while respecting dependencies.

---

## Notes

- **[P] tasks** = different files, no dependencies within the same phase
- **[Story] label** maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- **Avoid**: vague tasks, same file conflicts, cross-story dependencies that break independence
- **Performance targets**: LXC provision <5min (T128), container deploy <2min, TLS cert <5min, 95% webhook success (T053)
- **Security**: All secrets in Ansible Vault (T005, T127), unprivileged LXC (T032), nftables isolation (T123), AppArmor profiles (T124)
- **Idempotency**: All playbooks must support re-running safely with state checks before changes
- **CMDB**: All environments must be registered in NetBox (T039, T113) as Single Source of Truth
