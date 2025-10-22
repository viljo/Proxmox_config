# ADR-002: Container ID Standardization (ID = IP Last Octet)

**Status**: Implemented
**Date**: 2025-10-20
**Decision Makers**: Infrastructure Team
**Related**: [Container Mapping](../architecture/container-mapping.md)

## Context

The original container ID assignment was arbitrary and inconsistent:

### Original IDs (Before Standardization)
| Service | Old ID | IP Address | Issue |
|---------|--------|------------|-------|
| Firewall | 2200 | 172.16.10.1 | No relationship |
| PostgreSQL | 1990 | 172.16.10.50 | No relationship |
| Keycloak | 2000 | 172.16.10.51 | No relationship |
| GitLab | 2050 | 172.16.10.53 | No relationship |
| Demo Site | 2300 | 172.16.10.60 | No relationship |

### Problems Identified

1. **Cognitive Load**: No way to determine IP from container ID or vice versa
2. **Documentation Burden**: Every reference needed both ID and IP
3. **Error Prone**: Easy to confuse which ID belongs to which service
4. **Inconsistency**: Different services used different numbering schemes
5. **Not Scalable**: Running out of "memorable" IDs in 2000-2300 range

## Decision

Standardize container IDs to match the last octet of their IP address:

```
Container ID = Last octet of IP address (on 172.16.10.0/24 network)
```

### Examples
| Service | New ID | IP Address | Mnemonic |
|---------|--------|------------|----------|
| Firewall | **1** | 172.16.10.**1** | .1 = Gateway |
| PostgreSQL | **50** | 172.16.10.**50** | .50 = Backend services |
| Keycloak | **51** | 172.16.10.**51** | .51 = Auth |
| NetBox | **52** | 172.16.10.**52** | .52 = Infrastructure docs |
| GitLab | **53** | 172.16.10.**53** | .53 = DevOps |
| GitLab Runner | **54** | 172.16.10.**54** | .54 = CI runner |
| Nextcloud | **55** | 172.16.10.**55** | .55 = Files |
| Jellyfin | **56** | 172.16.10.**56** | .56 = Media |
| Home Assistant | **57** | 172.16.10.**57** | .57 = IoT |
| qBittorrent | **59** | 172.16.10.**59** | .59 = Torrents |
| Demo Site | **60** | 172.16.10.**60** | .60 = Demo |
| Wazuh | **62** | 172.16.10.**62** | .62 = Security |
| OpenMediaVault | **64** | 172.16.10.**64** | .64 = NAS |
| Zipline | **65** | 172.16.10.**65** | .65 = Screenshots |
| WireGuard | **90** | 172.16.10.**90** | .90 = VPN |

## Rationale

### Mental Model Simplification
- **Before**: "What's the IP of container 2050?" → Look it up
- **After**: "What's the IP of container 53?" → "172.16.10.53"

### Reduced Documentation
- Documentation can refer to just the ID or just the IP
- Both convey the same information
- Less chance of ID/IP mismatch in docs

### Self-Documenting Commands
```bash
# Old way - unclear what you're connecting to
pct exec 2050 -- systemctl status gitlab

# New way - instantly know it's the .53 IP
pct exec 53 -- systemctl status gitlab
```

### Consistency with Common Practices
Many infrastructure teams use this pattern:
- Kubernetes node IPs often match hostnames
- Server rack positions often match last octet
- Virtual machine IDs often match IP assignments

### Future Proofing
- Clear ID ranges for different service types
- Easy to see which IDs are "taken" vs available
- No risk of ID collision or confusion

## Implementation

### Migration Process

1. **Analysis**: Identified all container ID references in:
   - Inventory files (`inventory/group_vars/all/*.yml`)
   - Role defaults (`roles/*/defaults/main.yml`)
   - Documentation (`docs/**/*.md`)
   - Spec files (`specs/**/*.md`)

2. **Bulk Update**: Updated 22 files systematically
   - 16 service inventory files
   - 1 DMZ registry file
   - 3 role default files
   - Multiple documentation files

3. **Documentation Sync**: Updated all references in:
   - Role README files
   - Deployment guides
   - Architecture documentation
   - Runbooks
   - Feature specifications

### Changed Files

See `CONSISTENCY_FIXES_SUMMARY.md` (archived) for complete list of 22 files updated.

Key changes:
- `firewall.yml`: 2200 → 1
- `postgresql.yml`: 1990 → 50
- `keycloak.yml`: 2000 → 51
- `netbox.yml`: 2150 → 52
- `gitlab.yml`: 2050 → 53
- `gitlab_runner.yml`: 2051 → 54
- `nextcloud.yml`: 2040 → 55
- `jellyfin.yml`: 2010 → 56
- `homeassistant.yml`: 2030 → 57
- `qbittorrent.yml`: 2070 → 59
- `demo_site.yml`: 2300 → 60
- `wazuh.yml`: 2080 → 62
- `openmediavault.yml`: 2020 → 64
- `zipline.yml`: 2060 → 65
- `wireguard.yml`: 2090 → 90

