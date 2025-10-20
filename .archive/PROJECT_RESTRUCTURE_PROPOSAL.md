# Project Restructure Proposal
**Date**: 2025-10-20
**Status**: Proposal - Requires User Approval

## Current State Analysis

### Issues Identified

#### 1. **Root Directory Clutter** ⚠️
**Current**: 14 files at root level, including temporary analysis files
```
AGENTS.md                        # AI agent context
CLAUDE.md                        # Claude-specific notes
CONSISTENCY_FIXES_SUMMARY.md     # Temporary analysis (completed)
INCONSISTENCIES_ANALYSIS.md      # Temporary analysis (completed)
REMEDIATION_SUMMARY.md           # Temporary analysis
README.md                        # Main project documentation
ansible.cfg                      # Ansible configuration
generate_role_readmes.sh         # Utility script
requirements.txt                 # Python dependencies
```

**Problem**: Mix of permanent config, documentation, and temporary files makes root difficult to navigate.

#### 2. **Duplicate group_vars Structure** 🔴 CRITICAL
**Current**:
```
group_vars/all/secrets.yml                    # Vault file
inventory/group_vars/all/secrets.yml          # Symlink to above
inventory/group_vars/all/*.yml                # Service configs (23 files)
```

**Problem**:
- Confusing structure with symlink
- Not following Ansible best practices (inventory vars should be in inventory/)
- Root-level `group_vars/` should not exist when using `inventory/` directory

#### 3. **Hidden Framework Directories** ⚠️
**Current**:
```
.claude/commands/           # Claude Code slash commands (8 files)
.codex/prompts/            # Codex prompts (8 files - duplicates)
.specify/                  # Specify framework templates
```

**Problem**: Duplicated speckit files between .claude and .codex. These are tooling files that clutter the root.

#### 4. **Specs Directory Organization** ⚠️
**Current**: 8 feature specs with inconsistent structure
```
specs/001-google-oauth-keycloak/        # Has: spec.md, checklists/
specs/002-docker-platform-selfservice/  # Has: full structure + .agent_context.md
specs/003-external-ssh-admin/           # Has: full structure
specs/004-demo-website/                 # Has: spec.md only, checklists/
specs/005-webtop-browser/               # Has: full structure
specs/006-wireguard-vpn/                # Has: full structure + tasks.md
specs/007-gitlab-ci-runner/             # Has: full structure (no tasks.md)
specs/008-gitlab-cicd/                  # Has: partial structure (no tasks.md)
```

**Problem**:
- Inconsistent completion state
- Empty `checklists/` and `contracts/` directories in most specs
- Some specs are planning docs, others are for completed features
- No clear distinction between "active", "completed", and "archived" specs

#### 5. **Documentation Scattered** ⚠️
**Current locations**:
- `README.md` - Main project documentation
- `docs/` - Infrastructure documentation (5 files)
- `docs/adr/` - Architecture Decision Records (template only)
- `docs/runbooks/` - Operational runbooks (1 file)
- `roles/*/README.md` - 24 role-specific README files
- `specs/*/spec.md` - Feature specifications
- Root-level analysis files (3 files)

**Problem**: No clear hierarchy or single source of truth for documentation.

#### 6. **Role Documentation Quality** ⚠️
**Current**: 24 roles with varying README quality:
- **Complete**: `demo_site`, `gitlab` (detailed documentation)
- **Template only**: `nextcloud`, `homeassistant`, `openmediavault` (TODO placeholders)
- **Unknown**: Most other roles

**Problem**: Inconsistent documentation makes it hard to understand what each role does.

---

## Proposed Structure

### Goal
Create a clean, professional Ansible project structure that:
- Follows Ansible best practices
- Clearly separates config, code, documentation, and temporary files
- Makes it easy to find information
- Removes completed analysis files
- Consolidates tooling configuration

### New Directory Structure

