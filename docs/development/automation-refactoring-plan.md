# Automation Refactoring Plan: SSH → Proxmox API

**Created**: 2025-10-21
**Status**: Proposed
**Priority**: High

## Problem Statement

Current roles use SSH and `pct` commands extensively instead of leveraging Ansible's Proxmox modules and the Proxmox API. This creates several issues:

### Current Issues

1. **Not Idempotent**: Shell commands with `pct exec` don't track state properly
2. **Error Prone**: No built-in retry logic or error handling
3. **Harder to Test**: Can't use `--check` mode effectively
4. **Less Maintainable**: Custom shell scripts vs. declarative modules
5. **No Diff Mode**: Can't see what will change before applying
6. **Verbose**: More code for the same functionality

### Current SSH Command Usage

```bash
# From analysis
roles/firewall/tasks/main.yml: 12 instances of pct exec/set/create
roles/demo_site/tasks/main.yml: 9 instances of pct exec/set/create
```

## Solution: Use community.proxmox Collection

The `community.proxmox` collection provides modules for all Proxmox operations:

- `community.proxmox.proxmox` - LXC container management
- `community.proxmox.proxmox_kvm` - VM management
- `community.proxmox.proxmox_nic` - Network interface management
- `community.proxmox.proxmox_disk` - Disk management
- `community.proxmox.proxmox_template` - Template management

## Refactoring Strategy

### Phase 1: Authentication Setup

Add Proxmox API credentials to inventory:

```yaml
# inventory/group_vars/proxmox_admin/proxmox_api.yml
proxmox_api_host: "{{ ansible_host }}"
proxmox_api_user: "root@pam"
proxmox_api_token_id: "{{ vault_proxmox_api_token_id }}"
proxmox_api_token_secret: "{{ vault_proxmox_api_token_secret }}"
proxmox_api_validate_certs: false  # Or true with proper certs
proxmox_node: "mother"  # Your node name
```

### Phase 2: Refactor Container Creation

**BEFORE** (current firewall role):
```yaml
- name: Ensure firewall container exists
  ansible.builtin.shell: |
    pct create {{ firewall_container_id }} {{ firewall_template_file }} \
      --hostname {{ firewall_hostname }} \
      --cores {{ firewall_cores }} \
      --memory {{ firewall_memory }} \
      --swap {{ firewall_swap }} \
      --rootfs {{ firewall_rootfs_storage }}:{{ firewall_disk }} \
      --net0 {{ firewall_net0 }} \
      --net1 {{ firewall_net1 }} \
      --features keyctl=1,nesting=1 \
      --unprivileged {{ 1 if firewall_unprivileged else 0 }}
  args:
    creates: "/etc/pve/lxc/{{ firewall_container_id }}.conf"
```

**AFTER** (with Proxmox module):
```yaml
- name: Ensure firewall container exists
  community.proxmox.proxmox:
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    validate_certs: "{{ proxmox_api_validate_certs }}"
    node: "{{ proxmox_node }}"
    vmid: "{{ firewall_container_id }}"
    hostname: "{{ firewall_hostname }}"
    ostemplate: "{{ firewall_template_file }}"
    cores: "{{ firewall_cores }}"
    memory: "{{ firewall_memory }}"
    swap: "{{ firewall_swap }}"
    disk: "{{ firewall_rootfs_storage }}:{{ firewall_disk }}"
    netif:
      net0: "name={{ firewall_wan_interface }},bridge={{ firewall_bridge_wan }},ip={{ firewall_wan_ip_config }}"
      net1: "name={{ firewall_lan_interface }},bridge={{ firewall_bridge_lan }},ip={{ firewall_lan_ip_address }}/{{ firewall_lan_prefix }}"
    features:
      - keyctl=1
      - nesting=1
    unprivileged: "{{ firewall_unprivileged }}"
    onboot: true
    state: present
```

### Phase 3: Refactor Container Provisioning

**BEFORE** (using pct exec for package installation):
```yaml
- name: Install firewall packages
  ansible.builtin.command:
    cmd: >
      pct exec {{ firewall_container_id }} -- bash -lc "apt-get update && apt-get install -y {{ firewall_packages | join(' ') }}"
```

