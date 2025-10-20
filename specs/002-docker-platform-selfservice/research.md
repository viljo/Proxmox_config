# Phase 0 Research: Self-Service Docker Platform

**Feature**: 002-docker-platform-selfservice
**Phase**: 0 - Technology Research
**Date**: 2025-10-20

## Research Questions

### 1. How to provision LXC containers via Proxmox API programmatically?

**Answer**: Use Proxmox VE API v2 with `/nodes/{node}/lxc` endpoint. The `proxmoxer` Python library provides idiomatic access.

**Key Findings**:
- API endpoint: `POST /api2/json/nodes/{node}/lxc` creates container
- Required parameters: `vmid`, `ostemplate`, `hostname`, `storage`, `rootfs` (size), `memory`, `cores`
- Unprivileged containers require: `unprivileged: 1`, `features: nesting=1` (for Docker-in-LXC)
- AppArmor profile: Set `lxc.apparmor.profile: lxc-container-default-with-nesting`
- Network configuration via `net0`: `name=eth0,bridge=vmbr0,ip=dhcp,firewall=1`

**Implementation Pattern**:
```yaml
# Ansible task using proxmox module
- name: Create unprivileged LXC for Docker environment
  community.general.proxmox:
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    node: "{{ proxmox_node }}"
    vmid: "{{ lxc_vmid }}"
    hostname: "{{ environment_name }}"
    ostemplate: "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
    storage: "{{ proxmox_storage }}"
    disk: "{{ environment_disk_size | default('20') }}"
    cores: "{{ environment_cpu_cores | default(2) }}"
    memory: "{{ environment_memory_mb | default(4096) }}"
    swap: "{{ environment_swap_mb | default(512) }}"
    unprivileged: yes
    features:
      - nesting=1
      - keyctl=1
    netif: '{"net0":"name=eth0,bridge=vmbr0,ip=dhcp,firewall=1"}'
    onboot: yes
    state: present
```

**Idempotency**: Check existing VMID before creation. Use `community.general.proxmox_kvm` module's `state: present` which is idempotent.

**References**:
- Proxmox VE API docs: https://pve.proxmox.com/pve-docs/api-viewer/
- Ansible proxmox module: https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_module.html
- Docker in LXC guide: https://pve.proxmox.com/wiki/Linux_Container#pct_container_storage

---

### 2. How to configure Traefik for dynamic Docker container routing with automatic TLS?

**Answer**: Use Traefik file provider with dynamic configuration files, watched directory for hot-reload. Let's Encrypt DNS-01 challenge for wildcard certificates.

**Key Findings**:
- Traefik supports **file provider** for dynamic configs outside Docker labels
- File provider watches directory: `/etc/traefik/dynamic/*.yml` for changes
- Each Docker environment gets own routing file: `/etc/traefik/dynamic/env-{name}.yml`
- TLS certificates via **Let's Encrypt DNS-01** challenge (supports wildcard: `*.docker.example.com`)
- Alternative: HTTP-01 challenge per container subdomain (requires port 80 reachable)
- Route matching: `Host(`env-name.docker.example.com`)` rule
- Backends configured with container IP:port or Docker network overlay

**Implementation Pattern**:
```yaml
# traefik.yml (static config)
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
      storage: /etc/traefik/acme.json
      dnsChallenge:
        provider: cloudflare  # or route53, etc.
        delayBeforeCheck: 30

providers:
  file:
    directory: /etc/traefik/dynamic
    watch: true

# Dynamic config template: roles/traefik_docker/templates/dynamic/route.yml.j2
http:
  routers:
    {{ environment_name }}-router:
      rule: "Host(`{{ environment_name }}.docker.example.com`)"
      service: {{ environment_name }}-service
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
        domains:
          - main: "*.docker.example.com"

  services:
    {{ environment_name }}-service:
      loadBalancer:
        servers:
          - url: "http://{{ lxc_ip_address }}:{{ portainer_agent_port | default(9001) }}"
```

**Idempotency**: Template dynamic configs, deploy via Ansible copy module. Handler triggers Traefik config reload via API or Docker restart.

**References**:
- Traefik file provider: https://doc.traefik.io/traefik/providers/file/
- Let's Encrypt DNS challenge: https://doc.traefik.io/traefik/https/acme/#dnschallenge
- Dynamic configuration: https://doc.traefik.io/traefik/routing/overview/