```
Proxmox_config/
├── README.md                          # Main project overview
├── ansible.cfg                        # Ansible configuration
├── requirements.txt                   # Python dependencies
├── .gitignore                         # Git ignore rules
├── .gitlab-ci.yml                     # CI/CD pipeline
│
├── inventory/                         # Ansible inventory (UNCHANGED)
│   ├── hosts.yml
│   └── group_vars/
│       └── all/
│           ├── secrets.yml            # Vault (moved from root group_vars/)
│           ├── main.yml               # Global variables
│           ├── network.yml
│           ├── firewall.yml
│           └── [service configs]      # 20 service-specific files
│
├── playbooks/                         # Ansible playbooks
│   ├── site.yml
│   ├── dmz-rebuild.yml
│   ├── demo-site-deploy.yml
│   └── demo-site-teardown.yml
│
├── roles/                             # Ansible roles (24 roles)
│   ├── firewall/
│   ├── demo_site/
│   ├── gitlab/
│   └── [22 other roles]/
│
├── docs/                              # 📚 CONSOLIDATED DOCUMENTATION
│   ├── README.md                      # Documentation index
│   ├── getting-started.md             # Quick start guide
│   ├── architecture/
│   │   ├── network-topology.md        # Network design (MOVED)
│   │   ├── security-model.md          # Security architecture
│   │   └── container-mapping.md       # Container ID reference
│   ├── deployment/
│   │   ├── firewall-deployment.md     # Firewall setup (MOVED)
│   │   ├── proxmox-access.md          # Proxmox access (MOVED)
│   │   └── secrets-management.md      # Vault usage (MOVED)
│   ├── operations/
│   │   └── rollback-service.md        # Runbook (MOVED from docs/runbooks/)
│   ├── adr/                           # Architecture Decision Records
│   │   ├── README.md
│   │   ├── 001-network-topology-change.md      # NEW: Document vmbr1→vmbr2/vmbr3
│   │   ├── 002-container-id-standardization.md # NEW: Document ID=IP pattern
│   │   └── template.md
│   └── development/
│       ├── contributing.md            # Contribution guidelines
│       ├── role-development.md        # How to create roles
│       └── testing.md                 # Testing guidelines
│
├── specs/                             # 🗂️ REORGANIZED FEATURE SPECS
│   ├── README.md                      # Specs index and status
│   ├── completed/                     # ✅ Implemented features (archive)
│   │   ├── 004-demo-website/
│   │   │   └── spec.md
│   │   └── [move completed specs here]
│   ├── active/                        # 🚧 In progress
│   │   └── [specs being worked on]
│   └── planned/                       # 📋 Future features
│       ├── 001-google-oauth-keycloak/
│       ├── 002-docker-platform-selfservice/
│       ├── 003-external-ssh-admin/
│       ├── 005-webtop-browser/
│       ├── 006-wireguard-vpn/
│       ├── 007-gitlab-ci-runner/
│       └── 008-gitlab-cicd/
│
├── scripts/                           # 🔧 UTILITY SCRIPTS
│   ├── generate_role_readmes.sh       # MOVED from root
│   └── README.md                      # Scripts documentation
│
├── .tooling/                          # 🛠️ FRAMEWORK CONFIGURATION
│   ├── README.md                      # Tooling documentation
│   ├── ansible-lint/
│   │   └── .ansible-lint              # MOVED from root
│   ├── yaml-lint/
│   │   └── .yamllint                  # MOVED from root
│   ├── claude-code/                   # RENAMED from .claude/
│   │   └── commands/                  # Slash commands
│   └── specify/                       # RENAMED from .specify/
│       ├── memory/
│       └── templates/
│
└── .archive/                          # 📦 COMPLETED ANALYSIS FILES
    ├── README.md                      # Archive index
    ├── AGENTS.md                      # ARCHIVED
    ├── CLAUDE.md                      # ARCHIVED
    ├── CONSISTENCY_FIXES_SUMMARY.md   # ARCHIVED
    ├── INCONSISTENCIES_ANALYSIS.md    # ARCHIVED
    └── REMEDIATION_SUMMARY.md         # ARCHIVED
```

### Key Changes Summary

| Change | Action | Rationale |
|--------|--------|-----------|
| **Remove `group_vars/` from root** | Move `secrets.yml` to `inventory/group_vars/all/` | Follow Ansible best practices |
| **Consolidate documentation** | Move all docs to `docs/` with subdirectories | Single source of truth |
| **Archive temporary files** | Move 5 MD files to `.archive/` | Clean up root, preserve history |
| **Organize specs by status** | Create `completed/`, `active/`, `planned/` | Clear feature lifecycle |
| **Move scripts** | Create `scripts/` directory | Separate code from config |
| **Consolidate tooling** | Create `.tooling/` directory | Group framework files |
| **Remove `.codex/`** | Delete duplicate speckit files | Eliminate redundancy |
| **Create missing docs** | Add ADRs, contributing guide | Complete documentation |
| **Improve docs structure** | Add `architecture/`, `deployment/`, `operations/` | Logical grouping |

---

## Implementation Plan

### Phase 1: Backup and Preparation ✅
```bash
# Create backup
git status
git add -A
git commit -m "Pre-restructure backup"
git branch backup-before-restructure
```

