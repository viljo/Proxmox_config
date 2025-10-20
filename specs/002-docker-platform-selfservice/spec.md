# Feature Specification: Self-Service Docker Platform

**Feature Branch**: `002-docker-platform-selfservice`
**Created**: 2025-10-20
**Status**: Draft
**Input**: User description: "Self-service internal Docker platform with HTTPS routing, GUI management, and CI/CD integration. Provide authenticated users and administrators with the ability to create, manage, and deploy isolated Docker environments (LXCs) on Proxmox VE, automatically routed via Traefik with valid HTTPS, managed through Portainer, and integrated with the GitLab Container Registry."

## Clarifications

### Session 2025-10-20

- Q: Should ALL environment requests require administrator approval, or only requests that exceed default quotas? → A: Auto-approve requests within default quotas; only requests exceeding limits require approval
- Q: Can Docker environments be shared among multiple users, or is each environment strictly owned by a single user? → A: Team-based ownership - environments can be owned by LDAP groups, all members have access
- Q: How should the platform handle container updates to support rollback on deployment failures? → A: Rolling update with health check - new container starts, health validated, old stopped only if healthy
- Q: What notification channels should the platform support beyond email? → A: Email plus webhooks - allows users to integrate with their preferred tools (Slack, Mattermost, etc.)
- Q: Should the platform track and display resource usage costs for environments? → A: No cost tracking - only show resource allocation (CPU cores, RAM, disk assigned)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Request New Docker Environment (Priority: P1)

Authenticated users can request a new isolated Docker environment through a web interface. They specify a project name and description, submit the request, and within minutes receive a unique HTTPS URL and credentials to access their dedicated Docker environment with GUI management.

**Why this priority**: This is the core self-service capability that eliminates manual provisioning delays. Without this, users still depend on administrators for basic environment setup, defeating the purpose of a self-service platform.

**Independent Test**: Can be fully tested by a user logging into the platform, clicking "Create New Environment", entering a project name "test-project", and within 5 minutes receiving an email with URL `https://test-project.docker.example.com` and Port ainer login credentials. The user can then access Portainer and deploy containers.

**Acceptance Scenarios**:

1. **Given** an authenticated user on the platform dashboard, **When** they click "Request New Environment", enter project name "myapp" and description "Development environment", and submit, **Then** a provisioning job starts and the user sees a status page showing progress (creating container, installing Docker, configuring routing).

2. **Given** a provisioning job has completed successfully, **When** the user views their environment list, **Then** they see "myapp" with status "Ready", an HTTPS URL, and a "Launch Portainer" button.

3. **Given** a newly provisioned environment, **When** the user clicks the HTTPS URL or "Launch Portainer" button, **Then** they are redirected to `https://myapp.docker.example.com`, see a valid TLS certificate (not self-signed), and land on the Portainer login page.

4. **Given** a user with Portainer credentials, **When** they log in for the first time, **Then** they see an empty Docker environment with options to deploy containers, manage volumes, and configure networks.

5. **Given** a user requests an environment within default quotas (2 CPU, 4GB RAM, 50GB disk), **When** they submit the request, **Then** provisioning begins immediately without waiting for administrator approval.

6. **Given** a user requests an environment exceeding default quotas (8 CPU, 16GB RAM requested), **When** they submit the request, **Then** the request enters "Pending Approval" status and administrators receive a notification to review it.

7. **Given** a user creates an environment owned by an LDAP group "dev-team", **When** another member of "dev-team" logs into the platform, **Then** they see the environment in their environment list and can fully manage it (deploy containers, pause, delete).

---

### User Story 2 - Deploy Containers via GUI (Priority: P2)

Users can deploy and manage Docker containers in their environment using the Portainer web interface without needing command-line access. They can pull images from public registries or the internal GitLab Container Registry, configure environment variables, map ports, and monitor container health.

**Why this priority**: This is P2 because it requires P1 (environment creation) to be functional first. It provides the value of easy container deployment for users without Docker CLI expertise, which is essential for self-service adoption.

**Independent Test**: Can be fully tested by a user accessing their Portainer dashboard, clicking "Add container", selecting an image from the GitLab Container Registry (e.g., `gitlab.example.com:5050/mygroup/myimage:latest`), configuring ports and environment variables, and successfully deploying the container accessible via Traefik routing.

**Acceptance Scenarios**:

1. **Given** a user logged into Portainer, **When** they click "Containers" > "Add container", enter name "webapp", image "nginx:latest", and click "Deploy", **Then** the container starts successfully and appears in the container list with status "running".

