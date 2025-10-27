# Infrastructure Authentication Audit Report

**Date**: 2025-10-27
**Branch**: 001-jitsi-server
**Auditor**: Infrastructure DevOps Team

## Executive Summary

This audit examined the authentication infrastructure across all deployed and planned services in the Proxmox environment. The infrastructure uses a modern SSO architecture with GitLab.com OAuth as the identity provider, Keycloak as the OAuth broker, and oauth2-proxy for forward authentication.

**Key Findings**:
- Core SSO infrastructure (Keycloak + oauth2-proxy) is deployed and operational
- Nextcloud SSO is fully implemented and working (completed 2025-10-27)
- GitLab uses native authentication (no SSO needed - it IS the identity source)
- Webtop is deployed but NOT in Traefik routing - no HTTPS access configured
- Mattermost was intentionally removed due to SSO limitations in Team Edition
- Multiple planned services have no authentication configuration yet

**Status Summary**:
- Services with Working Auth: 2 (GitLab, Nextcloud)
- Services with Missing Auth Config: 1 (Webtop - not in Traefik)
- Services Planned (No Auth Yet): 10 services
- Authentication Infrastructure: Operational

## Architecture Overview

### Current SSO Stack

```
User Browser
    ↓
Traefik Reverse Proxy (192.168.1.3:443)
    ↓
    ├─→ Direct Backend (for services with native OAuth)
    │   ↓
    │   Backend Service (GitLab, Nextcloud with user_oidc)
    │
    └─→ oauth2-proxy Forward Auth (for services without native OAuth)
        ↓
        Keycloak OIDC (LXC 151 - 172.16.10.151:8080)
        ↓
        GitLab.com OAuth (https://gitlab.com)
```

### Components

| Component | Status | Location | Purpose |
|-----------|--------|----------|---------|
| Traefik | Running | Proxmox Host (192.168.1.3) | Reverse proxy, HTTPS termination |
| Keycloak | Running | LXC 151 (172.16.10.151) | OAuth broker, OIDC provider |
| oauth2-proxy | Running | LXC 167 (172.16.10.167) | Forward auth for Traefik |
| GitLab.com | External | https://gitlab.com | Identity provider (OAuth) |

## Service Inventory and Authentication Status

### Deployed and Working Services

#### 1. GitLab (gitlab.viljo.se)
- **Container**: LXC 153 (172.16.10.153)
- **Authentication**: Native GitLab authentication
- **SSO Status**: N/A (GitLab IS the identity source)
- **Traefik Routing**: Configured
- **Status**: Working
- **Issues**: None
- **Recommendation**: No action needed

#### 2. Nextcloud (nextcloud.viljo.se)
- **Container**: LXC 155 (172.16.10.155)
- **Authentication**: Keycloak OIDC via user_oidc app
- **SSO Status**: Fully Implemented (2025-10-27)
- **Traefik Routing**: Configured
- **Status**: Working
- **Auth Flow**: GitLab.com → Keycloak → Nextcloud user_oidc
- **Issues**: None - fully operational
- **Documentation**: `/docs/NEXTCLOUD_DEPLOYMENT_COMPLETE.md`
- **Recommendation**: No action needed

#### 3. Keycloak (keycloak.viljo.se)
- **Container**: LXC 151 (172.16.10.151)
- **Authentication**: Native admin authentication
- **SSO Status**: N/A (Keycloak IS the SSO broker)
- **Traefik Routing**: Configured
- **Status**: Working
- **Issues**: None
- **Recommendation**: No action needed

#### 4. Links Portal (links.viljo.se)
- **Container**: LXC 156 (demo_site_container_id)
- **Authentication**: None (public landing page)
- **SSO Status**: N/A (public service)
- **Traefik Routing**: Configured
- **Status**: Working
- **Issues**: None
- **Recommendation**: No action needed (intentionally public)

### Deployed Services with Authentication Issues

#### 5. Webtop (browser.viljo.se)
- **Container**: LXC 170 (172.16.10.170:3000)
- **Authentication**: Native Webtop authentication (username/password)
- **SSO Status**: NOT CONFIGURED
- **Traefik Routing**: NOT CONFIGURED
- **Status**: Running but NOT accessible via HTTPS
- **Issues**:
  1. Missing from Traefik routing configuration in main.yml
  2. No DNS record for browser.viljo.se
  3. Not accessible externally via HTTPS
  4. No SSO integration configured
  5. Native auth requires separate username/password
