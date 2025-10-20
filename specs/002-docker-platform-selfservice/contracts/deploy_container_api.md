# API Contract: Container Deployment

**Feature**: 002-docker-platform-selfservice
**Contract**: Deploy Container with Rolling Update
**Version**: 1.0

## Endpoint

```
POST /api/environments/{environment_id}/containers
```

## Purpose

Deploy a Docker container into an existing environment with rolling update strategy, health checks, and automatic rollback on failure.

## Request

### Headers

```
Content-Type: application/json
Authorization: Bearer <jwt-token>
X-User-DN: <ldap-user-dn>
```

### Path Parameters

- `environment_id` (UUID): Target environment identifier

### Body

```json
{
  "name": "string (required)",
  "image": "string (required)",
  "tag": "string (required)",
  "ports": [
    {
      "container_port": "integer (required)",
      "host_port": "integer (optional)",
      "protocol": "tcp | udp (default: tcp)"
    }
  ],
  "env_vars": {
    "KEY": "value"
  } (optional),
  "volumes": [
    {
      "source": "string (required)",
      "target": "string (required)",
      "read_only": "boolean (default: false)"
    }
  ] (optional),
  "restart_policy": "no | always | unless-stopped | on-failure (default: unless-stopped)",
  "health_check": {
    "enabled": "boolean (default: true)",
    "endpoint": "string (required if enabled)",
    "port": "integer (required if enabled)",
    "interval": "integer (default: 5)",
    "timeout": "integer (default: 5)",
    "retries": "integer (default: 12)"
  } (optional),
  "https_routing": {
    "enabled": "boolean (default: false)",
    "hostname": "string (required if enabled)",
    "path_prefix": "string (optional, e.g., /api)",
    "middlewares": ["string"] (optional)
  } (optional)
}
```

### Validation Rules

- **name**: Must be 2-64 characters, alphanumeric, hyphens, underscores only
- **image**: Must be valid Docker image name (e.g., "nginx", "registry.gitlab.com/group/project")
- **tag**: Must be valid tag (e.g., "latest", "1.25.0", "sha256:abc123...")
- **ports.host_port**: Must be unique within environment (1024-65535 range recommended)
- **volumes.source**: Must be absolute path or named volume
- **health_check.endpoint**: Must start with "/" if HTTP endpoint
- **https_routing.hostname**: Must be valid FQDN under `*.docker.example.com` or custom domain

### Example Request

```json
{
  "name": "api-backend",
  "image": "registry.gitlab.com/myteam/myapp/api",
  "tag": "v1.2.3",
  "ports": [
    {
      "container_port": 8080,
      "host_port": 8080,
      "protocol": "tcp"
    }
  ],
  "env_vars": {
    "DATABASE_URL": "postgresql://db.example.com/myapp",
    "LOG_LEVEL": "info",
    "ENVIRONMENT": "production"
  },
  "volumes": [
    {
      "source": "/var/data/myapp",
      "target": "/app/data",
      "read_only": false
    }
  ],
  "restart_policy": "unless-stopped",
  "health_check": {
    "enabled": true,
    "endpoint": "/health",
    "port": 8080,
    "interval": 5,
    "timeout": 5,
    "retries": 12
  },
  "https_routing": {
    "enabled": true,
    "hostname": "api.myapp.docker.example.com",
    "path_prefix": null,
    "middlewares": ["compress", "rate-limit"]
  }
}
```

## Response

### Success - New Deployment (201 Created)

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440010",
  "environment_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "api-backend",
  "image": "registry.gitlab.com/myteam/myapp/api:v1.2.3",
  "status": "running",
  "version": "v1.2.3",
  "created_at": "2025-10-20T11:00:00Z",
  "updated_at": "2025-10-20T11:00:00Z",
  "deployment": {
    "strategy": "rolling",
    "health_check_passed": true,
    "rollback_triggered": false,
    "deployment_time_seconds": 45
  },
  "https_url": "https://api.myapp.docker.example.com",
  "container_details": {
    "id": "abc123def456",
    "state": "running",
    "started_at": "2025-10-20T11:00:00Z",
    "ports": {
      "8080/tcp": "8080"
    }
  },
  "_links": {
    "self": "/api/environments/550e8400-e29b-41d4-a716-446655440000/containers/660e8400-e29b-41d4-a716-446655440010",
    "logs": "/api/environments/550e8400-e29b-41d4-a716-446655440000/containers/660e8400-e29b-41d4-a716-446655440010/logs",
    "portainer": "https://portainer.docker.example.com/#!/2/docker/containers/abc123def456"
  }
}
```

### Success - Rolling Update (200 OK)

When container already exists, performs rolling update.

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440010",
  "environment_id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "api-backend",
  "image": "registry.gitlab.com/myteam/myapp/api:v1.2.4",
  "status": "running",
  "version": "v1.2.4",
  "previous_version": "v1.2.3",
  "created_at": "2025-10-20T11:00:00Z",
  "updated_at": "2025-10-20T11:15:00Z",
  "deployment": {
    "strategy": "rolling",
    "health_check_passed": true,
    "rollback_triggered": false,
    "deployment_time_seconds": 52,
    "update_type": "version_upgrade",
    "old_container_removed": true
  },
  "https_url": "https://api.myapp.docker.example.com",
  "container_details": {
    "id": "xyz789abc012",
    "state": "running",
    "started_at": "2025-10-20T11:15:00Z",
    "ports": {
      "8080/tcp": "8080"
    }
  },
  "_links": {
    "self": "/api/environments/550e8400-e29b-41d4-a716-446655440000/containers/660e8400-e29b-41d4-a716-446655440010",
    "logs": "/api/environments/550e8400-e29b-41d4-a716-446655440000/containers/660e8400-e29b-41d4-a716-446655440010/logs"
  }
}
```