2. **Given** a running container needs environment configuration, **When** the user edits the container to add environment variable "DB_HOST=postgres.example.com" and restarts it, **Then** the container restarts with the new environment variable visible in the container inspect view.

3. **Given** a user wants to deploy from the internal registry, **When** they enter image `gitlab.example.com:5050/team/backend:v1.2.3` and provide registry credentials, **Then** Portainer pulls the image from GitLab Container Registry and deploys the container successfully.

4. **Given** a deployed container exposes port 8080, **When** the user configures a Traefik label for path-based routing (e.g., `/api`), **Then** requests to `https://myapp.docker.example.com/api` are routed to the container on port 8080.

---

### User Story 3 - CI/CD Integration with GitLab (Priority: P3)

Users can configure their GitLab pipelines to automatically build container images, push them to the GitLab Container Registry, and deploy them to their Docker environment. The platform provides deployment tokens and webhook endpoints that GitLab CI can use to trigger deployments after successful builds.

**Why this priority**: This is P3 because it builds on P1 (environment) and P2 (manual deployment). It enables automation but isn't required for initial platform value. Users can still deploy manually while this is being developed.

**Independent Test**: Can be fully tested by a user creating a `.gitlab-ci.yml` file in their repository that builds a Docker image, pushes it to the registry, and triggers a deployment to their Docker environment. Success means the pipeline completes and the new container version is running in Portainer within the CI/CD job duration.

**Acceptance Scenarios**:

1. **Given** a user with a Docker environment and GitLab project, **When** they configure a GitLab CI pipeline with build and deploy stages using provided deployment tokens, **Then** the pipeline successfully authenticates, builds the image, pushes to the registry, and triggers deployment.

2. **Given** a GitLab CI job needs to deploy to the Docker environment, **When** it calls the platform's deployment API with project name and image tag, **Then** the platform pulls the new image and updates the running container in Portainer with zero manual intervention.

3. **Given** a deployment triggered by CI/CD, **When** the deployment completes, **Then** the user receives a notification via email and any configured webhooks with deployment status, container health, and the URL to access the updated service.

4. **Given** a failed deployment (image pull error, container crash, or health check failure), **When** the CI/CD job checks deployment status, **Then** it receives an error response with details, the pipeline fails, and the previous container version continues running (automatic rollback via rolling update health validation).

---

### User Story 4 - Environment Monitoring and Management (Priority: P4)

Users can monitor their Docker environment's resource usage (CPU, memory, disk), view container logs, restart containers, and receive alerts when containers stop or resource limits are exceeded. Administrators can set resource quotas per environment to prevent overconsumption.

**Why this priority**: This is P4 because operational monitoring is important but not blocking for initial deployments (P1-P3). Users can deploy and run containers before comprehensive monitoring exists, though it improves operational quality significantly.

**Independent Test**: Can be fully tested by a user accessing their environment dashboard, viewing real-time CPU/memory graphs, clicking a container to see its logs, and receiving an email alert when they stop the container manually or when it crashes.

**Acceptance Scenarios**:

1. **Given** a user viewing their environment dashboard, **When** they navigate to the "Monitoring" tab, **Then** they see real-time graphs of CPU usage, memory usage, disk usage, and network traffic for their entire environment and per-container breakdowns.

2. **Given** a running container, **When** the user clicks "View Logs", **Then** they see the container's stdout/stderr output in real-time with options to filter by time range and search for keywords.

3. **Given** a container crashes or stops unexpectedly, **When** the monitoring system detects the status change, **Then** the user receives an email alert within 2 minutes with container name, stop reason, and suggested actions.

4. **Given** an administrator sets a resource quota (e.g., 4 CPU cores, 8GB RAM per environment), **When** a user's containers attempt to exceed this limit, **Then** new containers fail to start with a clear error message about quota exceeded, and existing containers continue running.

---

### User Story 5 - Environment Lifecycle Management (Priority: P5)

Users can pause, resume, snapshot, and delete their Docker environments. Pausing stops all containers and deallocates resources while preserving data. Snapshots capture the entire environment state for backup or cloning. Deletion removes all resources after confirmation.

**Why this priority**: This is P5 because it's an operational enhancement for mature usage. Early adopters will primarily create and run environments (P1-P4). Lifecycle management becomes important as the platform scales and users need cost optimization and backup strategies.

**Independent Test**: Can be fully tested by a user clicking "Pause Environment" on their dashboard, confirming that all containers stop and resource usage drops to near zero, then clicking "Resume" and verifying that containers restart automatically with preserved volumes and configuration.

**Acceptance Scenarios**:

