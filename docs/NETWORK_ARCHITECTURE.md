# Network Architecture - Proxmox Infrastructure with Coolify PaaS

**CRITICAL**: This document explains the simplified network architecture to prevent misunderstandings.

**Last Updated**: 2025-11-10
**Status**: Authoritative Reference
**Related**:
- [Network Topology](architecture/network-topology.md)
- [ADR-001: Network Architecture Decision](adr/001-network-topology-change.md)

---

## ARCHITECTURE OVERVIEW: SIMPLE IS BETTER

### The Reality (Current Implementation)

**One LXC container running everything:**
- **Coolify LXC 200**: Single container hosting all services as Docker containers
- **Direct Internet**: Coolify exposed directly to internet via vmbr2 (no firewall/NAT layer)
- **Management Network**: Separate management access via vmbr0
- **Unused DMZ**: vmbr3 created but DOWN, reserved for future use

**Why this approach:**
- Eliminated complexity of 16+ individual LXC containers
- PaaS management via Coolify API and dashboard
- Faster deployments, easier maintenance
- Modern Docker-based infrastructure

---

## WARNING: COMMON MISCONCEPTIONS

### MISCONCEPTION #1: Proxmox Host Should Have Internet

**INCORRECT ASSUMPTION**:
- The Proxmox host (192.168.1.3) should be able to ping 1.1.1.1
- The management network (vmbr0) needs internet access
- Lack of internet on Proxmox is a problem

**CORRECT UNDERSTANDING**:
- The Proxmox host does **NOT** have direct internet access
- The management network (vmbr0) is **management only**
- Internet flows through vmbr2 → Coolify LXC → Docker containers
- Proxmox host cannot and should not ping external IPs

**Why This Is Correct**:
- Management network isolated from production traffic
- Proxmox only needs SSH access for administration
- All services run inside Coolify Docker containers with their own network

### MISCONCEPTION #2: We Need a Firewall Container

**INCORRECT ASSUMPTION**:
- There should be a firewall container (LXC 101) between internet and services
- vmbr3 should be a DMZ network with NAT/routing
- Services shouldn't be directly exposed to internet

**CORRECT UNDERSTANDING**:
- **No firewall container exists** (never deployed)
- Coolify LXC directly exposed to internet on vmbr2
- vmbr3 exists but is DOWN/unused (reserved for future)
- Security provided by Coolify Proxy, Docker isolation, and application security

**Why This Was Chosen**:
- Single public IP doesn't benefit from NAT
- Coolify Proxy provides SSL termination and routing
- Simpler architecture easier to maintain
- Can add firewall layer later if needed (vmbr3 available)

### MISCONCEPTION #3: Each Service Has Its Own LXC Container

**INCORRECT ASSUMPTION**:
- GitLab runs in LXC 153
- Nextcloud runs in LXC 155
- Each service has a dedicated container on vmbr3

**CORRECT UNDERSTANDING**:
- **Only one LXC container**: Coolify (ID: 200)
- All services run as **Docker containers** inside Coolify LXC
- Services managed via Coolify API, not individual LXCs
- Container deployment happens via Ansible playbooks calling Coolify API

---

## Network Architecture Details

### Bridge Configuration Table

| Bridge | Network | Purpose | Internet Access | Proxmox Host | Notes |
|--------|---------|---------|----------------|--------------|-------|
| **vmbr0** | 192.168.1.0/16 | Management ONLY | NO | YES (192.168.1.3) | SSH access to Proxmox, Ansible API access to Coolify |
| **vmbr2** | DHCP from ISP | WAN/Public Internet | YES | NO | Coolify public interface, all DNS records point here |
| **vmbr3** | 172.16.10.0/24 | Reserved (unused) | NO | NO | Created but DOWN, available for future segmentation |

### Network Topology Diagram

