## CRITICAL - SSH ACCESS RULES - DO NOT VIOLATE

### 192.168.1.0/24 Network SSH (Port 22) - ABSOLUTELY NEVER TOUCH
**The 192.168.1.0/24 management network SSH on port 22 is the USER'S EMERGENCY BACKUP ACCESS.**
- NEVER modify, remove, or change SSH port 22 configuration on the 192.168.1.0/24 network
- NEVER touch /etc/ssh/sshd_config Port 22 setting
- This is the user's last resort access method - DO NOT TOUCH IT UNDER ANY CIRCUMSTANCES

### SSH Access for Operations
- Use port 22: `ssh root@ssh.viljo.se`
- This is the PRIMARY access method for Claude to use for all operations
- ALWAYS use domain names, never hardcoded IPs

### Access Priority
1. PRIMARY: `ssh root@ssh.viljo.se` (port 22, external via DDNS)
2. BACKUP: `ssh root@192.168.1.3` (port 22, only if on management network)

* DDNS Architecture - ENFORCING:
  - Public services use Dynamic DNS (DDNS) - the public IP can change
  - ALWAYS use domain names (*.viljo.se) for public access, NEVER hardcode public IPs
  - Ansible inventory MUST use ssh.viljo.se for external access
  - Service configurations that need public IP should fetch it dynamically (e.g., STUN servers, `curl ifconfig.me`)
  - 192.168.1.x management network is separate and static - not affected by DDNS

* IP Change Resilience - GOAL:
  - Public IP changes MUST NOT cause service failures
  - Services MUST handle IP changes automatically with minimal unavailability
  - Maximum acceptable downtime during IP change: DNS TTL (600s = 10 minutes)
  - Implementation requirements:
    1. loopia-ddns service MUST run every 15 minutes to update DNS
    2. All services MUST use domain names, never hardcoded public IPs
    3. Services needing real-time public IP (e.g., WebRTC/JVB) MUST use STUN discovery
    4. No service should require manual redeployment after IP change
  - Protected services: Jitsi (STUN), all web services (DNS-based)
  - Critical dependency: loopia-ddns systemd timer must be running on Proxmox host

* Dual ISP Architecture:
  - vmbr0: Starlink ISP (CGNAT) on 192.168.1.0/24 - Management ONLY - MUST NOT TOUCH
  - vmbr2: Bahnhof ISP (public IP via DHCP) - WAN for public services

## Network Infrastructure

### Network Topology
```
Internet
    │
    ▼
vmbr2 (Bahnhof WAN) ─── Public IP via DHCP (46.x.x.x)
    │
    │ NAT/Port Forward (iptables on Proxmox host)
    ▼
vmbr3 (DMZ Bridge) ─── 172.31.31.1/24
    │
    ▼
LXC 200 (containers) ─── 172.31.31.10
    │
    ▼
Docker containers (traefik_public network)
```

### Key Network Details
- **Proxmox host**: Routes traffic between vmbr2 (WAN) and vmbr3 (DMZ)
- **LXC 200**: Main container host at 172.31.31.10, also has 192.168.1.200 on management network
- **traefik_public**: Docker network for web services, Traefik handles HTTP/HTTPS routing
- **Port forwards**: Configured in `/etc/network/interfaces.d/vmbr3-dmz.cfg` and `/etc/iptables.rules`

### Standard Port Forwards (vmbr2 → LXC 200)
| Port | Protocol | Service |
|------|----------|---------|
| 80 | TCP | HTTP (Traefik) |
| 443 | TCP | HTTPS (Traefik) |
| 8000 | TCP | Coolify API |
| 6881 | TCP+UDP | qBittorrent |
| 10000 | UDP | Jitsi JVB (WebRTC) |

### Adding Port Forwards for New Services
When a service needs direct port access (not just HTTP via Traefik):

1. **Add to running iptables**:
   ```bash
   ssh root@ssh.viljo.se "iptables -t nat -A PREROUTING -i vmbr2 -p <tcp/udp> --dport <PORT> -j DNAT --to-destination 172.31.31.10:<PORT>"
   ```

2. **Persist to /etc/iptables.rules**:
   ```bash
   ssh root@ssh.viljo.se "iptables-save > /etc/iptables.rules"
   ```

3. **Add to /etc/network/interfaces.d/vmbr3-dmz.cfg** for interface-up persistence:
   ```
   post-up iptables -t nat -A PREROUTING -i vmbr2 -p <tcp/udp> --dport <PORT> -j DNAT --to-destination 172.31.31.10:<PORT>
   pre-down iptables -t nat -D PREROUTING -i vmbr2 -p <tcp/udp> --dport <PORT> -j DNAT --to-destination 172.31.31.10:<PORT> 2>/dev/null || true
   ```