1. **Given** a running Docker environment with multiple containers, **When** the user clicks "Pause Environment" and confirms, **Then** all containers stop gracefully, the HTTPS endpoint becomes unavailable, and the environment status shows "Paused" with resource allocation details (CPU cores, RAM, disk space assigned).

2. **Given** a paused environment, **When** the user clicks "Resume Environment", **Then** all containers that were running before pause restart automatically in their original configuration, and the HTTPS endpoint becomes accessible within 2 minutes.

3. **Given** a user wants to create a backup, **When** they click "Create Snapshot", enter a name "pre-upgrade-backup", and confirm, **Then** the platform creates a snapshot of the LXC container and Docker volumes, showing snapshot size and creation timestamp.

4. **Given** a user decides to permanently remove an environment, **When** they click "Delete Environment", type the environment name for confirmation, and confirm deletion, **Then** the platform stops all containers, removes the LXC container, deletes Traefik routing rules, and frees allocated resources within 5 minutes.

---

### Edge Cases

- **What happens when a user requests an environment name that already exists?** The system validates uniqueness during request submission and rejects duplicate names with an error message suggesting alternative names (e.g., appending `-2`, `-dev`, `-test`).

- **What happens when the Proxmox host runs out of resources (CPU, RAM, disk)?** New environment requests fail with a clear error message indicating resource constraints. Existing environments continue operating. Administrators receive an alert to add capacity.

- **What happens when Traefik fails to obtain a TLS certificate from Let's Encrypt?** The environment provisions successfully but serves traffic via HTTP with a warning banner. Certificate acquisition retries automatically every hour. Users can manually trigger retry from their dashboard.

- **What happens when a user's GitLab CI pipeline tries to deploy while the Docker environment is paused?** The deployment API returns an error indicating the environment is paused. The CI pipeline fails with instructions to resume the environment first.

- **What happens when two users try to access the same Portainer instance simultaneously?** Portainer supports multi-user sessions natively. Both users see real-time updates of container changes made by either user. Access control is managed by Portainer's RBAC.

- **What happens when LDAP authentication is unavailable during login?** The platform's authentication service returns an error and users cannot log in. Existing sessions remain valid until expiration. An administrator bypass option exists for emergency access.

- **What happens when a container consumes excessive resources and impacts other environments?** Resource limits (cgroups) at the LXC level prevent one environment from starving others. If a container hits its limit, it's throttled or OOM-killed, but other environments are unaffected.

- **What happens to data when an environment is deleted?** Before deletion, the system creates a final snapshot (retained for 30 days) and warns the user. After confirmation, all containers, volumes, and configuration are permanently deleted. The snapshot can be used for recovery if needed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a web-based dashboard where authenticated users can request new Docker environments by specifying a unique project name and optional description.

- **FR-002**: System MUST automatically provision an isolated container environment on the virtualization host when a request is approved, including container creation, Docker installation, and network configuration.

- **FR-003**: System MUST generate a unique HTTPS URL for each Docker environment based on the project name (e.g., `https://<project-name>.docker.example.com`).

- **FR-004**: System MUST automatically configure reverse proxy routing and TLS certificate issuance for each environment's HTTPS URL without manual intervention.

- **FR-005**: System MUST install and configure a container management GUI (web-based) in each Docker environment, accessible via the environment's HTTPS URL.

- **FR-006**: System MUST authenticate users via the existing directory service (LDAP) for both the platform dashboard and individual environment management interfaces.

- **FR-007**: System MUST allow users to deploy containers from public registries and the internal container registry through the management GUI without command-line access.

- **FR-008**: System MUST support pulling container images from the internal container registry with automatic authentication using stored credentials or deployment tokens.

- **FR-009**: System MUST provide deployment tokens or API keys that users can use in CI/CD pipelines to automate container deployment to their environments.

- **FR-010**: System MUST expose a REST API endpoint that accepts deployment requests (project name, image name, tag) and triggers container updates in the target environment.

- **FR-011**: System MUST allow users to view real-time resource usage (CPU, memory, disk, network) and resource allocation (assigned CPU cores, RAM limit, disk quota) for their Docker environments through the dashboard.

- **FR-012**: System MUST allow users to view container logs, inspect container configuration, and restart containers through the management GUI.

- **FR-013**: System MUST enforce resource quotas per Docker environment (maximum CPU cores, RAM, disk space) to prevent resource overconsumption.

- **FR-014**: System MUST allow administrators to configure default resource quotas. Requests within default quotas are auto-approved and provision immediately. Requests exceeding quotas require administrator approval or modification before provisioning.

