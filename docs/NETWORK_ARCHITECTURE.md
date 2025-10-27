# Network Architecture - Proxmox Infrastructure

**CRITICAL**: This document explains the network architecture to prevent recurring misunderstandings about internet connectivity.

**Last Updated**: 2025-10-27
**Status**: Authoritative Reference
**Related**:
- [Network Topology](architecture/network-topology.md)
- [ADR-001: Network Topology Redesign](adr/001-network-topology-change.md)
- [Firewall Deployment](deployment/firewall-deployment.md)

---

## WARNING: COMMON MISTAKE - READ THIS FIRST

### THE RECURRING MISUNDERSTANDING

There has been a **very common recurring mistake** about this network architecture:

**INCORRECT ASSUMPTION**:
- The 192.168.x network (vmbr0) should have internet access
- The Proxmox host should be able to ping external IPs (1.1.1.1, 8.8.8.8, etc.)
- Lack of internet on Proxmox host is a problem that needs fixing

**CORRECT UNDERSTANDING**:
- The 192.168.x network (vmbr0) is **MANAGEMENT ONLY** - it is **NOT** the internet connection
- The Proxmox host does **NOT** need direct internet access
- Internet flows through vmbr2 → Firewall container → vmbr3 (DMZ)
- The Proxmox host CANNOT and SHOULD NOT ping external IPs directly

### WHY THIS MATTERS

If you try to:
- Ping 1.1.1.1 from the Proxmox host → **WILL FAIL** (this is correct behavior)
- Access the internet from 192.168.1.3 → **WILL FAIL** (this is by design)
- Test internet connectivity from vmbr0 → **WILL FAIL** (this is intentional)

**This is NOT a problem. This is the architecture working as designed.**

### HOW TO TEST INTERNET CONNECTIVITY CORRECTLY

**WRONG**:
```bash
# From your workstation
ssh root@192.168.1.3 "ping 1.1.1.1"  # WILL FAIL - THIS IS EXPECTED
```

**CORRECT**:
```bash
# Test from a container on vmbr3 (DMZ)
ssh root@192.168.1.3 "pct exec 153 -- ping -c 2 1.1.1.1"  # GitLab container
ssh root@192.168.1.3 "pct exec 155 -- ping -c 2 1.1.1.1"  # Nextcloud container
```

---

## Network Architecture Overview

This Proxmox infrastructure uses a **three-bridge security architecture** with strict separation between management, WAN, and service networks.

### Bridge Summary Table

| Bridge | Network | Purpose | Internet | ISP | Proxmox Host Access |
|--------|---------|---------|----------|-----|---------------------|
| **vmbr0** | 192.168.1.0/24 | Management ONLY | NO | Starlink (CGNAT) | YES (192.168.1.3) |
| **vmbr2** | DHCP from ISP | WAN/Internet | YES | Bahnhof (Public IP) | NO |
| **vmbr3** | 172.16.10.0/24 | Service DMZ | Via Firewall | Internal | YES (172.16.10.1) |

### Critical Understanding

1. **vmbr0 (Management Network)**
   - Used ONLY for administrative SSH access to Proxmox host
   - Connected to Starlink ISP (behind CGNAT)
   - **Has NO internet connectivity** (by design)
   - Proxmox host IP: 192.168.1.3
   - Purpose: Secure management access separate from production traffic

2. **vmbr2 (WAN/Internet Connection)**
   - This is the **ACTUAL internet connection**
   - Connected to Bahnhof ISP (public IP, NOT CGNAT)
   - Connected ONLY to firewall container (LXC 101) WAN interface
   - Gets public IP via DHCP
   - This is where DNS records point (*.viljo.se)

3. **vmbr3 (Service DMZ Network)**
   - Private network for all service containers
   - Network: 172.16.10.0/24
   - Gateway: 172.16.10.101 (firewall container LAN interface)
   - DNS: 172.16.10.101, 1.1.1.1
   - Internet access via NAT through firewall container

---

## Network Topology Diagram

### Three-Bridge Architecture

