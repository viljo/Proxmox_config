# Tasks: WireGuard VPN Server

**Input**: Design documents from `/specs/006-wireguard-vpn/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/wireguard-config-schema.yml

**Tests**: Tests are not explicitly requested in the specification, so test tasks are omitted. Manual testing procedures are documented in quickstart.md.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions
- **Ansible roles**: `roles/wireguard/` for WireGuard-specific tasks
- **Playbooks**: `playbooks/` for deployment orchestration
- **Configuration**: `inventory/group_vars/all/` for WireGuard variables
- **Documentation**: `docs/` for architecture and operations guides

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and deployment structure

- [ ] T001 Create main deployment playbook in playbooks/wireguard-deploy.yml
- [ ] T002 [P] Create teardown playbook in playbooks/wireguard-teardown.yml
- [ ] T003 [P] Initialize documentation directory structure in docs/wireguard/
- [ ] T004 [P] Configure ansible-lint rules in .ansible-lint for WireGuard role
- [ ] T005 [P] Configure yamllint rules in .yamllint for WireGuard configuration files

**Checkpoint**: Basic project structure is ready for implementation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create NetBox integration tasks in roles/wireguard/tasks/netbox.yml
- [ ] T007 [P] Create Zabbix monitoring templates in roles/wireguard/tasks/zabbix.yml
- [ ] T008 [P] Create PBS backup configuration tasks in roles/wireguard/tasks/backup.yml
- [ ] T009 [P] Create GitLab CI pipeline configuration in .gitlab-ci.yml for WireGuard role
- [ ] T010 [P] Create role metadata file in roles/wireguard/meta/main.yml
- [ ] T011 Update main task file to include new integrations in roles/wireguard/tasks/main.yml
- [ ] T012 [P] Complete role documentation in roles/wireguard/README.md
- [ ] T013 [P] Create architecture documentation in docs/wireguard/architecture.md

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Secure Remote Access to Infrastructure (Priority: P1) 🎯 MVP

**Goal**: Deploy WireGuard VPN server that allows a single peer to securely connect and access the management network (192.168.0.0/16)

**Independent Test**: Install WireGuard client, import configuration, connect to VPN, verify ability to ping management network IPs (192.168.0.0/16) and verify connection latency <10ms

### Implementation for User Story 1

- [ ] T014 [P] [US1] Add server key generation documentation to roles/wireguard/README.md
- [ ] T015 [P] [US1] Create example vault configuration in inventory/group_vars/all/main.yml.example with wireguard variables
- [ ] T016 [US1] Enhance WireGuard configuration template with PostUp/PostDown rules in roles/wireguard/templates/wg0.conf.j2
- [ ] T017 [US1] Add IP forwarding configuration task in roles/wireguard/tasks/main.yml
- [ ] T018 [US1] Add configuration file validation task in roles/wireguard/tasks/main.yml using wg-quick strip command
- [ ] T019 [US1] Create restart handler for WireGuard service in roles/wireguard/handlers/main.yml
- [ ] T020 [US1] Add firewall configuration task for UDP port 51820 in roles/wireguard/tasks/main.yml
- [ ] T021 [US1] Add routing configuration for management network (192.168.0.0/16) in roles/wireguard/tasks/main.yml
- [ ] T022 [US1] Create peer onboarding documentation in docs/wireguard/peer-onboarding.md
- [ ] T023 [US1] Add connection verification steps to quickstart.md validation section

**Checkpoint**: At this point, User Story 1 should be fully functional - single peer can connect, access management network, and verify <5s connection time

---

## Phase 4: User Story 2 - Multi-Peer VPN Network (Priority: P2)

**Goal**: Support multiple concurrent peers with individualized access policies and IP allocations

**Independent Test**: Configure two different peers with separate allowed IPs (10.8.0.2/32 and 10.8.0.3/32), verify both can connect simultaneously, check no IP conflicts with `wg show`

### Implementation for User Story 2

- [ ] T024 [P] [US2] Create peer management playbook in playbooks/wireguard-peer-add.yml
- [ ] T025 [P] [US2] Create peer removal playbook in playbooks/wireguard-peer-remove.yml
- [ ] T026 [US2] Add peer IP allocation tracking in inventory/group_vars/all/wireguard.yml with documentation
- [ ] T027 [US2] Create peer validation task to check for duplicate public keys in roles/wireguard/tasks/validate-peers.yml
- [ ] T028 [US2] Create peer validation task to check for overlapping allowed_ips in roles/wireguard/tasks/validate-peers.yml
- [ ] T029 [US2] Add split tunneling configuration examples in roles/wireguard/templates/wg0.conf.j2 comments
- [ ] T030 [US2] Create QR code generation task for mobile clients in roles/wireguard/tasks/qrcode.yml
- [ ] T031 [US2] Add peer management documentation in docs/wireguard/peer-management.md
- [ ] T032 [US2] Update quickstart.md with multi-peer deployment examples

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - multiple peers can connect simultaneously without conflicts, each with unique IP allocation

---

## Phase 5: User Story 3 - Persistent VPN Service (Priority: P3)

**Goal**: Ensure VPN service starts automatically on boot and maintains stable connections through network disruptions

**Independent Test**: Reboot Proxmox host, verify WireGuard LXC container and service start automatically within 60 seconds, peers reconnect automatically

### Implementation for User Story 3

- [ ] T033 [P] [US3] Add container auto-start configuration (onboot=1) in roles/wireguard/tasks/main.yml
- [ ] T034 [P] [US3] Add systemd service enable task in roles/wireguard/tasks/main.yml
- [ ] T035 [US3] Create systemd service restart policy configuration in roles/wireguard/templates/wg-quick-override.conf.j2
- [ ] T036 [US3] Add service status check task in roles/wireguard/tasks/main.yml
- [ ] T037 [US3] Create connection keepalive monitoring in roles/wireguard/tasks/monitoring.yml
- [ ] T038 [US3] Add persistent keepalive configuration validation in roles/wireguard/tasks/validate-peers.yml
- [ ] T039 [US3] Create service recovery documentation in docs/wireguard/troubleshooting.md
- [ ] T040 [US3] Add auto-start verification to quickstart.md test procedures

**Checkpoint**: All user stories should now be independently functional - service auto-starts, connections persist, monitoring tracks uptime

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and finalize production readiness

- [ ] T041 [P] Create network topology diagram in docs/wireguard/network-diagram.md
- [ ] T042 [P] Add security hardening checklist in docs/wireguard/security.md
- [ ] T043 [P] Create backup and recovery procedures documentation in docs/wireguard/backup-recovery.md
- [ ] T044 [P] Add performance tuning guidance in docs/wireguard/performance.md
- [ ] T045 [P] Create Molecule test framework setup in roles/wireguard/molecule/default/molecule.yml
- [ ] T046 [P] Create Molecule converge playbook in roles/wireguard/molecule/default/converge.yml
- [ ] T047 [P] Create Molecule verification tests in roles/wireguard/molecule/default/verify.yml
- [ ] T048 Add log rotation configuration for WireGuard logs in roles/wireguard/tasks/logging.yml
- [ ] T049 Create operational runbook in docs/wireguard/runbook.md
- [ ] T050 Validate all quickstart.md procedures end-to-end

**Checkpoint**: Production-ready WireGuard VPN deployment with complete documentation, testing, and operational procedures

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Builds on US1 peer configuration but independently testable with 2+ peers
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Enhances US1/US2 reliability but independently testable via reboot test

### Within Each User Story

- Configuration templates before task implementations
- Validation tasks before handlers
- Core implementation before documentation
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (different files)
- All Foundational tasks marked [P] can run in parallel within Phase 2 (different files, no dependencies)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- Models/templates within a story marked [P] can run in parallel
- Documentation tasks in Polish phase marked [P] can run in parallel

---

## Parallel Example: Phase 2 (Foundational)

```bash
# After T006 completes, launch all [P] tasks together:
Task T007: "Create Zabbix monitoring templates in roles/wireguard/tasks/zabbix.yml"
Task T008: "Create PBS backup configuration tasks in roles/wireguard/tasks/backup.yml"
Task T009: "Create GitLab CI pipeline configuration in .gitlab-ci.yml"
Task T010: "Create role metadata file in roles/wireguard/meta/main.yml"
Task T012: "Complete role documentation in roles/wireguard/README.md"
Task T013: "Create architecture documentation in docs/wireguard/architecture.md"
```

---

## Parallel Example: User Story 1

```bash
# Launch documentation and examples together:
Task T014: "Add server key generation documentation to roles/wireguard/README.md"
Task T015: "Create example vault configuration in inventory/group_vars/all/main.yml.example"
```

---

## Parallel Example: User Story 2

```bash
# Launch peer management playbooks together:
Task T024: "Create peer management playbook in playbooks/wireguard-peer-add.yml"
Task T025: "Create peer removal playbook in playbooks/wireguard-peer-remove.yml"
```

---

## Parallel Example: User Story 3

```bash
# Launch auto-start configuration together:
Task T033: "Add container auto-start configuration in roles/wireguard/tasks/main.yml"
Task T034: "Add systemd service enable task in roles/wireguard/tasks/main.yml"
```

---

## Parallel Example: Polish Phase

```bash
# Launch all documentation tasks together:
Task T041: "Create network topology diagram in docs/wireguard/network-diagram.md"
Task T042: "Add security hardening checklist in docs/wireguard/security.md"
Task T043: "Create backup and recovery procedures in docs/wireguard/backup-recovery.md"
Task T044: "Add performance tuning guidance in docs/wireguard/performance.md"
Task T045: "Create Molecule test framework in roles/wireguard/molecule/default/molecule.yml"
Task T046: "Create Molecule converge playbook in roles/wireguard/molecule/default/converge.yml"
Task T047: "Create Molecule verification tests in roles/wireguard/molecule/default/verify.yml"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005) → ~30 minutes
2. Complete Phase 2: Foundational (T006-T013) → ~2-3 hours (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (T014-T023) → ~2-3 hours
4. **STOP and VALIDATE**: Test single peer connection, verify <5s connection time, confirm management network access
5. Deploy/demo if ready (MVP complete!)

**Total MVP Time**: ~5-7 hours

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (~3.5 hours)
2. Add User Story 1 → Test independently → Deploy/Demo (MVP! Single peer VPN working)
3. Add User Story 2 → Test independently with 2+ peers → Deploy/Demo (Multi-peer support)
4. Add User Story 3 → Test with reboot → Deploy/Demo (Production-grade reliability)
5. Polish Phase → Final hardening and documentation
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (~3.5 hours)
2. Once Foundational is done:
   - Developer A: User Story 1 (T014-T023) → Core VPN functionality
   - Developer B: User Story 2 (T024-T032) → Multi-peer management (can start in parallel!)
   - Developer C: User Story 3 (T033-T040) → Reliability features (can start in parallel!)
3. Stories complete and integrate independently
4. Team reconvenes for Polish phase (T041-T050)

**Note**: US2 and US3 both build on the existing role but can be developed in parallel since they modify different aspects (peer management vs. service reliability)

---

## Success Criteria Mapping

Each user story maps to specific success criteria from spec.md:

### User Story 1 (P1) Success Criteria
- ✅ **SC-001**: VPN connection within 5 seconds (verify in T023)
- ✅ **SC-007**: Latency overhead <10ms (verify in T023)
- ✅ **SC-008**: 95% first-try connection success (track in T023)

### User Story 2 (P2) Success Criteria
- ✅ **SC-003**: Support 20+ concurrent peers (verify in T032)
- ✅ **SC-005**: Peer config changes <2 minutes (verify in T032)
- ✅ **SC-006**: Peer onboarding <10 minutes (verify in T032)

### User Story 3 (P3) Success Criteria
- ✅ **SC-002**: 99.5% uptime (monitor via T037)
- ✅ **SC-004**: 100+ Mbps throughput (verify in T040)

---

## Notes

- [P] tasks = different files, no dependencies → can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Existing role (roles/wireguard/) provides foundation, tasks enhance it
- Commit after each task or logical group for version control
- Stop at any checkpoint to validate story independently
- Manual testing procedures in quickstart.md (no automated tests requested)
- NetBox/Zabbix/PBS integrations are foundational (required by constitution)
- DMZ (172.16.10.0/24) explicitly excluded from VPN routing per spec clarification
- Management network (192.168.0.0/16) is ONLY routable network via VPN

---

## Task Count Summary

- **Phase 1 (Setup)**: 5 tasks
- **Phase 2 (Foundational)**: 8 tasks (BLOCKS all user stories)
- **Phase 3 (User Story 1 - P1)**: 10 tasks 🎯 MVP
- **Phase 4 (User Story 2 - P2)**: 9 tasks
- **Phase 5 (User Story 3 - P3)**: 8 tasks
- **Phase 6 (Polish)**: 10 tasks

**Total**: 50 tasks

**Parallel Opportunities**: 23 tasks marked [P] (46% can run in parallel within their phase)

**Suggested MVP Scope**: Phase 1 + Phase 2 + Phase 3 (23 tasks, ~5-7 hours)
