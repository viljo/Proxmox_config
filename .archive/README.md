# Archive

This directory contains completed analysis files and historical documents that are no longer actively used but preserved for reference.

## Purpose

These files were created during infrastructure development and analysis phases. They contain valuable historical context but are not part of the active documentation.

## Archived Files

### Analysis Documents (October 2025)

| File | Date | Purpose | Status |
|------|------|---------|--------|
| `AGENTS.md` | 2025-10-20 | AI agent context and configuration | Completed |
| `CLAUDE.md` | 2025-10-20 | Claude-specific notes and context | Completed |
| `CONSISTENCY_FIXES_SUMMARY.md` | 2025-10-20 | Summary of container ID standardization | Completed |
| `INCONSISTENCIES_ANALYSIS.md` | 2025-10-20 | Detailed analysis of project inconsistencies | Completed |
| `REMEDIATION_SUMMARY.md` | 2025-10-19 | Security remediation for NetBox credentials | Completed |
| `PROJECT_RESTRUCTURE_PROPOSAL.md` | 2025-10-20 | Project reorganization proposal | Implemented |

### What Each File Contains

#### AGENTS.md
- Configuration and context for AI-assisted development
- Agent behaviors and prompts
- Tool usage patterns
- Now superseded by `.specify/` framework

#### CLAUDE.md
- Claude Code-specific notes and instructions
- Project context for AI assistance
- Now superseded by integrated documentation

#### CONSISTENCY_FIXES_SUMMARY.md
- Complete log of container ID standardization effort
- 22 files modified to implement ID = IP last octet pattern
- All changes documented in detail
- Related: [ADR-002: Container ID Standardization](../docs/adr/002-container-id-standardization.md)

#### INCONSISTENCIES_ANALYSIS.md
- 420+ line analysis identifying 8 categories of issues
- Container ID conflicts
- IP address collisions
- Domain naming inconsistencies
- Network bridge configuration issues
- Variable naming problems
- Led to comprehensive fixes documented in CONSISTENCY_FIXES_SUMMARY.md

#### REMEDIATION_SUMMARY.md
- Security audit findings
- Fixed critical NetBox credentials exposure
- Hardcoded passwords removed from `netbox.yml`
- Replaced with proper Ansible Vault references

#### PROJECT_RESTRUCTURE_PROPOSAL.md
- Detailed proposal for reorganizing project structure
- Analysis of current state issues
- New directory structure design
- Implementation plan (8 phases)
- This archive is part of implementing that proposal

## Why These Are Archived

### Not Deleted

These files contain important historical context and decision-making rationale. They may be useful for:
- Understanding how current state was reached
- Debugging if issues arise from changes
- Onboarding new team members to project history
- Audit trail of major infrastructure changes

### Not in Main Documentation

These are:
- Time-bound (specific to Oct 2025 work)
- Completed work (no ongoing relevance)
- Interim analysis (superseded by ADRs and permanent docs)
- Implementation details (vs. architectural decisions)

## Active Documentation

For current documentation, see:

- **[Documentation Index](../docs/README.md)** - All current documentation
- **[Architecture Decision Records](../docs/adr/)** - Formal decision documentation
- **[Getting Started](../docs/getting-started.md)** - Quick start guide
- **[Container Mapping](../docs/architecture/container-mapping.md)** - Current container configuration

## Retention Policy

Archived files are kept indefinitely in git history. This directory serves as a convenient reference without cluttering the main project.

Files may be removed from `.archive/` if:
- Content is fully incorporated into permanent documentation
- Historical value diminishes over time
- Information becomes irrelevant due to major architecture changes

## Related Changes

This archive was created as part of the project restructure (2025-10-20):
- **Branch**: `feature/project-restructure`
- **Proposal**: `PROJECT_RESTRUCTURE_PROPOSAL.md` (in this archive)
- **Commit**: See git history for "Phase 4: Archive temporary analysis files"

---

**Last Updated**: 2025-10-20
**Total Files**: 6 analysis documents