---

### 3. How to deploy Portainer with LDAP authentication and multi-environment management?

**Answer**: Deploy Portainer CE server with LDAP integration, register Docker environments as endpoints via Portainer Agent in each LXC.

**Key Findings**:
- **Portainer Server**: Central management UI, deployed as Docker container
- **Portainer Agent**: Lightweight agent in each Docker environment, communicates with server
- LDAP authentication configured via Portainer UI or API `/api/settings/ldap`
- Each LXC environment registered as **Endpoint** in Portainer
- Agent deployment: Docker Compose in LXC with `portainer/agent:latest` image
- Agent exposes port 9001, secured with shared secret
- LDAP groups mapped to Portainer **teams** for RBAC
- Team ownership: LDAP group members get environment access via team assignment

**Implementation Pattern**:
```yaml
# roles/portainer/tasks/ldap_config.yml
- name: Configure Portainer LDAP authentication
  uri:
    url: "https://{{ portainer_host }}/api/settings/ldap"
    method: PUT
    headers:
      X-API-Key: "{{ portainer_api_key }}"
    body_format: json
    body:
      ReaderDN: "{{ ldap_bind_dn }}"
      Password: "{{ ldap_bind_password }}"
      URL: "{{ ldap_url }}"
      SearchSettings:
        - BaseDN: "{{ ldap_user_base_dn }}"
          Filter: "(&(objectClass=person)(uid=*))"
          UserNameAttribute: "uid"
      GroupSearchSettings:
        - BaseDN: "{{ ldap_group_base_dn }}"
          Filter: "(objectClass=posixGroup)"
          GroupAttribute: "cn"
    status_code: 200

# roles/docker_platform/templates/portainer-agent.yml.j2
version: '3.8'
services:
  portainer-agent:
    image: portainer/agent:2.21.4
    container_name: portainer-agent
    restart: unless-stopped
    ports:
      - "9001:9001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
    environment:
      AGENT_SECRET: "{{ portainer_agent_secret }}"
      LOG_LEVEL: INFO
```

**Team-Based Ownership**:
```yaml
# Register environment endpoint with team assignment
- name: Create Portainer endpoint for environment
  uri:
    url: "https://{{ portainer_host }}/api/endpoints"
    method: POST
    headers:
      X-API-Key: "{{ portainer_api_key }}"
    body_format: json
    body:
      Name: "{{ environment_name }}"
      EndpointType: 2  # Agent endpoint
      URL: "tcp://{{ lxc_ip_address }}:9001"
      TLS: false
      TeamAccessPolicies:
        - TeamId: "{{ ldap_team_id }}"  # Resolved from LDAP group
          Access: 1  # Full control
    status_code: 201
```

**References**:
- Portainer API docs: https://docs.portainer.io/api/docs
- Portainer Agent deployment: https://docs.portainer.io/admin/environments/add/docker/agent
- LDAP integration: https://docs.portainer.io/admin/settings/authentication/ldap

---

### 4. How to implement resource quota enforcement with auto-approval logic?

**Answer**: Define quota thresholds in Ansible defaults, validate requests against quotas in playbook, auto-approve within limits or pause for admin approval.

**Key Findings**:
- Quotas stored in `roles/docker_platform/defaults/main.yml`: `default_cpu_limit`, `default_memory_limit`, `default_disk_limit`
- Request validation logic in `playbooks/provision_docker_env.yml`
- Use Ansible `assert` module to check quotas
- Within-quota: Provision immediately
- Exceeds quota: Use `pause` module with approval prompt or integrate with approval system (e.g., GitLab issue)
- Quota enforcement at Proxmox level: LXC cgroup limits (`memory.limit_in_bytes`, `cpu.cfs_quota_us`)