## Consequences

### Positive
- ✅ **Immediate Recognition**: See ID, know IP instantly
- ✅ **Reduced Errors**: Less chance of using wrong ID for service
- ✅ **Simplified Documentation**: Only need to mention one identifier
- ✅ **Easier Troubleshooting**: `pct exec 53` clearly operates on .53
- ✅ **Self-Documenting**: Code is more readable
- ✅ **Standard Pattern**: Follows industry best practices

### Negative
- ⚠️ **Existing Containers**: Requires destruction and recreation
- ⚠️ **ID Constraints**: Limited to IPs .1-.254 (but we only use ~16 services)
- ⚠️ **Learning Curve**: Team must learn new IDs

### Neutral
- 🔵 **One-Time Migration**: Required updating many files
- 🔵 **Documentation**: All docs needed review and updates
- 🔵 **Muscle Memory**: Commands like `pct exec 2050` need to change to `pct exec 53`

## IP Range Allocation Strategy

To maintain organization, services are grouped by IP range:

| Range | Purpose | Current Usage |
|-------|---------|---------------|
| .1-.9 | Core infrastructure | Firewall (1) |
| .10-.49 | Reserved future infrastructure | - |
| .50-.59 | Backend services | PostgreSQL (50), Keycloak (51), NetBox (52), GitLab (53-54), Nextcloud (55), Jellyfin (56), Home Assistant (57) |
| .60-.89 | User applications | Demo Site (60), Wazuh (62), OpenMediaVault (64), Zipline (65) |
| .90-.99 | Network services | WireGuard VPN (90) |

This provides clear separation and room for growth in each category.

## Rollout Plan

### Phase 1: Documentation Update ✅
- Updated all role defaults
- Updated all inventory files
- Updated documentation

### Phase 2: Container Recreation (Pending)
- Destroy existing containers with old IDs
- Recreate with new IDs using updated roles
- Verify services work correctly

### Phase 3: Validation (Pending)
- Test all service connectivity
- Verify Traefik routing
- Confirm DNS resolution
- Test firewall NAT rules

## Alternatives Considered

### Alternative 1: Keep Arbitrary IDs
Maintain status quo with random IDs like 2050, 2200, etc.

**Rejected because**:
- No cognitive benefit
- Harder to remember
- Doesn't scale well
- Missed opportunity for improvement

### Alternative 2: Sequential IDs (1, 2, 3...)
Use simple sequential numbering: 1, 2, 3, 4, etc.

**Rejected because**:
- Still requires IP lookup
- Doesn't convey useful information
- Same problems as current arbitrary system

### Alternative 3: Service Type Prefixes
Use prefixes like 1000-1999 for databases, 2000-2999 for web apps, etc.

**Rejected because**:
- Still requires separate IP tracking
- More complex than needed
- Arbitrary categorization

### Alternative 4: Last Two Octets
Match container ID to last two IP octets (e.g., container 1053 for 172.16.10.53).

**Rejected because**:
- Unnecessarily large IDs
- Third octet (10) never changes
- Harder to type and remember

## Compatibility Notes

### Proxmox Compatibility
- Proxmox supports container IDs from 100 to 999999999
- Our range (1-90) is well within limits
- No technical issues with single or double-digit IDs

### Backup/Restore
- Backups include container ID in filename
- Restoring with different ID is supported
- Migration requires coordination with backup system

### Monitoring/Logging
- Update monitoring systems to use new IDs
- Historical logs will reference old IDs
- Consider adding ID mapping documentation

## References

- [Container Mapping](../architecture/container-mapping.md) - Complete ID/IP reference
- [Network Topology](../architecture/network-topology.md) - Network architecture
- Git history: Commits from Oct 20, 2025 with "consistency" tags
- Original analysis: `INCONSISTENCIES_ANALYSIS.md` (archived)
- Implementation summary: `CONSISTENCY_FIXES_SUMMARY.md` (archived)

## Lessons Learned

1. **Plan for Conventions Early**: Would have saved migration effort if done initially
2. **Document Decisions**: This ADR would have been useful during initial setup
3. **Consistency Matters**: Small decisions like ID assignment have ongoing impact
4. **Automation Helps**: Ansible made bulk updates manageable

## Status History

- **2025-10-20**: Inconsistencies identified during review
- **2025-10-20**: Decision made to standardize IDs
- **2025-10-20**: Bulk updates completed (22 files)
- **2025-10-20**: Documentation updated
- **2025-10-20**: ADR created

---

**Last Updated**: 2025-10-20
**Next Review**: 2025-11-20 (1 month - verify containers recreated)
