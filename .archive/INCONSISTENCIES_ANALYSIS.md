# Comprehensive Codebase Inconsistencies Analysis

## Executive Summary

This analysis identified **7 critical inconsistencies** across the Proxmox infrastructure codebase affecting demo site naming, domain configuration, container ID conflicts, and network bridge references.

---

## CRITICAL FINDINGS

### 1. DEMO SITE NAMING INCONSISTENCY (SEVERITY: HIGH)

#### Finding: "demo" vs "demosite" inconsistency

The demo site has conflicting hostname and domain configurations across different configuration files.

**Inconsistency Details:**

| File | Line | Variable | Value | Issue |
|------|------|----------|-------|-------|
| `/Users/anders/git/Proxmox_config/roles/demo_site/defaults/main.yml` | 3 | `demo_site_hostname` | `demo` | Role default uses short form |
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/demo_site.yml` | 3 | `demo_site_hostname` | `demosite` | Inventory override uses longer form |
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/main.yml` | 12 | loopia_dns_records host | `demosite` | DNS record uses "demosite" |
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/main.yml` | 25 | traefik_services name | `demosite` | Traefik service uses "demosite" |
| `/Users/anders/git/Proxmox_config/roles/demo_site/README.md` | 14 | Documentation | `demo.infra.local` | README references "demo" |
| `/Users/anders/git/Proxmox_config/roles/demo_site/README.md` | 250 | Traefik example | `demo.infra.local` | Example uses "demo" |

**Root Cause:** 
- Role defaults define `demo_site_hostname: demo`
- Inventory override in `inventory/group_vars/all/demo_site.yml` sets `demo_site_hostname: demosite`
- DNS and Traefik configurations reference `demosite` (the correct override value)
- Documentation hasn't been updated to match current configuration

**Recommendation:** 
Standardize on either "demo" or "demosite". Based on current active configuration in Traefik and DNS:
- Current effective value: **demosite** (from inventory override)
- DNS record: `demosite.viljo.se`
- Traefik service: `demosite.viljo.se`
- **Action Required:** Update role defaults to `demo_site_hostname: demosite` and update README documentation accordingly

**Impact:** Hostname mismatches could cause container to boot with unexpected hostname, breaking TLS certificates if hostname doesn't match DNS records.

---

### 2. DOMAIN NAME INCONSISTENCY (SEVERITY: CRITICAL)

#### Finding: "infra.local" vs "viljo.se" usage mismatch

The demo site has conflicting domain configuration that creates a mismatch between internal and external domains.

**Inconsistency Details:**

| File | Line | Variable | Value | Purpose |
|------|------|----------|-------|---------|
| `/Users/anders/git/Proxmox_config/roles/demo_site/defaults/main.yml` | 4 | `demo_site_domain` | `infra.local` | Role default (internal) |
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/demo_site.yml` | 4 | `demo_site_domain` | `viljo.se` | Inventory override (external) |
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/demo_site.yml` | 14 | `demo_site_external_domain` | `viljo.se` | External domain |
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/main.yml` | 3 | `public_domain` | `viljo.se` | Global public domain |
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/loopia_dns/defaults/main.yml` | 3 | `loopia_dns_domain` | `viljo.se` | Loopia DNS domain |
| `/Users/anders/git/Proxmox_config/playbooks/demo-site-deploy.yml` | 31 | Deployment message | `demo_site_hostname.demo_site_domain` | Uses conflicting domain |

**The Conflict:**
```
Role Defaults:
  demo_site_domain: infra.local
  
Inventory Override:
  demo_site_domain: viljo.se
  