**Implementation Pattern**:
```yaml
# roles/docker_platform/defaults/main.yml
docker_platform_default_quotas:
  cpu_cores: 4
  memory_mb: 8192
  disk_gb: 50
  max_containers_per_env: 20

# playbooks/provision_docker_env.yml
---
- name: Provision Docker environment with quota enforcement
  hosts: localhost
  gather_facts: no
  vars:
    requested_cpu: "{{ environment_cpu_cores | default(2) }}"
    requested_memory: "{{ environment_memory_mb | default(4096) }}"
    requested_disk: "{{ environment_disk_size | default(20) }}"

  tasks:
    - name: Check if request exceeds quotas
      set_fact:
        exceeds_quota: >-
          {{ requested_cpu | int > docker_platform_default_quotas.cpu_cores or
             requested_memory | int > docker_platform_default_quotas.memory_mb or
             requested_disk | int > docker_platform_default_quotas.disk_gb }}

    - name: Auto-approve within quota limits
      debug:
        msg: "Request within quota limits - auto-approving"
      when: not exceeds_quota

    - name: Request admin approval for over-quota resources
      pause:
        prompt: |
          Environment request EXCEEDS quota limits:
          Requested: {{ requested_cpu }} cores, {{ requested_memory }} MB, {{ requested_disk }} GB
          Quota: {{ docker_platform_default_quotas.cpu_cores }} cores, {{ docker_platform_default_quotas.memory_mb }} MB, {{ docker_platform_default_quotas.disk_gb }} GB

          Approve this request? (yes/no)
      register: approval
      when: exceeds_quota

    - name: Fail if not approved
      fail:
        msg: "Environment request denied or not approved"
      when: exceeds_quota and approval.user_input | lower != 'yes'

    - name: Proceed with provisioning
      include_role:
        name: docker_platform
      vars:
        environment_name: "{{ env_name }}"
        environment_cpu_cores: "{{ requested_cpu }}"
        environment_memory_mb: "{{ requested_memory }}"
        environment_disk_size: "{{ requested_disk }}"
```

**Alternative - GitLab Issue Approval**:
- Integrate with GitLab API to create approval issue when quota exceeded
- Use GitLab webhook to trigger playbook re-run after approval
- Store approval state in NetBox custom field

**References**:
- Ansible pause module: https://docs.ansible.com/ansible/latest/collections/ansible/builtin/pause_module.html
- LXC resource limits: https://pve.proxmox.com/wiki/Linux_Container#pct_cpu_limit

---

### 5. How to implement rolling updates with health checks for container deployments?

**Answer**: Deploy new container version alongside old, perform HTTP health check, switch traffic via Traefik weighted routing, terminate old on success.

**Key Findings**:
- **Blue-Green Deployment** pattern for rolling updates
- Deploy new container with `-v2` suffix (e.g., `app-v2`)
- Health check via HTTP endpoint: `GET /health` returns 200 OK
- Traefik weighted services: Split traffic 100%/0% initially, then 0%/100% after validation
- Ansible `uri` module for health checks with retries
- Automatic rollback: If health checks fail, remove new container and keep old

**Implementation Pattern**:
```yaml
# playbooks/deploy_container.yml - Rolling update logic
---
- name: Deploy container with rolling update
  hosts: "{{ environment_name }}"
  gather_facts: no

  tasks:
    - name: Pull new container image
      community.docker.docker_image:
        name: "{{ container_image }}"
        tag: "{{ container_tag }}"
        source: pull
        force_source: yes

    - name: Start new container version (blue-green)
      community.docker.docker_container:
        name: "{{ container_name }}-new"
        image: "{{ container_image }}:{{ container_tag }}"
        state: started
        restart_policy: unless-stopped
        networks:
          - name: "{{ docker_network }}"
        env: "{{ container_env_vars }}"
        published_ports: "{{ container_ports }}"

    - name: Wait for new container to be healthy
      uri:
        url: "http://{{ container_name }}-new:{{ health_check_port }}/health"
        status_code: 200
        timeout: 5
      register: health_check
      retries: 12
      delay: 5
      until: health_check.status == 200
      ignore_errors: yes

    - name: Rollback if health check failed
      block:
        - name: Stop and remove failed container
          community.docker.docker_container:
            name: "{{ container_name }}-new"
            state: absent

        - name: Fail deployment
          fail:
            msg: "Health check failed - rolled back to previous version"
      when: health_check is failed

    - name: Switch traffic to new container (update Traefik route)
      ansible.builtin.template:
        src: traefik-route.yml.j2
        dest: "/etc/traefik/dynamic/{{ environment_name }}-{{ container_name }}.yml"
      vars:
        container_backend_url: "http://{{ container_name }}-new:{{ container_port }}"
      delegate_to: traefik_host
      notify: reload traefik

    - name: Wait for traffic switch (30 seconds grace period)
      pause:
        seconds: 30

    - name: Stop and remove old container
      community.docker.docker_container:
        name: "{{ container_name }}"
        state: absent

    - name: Rename new container to primary name
      community.docker.docker_container:
        name: "{{ container_name }}-new"
        container_default_behavior: no_defaults
        comparisons:
          '*': ignore
        rename: "{{ container_name }}"
```

