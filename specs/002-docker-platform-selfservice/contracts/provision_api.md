# API Contract: Environment Provisioning

**Feature**: 002-docker-platform-selfservice
**Contract**: Provision Docker Environment
**Version**: 1.0

## Endpoint

```
POST /api/environments
```

## Purpose

Create a new Docker environment with LXC container, Docker Engine, Portainer Agent, and Traefik routing. Validates resource quotas and auto-approves or queues for admin approval.

## Request

### Headers

```
Content-Type: application/json
Authorization: Bearer <jwt-token>
X-User-DN: <ldap-user-dn>
```

### Body

```json
{
  "name": "string (required)",
  "owner_type": "user | team (required)",
  "owner_id": "string (required)",
  "description": "string (optional)",
  "tags": ["string"] (optional),
  "resources": {
    "cpu_cores": "integer (required, min: 1, max: 32)",
    "memory_mb": "integer (required, min: 512, max: 32768)",
    "disk_gb": "integer (required, min: 10, max: 500)",
    "max_containers": "integer (optional, default: 20)"
  },
  "notifications": {
    "email": ["string (email)"] (optional),
    "webhooks": ["string (url)"] (optional)
  },
  "proxmox_node": "string (optional, defaults to least-loaded node)"
}
```

### Validation Rules

- **name**: Must be 3-32 characters, lowercase, alphanumeric, hyphens only, no leading/trailing hyphens
- **owner_id**: Must be valid LDAP DN (for user) or LDAP group DN (for team)
- **resources.cpu_cores**: Must be within quota limits (default: ≤4)
- **resources.memory_mb**: Must be within quota limits (default: ≤8192)
- **resources.disk_gb**: Must be within quota limits (default: ≤50)
- **notifications.webhooks**: Must be valid HTTPS URLs

### Example Request

```json
{
  "name": "myapp-dev",
  "owner_type": "team",
  "owner_id": "cn=devops,ou=groups,dc=example,dc=com",
  "description": "Development environment for myapp microservices",
  "tags": ["development", "myapp", "team-devops"],
  "resources": {
    "cpu_cores": 4,
    "memory_mb": 8192,
    "disk_gb": 30,
    "max_containers": 15
  },
  "notifications": {
    "email": ["devops@example.com"],
    "webhooks": ["https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"]
  }
}
```

## Response

### Success - Auto-Approved (201 Created)

When request is within quota limits, environment is provisioned immediately.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "provisioning",
  "name": "myapp-dev",
  "owner_type": "team",
  "owner_id": "cn=devops,ou=groups,dc=example,dc=com",
  "vmid": 250,
  "created_at": "2025-10-20T10:30:00Z",
  "estimated_completion": "2025-10-20T10:35:00Z",
  "resources": {
    "cpu_cores": 4,
    "memory_mb": 8192,
    "disk_gb": 30,
    "max_containers": 15
  },
  "quota_status": {
    "within_quota": true,
    "auto_approved": true
  },
  "_links": {
    "self": "/api/environments/550e8400-e29b-41d4-a716-446655440000",
    "status": "/api/environments/550e8400-e29b-41d4-a716-446655440000/status",
    "portainer": "https://portainer.docker.example.com"
  }
}
```

### Success - Pending Approval (202 Accepted)

When request exceeds quota limits, it's queued for admin approval.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "status": "pending_approval",
  "name": "myapp-dev",
  "owner_type": "team",
  "owner_id": "cn=devops,ou=groups,dc=example,dc=com",
  "created_at": "2025-10-20T10:30:00Z",
  "resources": {
    "cpu_cores": 8,
    "memory_mb": 16384,
    "disk_gb": 100,
    "max_containers": 50
  },
  "quota_status": {
    "within_quota": false,
    "auto_approved": false,
    "exceeded_limits": {
      "cpu_cores": {"requested": 8, "quota": 4, "exceeded_by": 4},
      "memory_mb": {"requested": 16384, "quota": 8192, "exceeded_by": 8192},
      "disk_gb": {"requested": 100, "quota": 50, "exceeded_by": 50}
    }
  },
  "approval": {
    "required": true,
    "notification_sent_to": ["admin@example.com"],
    "estimated_review_time": "24 hours"
  },
  "_links": {
    "self": "/api/environments/550e8400-e29b-41d4-a716-446655440001",
    "approval_status": "/api/environments/550e8400-e29b-41d4-a716-446655440001/approval"
  }
}
```

### Error Responses

#### 400 Bad Request - Validation Failed

```json
{
  "error": "validation_error",
  "message": "Request validation failed",
  "details": [
    {
      "field": "name",
      "error": "must be 3-32 characters, lowercase, alphanumeric, hyphens only",
      "provided": "MyApp-DEV!"
    },
    {
      "field": "resources.cpu_cores",
      "error": "must be between 1 and 32",
      "provided": 64
    }
  ]
}
```

#### 401 Unauthorized

```json
{
  "error": "unauthorized",
  "message": "Valid JWT token required",
  "details": "Authorization header missing or invalid"
}
```

#### 403 Forbidden - Insufficient Permissions