- **Auth Capabilities**: Limited - could use oauth2-proxy forward auth for URL protection
- **Recommendation**: HIGH PRIORITY FIX
  - Add Traefik routing for browser.viljo.se
  - Add DNS record to loopia_dns_records
  - Consider oauth2-proxy forward auth middleware for access control
  - Note: True SSO not possible - Webtop doesn't support OIDC natively

### Infrastructure Services

#### PostgreSQL (LXC 150 - 172.16.10.150)
- **Authentication**: PostgreSQL native auth
- **SSO Status**: N/A (database service)
- **Status**: Working
- **Issues**: None
- **Recommendation**: No action needed

#### Redis (LXC 158)
- **Authentication**: Redis password auth
- **SSO Status**: N/A (cache service)
- **Status**: Working
- **Issues**: None
- **Recommendation**: No action needed

#### Firewall (LXC 101 - 172.16.10.101)
- **Authentication**: System authentication
- **SSO Status**: N/A (infrastructure)
- **Status**: Working
- **Issues**: None
- **Recommendation**: No action needed

#### GitLab Runner (LXC - gitlab_runner_container_id)
- **Authentication**: GitLab integration token
- **SSO Status**: N/A (CI/CD service)
- **Status**: Working
- **Issues**: None
- **Recommendation**: No action needed

### Removed Services

#### Mattermost (REMOVED 2025-10-27)
- **Status**: Intentionally removed
- **Reason**: Team Edition SSO limitations made it impractical
- **Documentation**: See commit d00fcca and SSO_STRATEGY.md
- **Container**: LXC 163 (stopped and removed)
- **Recommendation**: No action (removal was correct decision)

### Planned Services (Not Yet Deployed)

The following services are defined in services.yml and have Traefik routing configured, but are not yet deployed. Authentication strategy needs to be determined during deployment:

1. **Jellyfin** (jellyfin.viljo.se) - Media server
   - Auth Strategy: May support LDAP/OIDC, evaluate during deployment
   - Priority: P1

2. **Home Assistant** (homeassistant.viljo.se) - Home automation
   - Auth Strategy: Supports OAuth, can integrate with Keycloak
   - Priority: P2

3. **NetBox** (netbox.viljo.se) - Infrastructure documentation
   - Auth Strategy: Supports OIDC/SAML, good candidate for Keycloak
   - Priority: P2

4. **Wazuh** (wazuh.viljo.se) - Security monitoring
   - Auth Strategy: Supports OIDC, integrate with Keycloak
   - Priority: P2

5. **OpenMediaVault** (openmediavault.viljo.se) - NAS
   - Auth Strategy: Limited OAuth support, may need oauth2-proxy
   - Priority: P3

6. **Zipline** (zipline.viljo.se) - Image hosting
   - Auth Strategy: May support OAuth, evaluate during deployment
   - Priority: P3

7. **qBittorrent** (qbittorrent.viljo.se) - Torrent client
   - Auth Strategy: Native auth only, use oauth2-proxy forward auth
   - Priority: P1

8. **Coolify** (coolify.viljo.se) - Docker platform
   - Auth Strategy: May support OAuth, evaluate during deployment
   - Priority: P1

9. **Zabbix** (zabbix.viljo.se) - Monitoring
   - Auth Strategy: Supports SAML/OIDC, integrate with Keycloak
   - Priority: P2

10. **WireGuard VPN** (vpn.viljo.se) - VPN service
    - Auth Strategy: N/A (VPN authentication separate from web SSO)
    - Priority: P1

### New Service Being Planned

#### Jitsi Meet (meet.viljo.se - specs/001-jitsi-server)
- **Status**: Specification in progress
- **Authentication Requirements**:
  - Primary: Anonymous access (no auth required for meetings)
  - Secondary: SSO integration for moderator privileges
  - Strategy: Authenticated users (via Keycloak SSO) = moderators, anonymous = guests
- **Auth Integration Points**:
  - JWT authentication with Keycloak OIDC
  - Moderator role based on authentication status
- **Priority**: Current feature branch
- **Recommendation**: Include SSO integration in deployment plan

## Issues Identified

### Critical Issues

**NONE** - Core authentication infrastructure is operational

### High Priority Issues