```
                            INTERNET
                               |
                       ISP Router (DHCP)
                               |
                               v
                    +---------------------+
                    |   vmbr2 (WAN)       |
                    |   Bridge on Proxmox |
                    +----------+----------+
                               |
                               | Public IP via DHCP
                               |
                +--------------+----------------+
                |   Coolify LXC 200 (eth0)     |
                |   Public IP from ISP         |
                |                               |
                |  +------------------------+   |
                |  |   Coolify Proxy        |   |
                |  |   (SSL termination,    |   |
                |  |    routing, Let's      |   |
                |  |    Encrypt)            |   |
                |  +----------+-------------+   |
                |             |                 |
                |             v                 |
                |  +------------------------+   |
                |  |  Docker Containers     |   |
                |  |  - Nextcloud           |   |
                |  |  - GitLab (if enabled) |   |
                |  |  - Jellyfin            |   |
                |  |  - qBittorrent         |   |
                |  |  - Links Portal        |   |
                |  |  - Other services      |   |
                |  +------------------------+   |
                |                               |
                |   Coolify LXC 200 (eth1)      |
                |   192.168.1.200/16            |
                +---------------+---------------+
                                |
                                | Management Network
                                |
                    +-----------+-----------+
                    |   vmbr0 (Management)  |
                    |   192.168.1.0/16      |
                    +-----------+-----------+
                                |
                                v
                    Proxmox Host (192.168.1.3)
                    Ansible Control Plane


    [vmbr3 - DOWN/Unused]
    172.16.10.0/24 - Reserved for future use
```

---

## Detailed Component Breakdown

### 1. Proxmox Host

**IP Address**: 192.168.1.3/16 on vmbr0
**Role**: Hypervisor and management platform
**Internet Access**: NO (by design)
**Purpose**:
- Runs LXC containers and VMs
- Provides SSH access for administration
- Executes Ansible playbooks
- Hosts Loopia DDNS service (updates DNS records)

**Why no internet**:
- Management network isolated from production
- Doesn't need direct internet access
- Security best practice: management separate from services

### 2. Coolify LXC Container (ID: 200)

**Container Type**: Privileged LXC with Docker support
**Operating System**: Debian-based
**Resource Allocation**: Adequate for running multiple Docker containers

**Network Interfaces**:

#### eth0 → vmbr2 (Public/WAN)
- **IP**: Dynamic via DHCP from ISP
- **Purpose**: Public internet access, service exposure
- **DNS Records**: All *.viljo.se point to this IP
- **Traffic**: All incoming HTTPS/HTTP requests
- **Security**: Coolify Proxy handles SSL, routing, rate limiting

#### eth1 → vmbr0 (Management)
- **IP**: 192.168.1.200/16 (static)
- **Purpose**: Ansible API access, management
- **Traffic**: Coolify API calls (port 8000)
- **Access**: From Proxmox host only

**Services Running**:
- **Docker Engine**: Container runtime
- **Coolify API**: Service management (port 8000)
- **Coolify Proxy**: Built-in reverse proxy (replaces Traefik)
- **Coolify Dashboard**: Web UI for management
- **Application Containers**: All services as Docker containers

### 3. Network Bridges (Proxmox Host)

#### vmbr0 - Management Network

**Network**: 192.168.1.0/16
**Status**: Active
**Physical**: Connected to local network switch
**Purpose**: Management and administration
**Connected Devices**:
- Proxmox host (192.168.1.3)
- Coolify eth1 (192.168.1.200)
- Workstations/laptops for SSH access

**Traffic Types**:
- SSH to Proxmox host
- Ansible API calls to Coolify
- Coolify dashboard access (via SSH tunnel or VPN)

**No Internet**: This bridge does NOT have internet connectivity

#### vmbr2 - WAN/Public Internet

**Network**: No static network (DHCP from ISP)
**Status**: Active
**Physical**: Connected to ISP router
**Purpose**: Public internet connectivity
**Connected Devices**:
- Coolify eth0 (gets public IP via DHCP)

**Traffic Types**:
- All incoming HTTPS requests (443)
- All incoming HTTP requests (80, redirected to HTTPS)
- Outbound internet from Docker containers
- DNS queries
- Let's Encrypt certificate challenges

**DNS Configuration**:
- Loopia DDNS monitors this interface
- Updates all *.viljo.se to current public IP
- Runs every 15 minutes via systemd timer