### Error - Health Check Failed with Rollback (500 Internal Server Error)

```json
{
  "error": "deployment_failed",
  "message": "Container health check failed, rolled back to previous version",
  "details": {
    "container_name": "api-backend",
    "attempted_version": "v1.2.4",
    "health_check": {
      "endpoint": "/health",
      "port": 8080,
      "failed_attempts": 12,
      "last_error": "Connection refused",
      "error_code": "ECONNREFUSED"
    },
    "rollback": {
      "performed": true,
      "current_version": "v1.2.3",
      "container_id": "abc123def456",
      "status": "running"
    }
  },
  "current_state": {
    "version": "v1.2.3",
    "status": "running",
    "https_url": "https://api.myapp.docker.example.com"
  }
}
```

### Error Responses

#### 400 Bad Request - Port Conflict

```json
{
  "error": "port_conflict",
  "message": "Host port already in use by another container",
  "details": {
    "requested_port": 8080,
    "conflicting_container": "nginx-proxy",
    "conflicting_container_id": "def456abc789"
  }
}
```

#### 403 Forbidden - No Access to Environment

```json
{
  "error": "forbidden",
  "message": "User does not have access to this environment",
  "details": "User 'uid=jdoe,ou=users,dc=example,dc=com' is not owner or team member of environment 'myapp-dev'"
}
```

#### 404 Not Found - Environment Does Not Exist

```json
{
  "error": "not_found",
  "message": "Environment not found",
  "details": "No environment with ID 550e8400-e29b-41d4-a716-446655440099"
}
```

#### 409 Conflict - Container Name Exists

```json
{
  "error": "conflict",
  "message": "Container name already exists in this environment",
  "details": "Container 'api-backend' already exists with ID 660e8400-e29b-41d4-a716-446655440010. Use PUT to update."
}
```

#### 422 Unprocessable Entity - Invalid Image

```json
{
  "error": "invalid_image",
  "message": "Cannot pull Docker image",
  "details": {
    "image": "registry.gitlab.com/myteam/myapp/api:v1.2.4",
    "error": "manifest unknown: manifest unknown",
    "registry": "registry.gitlab.com"
  }
}
```

## Ansible Implementation

### Playbook: `playbooks/deploy_container.yml`

