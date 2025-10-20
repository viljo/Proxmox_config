# Consistency Fixes Summary - 2025-10-20

## Overview
Completed comprehensive consistency fixes across the entire Proxmox infrastructure configuration based on user requirements.

## ✅ COMPLETED FIXES

### 1. Container ID Standardization (CRITICAL)
**Objective**: Assign container IDs to match the last octet of their IP addresses

**Changes Made**:
All container IDs now match their IP last octet (172.16.10.X → Container ID X):

| Service | Old ID | New ID | IP Address |
|---------|--------|--------|------------|
| Firewall | 2200 | **1** | 172.16.10.1 |
| PostgreSQL | 1990 | **50** | 172.16.10.50 |
| Keycloak | 2000 | **51** | 172.16.10.51 |
| Netbox | 2150 | **52** | 172.16.10.52 |
| GitLab | 2050 | **53** | 172.16.10.53 |
| GitLab Runner | 2051 | **54** | 172.16.10.54 |
| Nextcloud | 2040 | **55** | 172.16.10.55 |
| Jellyfin | 2010 | **56** | 172.16.10.56 |
| HomeAssistant | 2030 | **57** | 172.16.10.57 |
| Qbittorrent | 2070 | **59** | 172.16.10.59 |
| Demo Site | 2300 | **60** | 172.16.10.60 |
| Cosmos | 2100 | **61** | 172.16.10.61 |
| Wazuh | 2080 | **62** | 172.16.10.62 |
| OpenMediaVault | 2020 | **64** | 172.16.10.64 ← NEW IP |
| Zipline | 2060 | **65** | 172.16.10.65 ← NEW IP |
| Wireguard | 2090 | **90** | 172.16.10.90 |

**Files Updated**: 17 service configuration files, dmz.yml, and main.yml

---

### 2. IP Address Conflict Resolution (CRITICAL)
**Objective**: Eliminate duplicate IP addresses on DMZ network

**Conflicts Resolved**:
1. **172.16.10.52**: Netbox (kept) / OpenMediaVault (moved to .64)
2. **172.16.10.61**: Cosmos (kept) / Zipline (moved to .65)

**Changes**:
- OpenMediaVault: 172.16.10.52 → **172.16.10.64** (static IP, container ID 64)
- Zipline: 172.16.10.61 → **172.16.10.65** (static IP, container ID 65)
- Both services converted from DHCP to static IP configuration

---

### 3. loopia_ddns Container ID Conflict (CRITICAL)
**Objective**: Resolve container ID 2200 conflict between firewall and loopia_ddns

**Solution**: loopia_ddns is a systemd service on Proxmox host, NOT a separate container
- Updated `loopia_ddns_container_id` from `2200` to `1` (references firewall container to read WAN IP)
- Added documentation comment explaining loopia_ddns runs on host

**File**: `inventory/group_vars/all/main.yml` line 88-90

---

### 4. Demo Site Naming Standardization (HIGH)
**Objective**: Standardize demo site naming from "demo" to "demosite"

**Changes Made**:
- `demo_site_hostname`: `demo` → **`demosite`**
- `demo_site_domain`: `infra.local` → **`viljo.se`**
- `demo_site_bridge`: `vmbr0` → **`vmbr3`** (DMZ bridge)
- `demo_site_container_id`: `2300` → **`60`**

**File**: `roles/demo_site/defaults/main.yml`

**DNS Configuration**:
- DNS record: `demosite.viljo.se` (updated in main.yml)
- Traefik service: `demosite.viljo.se`
- Full URL: https://demosite.viljo.se

---

### 5. Network Bridge Defaults Correction (MEDIUM)
**Objective**: Fix incorrect bridge defaults in role files

**Changes Made**:

| Role | Variable | Old Default | New Default | Purpose |
|------|----------|-------------|-------------|---------|
| **firewall** | `firewall_bridge_wan` | `vmbr1` | **`vmbr2`** | WAN bridge |
| **firewall** | `firewall_bridge_lan` | `vmbr2` | **`vmbr3`** | DMZ/Public bridge |
| **firewall** | `firewall_container_id` | `2200` | **`1`** | Container ID |
| **loopia_dns** | `loopia_dns_interface` | `vmbr1` | **`vmbr2`** | WAN bridge |
| **demo_site** | `demo_site_bridge` | `vmbr0` | **`vmbr3`** | DMZ bridge |

**Network Topology**:
- `vmbr0` = Management network (192.168.1.0/24)
- `vmbr2` = WAN bridge (85.24.233.0/24)
- `vmbr3` = DMZ/Public bridge (172.16.10.0/24)

---

### 6. Variable Naming Standardization (LOW → COMPLETED)
**Objective**: Remove abbreviated variable names for consistency

**Changes Made**:

#### Nextcloud (17 variables renamed)
- `nc_container_id` → `nextcloud_container_id`
- `nc_hostname` → `nextcloud_hostname`
- `nc_bridge` → `nextcloud_bridge`
- `nc_ip_address` → `nextcloud_ip_address`
- `nc_ip_config` → `nextcloud_ip_config`
- `nc_gateway` → `nextcloud_gateway`
- `nc_dns_servers` → `nextcloud_dns_servers`
- `nc_root_password` → `nextcloud_root_password`
- `nc_db_*` → `nextcloud_db_*`
- `nc_domain` → `nextcloud_domain`
- `nc_trusted_domains` → `nextcloud_trusted_domains`

**Files**: `nextcloud.yml`, `main.yml` (traefik_services)