#### vmbr3 - Reserved/Unused DMZ

**Network**: 172.16.10.0/24 (configured but not active)
**Status**: DOWN (no carrier)
**Physical**: Created but no cable connected
**Purpose**: Reserved for future network segmentation
**Connected Devices**: None

**Why it exists**:
- Originally planned as DMZ network
- Created during initial setup
- Never activated in actual deployment
- Available if architecture changes

**Future Use Cases**:
- If firewall/NAT layer added
- If services moved behind DMZ
- If network segmentation required
- Can be activated without infrastructure changes

---

## Service Management

### Deployment Architecture

**Traditional Approach** (NOT used):
- Create individual LXC containers for each service
- Configure networking for each container
- Install and configure service in each LXC
- Manage updates per container

**Coolify Approach** (Current):
- Services defined as Docker Compose configurations
- Deployed via Coolify API calls from Ansible
- Coolify manages container lifecycle
- Updates via Coolify dashboard or API

### Deployment Flow

```
Developer/Operator
       |
       | Runs Ansible playbook
       v
Ansible Control Machine
       |
       | API Call (http://192.168.1.200:8000/api/v1/services)
       v
Coolify API (Coolify LXC)
       |
       | Creates Docker containers
       v
Docker Engine (Coolify LXC)
       |
       | Containers join Docker networks
       v
Coolify Proxy
       |
       | Routes traffic based on FQDN
       v
Application Containers
       |
       | Services accessible at https://service.viljo.se
       v
Internet Users
```

### Service Discovery

**Coolify Dashboard**: https://paas.viljo.se
- View all services
- Check container health
- View logs
- Manage deployments

**Coolify API**: http://192.168.1.200:8000/api/v1
- Programmatic access
- Service CRUD operations
- Health checks
- Deployment automation

**Direct Service Access**: https://service.viljo.se
- Public access to services
- SSL via Let's Encrypt
- Routed through Coolify Proxy

---

## DNS and SSL Configuration

### Loopia DDNS Service

**Location**: Proxmox host (systemd service)
**Script**: `/usr/local/lib/loopia-ddns/update.py`
**Frequency**: Every 15 minutes (systemd timer)
**Monitoring**: Coolify LXC 200 eth0 interface

**How It Works**:

1. **IP Detection**:
```python
# Runs on Proxmox host
pct exec 200 -- ip -4 addr show eth0
# Extracts public IP from eth0 (vmbr2)
```

2. **DNS Update**:
```python
# Calls Loopia API
client.updateZoneRecord(
    username=vault_loopia_api_user,
    password=vault_loopia_api_password,
    domain="viljo.se",
    subdomain="*",  # All subdomains
    ip=current_public_ip
)
```

3. **Result**:
- paas.viljo.se → Current public IP
- nextcloud.viljo.se → Current public IP
- All other services → Current public IP

### SSL Certificate Management

**Provider**: Let's Encrypt (via Coolify Proxy)
**Method**: Automatic via Coolify
**Renewal**: Automatic before expiration
**Challenge Type**: HTTP-01 or DNS-01 (configurable)

**Process**:
1. Service added to Coolify with FQDN
2. Coolify Proxy requests certificate from Let's Encrypt
3. Certificate stored and configured automatically
4. Auto-renewal 30 days before expiration

---

## HOW TO TEST CONNECTIVITY CORRECTLY

### WRONG: Testing from Proxmox Host

These will FAIL (and should):

```bash
# From workstation
ssh root@192.168.1.3 "ping 1.1.1.1"
# Result: FAIL - Proxmox has no internet

ssh root@192.168.1.3 "curl https://google.com"
# Result: FAIL - Proxmox has no internet

ssh root@192.168.1.3 "apt update"
# Result: FAIL - Proxmox has no internet
```

### CORRECT: Testing from Coolify LXC

These will SUCCEED:

```bash
# Test from Coolify LXC
ssh root@192.168.1.3 "pct exec 200 -- ping -c 2 1.1.1.1"
# Result: SUCCESS - Coolify has internet via eth0

ssh root@192.168.1.3 "pct exec 200 -- curl -s https://google.com"
# Result: SUCCESS - Coolify can reach internet

ssh root@192.168.1.3 "pct exec 200 -- docker ps"
# Result: Shows all running containers
```

