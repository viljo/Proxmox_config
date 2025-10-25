# Service Verification Strategy

**Status**: Active
**Last Updated**: 2025-10-25
**Owner**: Infrastructure Team
**Type**: Essential Project Goal

## Problem Statement

Service deployments were completing successfully at the Ansible level but services were not actually accessible or functional. This created a false sense of success and required manual verification after every deployment.

**Example**: Redis playbook completed with all tasks "ok" but the service was not responding to PING commands due to missing directories, wrong permissions, and systemd configuration issues.

## Essential Project Goal

**REQUIREMENT**: All service deployment playbooks SHALL end with thorough verification that the service is up and working.

**CRITICAL**: Verification code MUST be in playbooks (`playbooks/*-deploy.yml`), NOT in roles (`roles/*/tasks/main.yml`).

### Why Playbooks, Not Roles?

1. **Visibility**: Verification is immediately visible when reading the playbook
2. **Separation of Concerns**: Roles handle deployment, playbooks orchestrate and verify
3. **Maintainability**: Easy to update verification without modifying role internals
4. **Clarity**: Clear distinction between "deploy" (role) and "verify" (playbook)
5. **Reusability**: Same role can be used with different verification strategies

### Verification Levels

Every service deployment MUST include verification at multiple levels:

#### Level 1: Container Health
- Container is running (`pct status`)
- Container networking is functional (can reach gateway, DNS)
- Container SSH/shell access works

#### Level 2: Process Health
- Service process is running (systemd status or docker ps)
- Service is listening on expected ports (`ss -tlnp`)
- Service logs show no critical errors

#### Level 3: Service Functionality
- **Database services**: Test connection and simple query
- **Web services**: HTTP/HTTPS returns expected status code (200, 301, etc.)
- **API services**: API endpoint returns valid response
- **Cache services**: Test SET/GET or PING commands
- **Message queue services**: Test publish/subscribe

#### Level 4: External Accessibility
- **Public services**: Service is accessible via public domain (HTTPS)
- **Internal services**: Service is accessible from other containers
- DNS resolution working correctly
- SSL certificates valid (for HTTPS services)

### Implementation

#### Playbook Structure (REQUIRED)

All deployment playbooks **MUST** follow this structure:

```yaml
---
- name: Deploy Service Name
  hosts: proxmox_admin
  gather_facts: false
  become: false

  tasks:
    # 1. Apply the deployment role
    - name: Apply service_name_api role
      ansible.builtin.include_role:
        name: service_name_api

    ##############################
    # SERVICE VERIFICATION       #
    ##############################

    # 2. Verify container/process health
    - name: "VERIFY: Check service process running"
      ansible.builtin.command:
        cmd: ssh root@{{ ansible_host }} "pct exec {{ service_container_id }} -- pgrep service_name"
      changed_when: false

    # 3. Verify network/port availability
    - name: "VERIFY: Check service port listening"
      ansible.builtin.wait_for:
        host: "{{ service_ip }}"
        port: "{{ service_port }}"
        timeout: 30
      delegate_to: localhost

    # 4. Verify service functionality (HTTP/database/etc)
    - name: "VERIFY: Test service functionality"
      # Service-specific functionality test (see examples below)

    # 5. Display verification results
    - name: "VERIFY: Display verification results"
      ansible.builtin.debug:
        msg:
          - "=== Service Name Verification Results ==="
          - "Check 1: {{ 'PASS' if check1_ok else 'FAIL' }}"
          - "Check 2: {{ 'PASS' if check2_ok else 'FAIL' }}"

    # 6. Fail playbook if verification failed
    - name: "VERIFY: Fail if critical checks failed"
      ansible.builtin.fail:
        msg:
          - "❌ Service verification FAILED"
          - "  Troubleshooting steps..."
      when: not (check1_ok and check2_ok)

    # 7. Display success message
    - name: "VERIFY: Display success message"
      ansible.builtin.debug:
        msg:
          - "✅ {{ service_name }} deployed and verified successfully"
          - "  URL: {{ service_url }}"
          - "  Status: FUNCTIONAL ✅"
```

#### Role Structure (deployment only, NO verification)

Roles handle deployment only:

```yaml
---
# roles/service_name_api/tasks/main.yml

- name: Create container via Proxmox API
  # ...

- name: Install service packages
  # ...

- name: Configure service
  # ...

- name: Start service
  # ...

# NO VERIFICATION TASKS HERE!
# Verification belongs in the playbook
```

#### Service-Specific Verification Examples

**PostgreSQL**:
```yaml
- name: "VERIFY: Test PostgreSQL connection"
  ansible.builtin.command:
    cmd: psql -h {{ postgres_ip }} -U postgres -c 'SELECT version();'
  delegate_to: service_container
  changed_when: false
  register: postgres_test

- name: "VERIFY: PostgreSQL version check"
  ansible.builtin.assert:
    that:
      - "'PostgreSQL' in postgres_test.stdout"
    fail_msg: "PostgreSQL not responding correctly"
    success_msg: "PostgreSQL connection successful"
```

**Redis**:
```yaml
- name: "VERIFY: Test Redis PING"
  ansible.builtin.command:
    cmd: redis-cli -h {{ redis_ip }} -p 6379 PING
  delegate_to: service_container
  changed_when: false
  register: redis_ping

- name: "VERIFY: Redis response check"
  ansible.builtin.assert:
    that:
      - "'PONG' in redis_ping.stdout"
    fail_msg: "Redis not responding to PING"
    success_msg: "Redis responding correctly"
```

