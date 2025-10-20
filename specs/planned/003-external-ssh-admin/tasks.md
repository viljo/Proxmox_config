# Tasks: External SSH Access via viljo.se

**Input**: Design documents from `/specs/003-external-ssh-admin/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: No automated tests requested for this infrastructure feature. Validation will be performed via manual smoke tests from external networks per quickstart.md.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
- **Ansible roles**: `roles/<service>/tasks/`, `roles/<service>/templates/`
- **Playbooks**: `playbooks/` for orchestration
- **Configuration**: `group_vars/`, `inventory/`
- **Documentation**: `docs/` for architecture and operations guides

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify existing infrastructure and prepare for configuration changes

- [ ] T001 Verify firewall LXC container (CT 1) is deployed and operational
- [ ] T002 Verify Loopia DDNS is configured and updating viljo.se domain
- [ ] T003 [P] Verify Proxmox host is accessible at 192.168.1.3 on vmbr0
- [ ] T004 [P] Generate ed25519 SSH key pair for external access (if not exists)
- [ ] T005 Store SSH public key in group_vars/all/secrets.yml using Ansible Vault

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before user stories can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Add SSH forwarding service to roles/firewall/defaults/main.yml in firewall_forward_services list
- [ ] T007 Create roles/proxmox/defaults/main.yml with SSH hardening variables (ports, auth settings, fail2ban config)
- [ ] T008 [P] Create roles/proxmox/templates/sshd_config.j2 with Match Address directive for conditional password auth
- [ ] T009 [P] Create roles/proxmox/templates/fail2ban-sshd.conf.j2 for SSH jail configuration
- [ ] T010 [P] Create roles/proxmox/handlers/main.yml with restart sshd and fail2ban handlers

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - External SSH Access to Proxmox Host (Priority: P1) 🎯 MVP

**Goal**: Enable administrators to connect to Proxmox host (192.168.1.3) from external networks via ssh root@viljo.se

**Independent Test**: From external network, run `ssh root@viljo.se` with SSH key and verify successful connection to Proxmox host

### Implementation for User Story 1

- [ ] T011 [US1] Create roles/proxmox/tasks/ssh-hardening.yml to configure SSH daemon
- [ ] T012 [US1] Add task to backup existing /etc/ssh/sshd_config in roles/proxmox/tasks/ssh-hardening.yml
- [ ] T013 [US1] Add task to template sshd_config.j2 to /etc/ssh/sshd_config in roles/proxmox/tasks/ssh-hardening.yml
- [ ] T014 [US1] Add task to validate SSH config with `sshd -t` in roles/proxmox/tasks/ssh-hardening.yml
- [ ] T015 [US1] Add task to deploy authorized_keys file for root user in roles/proxmox/tasks/ssh-hardening.yml
- [ ] T016 [US1] Add task to set correct permissions (700/.ssh, 600/authorized_keys) in roles/proxmox/tasks/ssh-hardening.yml
- [ ] T017 [US1] Add notify handler to restart sshd in roles/proxmox/tasks/ssh-hardening.yml
- [ ] T018 [US1] Create playbooks/external-ssh-access.yml including proxmox role with ssh-hardening tasks
- [ ] T019 [US1] Run ansible-playbook playbooks/external-ssh-access.yml --check to verify syntax
- [ ] T020 [US1] Deploy SSH hardening configuration to Proxmox host (192.168.1.3)
- [ ] T021 [US1] Test SSH connection from internal network (192.168.x.x) with password auth
- [ ] T022 [US1] Test SSH connection from internal network with SSH key auth

**Checkpoint**: At this point, SSH hardening should be deployed and internal access verified

---

## Phase 4: User Story 2 - Firewall Port Forwarding (Priority: P2)

**Goal**: Configure firewall LXC to forward external SSH traffic (WAN:22) to Proxmox host (192.168.1.3:22)

**Independent Test**: From external network, verify `ssh root@viljo.se` forwards traffic through firewall to Proxmox host and connection succeeds

### Implementation for User Story 2

- [ ] T023 [US2] Update playbooks/external-ssh-access.yml to include firewall role
- [ ] T024 [US2] Run ansible-playbook playbooks/external-ssh-access.yml --tags firewall to deploy firewall changes
- [ ] T025 [US2] Verify firewall container restarts successfully with new configuration
- [ ] T026 [US2] Verify nftables rules include SSH DNAT entry: `pct exec 1 -- nft list ruleset | grep 192.168.1.3`
- [ ] T027 [US2] Test SSH connection from external network (mobile hotspot or VPN to different location)
- [ ] T028 [US2] Verify DNS resolution: `dig viljo.se +short` matches firewall WAN IP
- [ ] T029 [US2] Verify end-to-end connection: `ssh -v root@viljo.se` and check connection reaches Proxmox
- [ ] T030 [US2] Test firewall container reboot persistence: reboot CT 1 and verify rules restored

**Checkpoint**: At this point, external SSH access should work end-to-end through firewall forwarding

---

## Phase 5: User Story 3 - Security Hardening (Priority: P3)

**Goal**: Implement fail2ban protection to mitigate brute force attacks while maintaining usability

**Independent Test**: Trigger 6 failed authentication attempts from external IP and verify IP gets banned by fail2ban

### Implementation for User Story 3

- [ ] T031 [US3] Create roles/proxmox/tasks/fail2ban.yml to install and configure fail2ban
- [ ] T032 [US3] Add task to install fail2ban package via apt in roles/proxmox/tasks/fail2ban.yml
- [ ] T033 [US3] Add task to template fail2ban-sshd.conf.j2 to /etc/fail2ban/jail.d/sshd.conf in roles/proxmox/tasks/fail2ban.yml
- [ ] T034 [US3] Add task to enable fail2ban service in roles/proxmox/tasks/fail2ban.yml
- [ ] T035 [US3] Add notify handler to restart fail2ban in roles/proxmox/tasks/fail2ban.yml
- [ ] T036 [US3] Include fail2ban tasks in playbooks/external-ssh-access.yml
- [ ] T037 [US3] Deploy fail2ban configuration to Proxmox host
- [ ] T038 [US3] Verify fail2ban service is active: `systemctl status fail2ban`
- [ ] T039 [US3] Verify SSH jail is enabled: `fail2ban-client status sshd`
- [ ] T040 [US3] Test fail2ban by triggering 6 failed auth attempts from test IP
- [ ] T041 [US3] Verify test IP appears in banned list: `fail2ban-client status sshd`
- [ ] T042 [US3] Unban test IP: `fail2ban-client set sshd unbanip <IP>`
- [ ] T043 [US3] Verify successful SSH connection after unban

**Checkpoint**: All user stories should now be independently functional with security hardening complete

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and operational readiness

- [ ] T044 [P] Update docs/network-topology.md with SSH forwarding rule documentation
- [ ] T045 [P] Update roles/firewall/README.md documenting the SSH forwarding service entry
- [ ] T046 [P] Update roles/proxmox/README.md documenting SSH hardening and fail2ban configuration
- [ ] T047 [P] Create operational runbook in docs/runbooks/external-ssh-access.md with troubleshooting steps
- [ ] T048 Verify all configuration persists across Proxmox host reboot
- [ ] T049 Verify all configuration persists across firewall container (CT 1) reboot
- [ ] T050 Run through quickstart.md validation steps end-to-end
- [ ] T051 Verify SC-002: DNS resolution completes in under 2 seconds (`dig viljo.se`)
- [ ] T052 Verify SC-003: SSH connection establishment under 10 seconds from external network
- [ ] T053 Verify SC-004: Check /var/log/auth.log for complete connection audit trail
- [ ] T054 Verify SC-007: Test dynamic IP update (if applicable) reflects in DNS within 5 minutes

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion (T001-T005) - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion (T006-T010)
  - User stories CAN proceed in parallel if different team members work on them
  - Or sequentially in priority order: P1 (US1) → P2 (US2) → P3 (US3)
- **Polish (Phase 6)**: Depends on all user stories being complete (T011-T043)

### User Story Dependencies

- **User Story 1 (P1 - SSH Hardening)**: Can start after Foundational (Phase 2) - No dependencies on other stories
  - Deliverable: SSH works from internal networks with hardened config

- **User Story 2 (P2 - Firewall Forwarding)**: Can start after Foundational (Phase 2) - Integrates with US1 but independently testable
  - Depends on: US1 completion for end-to-end testing, but firewall config is independent
  - Deliverable: External SSH access works through firewall forwarding

- **User Story 3 (P3 - Fail2ban Security)**: Can start after Foundational (Phase 2) - Independent of firewall forwarding
  - Can be developed in parallel with US2
  - Deliverable: Brute force protection active

### Within Each User Story

**User Story 1 (T011-T022)**:
- Tasks T011-T017 must be sequential (building ssh-hardening.yml)
- T018-T020 must be sequential (playbook creation and deployment)
- T021-T022 can run in parallel (different test scenarios)

**User Story 2 (T023-T030)**:
- T023-T025 must be sequential (deployment steps)
- T026-T029 can run in parallel (different verification checks)
- T030 must be last (reboot test)

**User Story 3 (T031-T043)**:
- T031-T037 must be sequential (building fail2ban configuration)
- T038-T039 can run in parallel (status checks)
- T040-T043 must be sequential (ban test workflow)

### Parallel Opportunities

**Setup Phase**:
- T003 and T004 can run in parallel (different checks)

**Foundational Phase**:
- T008, T009, T010 can run in parallel (creating different template files)

**Between User Stories** (if team capacity allows):
- After Foundational complete, US1, US2, US3 can all start in parallel
- Different team members can work on different user stories simultaneously

**Within Polish Phase**:
- T044, T045, T046, T047 can all run in parallel (different documentation files)

---

## Parallel Example: User Story 1

```bash
# After T010 (Foundation) completes, User Story 1 tasks proceed:

# T011-T017: Sequential (building single file roles/proxmox/tasks/ssh-hardening.yml)
# These cannot be parallelized as they build the same file

# T018-T020: Sequential (playbook and deployment)
# Must happen in order

# T021-T022: Can be parallelized (different test scenarios)
Task: "Test SSH connection from internal network with password auth"
Task: "Test SSH connection from internal network with SSH key auth"
```

---

## Parallel Example: Multiple User Stories

```bash
# After Foundational (T006-T010) completes:

# If you have 3 team members, they can work in parallel:
Team Member A: User Story 1 (T011-T022) - SSH Hardening
Team Member B: User Story 2 (T023-T030) - Firewall Forwarding
Team Member C: User Story 3 (T031-T043) - Fail2ban Security

# Each story is independently completable and testable
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T010) - CRITICAL
3. Complete Phase 3: User Story 1 (T011-T022)
4. **STOP and VALIDATE**: Test internal SSH access with hardened config
5. This gives you hardened SSH but no external access yet

### Recommended Incremental Delivery

1. **Setup + Foundation** (T001-T010) → Configuration templates ready
2. **Add User Story 1** (T011-T022) → SSH hardened, internal access verified
3. **Add User Story 2** (T023-T030) → External access functional via viljo.se
4. **Add User Story 3** (T031-T043) → Brute force protection active
5. **Polish** (T044-T054) → Production-ready with docs and validation