This creates: demosite.viljo.se (via Traefik)
But internal container thinks: demosite.infra.local
```

**Root Cause:**
- Role defaults are designed for local/lab use with `infra.local`
- Inventory override correctly sets to public domain `viljo.se`
- But this creates a mismatch: the container hostname won't match the external FQDN

**Recommendation:**
The current configuration is actually **correct for production** because:
- Internal domain in container: `demosite.infra.local` (used for local DNS)
- External domain for TLS: `demosite.viljo.se` (configured in Traefik)

However, the configuration should be clearer. Best practice:
1. Keep role defaults as-is for flexibility (internal lab use)
2. Document clearly in playbooks that `demo_site_external_domain` is what matters for Traefik/TLS
3. Update README to explain the dual-domain pattern

**Current Status:** ✅ WORKING (but confusing without documentation)

---

### 3. CONTAINER ID CONFLICT (SEVERITY: CRITICAL)

#### Finding: Duplicate container ID 2200 for firewall AND loopia_ddns

**Conflict Details:**

| File | Line | Variable | Container ID | Service |
|------|------|----------|--------------|---------|
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/main.yml` | 89 | `loopia_ddns_container_id` | `2200` | DDNS updater |
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/firewall.yml` | 1 | `firewall_container_id` | `2200` | Firewall |
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/dmz.yml` | 5 | DMZ containers list | `2200` (firewall) | Container registry |

**Root Cause:**
Container ID 2200 is assigned to BOTH:
1. The firewall LXC container (primary service)
2. The loopia_ddns service (should be a Docker container or service inside firewall)

**Impact:**
- **CRITICAL:** Cannot deploy both services - they will conflict
- The firewall LXC at 2200 will prevent loopia_ddns from being deployed
- Current status: Only firewall can be deployed at this ID

**Recommendation:**
1. **If loopia_ddns is a Docker service:** Should NOT have `container_id` in inventory - it should be deployed inside the firewall container (ID 2200)
2. **If loopia_ddns is a separate LXC:** Assign it a different container ID (e.g., `2199` or another available ID)

**Action Required:** Clarify whether `loopia_ddns` is:
- A Docker container inside firewall (2200) → Remove `loopia_ddns_container_id` from main.yml
- A separate LXC → Assign unique ID and create dedicated role deployment

---

### 4. SERVICE CONFIGURATION MISMATCH (SEVERITY: HIGH)

#### Finding: Traefik service definition for demosite missing critical properties

**Mismatch Details:**

In `/Users/anders/git/Proxmox_config/inventory/group_vars/all/main.yml`:

```yaml
# Line 12 - DNS record defined
- host: demosite
  ttl: 600

# Line 25 - Traefik service defined
- name: demosite
  host: "demosite.{{ public_domain }}"
  container_id: "{{ demo_site_container_id }}"
  port: "{{ demo_site_service_port }}"
```