```
                                    INTERNET
                                       |
                                       |
        ┌──────────────────────────────┼──────────────────────────────┐
        |                              |                              |
        |                              |                              |
   Starlink ISP                   Bahnhof ISP                         |
   (CGNAT - NO inbound)          (Public IP)                          |
        |                              |                              |
        |                              |                              |
   ╔════▼════╗                    ╔════▼════╗                         |
   ║  vmbr0  ║                    ║  vmbr2  ║                         |
   ║ (br0)   ║                    ║ (br2)   ║                         |
   ╠═════════╣                    ╠═════════╣                         |
   ║ 192.168 ║                    ║  DHCP   ║                         |
   ║ .1.0/24 ║                    ║ from ISP║                         |
   ╚════╤════╝                    ╚════╤════╝                         |
        │                              │                              |
        │ MANAGEMENT ONLY              │ WAN ONLY                     |
        │                              │                              |
   ┌────▼─────────────┐          ┌─────▼─────────────┐               |
   │  Proxmox Host    │          │ Firewall (LXC 101)│               |
   │  192.168.1.3     │          │ eth0: vmbr2 (DHCP)│               |
   │                  │          │ eth1: 172.16.10.101               |
   │  - SSH Access    │          │                   │               |
   │  - Management    │          │  - NAT/Routing    │               |
   │  - NO Internet   │          │  - Port Forwarding│               |
   └──────────────────┘          │  - Firewall Rules │               |
                                 └─────┬─────────────┘               |
                                       │                              |
                                       │ ROUTES/NATS                  |
                                       │                              |
                                  ╔════▼════╗                         |
                                  ║  vmbr3  ║                         |
                                  ║ (br3)   ║                         |
                                  ╠═════════╣                         |
                                  ║172.16.10║                         |
                                  ║  .0/24  ║                         |
                                  ╚════╤════╝                         |
                                       │                              |
                        ┌──────────────┼──────────────┐               |
                        │              │              │               |
                   ┌────▼────┐    ┌────▼────┐   ┌────▼────┐          |
                   │ GitLab  │    │Nextcloud│   │Keycloak │          |
                   │ LXC 153 │    │ LXC 155 │   │ LXC 151 │          |
                   │172.16.  │    │172.16.  │   │172.16.  │          |
                   │ 10.153  │    │ 10.155  │   │ 10.151  │          |
                   └─────────┘    └─────────┘   └─────────┘          |
                                                                      |
                   [ ALL SERVICE CONTAINERS ON vmbr3 ]               |
                   [ Gateway: 172.16.10.101 ]                        |
                   [ Internet: Via Firewall NAT ]                    |
                                                                      |
        ┌─────────────────────────────────────────────────────┐      |
        │  Traefik (on Proxmox Host)                          │      |
        │  - Listens on 172.16.10.1:80/443                    │      |
        │  - Receives traffic via port forwarding from        │      |
        │    firewall (vmbr2:80/443 → 172.16.10.1:80/443)    │      |
        │  - Proxies to service containers on vmbr3           │      |
        └─────────────────────────────────────────────────────┘      |
                                       ▲                              |
                                       |                              |
                                       └──────────────────────────────┘
                                          DNS (*.viljo.se)
                                          Points to vmbr2 Public IP
```

---

## Internet Traffic Flow

### Inbound Traffic (Internet → Services)

```
Internet User
    |
    | HTTPS Request to gitlab.viljo.se
    |
    ▼
DNS Resolution (*.viljo.se → vmbr2 Public IP)
    |
    ▼
Bahnhof ISP (vmbr2)
    |
    ▼
Firewall Container (LXC 101) - eth0 on vmbr2
    |
    | nftables DNAT rule:
    | tcp dport {80,443} → 172.16.10.1:80/443
    |
    ▼
Traefik (Proxmox Host on vmbr3: 172.16.10.1)
    |
    | Traefik routing based on hostname
    |
    ▼
Service Container (e.g., GitLab LXC 153 on vmbr3)
    |
    ▼
Service responds
```

### Outbound Traffic (Services → Internet)

```
Service Container (e.g., Nextcloud LXC 155)
    |
    | Default route: 172.16.10.101
    |
    ▼
Firewall Container (LXC 101) - eth1 on vmbr3
    |
    | nftables MASQUERADE:
    | Source: 172.16.10.0/24
    | Output interface: eth0 (vmbr2)
    |
    ▼
Bahnhof ISP (vmbr2)
    |
    ▼
Internet
```

### Management Access (Your Workstation → Proxmox)

```
Your Workstation
    |
    | SSH to 192.168.1.3
    |
    ▼
Starlink ISP (CGNAT)
    |
    ▼
vmbr0 (Management Bridge)
    |
    ▼
Proxmox Host (192.168.1.3)
    |
    | STOPS HERE - NO INTERNET ACCESS
    |
    ✗ CANNOT reach internet from here
```