### Phase 2: Documentation Consolidation
1. Create new `docs/` structure
2. Move existing docs:
   - `docs/firewall-deployment.md` → `docs/deployment/firewall-deployment.md`
   - `docs/network-topology.md` → `docs/architecture/network-topology.md`
   - `docs/proxmox-access.md` → `docs/deployment/proxmox-access.md`
   - `docs/secrets-management.md` → `docs/deployment/secrets-management.md`
   - `docs/runbooks/rollback-service.md` → `docs/operations/rollback-service.md`
3. Create new documentation:
   - `docs/README.md` - Documentation index
   - `docs/getting-started.md` - Quick start
   - `docs/architecture/container-mapping.md` - Container ID reference table
   - `docs/adr/001-network-topology-change.md` - Document network redesign
   - `docs/adr/002-container-id-standardization.md` - Document ID standardization
4. Delete empty directories: `docs/runbooks/`

### Phase 3: Specs Reorganization
1. Create `specs/README.md` with status table
2. Create subdirectories: `specs/{completed,active,planned}/`
3. Move specs based on implementation status:
   - **completed**: `004-demo-website` (fully implemented)
   - **planned**: All others (7 specs)
4. Remove empty `checklists/` and `contracts/` directories
5. Delete `.agent_context.md` files (temporary)

### Phase 4: Root Cleanup
1. Create `.archive/` directory with README
2. Move completed analysis files:
   - `AGENTS.md` → `.archive/`
   - `CLAUDE.md` → `.archive/`
   - `CONSISTENCY_FIXES_SUMMARY.md` → `.archive/`
   - `INCONSISTENCIES_ANALYSIS.md` → `.archive/`
   - `REMEDIATION_SUMMARY.md` → `.archive/`

### Phase 5: Scripts and Tooling
1. Create `scripts/` directory
2. Move `generate_role_readmes.sh` → `scripts/`
3. Create `scripts/README.md`
4. Create `.tooling/` directory
5. Move `.ansible-lint` → `.tooling/ansible-lint/.ansible-lint`
6. Move `.yamllint` → `.tooling/yaml-lint/.yamllint`
7. Rename `.claude/` → `.tooling/claude-code/`
8. Rename `.specify/` → `.tooling/specify/`
9. Delete `.codex/` (duplicate of .claude/)
10. Update references in configuration files

### Phase 6: Inventory Cleanup
1. Remove `group_vars/` from root entirely
2. Update any references in playbooks/roles
3. Ensure `inventory/group_vars/all/secrets.yml` is the only vault file

### Phase 7: Update References
1. Update README.md with new structure
2. Update `.gitignore` if needed
3. Update `ansible.cfg` paths if needed
4. Update CI/CD pipeline (`.gitlab-ci.yml`) if needed
5. Search and replace documentation links

### Phase 8: Verification
1. Run ansible syntax check: `ansible-playbook playbooks/site.yml --syntax-check`
2. Run ansible-lint: `ansible-lint`
3. Verify documentation links work
4. Test that vault can still be accessed

---

## Benefits

1. **✅ Cleaner Root Directory**: Only essential config files at root
2. **✅ Ansible Best Practices**: Follows standard Ansible project layout
3. **✅ Better Documentation**: Organized by topic (architecture, deployment, operations)
4. **✅ Clear Feature Status**: Specs organized by implementation state
5. **✅ Preserved History**: Analysis files archived, not deleted
6. **✅ Professional Structure**: Easy for new team members to navigate
7. **✅ Reduced Redundancy**: Removed duplicate speckit files
8. **✅ Logical Grouping**: Related files grouped together

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Break Ansible paths | Test with `--syntax-check` before deploying |
| Break documentation links | Search/replace and verify all links |
| Lose file history | Use `git mv` to preserve history |
| Break CI/CD | Update `.gitlab-ci.yml` paths |
| Break tooling | Update `.ansible-lint`, `.yamllint` paths in configs |
| Vault access issues | Test vault decryption after moving |

---

## User Decision Required

**Options:**

1. **✅ FULL RESTRUCTURE (Recommended)**: Implement all phases above
2. **⚠️ PARTIAL RESTRUCTURE**: Implement only critical fixes (Phase 6: inventory cleanup)
3. **❌ NO CHANGE**: Keep current structure

**Questions for User:**

1. Should we proceed with the full restructure?
2. Are there any files/directories you want to keep at root level?
3. Do you want to keep any of the analysis files (CONSISTENCY_FIXES_SUMMARY.md, etc.) instead of archiving them?
4. Are there any custom paths in your workflow that might break?

**Next Steps After Approval:**
1. Create git branch: `feature/project-restructure`
2. Execute phases 1-8 systematically
3. Test thoroughly
4. Create pull request for review
5. Merge to main branch

---

**⚠️ IMPORTANT**: This restructure requires testing before deployment. Recommend running in a development environment first.