**Health Check Configuration**:
```yaml
# Container must expose health endpoint
container_health_check:
  endpoint: /health
  port: 8080
  timeout: 5
  retries: 12
  interval: 5
```

**References**:
- Ansible docker_container: https://docs.ansible.com/ansible/latest/collections/community/docker/docker_container_module.html
- Traefik weighted services: https://doc.traefik.io/traefik/routing/services/#weighted-round-robin

---

## Technology Decisions

| Decision | Rationale |
|----------|-----------|
| **Proxmox LXC over VMs** | LXC containers offer lower overhead (~10% vs ~30%), faster provisioning (<2min vs 5-10min), better density (10-20 containers per host vs 5-10 VMs). Unprivileged mode provides security isolation. |
| **Traefik v3 over Nginx** | Native Docker integration, automatic Let's Encrypt, dynamic config reload without downtime, file provider for non-Docker backends. Nginx requires manual cert renewal and reload. |
| **Portainer CE over Rancher** | Lightweight (50MB vs 1GB+ for Rancher), LDAP integration out-of-box, multi-environment support, simpler deployment (single container vs k3s cluster). Suitable for <100 environments. |
| **Let's Encrypt DNS-01 over HTTP-01** | Wildcard certificate support (`*.docker.example.com`), no port 80 requirement, works with internal-only hosts. Requires DNS provider API access (Cloudflare, Route53). |
| **PostgreSQL for platform metadata** | Stores environment metadata, approval states, audit logs. NetBox already uses PostgreSQL - can share instance. SQLite insufficient for multi-user concurrent writes. |
| **File-based Traefik configs over Docker labels** | Supports LXC-based Docker environments (no Docker socket access). Ansible can template and deploy configs idempotently. Labels only work for containers on same Docker host as Traefik. |

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **LXC kernel nesting vulnerabilities** | High - Container escape risk | Use unprivileged LXC + AppArmor profiles. Monitor security advisories for Proxmox/LXC. Apply kernel updates regularly. |
| **Let's Encrypt rate limits** | Medium - 50 certs/week limit | Use wildcard certificates to cover all environments with single cert. Implement cert caching in Traefik. |
| **Portainer single point of failure** | High - All environment management unavailable | Deploy Portainer with persistent volume backup. Document manual Docker management procedures. Consider HA with Portainer Business (paid). |
| **Traefik config file conflicts** | Low - Multiple environments updating same file | Use atomic writes (template to temp, mv to final). Implement file locking in Ansible. Use separate file per environment. |
| **LDAP group sync delays** | Low - New team members can't access environment immediately | Document LDAP sync interval (default 5min). Provide manual team assignment override for urgent access. |

## Open Questions

- **Q1**: Should we implement a web UI for environment requests, or rely on GitLab issues + Ansible playbook execution?
  - **Recommendation**: Start with GitLab issue templates + CI/CD pipeline. Web UI can be added later if needed.

- **Q2**: How to handle LXC IP address allocation - DHCP or static assignment?
  - **Recommendation**: Use DHCP with Proxmox DHCP server reservation based on MAC address. Ensures consistent IPs without manual management.

- **Q3**: Should Docker environments be able to communicate with each other, or strict network isolation?
  - **Recommendation**: Default isolation via nftables, explicit allow-list for inter-environment communication (configurable per environment).

- **Q4**: Backup strategy for Docker volumes in LXC containers?
  - **Recommendation**: Proxmox vzdump for full LXC backup (weekly), Docker volume bind mounts to NFS share for continuous backup of persistent data.

- **Q5**: How to handle LXC VMID assignment - sequential auto-increment or reserved ranges per team?
  - **Recommendation**: Use NetBox to track VMID allocation, reserve ranges per team (team A: 200-299, team B: 300-399). Prevents collisions.