```yaml
---
- name: Deploy container with rolling update
  hosts: "{{ environment_name }}"
  gather_facts: no

  tasks:
    - name: Pull Docker image
      community.docker.docker_image:
        name: "{{ container_image }}"
        tag: "{{ container_tag }}"
        source: pull
        force_source: yes
      register: image_pull

    - name: Check if container exists (for rolling update)
      community.docker.docker_container_info:
        name: "{{ container_name }}"
      register: existing_container
      ignore_errors: yes

    - name: Start new container version
      community.docker.docker_container:
        name: "{{ container_name }}-new"
        image: "{{ container_image }}:{{ container_tag }}"
        state: started
        restart_policy: "{{ restart_policy | default('unless-stopped') }}"
        networks: "{{ container_networks | default(['bridge']) }}"
        env: "{{ container_env_vars | default({}) }}"
        ports: "{{ container_ports | map('format_port') | list }}"
        volumes: "{{ container_volumes | default([]) }}"
        labels:
          deployment_timestamp: "{{ ansible_date_time.epoch }}"
          version: "{{ container_tag }}"

    - name: Wait for container to start
      pause:
        seconds: 5

    - name: Perform health check
      uri:
        url: "http://localhost:{{ health_check_port }}{{ health_check_endpoint }}"
        status_code: 200
        timeout: "{{ health_check_timeout | default(5) }}"
      register: health_check
      retries: "{{ health_check_retries | default(12) }}"
      delay: "{{ health_check_interval | default(5) }}"
      until: health_check.status == 200
      when: health_check_enabled | default(true)

    - name: Rollback on health check failure
      block:
        - name: Stop and remove failed container
          community.docker.docker_container:
            name: "{{ container_name }}-new"
            state: absent

        - name: Notify rollback
          debug:
            msg: "Health check failed - container removed, previous version still running"

        - name: Fail deployment
          fail:
            msg: "Container deployment failed health checks"
      when:
        - health_check_enabled | default(true)
        - health_check is failed

    - name: Update Traefik route (if HTTPS enabled)
      ansible.builtin.template:
        src: roles/traefik_docker/templates/dynamic/route.yml.j2
        dest: "/etc/traefik/dynamic/{{ environment_name }}-{{ container_name }}.yml"
      vars:
        route_hostname: "{{ https_routing_hostname }}"
        route_backend: "http://{{ ansible_default_ipv4.address }}:{{ container_port }}"
      delegate_to: traefik_host
      notify: reload traefik config
      when: https_routing_enabled | default(false)

    - name: Wait for traffic switch grace period
      pause:
        seconds: 30
      when: existing_container.exists | default(false)

    - name: Stop and remove old container
      community.docker.docker_container:
        name: "{{ container_name }}"
        state: absent
      when: existing_container.exists | default(false)

    - name: Rename new container to primary name
      community.docker.docker_container:
        name: "{{ container_name }}-new"
        container_default_behavior: no_defaults
        comparisons:
          '*': ignore
        rename: "{{ container_name }}"

    - name: Send deployment notification
      uri:
        url: "{{ item }}"
        method: POST
        body_format: json
        body:
          text: "Container {{ container_name }} deployed successfully to {{ environment_name }}"
          version: "{{ container_tag }}"
          status: "running"
          url: "{{ https_url | default('N/A') }}"
        status_code: [200, 201, 202, 204]
      loop: "{{ webhook_urls | default([]) }}"
      when: webhook_urls is defined
```

## Rolling Update Process

### Step-by-Step Flow

1. **Pre-deployment**:
   - Validate request parameters
   - Check user permissions
   - Verify image exists in registry

2. **Pull Image**:
   - Pull new image version to LXC
   - Verify image SHA256 digest

3. **Blue-Green Start**:
   - Start new container with `-new` suffix
   - Use same network, volumes, env vars
   - Expose on different temporary port or same port (depends on strategy)

4. **Health Check Loop**:
   - Wait 5 seconds for startup
   - Perform HTTP GET to health endpoint
   - Retry up to 12 times with 5-second interval (60 seconds total)
   - Check for HTTP 200 status code

5. **Decision Point**:
   - **If healthy**: Proceed to traffic switch
   - **If unhealthy**: Trigger rollback (stop new, keep old)

6. **Traffic Switch** (if healthy):
   - Update Traefik dynamic config to new backend
   - Traefik hot-reloads config (no downtime)
   - Wait 30-second grace period for active connections to drain

7. **Cleanup**:
   - Stop old container
   - Remove old container
   - Rename new container from `{name}-new` to `{name}`

8. **Post-deployment**:
   - Send notifications (email, webhooks)
   - Update NetBox metadata
   - Log deployment event

### Rollback Triggers

- Health check fails after max retries
- Container crashes immediately after start
- Image pull fails
- Port binding conflicts
- Volume mount failures

## State Transitions

```
Request received → Image pull → New container start → Health check
                                         ↓                   ↓
                                    Port conflict    ┌─── Pass → Traffic switch → Old container stop → Success
                                         ↓           │
                                      Fail ──────────┴─── Fail → Rollback → Keep old running
```

## Idempotency

- **Duplicate deployment**: Same image:tag with same config → No-op, returns 200 OK with existing container info
- **Version change**: Different image:tag → Triggers rolling update
- **Config change**: Same image:tag but different env vars/ports → Recreates container with new config

## Performance Expectations

- **Image pull**: 10-120 seconds (depends on image size and registry speed)
- **Container start**: 2-10 seconds
- **Health check validation**: 5-60 seconds (configurable)
- **Traffic switch**: <5 seconds (Traefik hot-reload)
- **Total deployment time**: 30-180 seconds for successful deployment
- **Rollback time**: <10 seconds

## Security

- **Image registry authentication**: Supports private registries with credential injection
- **Environment variable secrets**: Sensitive env vars stored in Ansible Vault, injected at runtime
- **Volume permissions**: Enforces UID/GID mapping for unprivileged LXC
- **Network isolation**: Containers default to bridge network within LXC (no cross-environment access)
