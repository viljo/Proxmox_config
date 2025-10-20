# Data Model: Self-Service Docker Platform

**Feature**: 002-docker-platform-selfservice
**Phase**: 1 - Design
**Date**: 2025-10-20

## Core Entities

### 1. DockerEnvironment

Represents a complete Docker environment provisioned in an LXC container.

**Attributes**:
- `id` (string, UUID): Unique identifier
- `name` (string): Human-readable environment name (DNS-safe, lowercase, hyphens)
- `vmid` (integer): Proxmox LXC container ID (100-999)
- `owner_type` (enum): "user" | "team"
- `owner_id` (string): LDAP user DN or LDAP group DN
- `status` (enum): "pending" | "provisioning" | "active" | "failed" | "deleting" | "deleted"
- `created_at` (datetime): Timestamp of request
- `provisioned_at` (datetime): Timestamp when provisioning completed
- `deleted_at` (datetime, nullable): Timestamp when deleted
- `proxmox_node` (string): Target Proxmox node name
- `lxc_ip_address` (string, IPv4): Assigned IP address
- `portainer_endpoint_id` (integer): Portainer endpoint ID
- `netbox_device_id` (integer): NetBox device record ID

**Resources**:
- `cpu_cores` (integer): Allocated CPU cores
- `memory_mb` (integer): Allocated memory in MB
- `disk_gb` (integer): Allocated disk size in GB
- `max_containers` (integer): Container limit for this environment

**Metadata**:
- `description` (string): User-provided description
- `tags` (array[string]): User-defined tags (e.g., "development", "staging", "team-alpha")
- `notifications` (object): Notification configuration
  - `email` (array[string]): Email addresses
  - `webhooks` (array[string]): Webhook URLs

**Relations**:
- Has many: `Container`
- Has many: `TraefikRoute`
- Owned by: `LDAPUser` or `LDAPGroup`

**Storage**: PostgreSQL table `docker_environments`, NetBox device with custom fields

---

### 2. Container

Represents a Docker container running within a DockerEnvironment.

**Attributes**:
- `id` (string, UUID): Unique identifier
- `environment_id` (string, UUID): Foreign key to DockerEnvironment
- `name` (string): Container name (unique within environment)
- `image` (string): Docker image (e.g., "nginx:1.25")
- `tag` (string): Image tag
- `status` (enum): "running" | "stopped" | "failed" | "updating"
- `created_at` (datetime): First deployment timestamp
- `updated_at` (datetime): Last update timestamp
- `version` (string): Current deployed version/tag
- `previous_version` (string, nullable): Previous version for rollback

**Configuration**:
- `ports` (array[object]): Port mappings
  - `container_port` (integer)
  - `host_port` (integer, optional)
  - `protocol` (enum): "tcp" | "udp"
- `env_vars` (object): Environment variables (key-value pairs)
- `volumes` (array[object]): Volume mounts
  - `source` (string): Host path or volume name
  - `target` (string): Container mount path
  - `read_only` (boolean)
- `networks` (array[string]): Docker networks
- `restart_policy` (enum): "no" | "always" | "unless-stopped" | "on-failure"

**Health Check**:
- `health_check_enabled` (boolean)
- `health_check_endpoint` (string): HTTP endpoint path (e.g., "/health")
- `health_check_port` (integer)
- `health_check_interval` (integer): Seconds between checks
- `health_check_timeout` (integer): Timeout in seconds
- `health_check_retries` (integer): Max retries before marking unhealthy

**Relations**:
- Belongs to: `DockerEnvironment`
- Has many: `TraefikRoute`

**Storage**: Not persisted in database - queried from Portainer API and Docker API in real-time

---

### 3. TraefikRoute

Represents an HTTPS routing rule in Traefik for accessing a container.