### CORRECT: Testing Services Externally

```bash
# From workstation (internet access)
curl -I https://paas.viljo.se
# Result: HTTP/2 200 - Coolify dashboard

curl -I https://nextcloud.viljo.se
# Result: HTTP/2 200 - Nextcloud (if deployed)

dig +short paas.viljo.se @1.1.1.1
# Result: Shows current public IP
```

### Verifying Network Configuration

**Check Coolify Public IP**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- ip addr show eth0 | grep inet"
# Should show public IP from ISP
```

**Check Coolify Management IP**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- ip addr show eth1 | grep inet"
# Should show 192.168.1.200/16
```

**Check DNS Resolution**:
```bash
dig +short paas.viljo.se @1.1.1.1
# Should match Coolify eth0 public IP
```

**Check Coolify API**:
```bash
curl -s http://192.168.1.200:8000/health
# Should return: {"status":"ok"}
```

**Check Docker Containers**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- docker ps --format 'table {{.Names}}\t{{.Status}}'"
# Shows all running containers
```

**Check Coolify Proxy**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- docker logs coolify-proxy 2>&1 | tail -20"
# Shows recent proxy logs
```

---

## Troubleshooting Guide

### Problem: Services Not Accessible from Internet

**Symptoms**:
- Cannot access https://service.viljo.se
- Connection timeout or refused

**Debugging Steps**:

1. **Check Coolify LXC Running**:
```bash
ssh root@192.168.1.3 "pct status 200"
# Should show: running
```

2. **Check Docker Service**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- systemctl status docker"
# Should show: active (running)
```

3. **Check Coolify Proxy**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- docker ps | grep coolify-proxy"
# Should show proxy container running
```

4. **Check Service Container**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- docker ps | grep service-name"
# Should show your service container
```

5. **Check DNS**:
```bash
dig +short service.viljo.se @1.1.1.1
# Should return Coolify public IP
```

6. **Check from Coolify**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- curl -I http://localhost"
# Test if proxy is responding locally
```

### Problem: Coolify API Not Accessible

**Symptoms**:
- Ansible playbooks fail with connection error
- Cannot reach http://192.168.1.200:8000

**Debugging Steps**:

1. **Check Coolify LXC eth1**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- ip addr show eth1"
# Should show 192.168.1.200/16
```

2. **Check Coolify API Process**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- ps aux | grep coolify"
# Should show Coolify processes
```

3. **Test API from Proxmox**:
```bash
ssh root@192.168.1.3 "curl -s http://192.168.1.200:8000/health"
# Should return health status
```