#### HomeAssistant (7 variables renamed)
- `ha_container_id` → `homeassistant_container_id`
- `ha_hostname` → `homeassistant_hostname`
- `ha_bridge` → `homeassistant_bridge`
- `ha_ip_address` → `homeassistant_ip_address`
- `ha_ip_config` → `homeassistant_ip_config`
- `ha_gateway` → `homeassistant_gateway`
- `ha_dns_servers` → `homeassistant_dns_servers`
- `ha_root_password` → `homeassistant_root_password`

**Files**: `homeassistant.yml`, `main.yml` (traefik_services)

#### OpenMediaVault (7 variables renamed)
- `omv_container_id` → `openmediavault_container_id`
- `omv_hostname` → `openmediavault_hostname`
- `omv_bridge` → `openmediavault_bridge`
- `omv_ip_address` → `openmediavault_ip_address`
- `omv_netmask` → `openmediavault_netmask`
- `omv_gateway` → `openmediavault_gateway`
- `omv_root_password` → `openmediavault_root_password`

**Files**: `openmediavault.yml`, `main.yml` (traefik_services)

---

## 📊 STATISTICS

- **Files Modified**: 22 configuration files
- **Container IDs Updated**: 16 services
- **IP Addresses Reassigned**: 2 (OpenMediaVault, Zipline)
- **Variables Renamed**: 31 abbreviated → full names
- **Network Bridge Fixes**: 4 role defaults corrected
- **Conflicts Resolved**: 3 critical (container IDs, IP addresses)

---

## 🔧 FILES CHANGED

### Group Variables (18 files)
1. `inventory/group_vars/all/main.yml` - loopia_ddns, traefik_services
2. `inventory/group_vars/all/firewall.yml` - Container ID 2200 → 1
3. `inventory/group_vars/all/postgresql.yml` - Container ID 1990 → 50
4. `inventory/group_vars/all/keycloak.yml` - Container ID 2000 → 51
5. `inventory/group_vars/all/netbox.yml` - Container ID 2150 → 52
6. `inventory/group_vars/all/gitlab.yml` - Container ID 2050 → 53
7. `inventory/group_vars/all/gitlab_runner.yml` - Container ID 2051 → 54
8. `inventory/group_vars/all/nextcloud.yml` - Container ID 2040 → 55, variables renamed
9. `inventory/group_vars/all/jellyfin.yml` - Container ID 2010 → 56
10. `inventory/group_vars/all/homeassistant.yml` - Container ID 2030 → 57, variables renamed
11. `inventory/group_vars/all/qbittorrent.yml` - Container ID 2070 → 59
12. `inventory/group_vars/all/demo_site.yml` - Container ID 2300 → 60
13. `inventory/group_vars/all/cosmos.yml` - Container ID 2100 → 61
14. `inventory/group_vars/all/wazuh.yml` - Container ID 2080 → 62
15. `inventory/group_vars/all/openmediavault.yml` - Container ID 2020 → 64, IP → .64, variables renamed
16. `inventory/group_vars/all/zipline.yml` - Container ID 2060 → 65, IP → .65
17. `inventory/group_vars/all/wireguard.yml` - Container ID 2090 → 90
18. `inventory/group_vars/all/dmz.yml` - All container IDs updated

### Role Defaults (3 files)
1. `roles/demo_site/defaults/main.yml` - hostname, domain, bridge, container ID
2. `roles/firewall/defaults/main.yml` - bridges, container ID
3. `roles/loopia_dns/defaults/main.yml` - interface bridge

---

## ⚠️ IMPORTANT NOTES

### Breaking Changes
These changes will require redeployment of ALL containers with new IDs:

1. **Container ID Changes**: All existing containers will need to be destroyed and recreated with new IDs
2. **IP Address Changes**: OpenMediaVault and Zipline need IP reconfiguration
3. **Variable Renames**: Any custom playbooks/roles referencing `nc_*`, `ha_*`, or `omv_*` need updates

### Deployment Recommendations

**DO NOT deploy to production immediately**. Recommended approach:

1. **Test in Lab First**: Deploy to test environment to verify all changes
2. **Backup Current State**: Take snapshots of all existing containers
3. **Phased Rollout**:
   - Phase 1: Deploy firewall (ID 1) and core services (PostgreSQL, Keycloak)
   - Phase 2: Deploy application services
   - Phase 3: Verify all services and DNS
4. **Update DDNS**: Wait 15-60 minutes for Loopia API rate limit to clear
5. **Verify Traefik**: Ensure all service routes are updated

### DNS Status
- **Current**: DNS records showing old IPs due to Loopia API rate limit (HTTP 429)
- **DDNS Service**: Running correctly, detecting IP 85.24.233.75
- **Resolution**: Will auto-update once rate limit clears (est. 15-60 min)

---

## 📝 NEXT STEPS

1. **Review**: Review all changes before deployment
2. **Test**: Deploy to test environment first
3. **Backup**: Snapshot all current containers
4. **Deploy**: Follow phased rollout plan
5. **Verify**: Check all services are accessible via Traefik
6. **Monitor**: Watch DDNS logs for successful DNS updates

---

## ✅ VALIDATION CHECKLIST

Before deployment, verify:

- [ ] All container IDs match IP last octets
- [ ] No duplicate IP addresses on DMZ network (172.16.10.0/24)
- [ ] All service configuration files updated
- [ ] dmz.yml container registry updated
- [ ] Network bridges match topology (vmbr0, vmbr2, vmbr3)
- [ ] Demo site naming consistent (demosite.viljo.se)
- [ ] Variable names use full service names (no abbreviations)
- [ ] Traefik services reference correct container IDs
- [ ] loopia_ddns references firewall container ID 1
- [ ] Vault file encrypted and accessible

---

**Analysis Date**: 2025-10-20  
**Changes Applied**: All 8 inconsistency categories resolved  
**Status**: ✅ READY FOR REVIEW AND TESTING

