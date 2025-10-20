# Network Topology Strategy

## Overview
The Proxmox host now exposes three bridges that split management, WAN, and the internal DMZ:

| Bridge | Addressing | Purpose | Notes |
|--------|------------|---------|-------|
| `vmbr0` | 192.168.1.0/24 (Starlink DHCP) | Management + internal lab | Proxmox management IP `192.168.1.3` lives here. Provides Internet egress for the admin network. |
| `vmbr2` | DHCP (ISP) | WAN uplink | Carries the ISP-provided public address that the Debian firewall LXC uses for NAT. |
| `vmbr3` | 172.16.10.0/24 (static) | Service DMZ | Backplane for all application LXCs. Routed/NATed by the firewall LXC. |

Traefik remains the only component that should be exposed to the public WAN. All other containers sit on the private `vmbr3` segment and are published through Traefik routes.

## Implementation Status
### Completed
- `vmbr0` remains the 192.168.1.0/24 management bridge. `vmbr2` (WAN) now stays on DHCP and feeds the firewall LXC WAN interface. A new `vmbr3` static bridge `(172.16.10.2/24)` carries the DMZ.
- All service inventories (`inventory/group_vars/all/*.yml`) use 172.16.10.x addresses, the firewall gateway (`172.16.10.1`), and DMZ DNS (`172.16.10.1`, `1.1.1.1`).
- `roles/firewall` builds LXC 1: `eth0 → vmbr2 (DHCP)`, `eth1 → vmbr3 (172.16.10.1/24)`, applies nftables masquerade and forwards WAN 80/443 to Traefik.
- `roles/dmz_cleanup`, `roles/gitlab`, `roles/traefik`, etc., recreate the GitLab stack on vmbr3; GitLab container (`53`) uses `eth0 → vmbr3` with default route via `172.16.10.1`.
- All LXC roles reference the Debian 13 “Trixie” template (`{{ debian_template_image }}`) so new containers track the latest release.
- `ansible-playbook playbooks/site.yml --tags loopia_ddns` installs a timer on the Proxmox host that calls the Loopia API every 5 minutes (or on WAN-IP change) using the firewall's WAN IP.
- `loopia_ddns` state stored in `/var/lib/loopia-ddns`, script at `/usr/local/lib/loopia-ddns/update.py`, systemd timer ensures the public DNS follows the firewall’s DHCP lease.
### Outstanding
- Consider decommissioning the old `vmbr1` if it’s no longer needed; currently it still shows a legacy DHCP lease but is link-down.
- Extend nftables (Firewall LXC) to allow additional inbound ports if services like SSH/SMTP are required from WAN.
- Optionally mirror ddns updates inside the firewall LXC if Proxmox-level timer isn’t desired.
- Finalise documentation of Traefik host validation from outside network once DNS propagation completes.

**Outstanding**
- Rebuild the affected LXCs (`pct destroy` + rerun the Ansible roles) so they pick up the new addressing.
- Re-render Traefik once backend services are online to clear the 404 responses.
- Validate outbound connectivity from each container and exercise HTTPS frontends through Traefik.

## Migration Runbook
1. **Deploy the firewall LXC**
   * Run `ansible-playbook playbooks/site.yml --tags firewall` (or `playbooks/dmz-rebuild.yml --tags firewall`) to create the Debian firewall container on `vmbr2`/`vmbr3`.
   * The role installs nftables, enables IP forwarding, masquerades 172.16.10.0/24 to the WAN, and DNATs TCP/80+443 towards the Traefik host IP (`{{ dmz_host_ip }}`).
   * Adjust `inventory/group_vars/all/firewall.yml` if additional ports or rules are required.
2. **Recreate Containers**
   * Run `ansible-playbook playbooks/dmz-rebuild.yml --tags dmz_cleanup` to purge the legacy 192.168.1.x LXCs (or skip the tag to rebuild everything in one go).
   * Rerun the full rebuild (`ansible-playbook playbooks/dmz-rebuild.yml`) or targeted tags (`ansible-playbook playbooks/site.yml --tags gitlab,nextcloud,postgres,...`) so each role provisions a clean container on `vmbr3`.
3. **Verify Connectivity**
   * Within each container: check `ip addr show eth0`, `ip route`, `ping 1.1.1.1`, and `apt-get update`.
   * From the Proxmox host: ensure `vmbr3` shows the static addressing (`{{ dmz_host_ip }}`/`{{ dmz_netmask }}`) and that the firewall container responds at `{{ dmz_gateway }}`.
4. **Update Traefik & DNS**
   * Execute `ansible-playbook playbooks/site.yml --tags traefik`.
   * Confirm Loopia DNS automation still resolves the public IP on `vmbr2`.
   * Validate `curl -Ik https://<service>.{{ public_domain }}` for each published application.

## Summary
Inventory and role defaults now align with the planned 172.16.10.0/24 DMZ on `vmbr3`, while `vmbr2` remains the WAN uplink and `vmbr0` handles management. The firewall LXC provides routing/NAT plus HTTPS forwarding to Traefik, so rebuilding the application containers immediately restores service without exposing additional public IPs.