4. **Check Firewall**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- iptables -L -n"
# Verify no blocking rules
```

### Problem: SSL Certificate Issues

**Symptoms**:
- Certificate expired warnings
- SSL handshake failures

**Resolution**:
- Coolify automatically renews certificates
- Check Coolify dashboard for certificate status
- Manually trigger renewal if needed via dashboard
- Verify DNS points to correct IP

### Problem: DNS Not Updating

**Symptoms**:
- Public IP changed but DNS still shows old IP
- Cannot access services after IP change

**Debugging Steps**:

1. **Check DDNS Timer**:
```bash
ssh root@192.168.1.3 "systemctl status loopia-ddns.timer"
# Should show: active
```

2. **Check Last Run**:
```bash
ssh root@192.168.1.3 "systemctl status loopia-ddns.service | tail -20"
# Shows last execution
```

3. **Check Current IP**:
```bash
ssh root@192.168.1.3 "pct exec 200 -- curl -s ifconfig.me"
# Shows current public IP from internet perspective
```

4. **Check DNS**:
```bash
dig +short paas.viljo.se @1.1.1.1
# Should match current public IP
```

5. **Manually Trigger Update**:
```bash
ssh root@192.168.1.3 "systemctl start loopia-ddns.service"
# Triggers immediate DNS update
```

---

## Security Considerations

### Current Security Model

**Positive Controls**:
- **SSL Everywhere**: All public services use HTTPS (Let's Encrypt)
- **Docker Isolation**: Containers isolated from each other
- **Coolify Proxy**: Central point for rate limiting, SSL termination
- **SSH Keys Only**: No password authentication
- **Ansible Vault**: All secrets encrypted
- **Application Security**: Services implement their own authentication

**Known Trade-offs**:
- **No Firewall Layer**: Coolify directly exposed to internet
  - Acceptable for single public IP
  - Application-level security sufficient
  - Can add firewall later if needed
- **Single LXC**: All services in one container
  - Mitigated by Docker isolation
  - Quick recovery via Ansible
- **No DMZ**: vmbr3 unused
  - Can be activated if requirements change

### Attack Surface Analysis

**Exposed to Internet**:
- Port 80 (HTTP): Redirects to HTTPS
- Port 443 (HTTPS): Coolify Proxy handles all requests
- Coolify LXC eth0 public IP

**Not Exposed**:
- Proxmox host (no internet access)
- Coolify management interface (vmbr0 only)
- Docker container IPs (internal to Coolify LXC)
- vmbr0 network (management only)

**Mitigation Strategies**:
1. **Coolify Proxy**: First line of defense
   - SSL termination
   - Request routing
   - Can implement rate limiting
2. **Docker Networks**: Isolation between containers
3. **Application Security**: Each service manages authentication
4. **Regular Updates**: Coolify and Docker kept current
5. **Monitoring**: Coolify dashboard shows container health

### Future Hardening Options

If security requirements increase:

1. **Add Firewall Layer**:
   - Create firewall LXC with eth0→vmbr2, eth1→vmbr3
   - Move Coolify eth0 from vmbr2 to vmbr3
   - Configure NAT/routing on firewall
   - Add iptables/nftables rules

2. **Activate vmbr3 DMZ**:
   - Configure vmbr3 network
   - Move services behind firewall
   - Implement network segmentation

3. **Add Proxmox Firewall**:
   - Enable Proxmox host firewall
   - Add rules at bridge level
   - Additional defense layer

4. **Implement fail2ban**:
   - Install in Coolify LXC
   - Monitor Coolify Proxy logs
   - Auto-ban aggressive scanners

5. **Web Application Firewall**:
   - Add ModSecurity to Coolify Proxy
   - OWASP rules for common attacks
   - Custom rules for specific threats

---

## Comparison: Documented vs Actual Architecture

### What Documentation USED TO Describe

**Old Architecture (Never Actually Deployed)**:
- Firewall LXC 101 with nftables
- vmbr3 as active DMZ network (172.16.10.0/24)
- 16+ individual service LXC containers
- Traefik running on Proxmox host
- NAT/routing between vmbr2 and vmbr3
- Port forwarding rules (80/443 → Traefik)

### What ACTUALLY Exists (Current Reality)

**Current Architecture (Deployed 2025-11-10)**:
- Coolify LXC 200 (single container)
- vmbr2 for WAN (Coolify eth0 public IP)
- vmbr3 created but DOWN/unused
- All services as Docker containers
- Coolify Proxy (built-in, replaces Traefik)
- No firewall/NAT layer
- Direct internet exposure

### Migration Timeline

- **2025-10-18**: vmbr1 connectivity issues identified
- **2025-10-19**: Decision to adopt Coolify PaaS approach
- **2025-10-19**: Coolify LXC deployed on vmbr2/vmbr0
- **2025-10-19**: Individual LXC containers decommissioned
- **2025-10-20**: Initial (incorrect) documentation created
- **2025-11-10**: Documentation corrected to match reality

---

## Operations

### Daily Operations

**Service Deployment**:
```bash
# Run Ansible playbook to deploy service
cd /path/to/ansible
ansible-playbook -i inventory/production.ini \
  playbooks/deploy-service-via-api.yml \
  --vault-password-file=.vault_pass.txt
```

**Check Infrastructure Status**:
```bash
# Run status check script
bash /Users/anders/git/Proxmox_config/scripts/check-infrastructure-status.sh
```

**View Service Logs**:
```bash
# Via Coolify dashboard
open https://paas.viljo.se