---

## Why This Architecture Exists

### Security Benefits

1. **Separation of Concerns**
   - Management traffic (vmbr0) is completely separate from production (vmbr3)
   - Production services never exposed directly to internet
   - Firewall container is single choke point for all internet traffic

2. **Defense in Depth**
   - Firewall container provides NAT isolation
   - All inbound traffic must go through firewall nftables rules
   - Service containers cannot be directly accessed from internet

3. **ISP Limitations**
   - Starlink uses CGNAT - cannot host public services
   - Bahnhof provides public IP - required for hosting
   - Separating management (Starlink) from production (Bahnhof) ensures stability

### Operational Benefits

1. **Clear Network Boundaries**
   - Easy to reason about traffic flows
   - Troubleshooting is straightforward
   - Each bridge has exactly one purpose

2. **Scalability**
   - Easy to add new services to vmbr3
   - All routing decisions centralized at firewall
   - No complex routing on service containers

3. **Standard Enterprise Pattern**
   - DMZ architecture is industry standard
   - Well-understood security model
   - Aligns with infrastructure best practices

---

## Detailed Bridge Configuration

### vmbr0 (Management Bridge)

**Purpose**: Management access ONLY

**Configuration**:
- Network: 192.168.1.0/24
- Physical connection: Starlink ISP (CGNAT)
- Proxmox host IP: 192.168.1.3
- Netmask: 255.255.255.0 (/24)
- Gateway: 192.168.1.1 (Starlink router)

**Connected Devices**:
- Proxmox host management interface ONLY
- NO containers connected to this bridge