```json
{
  "error": "forbidden",
  "message": "User does not have permission to create team-owned environments",
  "details": "User 'uid=jdoe,ou=users,dc=example,dc=com' is not a member of group 'cn=devops,ou=groups,dc=example,dc=com'"
}
```

#### 409 Conflict - Name Already Exists

```json
{
  "error": "conflict",
  "message": "Environment name already exists",
  "details": "Environment 'myapp-dev' already exists with ID 550e8400-e29b-41d4-a716-446655440002"
}
```

#### 503 Service Unavailable - Proxmox Unavailable

```json
{
  "error": "service_unavailable",
  "message": "Cannot connect to Proxmox API",
  "details": "Connection to pve.example.com failed after 3 retries",
  "retry_after": 60
}
```

## Ansible Implementation

### Playbook: `playbooks/provision_docker_env.yml`

```yaml
---
- name: Provision Docker environment via API call
  hosts: localhost
  gather_facts: no

  tasks:
    - name: Validate environment name format
      assert:
        that:
          - environment_name | length >= 3
          - environment_name | length <= 32
          - environment_name | regex_search('^[a-z0-9-]+$')
          - not environment_name.startswith('-')
          - not environment_name.endswith('-')
        fail_msg: "Invalid environment name format"

    - name: Validate LDAP owner exists
      community.general.ldap_search:
        dn: "{{ owner_id }}"
        server_uri: "{{ ldap_url }}"
        bind_dn: "{{ ldap_bind_dn }}"
        bind_pw: "{{ ldap_bind_password }}"
      register: ldap_check

    - name: Check quota limits
      set_fact:
        quota_check:
          within_quota: >-
            {{ (environment_cpu_cores | int) <= (docker_platform_default_quotas.cpu_cores | int) and
               (environment_memory_mb | int) <= (docker_platform_default_quotas.memory_mb | int) and
               (environment_disk_size | int) <= (docker_platform_default_quotas.disk_gb | int) }}
          exceeded_limits: {}

    - name: Calculate exceeded limits
      set_fact:
        quota_check: >-
          {{ quota_check | combine({
            'exceeded_limits': {
              'cpu_cores': {
                'requested': environment_cpu_cores | int,
                'quota': docker_platform_default_quotas.cpu_cores | int,
                'exceeded_by': (environment_cpu_cores | int) - (docker_platform_default_quotas.cpu_cores | int)
              } if (environment_cpu_cores | int) > (docker_platform_default_quotas.cpu_cores | int) else {},
              'memory_mb': {
                'requested': environment_memory_mb | int,
                'quota': docker_platform_default_quotas.memory_mb | int,
                'exceeded_by': (environment_memory_mb | int) - (docker_platform_default_quotas.memory_mb | int)
              } if (environment_memory_mb | int) > (docker_platform_default_quotas.memory_mb | int) else {},
              'disk_gb': {
                'requested': environment_disk_size | int,
                'quota': docker_platform_default_quotas.disk_gb | int,
                'exceeded_by': (environment_disk_size | int) - (docker_platform_default_quotas.disk_gb | int)
              } if (environment_disk_size | int) > (docker_platform_default_quotas.disk_gb | int) else {}
            }
          }) }}
      when: not (quota_check.within_quota | bool)

    - name: Auto-approve within quota
      debug:
        msg: "Request within quota - proceeding with provisioning"
      when: quota_check.within_quota | bool

    - name: Request approval for over-quota
      uri:
        url: "{{ api_base_url }}/api/provisioning-requests"
        method: POST
        headers:
          Content-Type: "application/json"
          Authorization: "Bearer {{ api_jwt_token }}"
        body_format: json
        body:
          environment_name: "{{ environment_name }}"
          owner_type: "{{ owner_type }}"
          owner_id: "{{ owner_id }}"
          resources:
            cpu_cores: "{{ environment_cpu_cores }}"
            memory_mb: "{{ environment_memory_mb }}"
            disk_gb: "{{ environment_disk_size }}"
          quota_check: "{{ quota_check }}"
        status_code: 202
      register: approval_request
      when: not (quota_check.within_quota | bool)

    - name: Provision environment (auto-approved)
      include_role:
        name: docker_platform
      vars:
        provision_mode: "auto_approved"
      when: quota_check.within_quota | bool
```

## State Transitions

```
Request submitted → Quota validation
                        ├─ Within quota → Provisioning → Active
                        └─ Exceeds quota → Pending Approval
                                              ├─ Approved → Provisioning → Active
                                              └─ Rejected → Rejected (terminal)
```

## Idempotency

- **Duplicate requests**: Submitting identical request returns existing environment ID with 200 OK (not 201)
- **Name collision**: Different resources with same name returns 409 Conflict
- **Re-provisioning**: If environment exists but status=failed, new request triggers re-provisioning

## Performance Expectations

- **Validation**: <500ms
- **Auto-approved provisioning**: 3-5 minutes total
- **Approval queue**: 24-48 hours (human review)
- **Concurrent requests**: Supports up to 10 simultaneous provisions per Proxmox node

## Security

- **Authentication**: JWT token with LDAP user DN claim
- **Authorization**: User must be owner or member of owner group
- **Audit logging**: All requests logged with user DN, timestamp, resources, approval status
- **Rate limiting**: 10 requests per user per hour, 100 requests per team per day