**Attributes**:
- `id` (string, UUID): Unique identifier
- `environment_id` (string, UUID): Foreign key to DockerEnvironment
- `container_name` (string, nullable): Associated container (if applicable)
- `hostname` (string): Full domain name (e.g., "myapp.docker.example.com")
- `path_prefix` (string, optional): Path-based routing (e.g., "/api")
- `backend_url` (string): Target URL (e.g., "http://10.0.1.50:8080")
- `tls_enabled` (boolean): HTTPS enabled
- `cert_resolver` (string): Let's Encrypt resolver name
- `created_at` (datetime)
- `updated_at` (datetime)

**Configuration**:
- `middlewares` (array[string]): Traefik middleware names (e.g., "auth", "compress")
- `priority` (integer): Route priority for overlapping rules
- `load_balancer_sticky` (boolean): Enable sticky sessions

**Relations**:
- Belongs to: `DockerEnvironment`
- Optionally belongs to: `Container`

**Storage**: File-based in `/etc/traefik/dynamic/{environment_name}-{route_id}.yml`, metadata in PostgreSQL

---

### 4. LDAPUser

Represents a user authenticated via LDAP/Keycloak.

**Attributes**:
- `dn` (string): LDAP Distinguished Name (unique identifier)
- `uid` (string): Username
- `email` (string): Email address
- `display_name` (string): Full name
- `groups` (array[string]): LDAP group DNs user is member of

**Relations**:
- Member of: `LDAPGroup` (many-to-many)
- Owns: `DockerEnvironment` (when owner_type = "user")

**Storage**: LDAP directory (read-only from platform perspective)

---

### 5. LDAPGroup

Represents a team/group in LDAP for collaborative environment ownership.

**Attributes**:
- `dn` (string): LDAP Distinguished Name
- `cn` (string): Common name (group name)
- `gid_number` (integer): POSIX group ID
- `member_uids` (array[string]): Member usernames
- `portainer_team_id` (integer, nullable): Mapped Portainer team ID

**Relations**:
- Has many: `LDAPUser` (members)
- Owns: `DockerEnvironment` (when owner_type = "team")

**Storage**: LDAP directory (read-only), Portainer team mapping in PostgreSQL

---

### 6. ResourceQuota

Represents resource allocation limits for auto-approval logic.

**Attributes**:
- `id` (string, UUID): Unique identifier
- `name` (string): Quota profile name (e.g., "default", "premium")
- `cpu_limit` (integer): Max CPU cores
- `memory_limit_mb` (integer): Max memory in MB
- `disk_limit_gb` (integer): Max disk size in GB
- `max_environments_per_user` (integer): Environment count limit per user
- `max_environments_per_team` (integer): Environment count limit per team
- `max_containers_per_environment` (integer): Container count limit

**Relations**:
- Applied to: `DockerEnvironment` (via default or assigned quota)

**Storage**: Ansible defaults in `roles/docker_platform/defaults/main.yml`, overridable in PostgreSQL

---

### 7. ProvisioningRequest

Represents an environment creation request with approval workflow.

**Attributes**:
- `id` (string, UUID): Unique identifier
- `requested_by` (string): LDAP user DN
- `requested_at` (datetime): Request timestamp
- `status` (enum): "pending_approval" | "approved" | "rejected" | "provisioned" | "failed"
- `approved_by` (string, nullable): LDAP user DN of approver
- `approved_at` (datetime, nullable)
- `rejection_reason` (string, nullable)

**Requested Resources**:
- `environment_name` (string)
- `owner_type` (enum): "user" | "team"
- `owner_id` (string)
- `cpu_cores` (integer)
- `memory_mb` (integer)
- `disk_gb` (integer)
- `description` (string)
- `tags` (array[string])

**Quota Check**:
- `exceeds_quota` (boolean): Whether request exceeds default quotas
- `quota_profile` (string): Applied quota profile name

**Relations**:
- Creates: `DockerEnvironment` (after approval and provisioning)

**Storage**: PostgreSQL table `provisioning_requests`, optionally GitLab issues for tracking

---

## Data Flows

### Flow 1: Environment Provisioning