**Capabilities**:
- SSH access to Proxmox host
- Proxmox web UI access (https://192.168.1.3:8006)
- Management operations (pct, pvesh, etc.)

**Limitations**:
- **NO internet access** (by design)
- Behind CGNAT - cannot receive inbound connections from internet
- ONLY for management traffic

**Why Starlink/CGNAT**:
- Starlink connection is used for management access
- CGNAT means NO inbound connections possible
- This is fine because this bridge is ONLY for management
- Production services use Bahnhof (vmbr2) instead

### vmbr2 (WAN Bridge)

**Purpose**: Internet connection ONLY

**Configuration**:
- IP: DHCP from Bahnhof ISP
- Physical connection: Bahnhof ISP (public IP)
- Netmask: Provided by DHCP
- Gateway: Provided by DHCP

**Connected Devices**:
- Firewall container (LXC 101) eth0 interface ONLY
- NO other devices connected

**Capabilities**:
- Public IP address (NOT CGNAT)
- Fully routable from internet
- Receives all inbound internet traffic
- Source of outbound internet connectivity

**DNS Configuration**:
- All DNS records (*.viljo.se) point to this bridge's public IP
- Loopia DDNS updates every 15 minutes
- IP read from firewall container eth0 interface

**Security**:
- Only firewall container connected
- All traffic must go through firewall nftables rules
- No services directly exposed

### vmbr3 (DMZ/Service Bridge)

**Purpose**: Internal service network

**Configuration**:
- Network: 172.16.10.0/24
- Proxmox host IP: 172.16.10.1
- Netmask: 255.255.255.0 (/24)
- Gateway: 172.16.10.101 (firewall container)
- DNS: 172.16.10.101, 1.1.1.1

**Connected Devices**:
- Firewall container (LXC 101) eth1 interface
- ALL service containers (GitLab, Nextcloud, Keycloak, etc.)
- Proxmox host has IP on this bridge

**IP Allocation Standard**:
- 172.16.10.1: Proxmox host (Traefik listener)
- 172.16.10.101: Firewall container gateway
- 172.16.10.{container_id}: Service containers
  - Example: GitLab LXC 153 → 172.16.10.153
  - Example: Nextcloud LXC 155 → 172.16.10.155

**Capabilities**:
- Inter-container communication
- Internet access via firewall NAT
- Traefik routing to services
- Private network - not directly internet accessible

**Traffic Flows**:
- Inbound: vmbr2 → firewall → DNAT → Traefik (172.16.10.1) → service container
- Outbound: service container → firewall gateway → MASQUERADE → vmbr2 → internet
- Inter-container: direct communication on same L2 network

---

## Firewall Container (LXC 101) Configuration

The firewall container is the **critical linchpin** of this architecture.

### Interfaces

**eth0 (WAN Interface)**:
- Bridge: vmbr2
- IP: DHCP from Bahnhof ISP
- Purpose: Internet connectivity
- Direction: Inbound and outbound internet traffic

**eth1 (LAN Interface)**:
- Bridge: vmbr3
- IP: 172.16.10.101/24 (static)
- Purpose: DMZ gateway
- Direction: Service network routing

### nftables Configuration

**NAT Table - Masquerading (Outbound)**:
```nft
table ip nat {
    chain postrouting {
        type nat hook postrouting priority srcnat;
        ip saddr 172.16.10.0/24 oifname "eth0" masquerade
    }
}
```
- Translates source IPs from DMZ (172.16.10.0/24) to WAN IP
- Allows service containers to reach internet
- Response packets automatically translated back

**NAT Table - DNAT (Inbound)**:
```nft
table ip nat {
    chain prerouting {
        type nat hook prerouting priority dstnat;
        iifname "eth0" tcp dport 80 dnat to 172.16.10.1:80
        iifname "eth0" tcp dport 443 dnat to 172.16.10.1:443
    }
}
```
- Forwards HTTP/HTTPS from WAN to Traefik
- Traefik runs on Proxmox host at 172.16.10.1
- All web traffic goes through Traefik for routing

### IP Forwarding

**sysctl configuration**:
```
net.ipv4.ip_forward = 1
```
- Enables routing between eth0 and eth1
- Required for NAT to work
- Configured automatically by firewall Ansible role

---

## DNS Configuration

### Loopia Dynamic DNS

**Script**: `/usr/local/lib/loopia-ddns/update.py`
**Frequency**: Every 15 minutes (systemd timer)
**Source Interface**: Firewall container (LXC 101) eth0 on vmbr2

**How It Works**:
```python
CONTAINER_ID = 101  # Firewall container
INTERFACE = "eth0"  # WAN interface on vmbr2

# Read current public IP from firewall WAN interface
ip_output = subprocess.check_output([
    "pct", "exec", str(CONTAINER_ID), "--",
    "ip", "-4", "-o", "addr", "show", "dev", INTERFACE
])
current_ip = ip_output.split()[3].split('/')[0]

# Update all DNS records (*.viljo.se) to this IP
```

**Why This Is Correct**:
- Firewall eth0 (vmbr2) has the public IP from Bahnhof
- This is the IP that receives all inbound traffic
- DNS must point to this IP for services to be accessible
- Script correctly monitors this interface and updates DNS

**DNS Records**:
- viljo.se → vmbr2 public IP
- *.viljo.se → vmbr2 public IP
- All subdomains (gitlab.viljo.se, nextcloud.viljo.se, etc.) → same IP

**Traffic Flow After DNS Resolution**:
1. User resolves gitlab.viljo.se → vmbr2 public IP
2. Connection arrives at firewall eth0 (vmbr2)
3. Firewall DNAT forwards to Traefik (172.16.10.1:443)
4. Traefik routes to GitLab container based on hostname
5. GitLab responds back through same path

---

## Traefik Configuration

### Location and Binding

**Runs On**: Proxmox host (NOT in a container)
**Listens On**: 172.16.10.1:80 and 172.16.10.1:443
**Bridge**: vmbr3 (DMZ network)

### Why This Configuration

1. **Proxmox host has IP on vmbr3**: 172.16.10.1
2. **Firewall DNAT targets this IP**: Traffic from vmbr2 forwarded to 172.16.10.1
3. **Traefik can reach service containers**: All on same vmbr3 network
4. **Centralized reverse proxy**: Single point for HTTPS termination and routing

### Traffic Flow

```
Internet (HTTPS to gitlab.viljo.se)
    |
    ▼
vmbr2 (Firewall eth0) - Public IP
    |
    ▼
Firewall DNAT: tcp dport 443 → 172.16.10.1:443
    |
    ▼
Traefik (Proxmox host on vmbr3: 172.16.10.1:443)
    |
    | TLS termination (Let's Encrypt cert)
    | Host header check: gitlab.viljo.se
    | Route to backend: http://172.16.10.153:80
    |
    ▼
GitLab Container (LXC 153: 172.16.10.153:80)
```

### Routing Configuration

Traefik routes are configured via Ansible in `inventory/group_vars/all/main.yml`:

```yaml
traefik_services:
  - name: gitlab
    host: "gitlab.{{ public_domain }}"
    container_id: 153
    port: 80
```

This generates:
- Router matching `Host: gitlab.viljo.se`
- Service backend `http://172.16.10.153:80`
- TLS cert for `gitlab.viljo.se`

---

## Container Network Configuration

### Standard Configuration for All Service Containers

**Bridge**: vmbr3
**IP Address**: 172.16.10.{container_id}
**Netmask**: 255.255.255.0 (/24)
**Gateway**: 172.16.10.101 (firewall container)
**DNS Servers**: 172.16.10.101, 1.1.1.1

### Example: GitLab Container (LXC 153)

**Network Config**:
```
eth0: 172.16.10.153/24
gateway: 172.16.10.101
dns: 172.16.10.101, 1.1.1.1
```

**Routing Table**:
```
default via 172.16.10.101 dev eth0
172.16.10.0/24 dev eth0 proto kernel scope link src 172.16.10.153
```

**Connectivity Tests**:
```bash
# Ping gateway
ping -c 2 172.16.10.101  # WORKS - direct L2 connectivity

# Ping internet
ping -c 2 1.1.1.1  # WORKS - routed via firewall

# Ping other container
ping -c 2 172.16.10.155  # WORKS - direct L2 connectivity (Nextcloud)

# HTTP to internet
curl -I https://google.com  # WORKS - NATed through firewall
```

---

## Troubleshooting Guide

### CRITICAL: Understanding What SHOULD and SHOULD NOT Work

This section explains the CORRECT expected behavior. If you see these "failures", they are NOT problems.

### From Proxmox Host (192.168.1.3)

**THESE COMMANDS SHOULD FAIL** (This is correct behavior):

```bash
# From your workstation
ssh root@192.168.1.3 "ping 1.1.1.1"
# Expected: FAILS - Network unreachable or timeout
# Why: Proxmox host has NO internet access by design

ssh root@192.168.1.3 "curl https://google.com"
# Expected: FAILS - Could not resolve host or connection timeout
# Why: vmbr0 (management network) is NOT connected to internet

ssh root@192.168.1.3 "apt update"
# Expected: FAILS - Cannot connect to repositories
# Why: Proxmox host cannot reach internet (by design)
```

**THIS IS NOT A PROBLEM. THIS IS THE ARCHITECTURE WORKING AS DESIGNED.**

**THESE COMMANDS SHOULD WORK** (Within vmbr3 network):

```bash
# Ping DMZ gateway (firewall)
ssh root@192.168.1.3 "ping -c 2 172.16.10.101"
# Expected: WORKS - Proxmox host can reach vmbr3 network

# Ping service containers
ssh root@192.168.1.3 "ping -c 2 172.16.10.153"  # GitLab
# Expected: WORKS - All on same vmbr3 network
```

### From Service Containers (172.16.10.x)

**THESE COMMANDS SHOULD WORK**:

```bash
# Ping gateway
ssh root@192.168.1.3 "pct exec 153 -- ping -c 2 172.16.10.101"
# Expected: WORKS - Container can reach gateway

# Ping internet
ssh root@192.168.1.3 "pct exec 153 -- ping -c 2 1.1.1.1"
# Expected: WORKS - Routed via firewall to internet

# HTTP to internet
ssh root@192.168.1.3 "pct exec 153 -- curl -I https://google.com"
# Expected: WORKS - NATed through firewall

# Ping other containers
ssh root@192.168.1.3 "pct exec 153 -- ping -c 2 172.16.10.155"
# Expected: WORKS - Direct L2 connectivity on vmbr3

# DNS resolution
ssh root@192.168.1.3 "pct exec 153 -- nslookup google.com"
# Expected: WORKS - DNS via 172.16.10.101 or 1.1.1.1

# Package updates
ssh root@192.168.1.3 "pct exec 153 -- apt update"
# Expected: WORKS - Can reach Debian repositories via NAT
```

**IF THESE FAIL**, then you have a real problem:

1. **Cannot ping gateway (172.16.10.101)**
   - Check container network configuration
   - Verify container is on vmbr3
   - Check firewall container is running: `pct status 101`

2. **Cannot ping internet (1.1.1.1)**
   - Check firewall container is running
   - Verify IP forwarding: `pct exec 101 -- sysctl net.ipv4.ip_forward`
   - Check nftables rules: `pct exec 101 -- nft list ruleset`
   - Verify firewall eth0 has IP: `pct exec 101 -- ip addr show eth0`

3. **Cannot reach HTTPS sites**
   - Check DNS configuration in container
   - Verify firewall is masquerading correctly
   - Check firewall eth0 can reach internet

### Testing Internet Connectivity - THE CORRECT WAY

**STEP 1: Choose a service container to test from**

Good choices:
- GitLab (LXC 153)
- Nextcloud (LXC 155)
- Keycloak (LXC 151)

**STEP 2: Test from INSIDE the container**

```bash
# Test basic IP connectivity
ssh root@192.168.1.3 "pct exec 153 -- ping -c 2 1.1.1.1"

# Test DNS resolution
ssh root@192.168.1.3 "pct exec 153 -- nslookup google.com"

# Test HTTPS connectivity
ssh root@192.168.1.3 "pct exec 153 -- curl -I https://google.com"
```

**STEP 3: If tests fail, diagnose step by step**

```bash
# 1. Can container reach its gateway?
ssh root@192.168.1.3 "pct exec 153 -- ping -c 2 172.16.10.101"

# 2. Is firewall container running?
ssh root@192.168.1.3 "pct status 101"

# 3. Does firewall have IP on WAN?
ssh root@192.168.1.3 "pct exec 101 -- ip addr show eth0"

# 4. Is IP forwarding enabled?
ssh root@192.168.1.3 "pct exec 101 -- sysctl net.ipv4.ip_forward"

# 5. Are nftables rules loaded?
ssh root@192.168.1.3 "pct exec 101 -- nft list ruleset"

# 6. Can firewall reach internet?
ssh root@192.168.1.3 "pct exec 101 -- ping -c 2 1.1.1.1"
```

### Common Issues and Solutions

#### Issue: "Proxmox host can't reach internet"

**Symptom**:
```bash
ssh root@192.168.1.3 "ping 1.1.1.1"
# Network unreachable or timeout
```

**Solution**: THIS IS NOT AN ISSUE. This is correct behavior. The Proxmox host does not have and does not need internet access.

**Why**: The management network (vmbr0/192.168.1.x) is separate from the internet connection (vmbr2). This is by design for security and operational reasons.

#### Issue: "Container can't reach internet"

**Symptom**:
```bash
ssh root@192.168.1.3 "pct exec 153 -- ping 1.1.1.1"
# Network unreachable or timeout
```

**Diagnosis**:

1. **Check container network config**:
   ```bash
   ssh root@192.168.1.3 "pct config 153 | grep net0"
   # Should show: bridge=vmbr3,ip=172.16.10.153/24,gw=172.16.10.101
   ```

2. **Check container routing**:
   ```bash
   ssh root@192.168.1.3 "pct exec 153 -- ip route"
   # Should show: default via 172.16.10.101
   ```

3. **Check firewall container status**:
   ```bash
   ssh root@192.168.1.3 "pct status 101"
   # Should show: status: running
   ```

4. **Check firewall IP forwarding**:
   ```bash
   ssh root@192.168.1.3 "pct exec 101 -- sysctl net.ipv4.ip_forward"
   # Should show: net.ipv4.ip_forward = 1
   ```

5. **Check firewall nftables**:
   ```bash
   ssh root@192.168.1.3 "pct exec 101 -- nft list ruleset"
   # Should show masquerade rule for 172.16.10.0/24
   ```

**Solution**: Fix whichever component is incorrect above, then re-test.

#### Issue: "DNS not resolving"

**Symptom**:
```bash
ssh root@192.168.1.3 "pct exec 153 -- nslookup google.com"
# ;; connection timed out; no servers could be reached
```

**Diagnosis**:

1. **Check container DNS config**:
   ```bash
   ssh root@192.168.1.3 "pct exec 153 -- cat /etc/resolv.conf"
   # Should show: nameserver 172.16.10.101 and nameserver 1.1.1.1
   ```

2. **Test DNS directly**:
   ```bash
   ssh root@192.168.1.3 "pct exec 153 -- dig @1.1.1.1 google.com"
   ```

**Solution**: Fix DNS configuration in container network settings.

#### Issue: "Service not reachable from internet"

**Symptom**: Cannot access https://gitlab.viljo.se from external network

**Diagnosis**:

1. **Check DNS resolution**:
   ```bash
   dig gitlab.viljo.se +short
   # Should return vmbr2 public IP
   ```

2. **Check firewall WAN IP**:
   ```bash
   ssh root@192.168.1.3 "pct exec 101 -- ip addr show eth0"
   # Should show public IP from Bahnhof
   ```

3. **Check Traefik routing**:
   ```bash
   ssh root@192.168.1.3 "cat /etc/traefik/dynamic/services.yml | grep -A10 gitlab"
   # Should show gitlab router and service
   ```

4. **Check service container is running**:
   ```bash
   ssh root@192.168.1.3 "pct status 153"
   # Should show: status: running
   ```

5. **Check service is listening**:
   ```bash
   ssh root@192.168.1.3 "pct exec 153 -- netstat -tulpn | grep :80"
   # Should show service listening on port 80
   ```

6. **Test from Proxmox host**:
   ```bash
   ssh root@192.168.1.3 "curl -I http://172.16.10.153:80"
   # Should get HTTP response
   ```

**Solution**: Fix whichever component is broken in the chain above.

---

## Network Verification Checklist

Use this checklist to verify the network is configured correctly:

### Bridge Configuration

- [ ] **vmbr0 exists and is active**
  ```bash
  ssh root@192.168.1.3 "ip addr show vmbr0"
  # Should show 192.168.1.3/24
  ```

- [ ] **vmbr2 exists and is active**
  ```bash
  ssh root@192.168.1.3 "ip addr show vmbr2"
  # Should show bridge (may have no IP - that's OK)
  ```

- [ ] **vmbr3 exists and is active**
  ```bash
  ssh root@192.168.1.3 "ip addr show vmbr3"
  # Should show 172.16.10.1/24
  ```

### Firewall Container (LXC 101)

- [ ] **Firewall container is running**
  ```bash
  ssh root@192.168.1.3 "pct status 101"
  # Should show: status: running
  ```

- [ ] **Firewall eth0 on vmbr2 with DHCP IP**
  ```bash
  ssh root@192.168.1.3 "pct exec 101 -- ip addr show eth0"
  # Should show IP address from ISP
  ```

- [ ] **Firewall eth1 on vmbr3 with static IP**
  ```bash
  ssh root@192.168.1.3 "pct exec 101 -- ip addr show eth1"
  # Should show 172.16.10.101/24
  ```

- [ ] **IP forwarding is enabled**
  ```bash
  ssh root@192.168.1.3 "pct exec 101 -- sysctl net.ipv4.ip_forward"
  # Should show: net.ipv4.ip_forward = 1
  ```

- [ ] **nftables rules are loaded**
  ```bash
  ssh root@192.168.1.3 "pct exec 101 -- nft list ruleset | grep -c masquerade"
  # Should show: 1 (or more)
  ```

- [ ] **Firewall can reach internet**
  ```bash
  ssh root@192.168.1.3 "pct exec 101 -- ping -c 2 1.1.1.1"
  # Should succeed
  ```

### Service Containers

- [ ] **Service container is on vmbr3**
  ```bash
  ssh root@192.168.1.3 "pct config 153 | grep bridge"
  # Should show: bridge=vmbr3
  ```

- [ ] **Service container has correct IP**
  ```bash
  ssh root@192.168.1.3 "pct exec 153 -- ip addr show eth0"
  # Should show 172.16.10.153/24
  ```

- [ ] **Service container has correct gateway**
  ```bash
  ssh root@192.168.1.3 "pct exec 153 -- ip route | grep default"
  # Should show: default via 172.16.10.101
  ```

- [ ] **Service container can ping gateway**
  ```bash
  ssh root@192.168.1.3 "pct exec 153 -- ping -c 2 172.16.10.101"
  # Should succeed
  ```

- [ ] **Service container can ping internet**
  ```bash
  ssh root@192.168.1.3 "pct exec 153 -- ping -c 2 1.1.1.1"
  # Should succeed
  ```

- [ ] **Service container can resolve DNS**
  ```bash
  ssh root@192.168.1.3 "pct exec 153 -- nslookup google.com"
  # Should succeed
  ```

- [ ] **Service container can reach HTTPS sites**
  ```bash
  ssh root@192.168.1.3 "pct exec 153 -- curl -I https://google.com"
  # Should succeed
  ```

### Traefik and External Access

- [ ] **Traefik is running**
  ```bash
  ssh root@192.168.1.3 "systemctl status traefik"
  # Should show: active (running)
  ```

- [ ] **Traefik is listening on vmbr3**
  ```bash
  ssh root@192.168.1.3 "netstat -tulpn | grep traefik"
  # Should show listening on 172.16.10.1:80 and :443
  ```

- [ ] **DNS resolves to vmbr2 IP**
  ```bash
  dig gitlab.viljo.se +short
  # Should return public IP on vmbr2
  ```

- [ ] **Service is accessible from internet**
  ```bash
  curl -I https://gitlab.viljo.se
  # Should return HTTP 200 or 302
  ```

---

## Ansible Configuration References

### Variable Definitions

**File**: `inventory/group_vars/all/main.yml`

```yaml
management_bridge: vmbr0
wan_bridge: vmbr2
public_bridge: vmbr3
dmz_subnet: 172.16.10.0/24
dmz_prefix: 24
dmz_gateway: 172.16.10.101
dmz_host_ip: 172.16.10.1
```

### Firewall Configuration

**File**: `inventory/group_vars/all/firewall.yml`

```yaml
firewall_container_id: 101
firewall_hostname: firewall
firewall_bridge_wan: "{{ wan_bridge }}"      # vmbr2
firewall_bridge_lan: "{{ public_bridge }}"    # vmbr3
firewall_wan_ip_config: dhcp
firewall_lan_ip_address: "{{ dmz_gateway }}"  # 172.16.10.101
```

### Container Standard Configuration

**Example** (GitLab):

```yaml
gitlab_container_id: 153
gitlab_ip: "172.16.10.{{ gitlab_container_id }}"
gitlab_gateway: "{{ dmz_gateway }}"           # 172.16.10.101
gitlab_nameserver: "{{ dmz_gateway }}"        # 172.16.10.101
gitlab_bridge: "{{ public_bridge }}"          # vmbr3
```

### Traefik Service Routing

**File**: `inventory/group_vars/all/main.yml`

```yaml
traefik_services:
  - name: gitlab
    host: "gitlab.{{ public_domain }}"
    container_id: "{{ gitlab_container_id }}"  # 153
    port: 80
```

This generates backend URL: `http://172.16.10.153:80`

---

## Summary

### The Three-Bridge Model

1. **vmbr0 (Management)**
   - Purpose: SSH/management access ONLY
   - Connected to: Starlink ISP (CGNAT)
   - Proxmox host: 192.168.1.3
   - Internet: NO
   - Containers: NONE

2. **vmbr2 (WAN)**
   - Purpose: Internet connection ONLY
   - Connected to: Bahnhof ISP (public IP)
   - Containers: Firewall (LXC 101) eth0 ONLY
   - Internet: YES
   - DNS points here: *.viljo.se

3. **vmbr3 (DMZ)**
   - Purpose: Service containers
   - Network: 172.16.10.0/24
   - Gateway: 172.16.10.101 (firewall)
   - Containers: ALL services
   - Internet: Via firewall NAT

### Critical Understanding

**The Proxmox host does NOT need internet access.**

Internet connectivity flows:
- **Inbound**: vmbr2 → firewall → Traefik → service containers
- **Outbound**: service containers → firewall → vmbr2 → internet

Testing internet from the Proxmox host will FAIL. This is CORRECT behavior.

Test internet connectivity from SERVICE CONTAINERS on vmbr3, not from the Proxmox host.

### Common Mistakes to Avoid

1. ✗ Trying to ping internet from Proxmox host
2. ✗ Expecting 192.168.1.3 to have internet access
3. ✗ Thinking vmbr0 is the internet connection
4. ✗ Testing connectivity from management network
5. ✗ Assuming lack of internet on Proxmox host is a problem

### The Correct Way to Think About This

- **Management network (vmbr0)**: Your SSH connection to Proxmox - NO internet
- **Internet network (vmbr2)**: Where internet enters - firewall only
- **Service network (vmbr3)**: Where services live - internet via firewall

**Your workstation → vmbr0 → Proxmox host** (management)
**Internet → vmbr2 → firewall → vmbr3 → services** (production)

These are SEPARATE paths. There is NO route from vmbr0 to internet, BY DESIGN.

---

## References

- [Network Topology](architecture/network-topology.md) - Original topology documentation
- [ADR-001: Network Topology Change](adr/001-network-topology-change.md) - Decision record for this architecture
- [Firewall Deployment](deployment/firewall-deployment.md) - Firewall container setup
- [Container Mapping](architecture/container-mapping.md) - Service container IP allocations

---

**Last Updated**: 2025-10-27
**Author**: DevOps Infrastructure Team
**Status**: Authoritative Reference
**Review Date**: 2026-01-27 (quarterly review)
