# Implementation Plan: External SSH Access via viljo.se

**Branch**: `003-external-ssh-admin` | **Date**: 2025-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-external-ssh-admin/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Enable external SSH access to the Proxmox host (mother) via the viljo.se domain. Internet connectivity is provided through the firewall container (LXC 101) which connects vmbr2 (WAN) to vmbr3 (DMZ) where the Proxmox host has IP 172.16.10.1. This will be accomplished through DNS configuration, firewall DNAT rules to forward SSH port 22 to the Proxmox host, and SSH hardening managed via Ansible roles. The solution leverages existing Loopia DDNS infrastructure for dynamic IP updates and implements security best practices including fail2ban protection and key-based authentication.

## Technical Context

**Language/Version**: YAML (Ansible 2.15+), Shell scripting (bash)
**Primary Dependencies**: Ansible, fail2ban, openssh-server, loopia-ddns (existing), nftables/iptables
**Storage**: Configuration files (/etc/ssh/sshd_config, /etc/fail2ban/, firewall rules), audit logs (syslog/journald)
**Testing**: ansible-lint, yamllint, molecule (optional for role testing), manual smoke tests from external network
**Target Platform**: Debian-based Proxmox VE host on vmbr3 (172.16.10.1), internet access via firewall container on vmbr2
**Project Type**: Infrastructure configuration (Ansible roles)
**Performance Goals**: SSH connection establishment <10 seconds from external networks, DNS resolution <2 seconds
**Constraints**: Must not disrupt existing Proxmox operations, must maintain constitutional compliance (idempotent, IaC)
**Scale/Scope**: Single Proxmox host, 1-5 concurrent admin sessions expected, external access for 1-3 administrators

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Infrastructure as Code
- [x] All infrastructure changes defined in Ansible roles (proxmox host SSH config, fail2ban, firewall rules, loopia DDNS)
- [x] No manual configuration steps required (all configured via Ansible)
- [x] Roles are version-controlled and documented

### Security-First Design
- [N/A] Integration with Keycloak/LDAP authentication (SSH uses key-based auth, not centralized SSO)
- [x] No plaintext secrets (using Ansible Vault for any credentials)
- [N/A] Container security (unprivileged LXC, AppArmor, nftables) - applies to Proxmox host directly, not LXC

### Idempotent Operations
- [x] All playbooks can be re-run safely (SSH config, fail2ban setup, DNS updates)
- [x] Proper state checks before changes (Ansible built-in idempotency)
- [x] Destructive operations require explicit flags (no destructive ops in this feature)

### Single Source of Truth
- [x] NetBox integration for inventory (Proxmox host in NetBox inventory)
- [⚠️] DNS configuration external to NetBox (Loopia is authoritative DNS provider - see Complexity Tracking)
- [N/A] Monitoring aligned with CMDB (basic SSH access monitoring via fail2ban logs)
- [x] Documentation derived from NetBox data (where applicable)

### Automated Operations
- [x] CI/CD pipeline configuration (GitLab CI for Ansible role testing)
- [x] Automated testing approach defined (ansible-lint, yamllint, manual smoke tests)
- [x] Backup and monitoring automation included (SSH config backed up, fail2ban logs monitored)

## Project Structure

### Documentation (this feature)

```
specs/003-external-ssh-admin/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── ssh-config.yml   # SSH daemon configuration contract
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

This is an infrastructure configuration feature using Ansible roles, not a traditional source code project.

```
roles/
├── proxmox/             # Existing role - will be extended
│   ├── tasks/
│   │   ├── ssh-hardening.yml     # NEW: SSH security configuration
│   │   └── firewall-vmbr2.yml    # NEW: Firewall rules for vmbr2
│   ├── handlers/
│   │   └── main.yml              # Restart sshd, reload firewall handlers
│   ├── templates/
│   │   ├── sshd_config.j2        # NEW: Hardened SSH config
│   │   ├── fail2ban-sshd.conf.j2 # NEW: fail2ban jail config
│   │   └── nftables-vmbr2.conf.j2 # NEW: nftables rules for vmbr2
│   └── defaults/
│       └── main.yml              # SSH config variables, firewall config
│
├── loopia_ddns/         # Existing role - will be verified/extended
│   └── tasks/
│       └── main.yml     # Ensure viljo.se DDNS updates for vmbr2 IP

playbooks/
└── external-ssh-access.yml  # NEW: Main playbook for this feature