```
1. User submits request → ProvisioningRequest created (status: pending_approval)
2. Quota validation:
   - Within quota → Auto-approve (status: approved)
   - Exceeds quota → Notify admin, wait for approval
3. Approved request triggers Ansible playbook:
   - Create LXC via Proxmox API → Assign VMID, allocate resources
   - Record in NetBox → Create device, set custom fields
   - Install Docker in LXC → Ansible role execution
   - Deploy Portainer Agent → Docker Compose
   - Register Portainer Endpoint → API call with team assignment
4. DockerEnvironment created (status: active)
5. ProvisioningRequest updated (status: provisioned)
6. Notifications sent (email, webhooks)
```

### Flow 2: Container Deployment with Rolling Update

```
1. User triggers deployment via GitLab CI or Portainer UI
2. Container configuration validated
3. Health check configuration verified
4. Rolling update process:
   - Pull new image
   - Start new container (name-new)
   - Health check loop (12 retries × 5s)
   - If healthy:
     - Update Traefik route to new backend
     - Wait 30s grace period
     - Stop old container
     - Rename new container
   - If unhealthy:
     - Stop and remove new container
     - Rollback (keep old container running)
     - Notify failure
5. Container record updated (version, status)
```

### Flow 3: HTTPS Route Registration

```
1. Container deployed with exposed ports
2. User requests HTTPS access via Portainer UI or API
3. TraefikRoute created:
   - Hostname: {container-name}.{environment-name}.docker.example.com
   - Backend: http://{lxc_ip}:{container_port}
4. Ansible template generates Traefik dynamic config file
5. Deploy config to Traefik host → /etc/traefik/dynamic/{env}-{route}.yml
6. Traefik watches directory, hot-reloads config
7. Let's Encrypt certificate requested (DNS-01 or HTTP-01)
8. Certificate obtained and cached
9. HTTPS route active within 5 minutes
```

### Flow 4: Team-Based Access Control

```
1. Environment created with owner_type = "team", owner_id = {ldap_group_dn}
2. LDAP group mapped to Portainer team:
   - Check if Portainer team exists for group
   - If not, create team via API
   - Store mapping: portainer_team_id in LDAPGroup record
3. Portainer endpoint assigned to team with access level
4. LDAP group members queried
5. Each member granted access to:
   - Environment in Portainer (via team membership)
   - Environment metadata in platform database
6. LDAP sync runs every 5 minutes:
   - Query LDAP for group membership changes
   - Update Portainer team members
   - Revoke access for removed members
```

## State Machines

### DockerEnvironment Status States

```
pending → provisioning → active
            ↓               ↓
          failed          deleting → deleted

States:
- pending: Request created, awaiting approval
- provisioning: LXC creation and setup in progress
- active: Environment running and accessible
- failed: Provisioning failed, manual intervention required
- deleting: Deletion in progress
- deleted: Environment removed, historical record retained
```

### ProvisioningRequest Status States

```
pending_approval → approved → provisioned
       ↓                ↓
   rejected          failed

States:
- pending_approval: Within quota (auto) or awaiting admin approval
- approved: Approved for provisioning
- rejected: Admin denied request
- provisioned: Environment successfully created
- failed: Provisioning failed
```

### Container Status States

```
stopped → running ⇄ updating
            ↓
          failed

States:
- stopped: Container exists but not running
- running: Container active and healthy
- updating: Rolling update in progress
- failed: Health checks failed or container crashed
```

## Persistence Strategy

| Entity | Storage | Rationale |
|--------|---------|-----------|
| **DockerEnvironment** | PostgreSQL + NetBox | PostgreSQL for platform metadata, NetBox for infrastructure inventory (CMDB) |
| **Container** | Runtime (Portainer API) | Containers are ephemeral, queried in real-time from Docker API via Portainer |
| **TraefikRoute** | File-based + PostgreSQL metadata | Files are Traefik's source of truth, PostgreSQL tracks metadata for UI/API |
| **LDAPUser** | LDAP (external) | LDAP is authoritative source, platform queries read-only |
| **LDAPGroup** | LDAP + Portainer mapping | LDAP for membership, PostgreSQL for Portainer team mapping |
| **ResourceQuota** | Ansible defaults + PostgreSQL overrides | Git-managed defaults, database for custom quotas |
| **ProvisioningRequest** | PostgreSQL + GitLab issues | PostgreSQL for workflow state, GitLab for human-readable tracking |

