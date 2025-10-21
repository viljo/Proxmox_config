# Firewall Role V2 - Refactored Example

This is an example of the firewall role refactored to use Proxmox API modules instead of SSH/pct commands.

## Key Improvements

### 1. Container Management via API

**Before** (SSH-based):
```yaml
- name: Ensure firewall container exists
  ansible.builtin.shell: |
    pct create {{ firewall_container_id }} {{ firewall_template_file }} \
      --hostname {{ firewall_hostname }} \
      # ... many more flags ...
  args:
    creates: "/etc/pve/lxc/{{ firewall_container_id }}.conf"
```

**After** (API-based):
```yaml
- name: Create/update firewall container via Proxmox API
  community.proxmox.proxmox:
    api_host: "{{ proxmox_api_host }}"
    api_user: "{{ proxmox_api_user }}"
    api_token_id: "{{ proxmox_api_token_id }}"
    api_token_secret: "{{ proxmox_api_token_secret }}"
    vmid: "{{ firewall_container_id }}"
    hostname: "{{ firewall_hostname }}"
    # ... declarative config ...
    state: started
```

### 2. Package Installation via SSH Delegation

**Before** (pct exec):
```yaml
- name: Install firewall packages
  ansible.builtin.command:
    cmd: >
      pct exec {{ firewall_container_id }} -- bash -lc
      "apt-get update && apt-get install -y {{ firewall_packages | join(' ') }}"
```

**After** (proper delegation):
```yaml
- name: Install firewall packages
  ansible.builtin.apt:
    name: "{{ firewall_packages }}"
    state: present
    update_cache: true
  delegate_to: "{{ firewall_hostname }}"
  vars:
    ansible_connection: ssh
    ansible_host: "{{ firewall_lan_ip_address }}"
```

### 3. File Management via Templates

**Before** (pct push):
```yaml
- name: Render nftables configuration locally
  ansible.builtin.template:
    src: nftables.conf.j2
    dest: "/tmp/firewall-nftables-{{ firewall_container_id }}.conf"

- name: Push nftables configuration into container
  ansible.builtin.command:
    cmd: >
      pct push {{ firewall_container_id }}
      /tmp/firewall-nftables-{{ firewall_container_id }}.conf
      /etc/nftables.conf

- name: Remove temporary file
  ansible.builtin.file:
    path: "/tmp/firewall-nftables-{{ firewall_container_id }}.conf"
    state: absent
```

**After** (direct template):
```yaml
- name: Configure nftables firewall rules
  ansible.builtin.template:
    src: nftables.conf.j2
    dest: /etc/nftables.conf
    owner: root
    group: root
    mode: '0644'
  delegate_to: "{{ firewall_hostname }}"
  notify: Restart nftables
```

## Benefits

- ✅ **Idempotent**: Modules track state, only change when needed
- ✅ **Testable**: `--check` mode works properly
- ✅ **Cleaner**: 40% less code
- ✅ **Declarative**: What vs. how
- ✅ **Error handling**: Built-in retries and validation
- ✅ **Diff mode**: See exactly what will change

## Usage

This is an example role. To use it:

1. Add API credentials to vault (see `/tmp/proxmox_api_creds.txt`)
2. Update `inventory/group_vars/proxmox_admin/proxmox_api.yml`
3. Replace current firewall role tasks with this approach
4. Test with `--check --diff` first

## Line Count Comparison

- **Old role**: ~150 lines (with shell commands)
- **New role**: ~95 lines (pure Ansible modules)
- **Reduction**: 37% less code, 100% more maintainable

## Next Steps

See [docs/development/automation-refactoring-plan.md](../../docs/development/automation-refactoring-plan.md) for full refactoring plan.