#### Issue #1: Webtop Not Accessible via HTTPS
- **Service**: Webtop (browser.viljo.se)
- **Severity**: High
- **Impact**: Service is deployed but completely inaccessible externally
- **Root Cause**: Missing Traefik routing configuration
- **Details**:
  - Webtop container is running on LXC 170 (172.16.10.170:3000)
  - No entry in traefik_services in main.yml
  - No DNS record in loopia_dns_records
  - Service is defined in services.yml with subdomain "browser"
  - Users cannot access the service at all
- **Fix Required**:
  1. Add Traefik routing entry
  2. Add DNS record
  3. Decide on oauth2-proxy forward auth requirement
- **Priority**: HIGH - Service is completely non-functional externally

### Medium Priority Issues

**NONE** - All deployed services either work correctly or have high priority issues listed above

### Low Priority Issues

**NONE**

## Authentication Patterns Established

### Pattern 1: Native OAuth/OIDC Support
**Used by**: Nextcloud
**Flow**: Service → Keycloak OIDC → GitLab.com OAuth
**Characteristics**:
- True single sign-on
- User auto-provisioning
- Best user experience
**Implementation**: Configure OIDC client in Keycloak, configure OIDC in application

### Pattern 2: Traefik Forward Auth with oauth2-proxy
**Used by**: None currently (was attempted with Mattermost, now removed)
**Flow**: Traefik → oauth2-proxy → Keycloak → GitLab.com
**Characteristics**:
- URL protection
- May require separate service login
- Works for services without native OAuth
**Implementation**: Add oauth2-proxy-auth middleware to Traefik route

### Pattern 3: Native Authentication
**Used by**: GitLab, Webtop, infrastructure services
**Flow**: Direct service authentication
**Characteristics**:
- No SSO integration
- Service-specific credentials
- Appropriate for special cases (GitLab is IdP, infrastructure services)
**Implementation**: Standard service configuration

### Pattern 4: Public Access
**Used by**: Links portal
**Flow**: No authentication
**Characteristics**:
- Completely public
- No credentials required
- Appropriate for landing pages
**Implementation**: Standard Traefik routing without auth middleware

## Recommended Authentication Strategy for New Services

When deploying new services, follow this decision tree:

1. **Does the service need authentication?**
   - No → Use Pattern 4 (Public Access)
   - Yes → Continue to 2

2. **Does the service natively support OAuth 2.0 or OIDC?**
   - Yes → Use Pattern 1 (Native OAuth/OIDC)
   - No → Continue to 3

3. **Is URL-level protection sufficient?**
   - Yes → Use Pattern 2 (oauth2-proxy Forward Auth)
   - No → Use Pattern 3 (Native Auth) or reconsider service choice

## Credentials Management Status

All authentication credentials are stored in Ansible Vault:
- **Location**: `inventory/group_vars/all/secrets.yml`
- **Status**: Properly vaulted
- **Credentials Stored**:
  - Keycloak admin credentials
  - Keycloak database credentials
  - GitLab.com OAuth client credentials
  - oauth2-proxy client credentials
  - Service-specific credentials (Nextcloud, Webtop, etc.)
- **Issues**: None
- **Recommendation**: Continue using Ansible Vault for all sensitive credentials

## Testing Status

### Tested and Working
- Keycloak admin access
- Keycloak GitLab.com OAuth integration
- oauth2-proxy health endpoint
- Nextcloud OIDC SSO (2025-10-27)
- GitLab external HTTPS access
- Traefik routing for deployed services

### Needs Testing
- Webtop access after fix implementation
- oauth2-proxy forward auth middleware (not currently used by any service)

## Summary of Findings

### Working Correctly
1. Core SSO infrastructure (Keycloak + oauth2-proxy + GitLab.com OAuth)
2. Nextcloud SSO integration (fully operational)
3. GitLab authentication and access
4. Links portal public access
5. Infrastructure services authentication

### Requires Immediate Fix
1. Webtop Traefik routing and HTTPS access

### Requires Planning
1. Authentication strategy for 10 planned services
2. Jitsi Meet SSO integration (JWT with Keycloak)
3. Decision on oauth2-proxy usage for services without native OAuth

### Correctly Removed
1. Mattermost (Team Edition SSO limitations)

## Next Steps

See accompanying FIX_PLAN.md for detailed implementation steps.