## Query Patterns

### 1. List Environments for User

**Query**: Get all environments owned by user or their teams

```sql
SELECT e.*
FROM docker_environments e
LEFT JOIN ldap_users u ON e.owner_id = u.dn AND e.owner_type = 'user'
LEFT JOIN ldap_group_members gm ON e.owner_id = gm.group_dn AND e.owner_type = 'team'
WHERE (e.owner_type = 'user' AND e.owner_id = :user_dn)
   OR (e.owner_type = 'team' AND gm.user_dn = :user_dn)
   AND e.status != 'deleted'
ORDER BY e.created_at DESC;
```

### 2. Check Quota Usage for User

**Query**: Calculate current resource consumption vs quota

```sql
SELECT
  COUNT(*) as environment_count,
  SUM(cpu_cores) as total_cpu,
  SUM(memory_mb) as total_memory,
  SUM(disk_gb) as total_disk
FROM docker_environments
WHERE (owner_type = 'user' AND owner_id = :user_dn)
   OR (owner_type = 'team' AND owner_id IN (
     SELECT group_dn FROM ldap_group_members WHERE user_dn = :user_dn
   ))
   AND status = 'active';
```

### 3. Find Pending Approval Requests

**Query**: Get requests exceeding quota awaiting admin approval

```sql
SELECT pr.*
FROM provisioning_requests pr
WHERE pr.status = 'pending_approval'
  AND pr.exceeds_quota = true
ORDER BY pr.requested_at ASC;
```

### 4. Get Environment Health Status

**Query**: Aggregate container health for environment dashboard

```python
# Via Portainer API + Database join
environment = db.query(DockerEnvironment).filter_by(id=env_id).first()
containers = portainer_client.get_containers(environment.portainer_endpoint_id)

health_summary = {
    "total": len(containers),
    "running": sum(1 for c in containers if c.status == "running"),
    "stopped": sum(1 for c in containers if c.status == "stopped"),
    "failed": sum(1 for c in containers if c.status == "failed"),
}
```

## Validation Rules

### DockerEnvironment

- `name`: Must be DNS-safe (lowercase, alphanumeric, hyphens, 3-32 chars)
- `vmid`: Must be unique across Proxmox cluster (100-999 range)
- `cpu_cores`: Must be ≥1, ≤quota limit
- `memory_mb`: Must be ≥512, ≤quota limit
- `disk_gb`: Must be ≥10, ≤quota limit
- `owner_id`: Must exist in LDAP (validate DN)

### Container

- `name`: Must be unique within environment, alphanumeric + hyphens
- `ports`: No duplicate `host_port` values within environment
- `health_check_endpoint`: Must start with "/" if enabled
- `env_vars`: Keys must be valid environment variable names (uppercase, underscores)

### TraefikRoute

- `hostname`: Must be valid FQDN, unique across all routes
- `backend_url`: Must be valid HTTP/HTTPS URL
- `priority`: Higher priority for more specific routes

## Indexes

```sql
-- DockerEnvironment
CREATE INDEX idx_docker_env_owner ON docker_environments(owner_type, owner_id);
CREATE INDEX idx_docker_env_status ON docker_environments(status);
CREATE INDEX idx_docker_env_vmid ON docker_environments(vmid);

-- ProvisioningRequest
CREATE INDEX idx_prov_req_status ON provisioning_requests(status);
CREATE INDEX idx_prov_req_requested_by ON provisioning_requests(requested_by);
CREATE INDEX idx_prov_req_exceeds_quota ON provisioning_requests(exceeds_quota, status);

-- TraefikRoute
CREATE UNIQUE INDEX idx_traefik_hostname ON traefik_routes(hostname);
CREATE INDEX idx_traefik_environment ON traefik_routes(environment_id);
```