4. **Expose in Docker container** (docker-compose):
   ```yaml
   ports:
     - "<PORT>:<PORT>/udp"  # or tcp
   ```

### Web Services (HTTP/HTTPS via Traefik)
Most services only need Traefik labels - no port forward required:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<service>.rule=Host(`<subdomain>.{{ public_domain }}`)"
  - "traefik.http.routers.<service>.entrypoints=websecure"
  - "traefik.http.routers.<service>.tls.certresolver=letsencrypt"
  - "traefik.http.services.<service>.loadbalancer.server.port=<internal-port>"
networks:
  - traefik_public
```

### Verification Commands
```bash
# Check port forward exists
iptables -t nat -L PREROUTING -v -n | grep <PORT>

# Check Docker port binding
pct exec 200 -- docker port <container-name>

# Check if port is listening
pct exec 200 -- ss -ulpn | grep <PORT>  # UDP
pct exec 200 -- ss -tlpn | grep <PORT>  # TCP
```

* Always first access the services and proxmox host via their external dns alias .viljo.se (ssh, web, api etc), as a reserve backup if on the 192.168. net use direct local connection.
* inventory/services.yml:  Service Registry - Single Source of Truth, All services MUST be registered here before deployment
* Always update ansible playbooks so they have the same configuration as the system. The system shall be able to be recreated using the playbooks
* Use ansible vault to keep all secrets and API keys
* Save ansible vault password in a noncomitted textfile in project root
* Always strive to create end to end test (emulating a user testing the service) for all services
* Always run end to end test before assuming service is correctly deployed
* Always check and remove previous existing duplicates before creating a new service

* RemoteLLM/llama.cpp model naming:
  - Always use --alias flag with llama-server to set a clean model name (e.g., "qwen3-coder-30b")
  - Model names should not contain paths or file extensions
  - Standard format: {model-family}-{size} (e.g., "qwen3-coder-30b", "llama-3.1-8b")

* Service Testing - ENFORCING:
  - When testing services, ALWAYS test from external/public access (e.g., curl from the internet, not local)
  - Use WebFetch tool or external DNS resolution to verify services are reachable from outside
  - Local curl from the Proxmox host does NOT validate public accessibility
  - End-to-end tests must emulate a real user accessing from the internet

* Service Registry - ENFORCING:
  - ALWAYS use inventory/group_vars/all/services.yml as the single source of truth for deployed services
  - NEVER guess or assume which services exist - read the services.yml file first
  - Only test/deploy services that are listed in the registry
  - When adding new services, register them in services.yml BEFORE deployment

* Links Portal - ENFORCING:
  - ALL services in services.yml MUST be included in the links.viljo.se portal
  - Exception: Services with `show_in_portal: false` are explicitly excluded
  - The portal is AUTO-GENERATED from services.yml - do NOT edit HTML manually
  - ALWAYS run `ansible-playbook playbooks/links-portal-deploy.yml` after modifying services.yml
  - The links portal is the user-facing service directory - keep it in sync

* Loopia DNS Records - ENFORCING:
  - ALWAYS delete/replace old DNS records before adding new ones
  - NEVER add duplicate A records - remove the old IP first, then add the new one
  - The loopia-ddns script MUST remove existing records before creating new ones
  - If DNS shows multiple A records for the same subdomain, clean up duplicates immediately

* Container Hygiene - ENFORCING:
  - When troubleshooting errors or deploying/changing services, ALWAYS check for:
    1. Old/stale containers with same Traefik labels (causes load-balancing conflicts)
    2. Duplicate containers from previous deployments
    3. Containers not defined in Ansible playbooks (orphaned containers)
  - Verification commands:
    ```bash
    # List all containers (including stopped)
    pct exec 200 -- docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

    # Check for containers with conflicting Traefik labels
    pct exec 200 -- docker ps --format '{{.Names}}' | xargs -I{} docker inspect {} --format '{{.Name}} {{index .Config.Labels "traefik.http.routers.*"}}'

    # Find containers not in current docker-compose files
    pct exec 200 -- docker ps --format '{{.Names}}' | sort > /tmp/running
    # Compare against expected containers from Ansible
    ```
  - If duplicate/orphaned containers found: `pct exec 200 -- docker rm -f <container>`
  - Root cause of many "random 502 errors" or "intermittent failures" is old containers with same routing rules