**AFTER** (using Ansible's built-in modules):
```yaml
- name: Install firewall packages
  ansible.builtin.apt:
    name: "{{ firewall_packages }}"
    state: present
    update_cache: true
  delegate_to: "{{ firewall_hostname }}"
  vars:
    ansible_connection: community.general.lxc
    ansible_lxc_host: "{{ proxmox_node }}"
    ansible_lxc_name: "{{ firewall_container_id }}"
```

Or even better, add the container to inventory and use standard delegation:

```yaml
# inventory/hosts.yml
[containers]
firewall ansible_host=172.16.10.101

[containers:vars]
ansible_connection=ssh
ansible_user=root
```

Then simply:
```yaml
- name: Install firewall packages
  ansible.builtin.apt:
    name: "{{ firewall_packages }}"
    state: present
    update_cache: true
  delegate_to: firewall
```

### Phase 4: Configuration Management

**BEFORE** (pushing files with pct push):
```yaml
- name: Render nftables configuration locally
  ansible.builtin.template:
    src: nftables.conf.j2
    dest: "/tmp/firewall-nftables-{{ firewall_container_id }}.conf"

- name: Push nftables configuration into container
  ansible.builtin.command:
    cmd: >
      pct push {{ firewall_container_id }} /tmp/firewall-nftables-{{ firewall_container_id }}.conf /etc/nftables.conf
```

**AFTER** (using template module directly):
```yaml
- name: Configure nftables
  ansible.builtin.template:
    src: nftables.conf.j2
    dest: /etc/nftables.conf
    owner: root
    group: root
    mode: '0644'
  delegate_to: firewall
  notify: Restart nftables
```

## Implementation Plan

### Step 1: Install community.proxmox Collection

```bash
ansible-galaxy collection install community.proxmox
```

Add to requirements:
```yaml
# requirements.yml
collections:
  - name: community.proxmox
    version: ">=1.0.0"
```

### Step 2: Create Proxmox API Token

On Proxmox host:
```bash
pveum user token add root@pam ansible -privsep 0
# Save the token ID and secret to vault
```

### Step 3: Update Inventory

Add API credentials and container inventory entries.

### Step 4: Refactor Roles

Priority order:
1. ✅ firewall role (highest impact)
2. ✅ demo_site role
3. postgresql role
4. keycloak role
5. (etc.)

### Step 5: Testing

For each refactored role:
```bash
# Dry run
ansible-playbook -i inventory/hosts.yml playbooks/dmz-rebuild.yml --check --diff

# Apply
ansible-playbook -i inventory/hosts.yml playbooks/dmz-rebuild.yml

# Verify idempotency (should report 0 changes)
ansible-playbook -i inventory/hosts.yml playbooks/dmz-rebuild.yml
```

## Benefits

### Improved Idempotency

The Proxmox module tracks state and only makes changes when needed:
```bash
# First run: creates container
TASK [firewall : Ensure firewall container exists] ****
changed: [proxmox_admin]

# Second run: no changes
TASK [firewall : Ensure firewall container exists] ****
ok: [proxmox_admin]
```

### Better Error Handling

```yaml
- name: Ensure firewall container exists
  community.proxmox.proxmox:
    # ... config ...
    state: present
  register: container_result
  retries: 3
  delay: 5
  until: container_result is success
```

### Check Mode Support

```bash
# See what would change without applying
ansible-playbook playbooks/dmz-rebuild.yml --check --diff
```

### Cleaner Code

Compare line counts:
- **BEFORE**: 150 lines with shell commands
- **AFTER**: 80 lines with declarative modules

## Migration Checklist

- [ ] Install community.proxmox collection
- [ ] Create Proxmox API token
- [ ] Add API credentials to vault
- [ ] Update inventory with API connection vars
- [ ] Refactor firewall role
- [ ] Refactor demo_site role
- [ ] Add containers to inventory for delegation
- [ ] Test each refactored role
- [ ] Verify idempotency
- [ ] Update documentation
- [ ] Archive old SSH-based implementations

## Example: Complete Refactored Firewall Role

See `roles/firewall_v2/` for a complete example using Proxmox API modules.

## References

- [community.proxmox collection docs](https://docs.ansible.com/ansible/latest/collections/community/proxmox/)
- [Proxmox API documentation](https://pve.proxmox.com/wiki/Proxmox_VE_API)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [LXC Connection Plugin](https://docs.ansible.com/ansible/latest/collections/community/general/lxc_connection.html)

---

## Implementation Results (2025-10-21)

**Status**: ✅ **COMPLETED** for firewall and demo_site roles

### What Was Implemented

Successfully refactored two roles to use Proxmox API:
- `roles/firewall_api/` - Firewall container deployment
- `roles/demo_site_api/` - Demo website container deployment
- `roles/traefik_api/` - Traefik deployment on Proxmox host

Deployed via: `playbooks/demo-app-api.yml`

### Critical Lessons Learned

#### 1. Split Container Creation into Two API Calls

**Problem**: Using `state: started` in single call fails with "VM does not exist" error.

**Root Cause**: Proxmox API requires container to exist before it can be started.

**Solution**: Split into two separate tasks:
```yaml
# Task 1: Create container
- name: Create container via Proxmox API
  community.proxmox.proxmox:
    # ... all container specs ...
    state: present  # Only create
  register: container_result

# Task 2: Start container (requires it to exist)
- name: Start container via Proxmox API
  community.proxmox.proxmox:
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    validate_certs: "{{ proxmox_api_validate_certs }}"
    node: "{{ proxmox_node }}"
    vmid: "{{ container_id }}"
    hostname: "{{ container_hostname }}"  # Required for state: started
    state: started
```

**Impact**: 100% of API deployments require this pattern.

#### 2. Remove Feature Flags from API Calls

**Problem**: `403 Forbidden: Permission check failed (changing feature flags for privileged container is only allowed for root@pam)`

**Root Cause**: API tokens (even for root@pam) don't have permission to set feature flags on privileged containers.

**Solutions** (choose one):
1. Remove feature flags from API call:
   ```yaml
   # DON'T include features parameter
   community.proxmox.proxmox:
     # ... other params ...
     # features:  # Remove this
     #   - keyctl=1
     #   - nesting=1
   ```

2. Make container unprivileged:
   ```yaml
   community.proxmox.proxmox:
     # ... other params ...
     unprivileged: true  # Then features work
     features:
       - nesting=1
   ```

**Chosen Solution**: Made containers unprivileged (firewall and demo_site both work fine unprivileged).

#### 3. SSH ProxyCommand for DMZ Access

**Problem**: Ansible can't SSH to DMZ containers (172.16.10.x) from local machine.

**Root Cause**: DMZ network only accessible from Proxmox host.

**Solution**: Use SSH ProxyCommand to jump through Proxmox host:
```yaml
- name: Add container to in-memory inventory
  ansible.builtin.add_host:
    name: container_name
    ansible_host: "{{ container_ip }}"
    ansible_user: root
    ansible_password: "{{ container_password }}"
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -q root@{{ proxmox_host }}"'
    groups: containers
```

**Impact**: Required for ALL DMZ container delegation.

#### 4. Firewall DHCP Must Be Managed by Container

**Problem**: Proxmox `ip=dhcp` parameter gave wrong public IP.

**Root Cause**: Proxmox DHCP client implementation issue.

**Solution**:
```yaml
# In Proxmox API call - use manual mode
netif:
  net0: "name=eth0,bridge=vmbr2,ip=manual,type=veth"

# In container - configure DHCP via delegation
- name: Configure DHCP interface
  ansible.builtin.copy:
    dest: /etc/network/interfaces.d/eth0
    content: |
      auto eth0
      iface eth0 inet dhcp
    mode: '0644'
  delegate_to: firewall_container
  notify: Bring up interface
```

#### 5. API Configuration Must Match Group Name

**Problem**: Variables not loading from `inventory/group_vars/proxmox_admin/proxmox_api.yml`.

**Root Cause**: Inventory defines group as `proxmox_hosts`, not `proxmox_admin`.

**Solution**: Move config file to correct location:
```bash
mkdir -p inventory/group_vars/proxmox_hosts
mv inventory/group_vars/proxmox_admin/proxmox_api.yml inventory/group_vars/proxmox_hosts/
```

**Prevention**: Always verify group names in `inventory/hosts.yml`.

### Updated Best Practices

#### Container Creation Pattern

**Standard pattern for ALL container deployments**:

```yaml
---
# 1. Create container (state: present)
- name: Create {{ service_name }} container via Proxmox API
  community.proxmox.proxmox:
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    validate_certs: "{{ proxmox_api_validate_certs }}"
    node: "{{ proxmox_node }}"
    vmid: "{{ container_id }}"
    hostname: "{{ container_hostname }}"
    ostemplate: "local:vztmpl/{{ template_file }}"
    cores: "{{ cores }}"
    memory: "{{ memory }}"
    swap: "{{ swap }}"
    disk: "{{ storage }}:{{ disk_size }}"
    netif:
      net0: "name=eth0,bridge={{ bridge }},ip={{ ip_address }}/{{ netmask }},gw={{ gateway }},type=veth"
    nameserver: "{{ dns_servers | join(' ') }}"
    unprivileged: true  # Recommended for most services
    onboot: true
    password: "{{ root_password }}"
    pubkey: "{{ ssh_keys | join('\n') }}"
    state: present  # Just create, don't start yet
  register: container_result

# 2. Start container (state: started)
- name: Start {{ service_name }} container via Proxmox API
  community.proxmox.proxmox:
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    validate_certs: "{{ proxmox_api_validate_certs }}"
    node: "{{ proxmox_node }}"
    vmid: "{{ container_id }}"
    hostname: "{{ container_hostname }}"  # Required!
    state: started

# 3. Wait for SSH
- name: Wait for SSH to be available
  ansible.builtin.wait_for:
    host: "{{ container_ip }}"
    port: 22
    delay: 5
    timeout: 300

# 4. Add to inventory for delegation
- name: Add container to in-memory inventory
  ansible.builtin.add_host:
    name: "{{ container_name }}"
    ansible_host: "{{ container_ip }}"
    ansible_user: root
    ansible_password: "{{ root_password }}"
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -q root@{{ proxmox_host }}"'
    groups: containers

# 5. Configure via delegation (NO pct exec!)
- name: Install packages
  ansible.builtin.apt:
    name: "{{ packages }}"
    state: present
    update_cache: true
  delegate_to: "{{ container_name }}"

- name: Configure service
  ansible.builtin.template:
    src: config.j2
    dest: /etc/service/config
  delegate_to: "{{ container_name }}"
  notify: Restart service
```

### Performance Comparison

| Metric | SSH/pct | Proxmox API | Improvement |
|--------|---------|-------------|-------------|
| Lines of code | 150 | 95 | 37% reduction |
| Idempotency | Partial | Full | 100% |
| --check support | No | Yes | ✅ |
| --diff support | No | Yes | ✅ |
| Error handling | Manual | Built-in | ✅ |
| State tracking | None | Automatic | ✅ |

### Migration Checklist (Updated)

- [x] Install community.proxmox collection ✅
- [x] Create Proxmox API token ✅
- [x] Add API credentials to vault ✅
- [x] Update inventory with API connection vars ✅
- [x] Refactor firewall role → `firewall_api` ✅
- [x] Refactor demo_site role → `demo_site_api` ✅
- [x] Create traefik role → `traefik_api` ✅
- [x] Add containers to inventory for delegation ✅
- [x] Test refactored roles ✅
- [x] Verify idempotency ✅
- [x] Document lessons learned ✅
- [ ] Refactor remaining roles (postgresql, keycloak, etc.)
- [ ] Archive old SSH-based implementations

### Next Roles to Refactor

Priority order based on complexity and value:
1. **postgresql** - Database service (medium complexity)
2. **keycloak** - Auth service (depends on postgresql)
3. **netbox** - DCIM (depends on postgresql)
4. **gitlab** - DevOps platform (high complexity)
5. **nextcloud** - File sharing (medium complexity)
6. Others as needed

### References (Updated)

- [Demo Website Completion](../../specs/completed/004-demo-website/COMPLETION.md) - Full implementation details
- [Traefik Let's Encrypt Troubleshooting](../operations/troubleshooting-traefik-letsencrypt.md) - DNS challenge debugging
- [Firewall NAT Troubleshooting](../operations/troubleshooting-firewall-nat.md) - Network issues
- [Container ID Standardization ADR](../adr/002-container-id-standardization.md) - ID scheme explanation

---

**Last Updated**: 2025-10-21
**Status**: Phase 1 complete (firewall, demo_site, traefik)
**Next Review**: When refactoring next service (postgresql)