- **FR-015**: System MUST send notifications to users when their environment is successfully provisioned, including the HTTPS URL and initial credentials. Notifications are sent via email and optionally via user-configured webhooks.

- **FR-016**: System MUST send alerts to users when containers in their environment stop unexpectedly or when resource usage exceeds configured thresholds. Alerts are sent via email and optionally via user-configured webhooks.

- **FR-026**: System MUST allow users to configure webhook URLs for their environments to receive notifications in external systems (Slack, Mattermost, Microsoft Teams, custom endpoints). Webhook payloads include event type, environment details, and relevant metadata in JSON format.

- **FR-017**: System MUST allow users to pause their Docker environment, stopping all containers and preserving data, to reduce resource consumption when not in use.

- **FR-018**: System MUST allow users to resume a paused environment, automatically restarting previously running containers with preserved configuration.

- **FR-019**: System MUST allow users to create snapshots of their Docker environment for backup purposes, capturing container state, volumes, and configuration.

- **FR-020**: System MUST allow users to delete their Docker environment after explicit confirmation, with all data removed within a defined retention period.

- **FR-021**: System MUST maintain an audit log of all environment lifecycle events (creation, deployment, pause, resume, deletion) for security and compliance.

- **FR-022**: System MUST validate project names for uniqueness, allowed characters (alphanumeric, hyphens), and length limits (3-32 characters).

- **FR-023**: System MUST allow environments to be owned by either individual users or LDAP groups. When owned by an LDAP group, all members of that group have full access to manage the environment (deploy containers, view logs, pause/resume, delete).

- **FR-024**: System MUST enforce access control such that only the owner (individual user or LDAP group members) can access and manage their environment. Non-owners cannot view or modify environments they don't own.

- **FR-025**: System MUST implement rolling updates for container deployments: start new container version, perform health check validation (HTTP endpoint check or startup wait period), route traffic to new container only if healthy, then stop old container. If new container fails health check, stop new container and keep old container running.

### Infrastructure Requirements *(for Proxmox deployments)*

- **IR-001**: Platform controller service MUST run on a dedicated management node (Debian-based) separate from user Docker environments.

- **IR-002**: Each Docker environment MUST run in an isolated LXC container on the virtualization host with unprivileged configuration and resource limits enforced via cgroups.

- **IR-003**: System MUST use the standard container template (Debian 13 Trixie) as the base for all Docker environment LXCs, with Docker engine pre-installed.

- **IR-004**: System MUST configure Traefik reverse proxy (Docker or native) to automatically discover new environments and configure routing rules with TLS certificate provisioning.

- **IR-005**: System MUST integrate with the virtualization host API (Proxmox VE) to create, configure, start, stop, snapshot, and delete LXC containers programmatically.

- **IR-006**: System MUST update NetBox inventory with each new Docker environment, including container ID, IP address, project name, owner, and resource allocation.

- **IR-007**: System MUST configure Zabbix monitoring for each Docker environment, tracking resource usage and container health metrics.

- **IR-008**: System MUST ensure automated backups include Docker environment metadata, Portainer configuration, and optionally Docker volumes (user-configurable).

- **IR-009**: System MUST configure network isolation between Docker environments to prevent unauthorized cross-environment communication while allowing internet and internal registry access.

- **IR-010**: Traefik instance MUST obtain TLS certificates from Let's Encrypt using DNS-01 or HTTP-01 challenge, with automatic renewal before expiration.

### Security Requirements *(mandatory for all services)*

- **SR-001**: Platform dashboard MUST authenticate users via LDAP and enforce role-based access control (regular users vs. administrators).

- **SR-002**: Deployment API MUST authenticate requests using bearer tokens, API keys, or mutual TLS, with tokens stored in Ansible Vault.

- **SR-003**: Each Docker environment's management GUI MUST enforce authentication, with credentials unique per environment and securely generated during provisioning.

- **SR-004**: System MUST NOT expose Docker daemon sockets or container APIs directly to users; all access MUST be mediated through the management GUI or platform API.

- **SR-005**: System MUST enforce HTTPS for all web interfaces (dashboard, management GUIs) with valid TLS certificates, prohibiting HTTP access.

- **SR-006**: LXC containers running Docker environments MUST run unprivileged to limit impact of container breakout vulnerabilities.

- **SR-007**: System MUST implement network policies or firewall rules preventing Docker containers in one environment from accessing containers in another environment directly.

- **SR-008**: System MUST log all API authentication attempts, environment lifecycle actions, and administrative operations for security auditing.

- **SR-009**: System MUST securely store and transmit container registry credentials, deployment tokens, and management GUI passwords using encryption at rest and in transit.