# Via CLI
ssh root@192.168.1.3 "pct exec 200 -- docker logs service-name"
```

### Backup Strategy

**What Gets Backed Up**:
- Coolify LXC configuration
- Docker volumes (service data)
- Ansible vault (secrets)
- Infrastructure as code (Git repository)

**What Doesn't Need Backup**:
- Docker images (reproducible from registries)
- Coolify binary (can be reinstalled)
- Proxmox OS (can be reinstalled)

### Disaster Recovery

**Scenario: Complete Proxmox Host Failure**

1. **Reinstall Proxmox**:
   - Boot from Proxmox ISO
   - Configure vmbr0, vmbr2, vmbr3

2. **Restore Repository**:
   - Clone Proxmox_config repository
   - Configure vault password

3. **Run Coolify Deployment**:
   ```bash
   ansible-playbook -i inventory/production.ini \
     playbooks/coolify-deploy.yml \
     --vault-password-file=.vault_pass.txt
   ```

4. **Deploy Services**:
   ```bash
   # Run service deployment playbooks
   # Coolify will pull Docker images and restore from volumes
   ```

5. **Verify DNS**:
   - DDNS will auto-update within 15 minutes
   - Or manually trigger update

**Recovery Time Objective**: 1-2 hours for full restoration

---

## References and Related Documentation

### Internal Documentation
- [Network Topology](architecture/network-topology.md) - Detailed topology
- [ADR-001](adr/001-network-topology-change.md) - Architecture decision record
- [Container Mapping](architecture/container-mapping.md) - Container assignments
- [Getting Started](getting-started.md) - Setup guide
- [DR Runbook](DR_RUNBOOK.md) - Disaster recovery procedures

### Configuration Files
- `inventory/group_vars/all/main.yml` - Network configuration
- `inventory/group_vars/all/services.yml` - Service definitions
- `inventory/group_vars/all/secrets.yml` - Encrypted secrets
- `scripts/check-infrastructure-status.sh` - Health check script

### External Documentation
- [Coolify Documentation](https://coolify.io/docs)
- [Docker Documentation](https://docs.docker.com/)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

---

## Appendix: Command Reference

### Proxmox Commands

```bash
# List all containers
pct list

# Check container status
pct status 200

# Execute command in container
pct exec 200 -- <command>

# Enter container console
pct enter 200

# Check bridge configuration
ip addr show vmbr0
ip addr show vmbr2
ip addr show vmbr3
```

### Coolify Commands

```bash
# Check Docker status
pct exec 200 -- systemctl status docker

# List containers
pct exec 200 -- docker ps

# Check specific service
pct exec 200 -- docker ps | grep service-name

# View logs
pct exec 200 -- docker logs service-name

# Check Coolify Proxy
pct exec 200 -- docker logs coolify-proxy
```

### DNS Commands

```bash
# Check DNS resolution
dig +short paas.viljo.se @1.1.1.1

# Check all service DNS
for service in paas nextcloud jellyfin; do
  echo "$service.viljo.se: $(dig +short $service.viljo.se @1.1.1.1)"
done

# Trigger DDNS update
ssh root@192.168.1.3 "systemctl start loopia-ddns.service"

# Check DDNS status
ssh root@192.168.1.3 "systemctl status loopia-ddns.service"
```

### Network Diagnostics

```bash
# Check Coolify public IP
ssh root@192.168.1.3 "pct exec 200 -- ip addr show eth0 | grep inet"

# Check Coolify management IP
ssh root@192.168.1.3 "pct exec 200 -- ip addr show eth1 | grep inet"

# Test internet from Coolify
ssh root@192.168.1.3 "pct exec 200 -- ping -c 2 1.1.1.1"

# Test Coolify API
curl -s http://192.168.1.200:8000/health

# Test service externally
curl -I https://paas.viljo.se
```

---

**Document Maintainer**: Infrastructure Team
**Review Schedule**: Monthly
**Next Review**: 2025-12-10
**Version**: 2.0 (Rewritten for Coolify architecture)
