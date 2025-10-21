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

Standardize container IDs based on the last octet of their IP address plus 100:

```
Container ID = Last octet of IP address + 100
```

This formula satisfies Proxmox's requirement that VMIDs must be >= 100 while maintaining a predictable relationship between container ID and IP address.

### Examples
| Service | New ID | IP Address | Calculation | Mnemonic |
|---------|--------|------------|-------------|----------|
| Firewall | **101** | 172.16.10.**1** | 1 + 100 | .1 = Gateway |
| PostgreSQL | **150** | 172.16.10.**50** | 50 + 100 | .50 = Backend services |
| Keycloak | **151** | 172.16.10.**51** | 51 + 100 | .51 = Auth |
| NetBox | **152** | 172.16.10.**52** | 52 + 100 | .52 = Infrastructure docs |
| GitLab | **153** | 172.16.10.**53** | 53 + 100 | .53 = DevOps |
| GitLab Runner | **154** | 172.16.10.**54** | 54 + 100 | .54 = CI runner |
| Nextcloud | **155** | 172.16.10.**55** | 55 + 100 | .55 = Files |
| Jellyfin | **156** | 172.16.10.**56** | 56 + 100 | .56 = Media |
| Home Assistant | **157** | 172.16.10.**57** | 57 + 100 | .57 = IoT |
| qBittorrent | **159** | 172.16.10.**59** | 59 + 100 | .59 = Torrents |
| Demo Site | **160** | 172.16.10.**60** | 60 + 100 | .60 = Demo |
| Cosmos | **161** | 172.16.10.**61** | 61 + 100 | .61 = Dashboard |
| Wazuh | **162** | 172.16.10.**62** | 62 + 100 | .62 = Security |
| OpenMediaVault | **164** | 172.16.10.**64** | 64 + 100 | .64 = NAS |
| Zipline | **165** | 172.16.10.**65** | 65 + 100 | .65 = Screenshots |
| WireGuard | **190** | 172.16.10.**90** | 90 + 100 | .90 = VPN |

## Rationale

### Mental Model Simplification
- **Before**: "What's the IP of container 2050?" → Look it up
- **After**: "What's the IP of container 153?" → "172.16.10.53" (153 - 100 = 53)

### Reduced Documentation
- Documentation can refer to just the ID or just the IP
- Both convey the same information
- Less chance of ID/IP mismatch in docs

### Self-Documenting Commands
```bash
# Old way - unclear what you're connecting to
pct exec 2050 -- systemctl status gitlab

# New way - instantly know it's the .53 IP (153 - 100 = 53)
pct exec 153 -- systemctl status gitlab
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
- `firewall.yml`: 2200 → 101 (IP .1 + 100)
- `postgresql.yml`: 1990 → 150 (IP .50 + 100)
- `keycloak.yml`: 2000 → 151 (IP .51 + 100)
- `netbox.yml`: 2150 → 152 (IP .52 + 100)
- `gitlab.yml`: 2050 → 153 (IP .53 + 100)
- `gitlab_runner.yml`: 2051 → 154 (IP .54 + 100)
- `nextcloud.yml`: 2040 → 155 (IP .55 + 100)
- `jellyfin.yml`: 2010 → 156 (IP .56 + 100)
- `homeassistant.yml`: 2030 → 157 (IP .57 + 100)
- `qbittorrent.yml`: 2070 → 159 (IP .59 + 100)
- `demo_site.yml`: 2300 → 160 (IP .60 + 100)
- `cosmos.yml`: 2100 → 161 (IP .61 + 100)
- `wazuh.yml`: 2080 → 162 (IP .62 + 100)
- `openmediavault.yml`: 2020 → 164 (IP .64 + 100)
- `zipline.yml`: 2060 → 165 (IP .65 + 100)
- `wireguard.yml`: 2090 → 190 (IP .90 + 100)

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
- ⚠️ **ID Range**: Container IDs 101-354 (IP .1-.254 + 100), but we only use ~16 services
- ⚠️ **Learning Curve**: Team must learn new IDs and the +100 formula

### Neutral
- 🔵 **One-Time Migration**: Required updating many files
- 🔵 **Documentation**: All docs needed review and updates
- 🔵 **Muscle Memory**: Commands like `pct exec 2050` need to change to `pct exec 153`

## IP Range Allocation Strategy

To maintain organization, services are grouped by IP range:

| IP Range | Container ID Range | Purpose | Current Usage |
|----------|-------------------|---------|---------------|
| .1-.9 | 101-109 | Core infrastructure | Firewall (101) |
| .10-.49 | 110-149 | Reserved future infrastructure | - |
| .50-.59 | 150-159 | Backend services | PostgreSQL (150), Keycloak (151), NetBox (152), GitLab (153-154), Nextcloud (155), Jellyfin (156), Home Assistant (157), qBittorrent (159) |
| .60-.89 | 160-189 | User applications | Demo Site (160), Cosmos (161), Wazuh (162), OpenMediaVault (164), Zipline (165) |
| .90-.99 | 190-199 | Network services | WireGuard VPN (190) |

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

### Selected Alternative: Last Octet + 100
Add 100 to the last IP octet (e.g., container 153 for 172.16.10.53).

**Chosen because**:
- Meets Proxmox VMID >= 100 requirement
- Simple mental arithmetic (subtract 100 to get IP last octet)
- Compact IDs (101-254 range)
- Maintains predictable relationship between ID and IP

## Compatibility Notes

### Proxmox Compatibility
- Proxmox requires container IDs >= 100 (enforced in Proxmox VE 9.0+)
- Our range (101-190) satisfies this requirement
- Formula ensures all IDs are >= 100 automatically

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