- **SR-010**: System MUST implement rate limiting on the deployment API to prevent abuse and resource exhaustion attacks.

### Key Entities

- **Docker Environment**: An isolated LXC container running Docker engine and management GUI, assigned to a user or LDAP group. When owned by an LDAP group, all group members have full access to manage the environment. Attributes include project name (unique identifier), owner (username or LDAP group name), owner type (user or group), HTTPS URL, resource quota (CPU, RAM, disk), status (provisioning, ready, paused, deleted), and creation timestamp.

- **User**: An authenticated individual with access to the platform. Attributes include username, email, roles (user, admin), owned environments (list), and quotas (max environments, total resources). Users authenticate via LDAP.

- **Container Registry Credentials**: Authentication details for accessing the internal container registry. Includes registry URL, username, password/token, and associated Docker environment. Used by Portainer and CI/CD pipelines to pull private images.

- **Deployment Token**: An API credential that allows CI/CD pipelines to trigger deployments to a specific Docker environment. Attributes include token value (hashed), environment ID, creation date, expiration date, and permissions (deploy, read status).

- **Resource Quota**: Limits applied to a Docker environment or user. Attributes include maximum CPU cores, maximum RAM (GB), maximum disk space (GB), maximum number of environments per user. Enforced at LXC level and during provisioning.

- **Environment Snapshot**: A point-in-time backup of a Docker environment's state. Attributes include snapshot ID, environment ID, creation timestamp, size (GB), description, and retention policy (number of days until automatic deletion).

- **Audit Log Entry**: A record of a significant platform event. Attributes include timestamp, user ID, action type (create, deploy, pause, delete), environment ID, IP address, and result (success, failure, error message).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Authenticated users can successfully request and receive a fully functional Docker environment with HTTPS access in under 5 minutes from submission to ready status.

- **SC-002**: Users can deploy a container from a public registry through the management GUI and access it via HTTPS in under 2 minutes from initiating deployment.

- **SC-003**: CI/CD pipelines can authenticate, build, push, and deploy container images to Docker environments with 95% success rate and complete the full cycle in under 10 minutes.

- **SC-004**: System maintains 99% uptime for the platform dashboard and deployment API, measured over a 30-day period, excluding scheduled maintenance windows.

- **SC-005**: Resource isolation prevents one Docker environment from consuming more than its allocated quota, verified by load testing with 10 concurrent environments under stress.

- **SC-006**: Environment provisioning succeeds for at least 95% of requests on first attempt, with failures clearly reported to users with actionable error messages within 1 minute of failure.

- **SC-007**: All Docker environments serve traffic exclusively over HTTPS with valid TLS certificates (not self-signed), verified by automated certificate checks across all active environments.

- **SC-008**: Users can pause and resume their Docker environments with preserved container configuration and data, achieving full resume (all containers running) within 3 minutes of resume action.

- **SC-009**: Zero unauthorized cross-environment container access, verified through security testing with containers attempting to reach other environments' networks.

- **SC-010**: Administrators can manage platform-wide operations (approve requests, set quotas, view all environments) through the dashboard in under 30 seconds per action with no command-line access required.

## Assumptions

- Virtualization host (Proxmox VE) API is accessible and permits programmatic LXC container management (creation, configuration, lifecycle operations).
- Existing Traefik instance or new dedicated instance can be configured to dynamically add routing rules and obtain Let's Encrypt certificates via DNS-01 or HTTP-01 challenges.
- DNS infrastructure supports automatic creation of A/AAAA records or wildcard DNS entry (*.docker.example.com) points to Traefik host.
- Internal container registry (GitLab Container Registry) is operational and accessible from Docker environments with proper authentication mechanisms.
- LDAP directory contains user accounts and group memberships that the platform can query for authentication and authorization.
- Debian 13 (Trixie) LXC template with Docker pre-installed exists or can be created as a reusable base image.
- Portainer Community Edition licensing permits use for internal self-service platform deployment across multiple isolated instances.
- Proxmox host has sufficient resources (CPU, RAM, disk, network bandwidth) to support multiple concurrent Docker environments based on expected user demand.
- GitLab CI/CD runners can reach the platform deployment API endpoint over the network (not blocked by firewalls).
- Users have basic familiarity with Docker concepts (containers, images, registries) or platform provides adequate onboarding documentation.
- Resource quota defaults (e.g., 2 CPU cores, 4GB RAM, 50GB disk per environment) are reasonable for expected workloads and can be adjusted based on usage patterns.
- Network architecture supports VLAN or network namespace isolation for Docker environments if required for security policy compliance.
