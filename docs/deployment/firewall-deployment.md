# Firewall (Debian nftables) Deployment Guide

The `roles/firewall` role provisions a Debian LXC on Proxmox that replaces the earlier OPNsense plan. It terminates on `vmbr2` for WAN ingress and publishes a NATed LAN on `vmbr3` for all application containers.

## What the role configures
- Creates LXC ID `1` (hostname `firewall`) with two interfaces:
  - `eth0` → `vmbr2` (DHCP from the ISP)
  - `eth1` → `vmbr3` (`{{ dmz_gateway }}`/`{{ dmz_prefix }}`)
- Enables IPv4 forwarding and installs `nftables`.
- Applies `/etc/nftables.conf` that:
  - Masquerades traffic sourced from `{{ dmz_subnet }}` out the WAN.
  - DNATs TCP/80 and TCP/443 from WAN to the Traefik host (`{{ dmz_host_ip }}`).
  - Allows management access (SSH) from the DMZ by default.

All parameters can be tuned via `inventory/group_vars/all/firewall.yml` (additional ports, packages, etc.). After editing, re-run:

```bash
ANSIBLE_LOCAL_TEMP=$(pwd)/.ansible/tmp ANSIBLE_REMOTE_TMP=$(pwd)/.ansible/tmp \
  ansible-playbook playbooks/site.yml --tags firewall
```

## Verification checklist
1. `ssh root@192.168.1.3 pct exec 1 -- ip addr` should show `eth0` with a WAN lease and `eth1` as `{{ dmz_gateway }}`.
2. From the Proxmox host: `ping {{ dmz_gateway }}` succeeds, and `ip route get 1.1.1.1` from GitLab/Nextcloud containers uses that gateway.
3. External hosts can reach `https://gitlab.{{ public_domain }}` via Traefik (forwarded through the firewall).
4. Review or extend nftables rules by editing `roles/firewall/templates/nftables.conf.j2` and re-running the role.

No manual console work is required—the firewall container is fully controlled by Ansible.
