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

**Last Updated**: 2025-10-21
**Next Review**: After Phase 1 implementation