group_vars/all/
└── secrets.yml          # Vault-encrypted secrets (SSH keys, Loopia credentials)
```

**Structure Decision**: This feature extends existing Ansible roles (proxmox, firewall, loopia_ddns) rather than creating new source code. The implementation follows the Infrastructure as Code principle using Ansible's declarative YAML configuration. New tasks and templates will be added to existing roles to maintain organizational consistency. Firewall DNAT port forwarding (vmbr2:22 → 172.16.10.1:22) will be configured in the firewall container role to route external SSH traffic to the Proxmox host.

## Complexity Tracking

*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| DNS configuration external to NetBox | Loopia DNS is managed via external API, not NetBox | NetBox is primarily for internal infrastructure inventory. External DNS services (Loopia) are authoritative for public DNS and must be configured directly. Will use existing loopia_ddns role for automation. |

## Post-Design Constitution Re-Evaluation

**Date**: 2025-10-20
**Status**: ✅ APPROVED WITH JUSTIFIED EXCEPTION

### Infrastructure as Code
- ✅ **PASS**: All infrastructure changes defined in Ansible roles
  - SSH hardening: `roles/proxmox/tasks/ssh-hardening.yml`
  - Firewall rules: `roles/proxmox/tasks/firewall-vmbr2.yml`
  - fail2ban config: templates in `roles/proxmox/templates/`
  - DDNS updates: `roles/loopia_ddns/` (existing)
- ✅ **PASS**: No manual configuration steps required
  - All automated via Ansible (no router/port forwarding needed)
- ✅ **PASS**: Roles are version-controlled and documented
  - All configs in git, quickstart.md provides comprehensive guide

### Security-First Design
- ✅ **PASS**: Key-based authentication enforced (no passwords)
  - `PasswordAuthentication no` in sshd_config
  - `PermitRootLogin without-password` (keys only)
- ✅ **PASS**: No plaintext secrets (using Ansible Vault)
  - SSH public keys in vault
  - Loopia credentials in vault
- ✅ **PASS**: Fail2ban provides brute force protection
  - Configured with conservative thresholds
  - Whitelists internal network
- ✅ **PASS**: Audit logging to syslog/Wazuh
  - LogLevel VERBOSE captures all events
  - 90-day retention minimum
- N/A: Keycloak/LDAP integration (SSH uses native key auth)
- N/A: Container security (applies to Proxmox host directly)

### Idempotent Operations
- ✅ **PASS**: All playbooks can be re-run safely
  - Ansible template module is idempotent
  - sshd config validated before restart (`sshd -t`)
  - fail2ban installation via package manager (idempotent)
- ✅ **PASS**: Proper state checks before changes
  - Ansible's built-in idempotency mechanism
  - Configuration validation before service restart
- ✅ **PASS**: No destructive operations
  - Config changes only, no data deletion
  - Backup of previous sshd_config maintained

### Single Source of Truth
- ✅ **PASS**: Proxmox host should be in NetBox inventory
  - Ansible targets `proxmox_admin` inventory group
  - NetBox integration for host metadata
- ⚠️ **EXCEPTION**: DNS configuration external to NetBox
  - **Justification**: Loopia is authoritative DNS provider
  - **Mitigation**: Existing loopia_ddns role provides automation
  - **Rationale**: External DNS services can't be inventoried in NetBox
- ✅ **PASS**: Documentation derived from configuration
  - quickstart.md references Ansible variables
  - contracts/ define expected state

### Automated Operations
- ✅ **PASS**: CI/CD pipeline for testing
  - ansible-lint, yamllint in GitLab CI
  - Playbook syntax validation
- ✅ **PASS**: Automated testing defined
  - Contract-based validation in contracts/ssh-config-contract.yml
  - Manual smoke tests documented in quickstart.md
- ✅ **PASS**: Monitoring automation
  - fail2ban logs monitored
  - Wazuh SIEM integration (if available)
  - SSH auth logs to syslog
- ✅ **PASS**: Full automation of infrastructure
  - No router involved - direct internet on vmbr2
  - Firewall rules automated via nftables/iptables Ansible tasks

### Summary

**Overall Status**: ✅ **CONSTITUTIONAL COMPLIANCE ACHIEVED**

**Exception**: 1 justified exception due to service constraints:
1. DNS configuration external to NetBox (Loopia API automation provided)

The exception has:
- Clear justification (external DNS service, not internal infrastructure)
- Full automation via loopia_ddns role
- No simpler alternative available (Loopia is authoritative DNS provider)

The design maintains constitutional principles with full automation. No manual steps required thanks to direct internet connectivity on vmbr2 (eliminating router/port forwarding complexity).

## Design Artifacts Summary

All Phase 0 and Phase 1 artifacts have been generated:

### Phase 0: Research ✅
- **research.md**: Technology decisions, best practices, risk assessment

### Phase 1: Design & Contracts ✅
- **data-model.md**: Configuration entities and relationships
- **contracts/ssh-config-contract.yml**: SSH daemon, fail2ban, DNS, port forwarding contracts
- **quickstart.md**: Comprehensive step-by-step implementation guide

### Phase 2: Tasks (Next Command)
- **tasks.md**: Will be generated by `/speckit.tasks` command
- Dependency-ordered implementation tasks based on this plan

## Implementation Readiness

✅ **Ready for task generation via `/speckit.tasks`**

**Key Decisions Made**:
- SSH hardening with OpenSSH best practices
- fail2ban for brute force protection
- Loopia DDNS for vmbr2 IP updates
- ed25519 SSH keys (Ansible Vault encrypted)
- Standard port 22 (no port obfuscation needed - fail2ban provides protection)
- 300-second DNS TTL for fast propagation
- nftables firewall rules on vmbr2 interface

**Technology Stack**:
- Ansible 2.15+ for automation
- OpenSSH 8.x for remote access
- fail2ban 0.11+ for attack mitigation
- Loopia API for DNS management
- syslog/journald for audit logging

**Next Steps**:
1. Run `/speckit.tasks` to generate implementation task list
2. Implement tasks in dependency order
3. Test each component as documented in quickstart.md
4. Verify success criteria from spec.md