### Minimal Viable Feature

For quickest external SSH access:

1. Complete Setup (T001-T005)
2. Complete Foundational (T006-T010)
3. Complete US1 (T011-T022) + US2 (T023-T030)
4. **STOP** - You now have working external SSH access
5. Add US3 later when you want fail2ban protection

---

## Notes

- [P] tasks = different files, no dependencies, can run concurrently
- [Story] label maps task to specific user story (US1, US2, US3)
- Each user story should be independently completable and testable
- Commit after each task or logical group of related tasks
- Stop at any checkpoint to validate story independently
- All secrets (SSH keys, Loopia credentials) must be stored in Ansible Vault
- Follow quickstart.md for detailed step-by-step validation procedures
- Verify idempotency: all Ansible tasks should be safely re-runnable
- DNS is already configured via existing loopia_ddns infrastructure
- Firewall nftables template already supports port forwarding via firewall_forward_services

## Task Summary

**Total Tasks**: 54
- **Phase 1 (Setup)**: 5 tasks
- **Phase 2 (Foundational)**: 5 tasks
- **Phase 3 (US1 - SSH Hardening)**: 12 tasks
- **Phase 4 (US2 - Firewall Forwarding)**: 8 tasks
- **Phase 5 (US3 - Fail2ban Security)**: 13 tasks
- **Phase 6 (Polish)**: 11 tasks

**Parallel Opportunities**:
- 8 tasks marked [P] can run in parallel within their phases
- 3 user stories can be developed in parallel after Foundational phase
- Estimated time savings: 30-40% if parallelized effectively

**MVP Scope** (Minimal external SSH access):
- Phases 1-4: Tasks T001-T030 (33 tasks)
- Skip fail2ban (US3) and polish for fastest deployment
- Add US3 and polish incrementally after validating external access

**Full Feature Scope** (Production-ready with security):
- All phases: Tasks T001-T054 (54 tasks)
- Includes hardening, forwarding, fail2ban, docs, and validation
- Recommended for production deployment