**Web Service (Nginx/Apache)**:
```yaml
- name: "VERIFY: Test web service HTTP"
  ansible.builtin.uri:
    url: "http://{{ service_ip }}:{{ service_port }}"
    method: GET
    status_code: [200, 301, 302]
    timeout: 10
  register: http_test

- name: "VERIFY: Test web service HTTPS (external)"
  ansible.builtin.uri:
    url: "https://{{ service_domain }}"
    method: GET
    status_code: [200, 301, 302]
    validate_certs: yes
    timeout: 30
  delegate_to: localhost
  when: service_domain is defined
```

**Docker-based Service**:
```yaml
- name: "VERIFY: Check Docker container health"
  ansible.builtin.command:
    cmd: docker ps --filter name={{ container_name }} --format '{{{{.Status}}}}'
  delegate_to: service_container
  changed_when: false
  register: docker_status

- name: "VERIFY: Docker container healthy"
  ansible.builtin.assert:
    that:
      - "'healthy' in docker_status.stdout or 'Up' in docker_status.stdout"
    fail_msg: "Docker container not healthy"
    success_msg: "Docker container is healthy"
```

### Verification Checklist

Use this checklist for all service deployments:

- [ ] Container created and running
- [ ] Service process running (systemd/docker)
- [ ] Service listening on expected port(s)
- [ ] Service responds to basic health check
- [ ] Service logs show no errors
- [ ] Service accessible from other containers (if internal)
- [ ] Service accessible from internet (if public)
- [ ] DNS resolution working (if public)
- [ ] SSL certificate valid (if HTTPS)
- [ ] Playbook displays clear success message

### Failure Handling

If verification fails:

1. **Do NOT mark the playbook as successful**
2. **Display clear error message** with:
   - What failed (specific check)
   - Current state (what was found)
   - Expected state (what should be)
   - Troubleshooting hints
3. **Return non-zero exit code** from playbook
4. **Log failure** for monitoring/alerting

Example:
```yaml
- name: "VERIFY: Fail if service not responding"
  ansible.builtin.fail:
    msg:
      - "❌ {{ service_name }} verification FAILED"
      - "  Check: Service HTTP response"
      - "  Expected: HTTP 200"
      - "  Actual: {{ http_test.status }} ({{ http_test.msg }})"
      - "  Troubleshooting:"
      - "    1. Check service logs: journalctl -u {{ service_name }} -n 50"
      - "    2. Check service status: systemctl status {{ service_name }}"
      - "    3. Check firewall: iptables -L -n | grep {{ service_port }}"
  when: http_test.status not in [200, 301, 302]
```

## Benefits

1. **Immediate Feedback**: Know instantly if deployment succeeded
2. **Prevent False Positives**: Ansible "ok" means service is actually working
3. **Faster Debugging**: Verification pinpoints exact failure point
4. **Documentation**: Verification tasks document expected behavior
5. **Confidence**: Safe to automate deployments in production
6. **Regression Prevention**: Catch broken deployments immediately

## Rollout Plan

### Phase 1: Critical Infrastructure Services (Completed)
- [x] PostgreSQL - Database foundation
- [x] Redis - Cache/message queue foundation

### Phase 2: Core Application Services (Next)
- [ ] Keycloak - Authentication foundation
- [ ] GitLab - Code repository
- [ ] Nextcloud - File storage

### Phase 3: Additional Services
- [ ] Mattermost - Team communication
- [ ] Webtop - Browser workspace
- [ ] Demo Site / Links Portal

### Phase 4: Infrastructure Services
- [ ] Firewall - Network security
- [ ] Bastion - SSH access
- [ ] Traefik - Reverse proxy

## Examples from Redis Deployment

The Redis deployment demonstrates the complete verification strategy:

**File**: `playbooks/redis-deploy.yml`

```yaml
- name: Wait for Redis to be ready
  ansible.builtin.wait_for:
    host: "{{ redis_ip_address }}"
    port: 6379
    timeout: 30
  delegate_to: localhost

- name: Display redis configuration
  ansible.builtin.debug:
    msg:
      - "Redis deployed successfully"
      - "  Container ID: {{ redis_container_id }}"
      - "  IP: {{ redis_ip_address }}"
      - "  Port: 6379"
      - "  Connection: redis://:password@{{ redis_ip_address }}:6379"
      - "  Max Memory: {{ redis_maxmemory }}"
      - "  Eviction Policy: {{ redis_maxmemory_policy }}"
```

**Results**:
- Playbook succeeds only when Redis is actually listening on port 6379
- Clear success message with connection details
- Operator knows immediately if deployment worked

## References

- [Configuration Management Strategy](configuration-management.md)
- [New Service Workflow](../NEW_SERVICE_WORKFLOW.md)
- [Service Checklist Template](../SERVICE_CHECKLIST_TEMPLATE.md)
- [Adding Services to Status Script](../ADDING_SERVICES_TO_STATUS_SCRIPT.md)

## Related ADRs

- [002-container-id-standardization](../adr/002-container-id-standardization.md)

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2025-10-25 | Initial version - Global verification strategy | Infrastructure Team |
| 2025-10-25 | Added Redis example and verification levels | Infrastructure Team |