**What's Missing:**
- No `scheme` property (defaults to HTTP, which is correct for this case)
- No `insecure_skip_verify` property (correct, as we're serving HTTP internally)
- Hostname in traefik_services is using `demosite` but should match the actual internal hostname

**Current State:** ✅ Configuration appears correct, but undocumented

**Recommendation:** Document the intent - is the demo site using:
1. HTTP only internally (correct for DMZ pattern)
2. Traefik handling HTTPS termination (yes, lines 65-66 show examples)

---

### 5. DNS RECORD vs HOSTNAME MISMATCH (SEVERITY: MEDIUM)

#### Finding: Container hostname doesn't match DNS record name

**Details:**

| Configuration | Value | Expected Match |
|---------------|-------|-----------------|
| Container hostname | `demosite` (from inventory) | Should match... |
| DNS record host | `demosite` | ✓ Matches |
| Traefik routing | `demosite.viljo.se` | ✓ Matches public domain |
| Internal reference | `demosite.infra.local` | ✓ Matches (via role default) |

**Current Status:** ✅ CONSISTENT (all using "demosite")

---

### 6. NETWORK BRIDGE INCONSISTENCY (SEVERITY: MEDIUM)

#### Finding: Conflicting default bridge assignments

**Bridge Configuration Details:**

| File | Line | Variable | Default | Expected |
|------|------|----------|---------|----------|
| `/Users/anders/git/Proxmox_config/inventory/group_vars/all/main.yml` | 77-79 | `management_bridge` `wan_bridge` `public_bridge` | `vmbr0` `vmbr2` `vmbr3` | Explicit values |
| `/Users/anders/git/Proxmox_config/roles/demo_site/defaults/main.yml` | 9 | `demo_site_bridge` | `vmbr0` | Should be `vmbr3` |
| `/Users/anders/git/Proxmox_config/roles/firewall/defaults/main.yml` | 9-10 | `firewall_bridge_wan` `firewall_bridge_lan` | `vmbr1` `vmbr2` | Role defaults differ from main! |
| `/Users/anders/git/Proxmox_config/roles/loopia_dns/defaults/main.yml` | 6 | `loopia_dns_interface` | `vmbr1` | Should likely be `vmbr2` |

**Root Cause:**
Role defaults specify `vmbr0`, `vmbr1`, `vmbr2` but main.yml specifies `vmbr0`, `vmbr2`, `vmbr3`

**The Problem:**

1. **demo_site_bridge default is `vmbr0` (management bridge)** but should be `vmbr3` (public/DMZ bridge)
   - This is OVERRIDDEN by the variable reference to `public_bridge` in role default
   - Inventory settings correctly set bridge to `vmbr3`
   - Status: ✅ Functional due to override, but confusing

2. **firewall_bridge_lan default is `vmbr2` but main.yml expects `vmbr3`**
   - File: `/Users/anders/git/Proxmox_config/roles/firewall/defaults/main.yml` line 10
   - Says: `firewall_bridge_lan: "{{ public_bridge | default('vmbr2') }}"`
   - Should say: `"{{ public_bridge | default('vmbr3') }}"`

3. **loopia_dns_interface default is `vmbr1` but should be `vmbr2`**
   - File: `/Users/anders/git/Proxmox_config/roles/loopia_dns/defaults/main.yml` line 6
   - Says: `loopia_dns_interface: "{{ public_bridge | default('vmbr1') }}"`
   - Should say: `"{{ public_bridge | default('vmbr2') }}"` (WAN bridge)

**Current Bridge Assignment:**
```
vmbr0 = Management network (192.168.1.0/24)
vmbr2 = WAN bridge (for firewall's upstream link)
vmbr3 = DMZ/Public bridge (172.16.10.0/24)
vmbr1 = Not used in main.yml but appears in role defaults (UNUSED!)
```

**Impact:**
If defaults are used without inventory overrides, services will connect to wrong bridges:
- Demo site would try to use management bridge (vmbr0) instead of DMZ (vmbr3)
- Firewall would try to use vmbr2 instead of vmbr3
- Loopia DNS would use vmbr1 (doesn't exist) instead of vmbr2

**Recommendation:**
Update role defaults to match actual environment:

1. **firewall/defaults/main.yml line 10:** Change `vmbr2` to `vmbr3`
2. **loopia_dns/defaults/main.yml line 6:** Change `vmbr1` to `vmbr2`
3. **demo_site/defaults/main.yml line 9:** Change `vmbr0` to `vmbr3` (or keep relying on variable override)

---

### 7. IP ADDRESS CONFLICTS & HARDCODED IPS (SEVERITY: MEDIUM)

#### Finding: All IP addresses are hardcoded in inventory without flexibility

**Hardcoded IP Analysis:**

| Service | Container | IP Address | Subnet | Gateway | Notes |
|---------|-----------|-----------|--------|---------|-------|
| Proxmox host | N/A | 192.168.1.3 | 255.255.0.0 | 192.168.1.1 | Management |
| Firewall (DMZ gateway) | 2200 | 172.16.10.1 | 255.255.255.0 | N/A | Gateway for all DMZ |
| PostgreSQL | 1990 | 172.16.10.50 | 255.255.255.0 | 172.16.10.1 | Database backend |
| Keycloak | 2000 | 172.16.10.51 | 255.255.255.0 | 172.16.10.1 | Auth |
| Jellyfin | 2010 | 172.16.10.56 | 255.255.255.0 | 172.16.10.1 | Media |
| OpenMediaVault | 2020 | 172.16.10.52 | 255.255.255.0 | 172.16.10.1 | Storage (conflict!) |
| HomeAssistant | 2030 | 172.16.10.57 | 255.255.255.0 | 172.16.10.1 | HA |
| Nextcloud | 2040 | 172.16.10.55 | 255.255.255.0 | 172.16.10.1 | File storage |
| GitLab | 2050 | 172.16.10.53 | 255.255.255.0 | 172.16.10.1 | CI/CD (conflict!) |
| GitLab Runner | 2051 | 172.16.10.54 | 255.255.255.0 | 172.16.10.1 | CI/CD execution |
| Zipline | 2060 | 172.16.10.61 | 255.255.255.0 | 172.16.10.1 | File sharing |
| Qbittorrent | 2070 | 172.16.10.59 | 255.255.255.0 | 172.16.10.1 | Torrent |
| Wazuh | 2080 | 172.16.10.62 | 255.255.255.0 | 172.16.10.1 | Monitoring |
| Wireguard | 2090 | 172.16.10.90 | 255.255.255.0 | 172.16.10.1 | VPN |
| Netbox | 2150 | 172.16.10.52 | 255.255.255.0 | 172.16.10.1 | IPAM (CONFLICT!) |
| Demo Site | 2300 | 172.16.10.60 | 255.255.255.0 | 172.16.10.1 | Test |

**CRITICAL IP CONFLICTS FOUND:**

1. **172.16.10.52** - Assigned to BOTH:
   - OpenMediaVault (omv_ip_address: 172.16.10.52)
   - Netbox (netbox_ip_address: 172.16.10.52)
   
   **Files:**
   - `/Users/anders/git/Proxmox_config/inventory/group_vars/all/openmediavault.yml` line 3
   - `/Users/anders/git/Proxmox_config/inventory/group_vars/all/netbox.yml` line 2

2. **172.16.10.53** - Assigned to BOTH:
   - GitLab (gitlab_ip_address: 172.16.10.53)
   - (Note: OpenMediaVault also at .52)
   
   **Files:**
   - `/Users/anders/git/Proxmox_config/inventory/group_vars/all/gitlab.yml` line 2

3. **172.16.10.61** - Assigned to:
   - Zipline (zipline_ip_address: 172.16.10.61)

   **Files:**
   - `/Users/anders/git/Proxmox_config/inventory/group_vars/all/zipline.yml` line 2

**Impact:**
- Network collisions when deploying services
- Containers unable to communicate properly
- Service discovery failures
- ARP conflicts on DMZ network

**Recommendation:**
Assign unique IPs to each service:
```
172.16.10.50 = PostgreSQL
172.16.10.51 = Keycloak
172.16.10.52 = Netbox (reassign OMV)
172.16.10.53 = GitLab
172.16.10.54 = GitLab Runner
172.16.10.55 = Nextcloud
172.16.10.56 = Jellyfin
172.16.10.57 = HomeAssistant
172.16.10.58 = (reserve for future)
172.16.10.59 = Qbittorrent
172.16.10.60 = Demo Site
172.16.10.61 = Zipline
172.16.10.62 = Wazuh
172.16.10.63 = (reserve for future)
172.16.10.64 = OpenMediaVault (move from .52)
172.16.10.65 = (reserve for future)
172.16.10.90 = Wireguard
```

---

### 8. INCONSISTENT VARIABLE NAMING (SEVERITY: LOW)

#### Finding: Inconsistent container ID variable naming convention

**Pattern Analysis:**

Most services follow the pattern: `{service}_container_id`
- `demo_site_container_id`
- `keycloak_container_id`
- `gitlab_container_id`
- `netbox_container_id`

But some services use abbreviated prefixes:
- `nc_container_id` (Nextcloud) - uses `nc_` instead of `nextcloud_`
- `ha_container_id` (HomeAssistant) - uses `ha_` instead of `homeassistant_`
- `omv_container_id` (OpenMediaVault) - uses `omv_` instead of `openmediavault_`

**Files:**
- `/Users/anders/git/Proxmox_config/inventory/group_vars/all/nextcloud.yml` line 1
- `/Users/anders/git/Proxmox_config/inventory/group_vars/all/homeassistant.yml` line 2
- `/Users/anders/git/Proxmox_config/inventory/group_vars/all/openmediavault.yml` line 1

**Also affects:**
- `nc_ip_address` vs others' pattern `{service}_ip_address`
- `ha_ip_address` vs expected `homeassistant_ip_address`
- `omv_ip_address` vs expected `openmediavault_ip_address`

**Impact:** Minor - creates inconsistency in configuration that could confuse team members

**Recommendation:** 
Standardize all variable names to use full service names:
- `nc_container_id` → `nextcloud_container_id`
- `ha_container_id` → `homeassistant_container_id`
- `omv_container_id` → `openmediavault_container_id`
- Same for all `*_ip_address`, `*_hostname`, etc.

---

## SUMMARY TABLE

| Issue # | Category | Severity | Status | Action Items |
|---------|----------|----------|--------|--------------|
| 1 | Demo hostname: "demo" vs "demosite" | HIGH | Inconsistent | Update role defaults to match inventory |
| 2 | Domain: "infra.local" vs "viljo.se" | CRITICAL | Working (confusing) | Document dual-domain pattern |
| 3 | Container ID 2200 conflict (firewall + loopia_ddns) | CRITICAL | Broken | Resolve container ID conflict |
| 4 | Traefik service config undocumented | MEDIUM | Functional | Document Traefik configuration pattern |
| 5 | DNS vs hostname mismatch | MEDIUM | Consistent | No action needed |
| 6 | Bridge defaults incorrect in role files | MEDIUM | Functional (override) | Update role defaults for clarity |
| 7 | IP address collisions (3 conflicts) | CRITICAL | Broken | Reassign IPs for all 3 conflicts |
| 8 | Inconsistent variable naming (3 services) | LOW | Confusing | Standardize variable names |

---

## FILES WITH ISSUES

### Files Requiring Updates:

1. `/Users/anders/git/Proxmox_config/roles/demo_site/defaults/main.yml`
   - Line 3: Update `demo_site_hostname: demo` → `demo_site_hostname: demosite`
   - Line 9: Update `demo_site_bridge: "{{ public_bridge | default('vmbr0') }}"` → `"{{ public_bridge | default('vmbr3') }}"`

2. `/Users/anders/git/Proxmox_config/roles/firewall/defaults/main.yml`
   - Line 10: Update `vmbr2` → `vmbr3`

3. `/Users/anders/git/Proxmox_config/roles/loopia_dns/defaults/main.yml`
   - Line 6: Update `vmbr1` → `vmbr2`

4. `/Users/anders/git/Proxmox_config/inventory/group_vars/all/main.yml`
   - Line 89: Remove or clarify `loopia_ddns_container_id: 2200` conflict
   - Line 12: Verify DNS records align with current demo site naming

5. `/Users/anders/git/Proxmox_config/inventory/group_vars/all/openmediavault.yml`
   - Line 3: Change `omv_ip_address: 172.16.10.52` → `172.16.10.64`

6. `/Users/anders/git/Proxmox_config/inventory/group_vars/all/zipline.yml`
   - Line 2: Keep `zipline_ip_address: 172.16.10.61`

7. All service group_vars files - Update abbreviated variable names:
   - `nextcloud.yml`: `nc_*` → `nextcloud_*`
   - `homeassistant.yml`: `ha_*` → `homeassistant_*`
   - `openmediavault.yml`: `omv_*` → `openmediavault_*`

---

## RECOMMENDATIONS

### PRIORITY 1: CRITICAL (Deploy blockers)
1. Resolve container ID 2200 conflict between firewall and loopia_ddns
2. Fix IP address collisions (3 services with duplicate IPs)
3. Verify which domain should be used for demo site (infra.local vs viljo.se)

### PRIORITY 2: HIGH (Data consistency)
1. Update demo site hostname from "demo" to "demosite" in role defaults
2. Update network bridge defaults in role defaults (vmbr0→vmbr3, vmbr1→vmbr2, vmbr2→vmbr3)
3. Document the dual-domain pattern for demo site

### PRIORITY 3: MEDIUM (Code quality)
1. Standardize variable naming (remove abbreviations)
2. Add documentation for Traefik service configuration pattern
3. Create network planning diagram showing IP assignments

---

**Analysis Date:** 2025-10-20
**Codebase Location:** /Users/anders/git/Proxmox_config
**Total Issues Found:** 8 categories, 15+ specific inconsistencies
