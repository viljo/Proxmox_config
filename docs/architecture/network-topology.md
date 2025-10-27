# Network Topology Strategy

**IMPORTANT**: For comprehensive network architecture documentation including troubleshooting and common mistakes, see [NETWORK_ARCHITECTURE.md](../NETWORK_ARCHITECTURE.md).

## CRITICAL: Bridge Usage Policy

**⚠️ IMPORTANT - Public Service Access:**

- **vmbr0 (br0)** - **MANAGEMENT ONLY (Starlink - CGNAT)**: Used exclusively for administrative access to the Proxmox host. **Behind CGNAT - cannot host public services**. NOT for service traffic or DNS.
- **vmbr2 (br2)** - **PUBLIC INTERNET (Bahnhof - NOT CGNAT)**: Used for all public service access, DNS records, and WAN connectivity. The firewall container (101) WAN interface on this bridge provides the **publicly routable IP address** that DNS must point to.
- **vmbr3 (br3)** - **DMZ**: Internal communication between services. Not directly accessible from internet.

**ISP Details**:
- **vmbr0 (Starlink)**: Behind Carrier-Grade NAT (CGNAT). Inbound connections from internet are NOT possible. Only suitable for outbound management traffic.
- **vmbr2 (Bahnhof)**: Direct public IP assignment (NOT CGNAT). Fully routable from internet. **Required for hosting public services**.

**DNS Configuration**: All DNS records (*.viljo.se) MUST point to the public IP address on vmbr2 (br2) obtained from the firewall container's WAN interface (Bahnhof connection). The Loopia DDNS script automatically reads this IP from container 101 eth0 and updates DNS records accordingly.

**Why This Matters**:
1. Starlink (vmbr0) uses CGNAT - services hosted here cannot be reached from internet
2. Bahnhof (vmbr2) provides direct public IP - services must use this connection
3. Testing or configuring services using the Starlink/vmbr0 IP will fail from internet

## Overview
The Proxmox host exposes three bridges that strictly separate management, WAN, and internal DMZ traffic:

| Bridge | Addressing | Purpose | DNS Usage | ISP/CGNAT | Notes |
|--------|------------|---------|-----------|-----------|-------|
| `vmbr0` | 192.168.1.0/24 (Starlink DHCP) | **Management ONLY** | ❌ Never | Starlink (CGNAT) | Proxmox management IP `192.168.1.3`. **Cannot host public services** due to CGNAT. |
| `vmbr2` | DHCP (Bahnhof) | **WAN/Public Internet** | ✅ Always | Bahnhof (Public IP) | Publicly routable IP on firewall container 101 eth0. **All DNS records point here**. |
| `vmbr3` | 172.16.10.0/24 (static) | **Service DMZ** | ❌ Never | Internal only | Backplane for all application LXCs. Routed/NATed by firewall LXC (101). |

Traefik runs on the Proxmox host and accepts traffic from vmbr2 (Bahnhof public IP) after it passes through the firewall container's DNAT rules. All service containers sit on the private `vmbr3` segment and are published through Traefik routes.

## DNS Synchronization with vmbr2 (br2)

The Loopia DDNS automation ensures DNS records always point to the correct public IP on vmbr2:

**Script Location**: `/usr/local/lib/loopia-ddns/update.py`
**Update Frequency**: Every 15 minutes (systemd timer)
**IP Source**: Container 101 (firewall) eth0 interface on vmbr2

**How It Works**:
```python
CONTAINER_ID = 101  # Firewall container
INTERFACE = "eth0"  # WAN interface on vmbr2

# Reads public IP from firewall's WAN interface
ip_output = subprocess.check_output([
    "pct", "exec", str(CONTAINER_ID), "--",
    "ip", "-4", "-o", "addr", "show", "dev", INTERFACE
])
current_ip = ip_output.split()[3].split('/')[0]

# Updates all DNS records (*.viljo.se) to this IP
```

**Why This Is Correct**: The firewall container (101) has its WAN interface (eth0) connected to vmbr2, which receives the ISP's public IP via DHCP. This is the IP address that receives all inbound traffic from the internet. The script correctly queries this interface and updates DNS records accordingly.

**Verification**:
```bash
# Check firewall WAN IP (should match DNS)
pct exec 101 -- ip -4 addr show eth0 | grep inet

# Check DNS resolution (should match above)
dig +short mattermost.viljo.se @1.1.1.1
```

## Implementation Status
### Completed
- `vmbr0` remains the 192.168.1.0/24 management bridge (admin access only). `vmbr2` (WAN) stays on DHCP and feeds the firewall LXC WAN interface (public internet). `vmbr3` static bridge `(172.16.10.2/24)` carries the DMZ (internal services).
- All service inventories (`inventory/group_vars/all/*.yml`) use 172.16.10.x addresses, the firewall gateway (`172.16.10.1`), and DMZ DNS (`172.16.10.1`, `1.1.1.1`).
- `roles/firewall` builds LXC 101: `eth0 → vmbr2 (DHCP)`, `eth1 → vmbr3 (172.16.10.1/24)`, applies nftables masquerade and forwards WAN 80/443 to Traefik on vmbr2.
- `roles/dmz_cleanup`, `roles/gitlab`, `roles/traefik`, etc., recreate service containers on vmbr3; containers use `eth0 → vmbr3` with default route via `172.16.10.1`.
- All LXC roles reference the Debian 13 "Trixie" template (`{{ debian_template_image }}`) so new containers track the latest release.
- `ansible-playbook playbooks/site.yml --tags loopia_ddns` installs a timer on the Proxmox host that calls the Loopia API every 15 minutes using the firewall's vmbr2 WAN IP.
- `loopia_ddns` state stored in `/var/lib/loopia-ddns`, script at `/usr/local/lib/loopia-ddns/update.py`, systemd timer ensures public DNS follows the firewall's DHCP lease on vmbr2.
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
