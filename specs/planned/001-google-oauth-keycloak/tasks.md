# Tasks: Google OAuth Integration with Keycloak

**Input**: Design documents from `/specs/planned/001-google-oauth-keycloak/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Tests**: Not explicitly requested in specification - implementation tasks only

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Technical dependencies are reflected in phase ordering.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4, US5)
- All tasks include exact file paths

## Path Conventions (Ansible Project)
- **Ansible roles**: `roles/<service>/tasks/`, `roles/<service>/templates/`
- **Playbooks**: `playbooks/` for orchestration
- **Configuration**: `inventory/group_vars/all/`
- **Scripts**: `scripts/` for utilities
- **Documentation**: `docs/deployment/`, `docs/operations/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and secrets management

- [ ] T001 Add Google OAuth client credentials to Ansible Vault in inventory/group_vars/all/secrets.yml
- [ ] T002 [P] Add OIDC client secrets for all services (GitLab, Nextcloud, Grafana, Mattermost, NetBox, Zabbix) to Ansible Vault in inventory/group_vars/all/secrets.yml
- [ ] T003 [P] Define Keycloak configuration variables in inventory/group_vars/all/main.yml
- [ ] T004 [P] Create main orchestration playbook playbooks/google-oauth-rollout.yml

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Keycloak infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T005 Create Keycloak realm configuration task in roles/keycloak/tasks/realm.yml
- [ ] T006 [P] Create Keycloak installation task in roles/keycloak/tasks/install.yml (if not already installed)
- [ ] T007 [P] Create realm configuration template in roles/keycloak/templates/realm-export.json.j2
- [ ] T008 Implement idempotent realm creation with token lifetime and session settings in roles/keycloak/tasks/realm.yml
- [ ] T009 [P] Configure Keycloak PostgreSQL database connection in roles/keycloak/templates/standalone.xml.j2
- [ ] T010 [P] Implement Keycloak service restart handler in roles/keycloak/handlers/main.yml
- [ ] T011 Create Keycloak setup playbook in playbooks/keycloak-setup.yml
- [ ] T012 [P] Update NetBox to document Keycloak as authoritative identity source
- [ ] T013 [P] Create Zabbix monitoring template for Keycloak service health

**Checkpoint**: Keycloak infrastructure ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Google Sign-In for End Users (Priority: P1) 🎯

**Goal**: Enable users to authenticate using Google accounts through Keycloak

**Independent Test**: User with Google account can log into GitLab by clicking "Sign in with Google", authenticating with Google, and accessing their dashboard without creating a GitLab password

### Implementation for User Story 1

- [ ] T014 [P] [US1] Create Google Identity Provider configuration task in roles/keycloak/tasks/google_idp.yml
- [ ] T015 [P] [US1] Create Google IdP configuration template using contracts/keycloak-google-idp.json as reference in roles/keycloak/templates/google-idp-config.json.j2
- [ ] T016 [US1] Implement Google IdP registration via Keycloak REST API in roles/keycloak/tasks/google_idp.yml
- [ ] T017 [US1] Configure Google OAuth scopes (openid, profile, email) and token validation in roles/keycloak/tasks/google_idp.yml
- [ ] T018 [US1] Set up automatic user account creation on first Google authentication in roles/keycloak/tasks/google_idp.yml
- [ ] T019 [US1] Configure Google attribute mappers (username from email, firstName, lastName, email) in roles/keycloak/tasks/google_idp.yml
- [ ] T020 [US1] Implement idempotency checks for Google IdP configuration (skip if already exists) in roles/keycloak/tasks/google_idp.yml
- [ ] T021 [US1] Add Google IdP tasks to main Keycloak role in roles/keycloak/tasks/main.yml
- [ ] T022 [US1] Add Zabbix monitoring for Google OAuth endpoint availability

**Checkpoint**: Google authentication configured in Keycloak - ready to integrate with services

---

## Phase 4: User Story 3 - Automatic LDAP Synchronization (Priority: P3)

**Goal**: Automatically synchronize Keycloak user accounts to OpenLDAP for legacy service compatibility

**Independent Test**: New user signs in with Google, then their account appears in LDAP with correct attributes (email, username, groups) within 5 minutes

**Note**: Implemented before US2 because LDAP sync is foundational infrastructure needed for the entire migration

### Implementation for User Story 3

- [ ] T023 [P] [US3] Create LDAP sync script using contracts/ldap-sync-mapping.json as reference in roles/ldap/files/keycloak-ldap-sync.py
- [ ] T024 [P] [US3] Implement Keycloak REST API client for fetching users in roles/ldap/files/keycloak-ldap-sync.py
- [ ] T025 [P] [US3] Implement LDAP connection and authentication in roles/ldap/files/keycloak-ldap-sync.py
- [ ] T026 [US3] Implement user attribute mapping (username→uid, email→mail, firstName→givenName, lastName→sn) in roles/ldap/files/keycloak-ldap-sync.py
- [ ] T027 [US3] Implement uidNumber and gidNumber generation using LDAP counter objects in roles/ldap/files/keycloak-ldap-sync.py
- [ ] T028 [US3] Implement posixAccount creation with homeDirectory and loginShell in roles/ldap/files/keycloak-ldap-sync.py
- [ ] T029 [US3] Implement group membership synchronization to posixGroup in roles/ldap/files/keycloak-ldap-sync.py
- [ ] T030 [US3] Implement account status sync (enabled/disabled) in roles/ldap/files/keycloak-ldap-sync.py
- [ ] T031 [US3] Implement error handling and retry logic with exponential backoff in roles/ldap/files/keycloak-ldap-sync.py
- [ ] T032 [US3] Create systemd service file for sync script in roles/ldap/templates/keycloak-ldap-sync.service.j2
- [ ] T033 [US3] Create systemd timer for 15-minute sync interval in roles/ldap/templates/keycloak-ldap-sync.timer.j2
- [ ] T034 [US3] Create LDAP sync configuration task in roles/ldap/tasks/sync.yml
- [ ] T035 [US3] Deploy sync script and systemd units in roles/ldap/tasks/sync.yml
- [ ] T036 [US3] Create LDAP service account with write permissions to ou=users in roles/ldap/tasks/sync_user.yml
- [ ] T037 [US3] Configure LDAP ACLs to allow sync user write access in roles/ldap/templates/acl.ldif.j2
- [ ] T038 [US3] Create LDAP counter objects for uidNumber allocation in roles/ldap/tasks/sync.yml
- [ ] T039 [US3] Enable and start systemd timer in roles/ldap/tasks/sync.yml
- [ ] T040 [P] [US3] Create LDAP sync verification script in scripts/verify-ldap-sync.sh
- [ ] T041 [P] [US3] Add Zabbix monitoring for LDAP sync status and last successful run
- [ ] T042 [P] [US3] Document LDAP sync troubleshooting in docs/operations/ldap-sync-troubleshooting.md

**Checkpoint**: LDAP sync operational - new Google users automatically appear in LDAP

---

## Phase 5: User Story 4 - Service OIDC Integration (Priority: P4)

**Goal**: Configure infrastructure services to authenticate via Keycloak OIDC

**Independent Test**: Grafana configured with Keycloak OIDC - user logs in via Google, lands in Grafana with proper permissions

### Implementation for User Story 4

**OIDC Client Registration (Foundation for all services):**

- [ ] T043 [P] [US4] Create OIDC client registration task in roles/keycloak/tasks/oidc_clients.yml
- [ ] T044 [P] [US4] Create OIDC client template using contracts/oidc-client-template.json in roles/keycloak/templates/oidc-client-template.json.j2
- [ ] T045 [US4] Implement OIDC client registration for all services (GitLab, Nextcloud, Grafana, Mattermost, NetBox) via Keycloak REST API in roles/keycloak/tasks/oidc_clients.yml
- [ ] T046 [US4] Configure OIDC client redirect URIs for each service in roles/keycloak/tasks/oidc_clients.yml
- [ ] T047 [US4] Configure OIDC client scopes (openid, profile, email, roles, groups) in roles/keycloak/tasks/oidc_clients.yml
- [ ] T048 [US4] Generate secure client secrets and store in Ansible Vault references in roles/keycloak/tasks/oidc_clients.yml
- [ ] T049 [US4] Add OIDC client registration to main Keycloak role in roles/keycloak/tasks/main.yml

**GitLab OIDC Configuration:**

- [ ] T050 [P] [US4] Create GitLab OIDC configuration task in roles/gitlab/tasks/oidc_config.yml
- [ ] T051 [P] [US4] Create GitLab OIDC configuration template using contracts/service-oidc-configs/gitlab-oidc.rb in roles/gitlab/templates/gitlab.rb.j2 (add OmniAuth section)
- [ ] T052 [US4] Configure GitLab OmniAuth with Keycloak issuer URL and discovery in roles/gitlab/tasks/oidc_config.yml
- [ ] T053 [US4] Configure GitLab OIDC client ID and secret from Ansible Vault in roles/gitlab/tasks/oidc_config.yml
- [ ] T054 [US4] Enable GitLab external authentication and disable sign-up in roles/gitlab/tasks/oidc_config.yml
- [ ] T055 [US4] Add GitLab reconfigure handler to apply changes in roles/gitlab/handlers/main.yml

**Nextcloud OIDC Configuration:**

- [ ] T056 [P] [US4] Create Nextcloud OIDC configuration task in roles/nextcloud/tasks/oidc_config.yml
- [ ] T057 [P] [US4] Install Nextcloud user_oidc app via occ command in roles/nextcloud/tasks/oidc_config.yml
- [ ] T058 [P] [US4] Create Nextcloud OIDC configuration template using contracts/service-oidc-configs/nextcloud-oidc.php in roles/nextcloud/templates/config.php.j2 (add OIDC section)
- [ ] T059 [US4] Configure Nextcloud OIDC provider URL and client credentials in roles/nextcloud/tasks/oidc_config.yml
- [ ] T060 [US4] Configure Nextcloud OIDC attribute mapping (username, email, groups) in roles/nextcloud/tasks/oidc_config.yml
- [ ] T061 [US4] Enable auto-provisioning for new users in Nextcloud OIDC config in roles/nextcloud/tasks/oidc_config.yml

**Grafana OIDC Configuration:**

- [ ] T062 [P] [US4] Create Grafana OIDC configuration task in roles/grafana/tasks/oidc_config.yml
- [ ] T063 [P] [US4] Create Grafana OIDC configuration template using contracts/service-oidc-configs/grafana-oidc.ini in roles/grafana/templates/grafana.ini.j2 (add auth.generic_oauth section)
- [ ] T064 [US4] Configure Grafana generic OAuth with Keycloak endpoints in roles/grafana/tasks/oidc_config.yml
- [ ] T065 [US4] Configure Grafana OIDC scopes and role attribute path in roles/grafana/tasks/oidc_config.yml
- [ ] T066 [US4] Configure Grafana role mapping (grafana-admin → Admin, default → Viewer) in roles/grafana/tasks/oidc_config.yml
- [ ] T067 [US4] Add Grafana service restart handler in roles/grafana/handlers/main.yml

**Mattermost OIDC Configuration:**

- [ ] T068 [P] [US4] Create Mattermost OIDC configuration task in roles/mattermost/tasks/oidc_config.yml
- [ ] T069 [P] [US4] Create Mattermost OIDC configuration template in roles/mattermost/templates/config.json.j2 (add GitLab OAuth section as workaround)
- [ ] T070 [US4] Configure Mattermost to use GitLab OAuth provider pointing to Keycloak in roles/mattermost/tasks/oidc_config.yml
- [ ] T071 [US4] Add mattermostId custom attribute to Keycloak user schema in roles/keycloak/tasks/oidc_clients.yml
- [ ] T072 [US4] Configure Mattermost attribute mapping for GitLab provider workaround in roles/mattermost/tasks/oidc_config.yml

**NetBox OIDC Configuration:**

- [ ] T073 [P] [US4] Create NetBox OIDC configuration task in roles/netbox/tasks/oidc_config.yml
- [ ] T074 [P] [US4] Create NetBox OIDC configuration template in roles/netbox/templates/configuration.py.j2 (add REMOTE_AUTH section)
- [ ] T075 [US4] Configure NetBox python-social-auth with Keycloak OIDC backend in roles/netbox/tasks/oidc_config.yml
- [ ] T076 [US4] Configure NetBox OIDC pipeline for group synchronization in roles/netbox/tasks/oidc_config.yml
- [ ] T077 [US4] Configure NetBox permissions and auto-provisioning in roles/netbox/tasks/oidc_config.yml

**Zabbix SAML Configuration:**

- [ ] T078 [P] [US4] Create Zabbix SAML configuration task in roles/zabbix/tasks/saml_config.yml
- [ ] T079 [P] [US4] Configure Keycloak SAML client for Zabbix in roles/keycloak/tasks/saml_clients.yml
- [ ] T080 [US4] Document Zabbix web UI SAML configuration steps in docs/deployment/zabbix-saml-setup.md
- [ ] T081 [US4] Create Zabbix SAML attribute mapping configuration guide in docs/deployment/zabbix-saml-setup.md

**Service Integration Orchestration:**

- [ ] T082 [US4] Create service OIDC integration playbook in playbooks/service-oidc-integration.yml
- [ ] T083 [US4] Add all service OIDC configuration tasks to integration playbook in playbooks/service-oidc-integration.yml
- [ ] T084 [P] [US4] Create integration test script for SSO across services in scripts/test-authentication.sh
- [ ] T085 [P] [US4] Create SSO verification playbook in playbooks/verify-sso.yml
- [ ] T086 [P] [US4] Document service OIDC configuration in docs/deployment/google-oauth-deployment.md

**Checkpoint**: All services configured for Keycloak OIDC - users can authenticate via Google across all infrastructure

---

## Phase 6: User Story 5 - Traefik Forward Auth for Custom Websites (Priority: P5)

**Goal**: Protect custom websites and services without native OIDC using Traefik forward authentication

**Independent Test**: Static website deployed behind Traefik with forward auth - unauthenticated user redirected to Keycloak, authenticates with Google, gains access to website

### Implementation for User Story 5

**OAuth2 Proxy Deployment:**

- [ ] T087 [P] [US5] Create OAuth2 Proxy LXC container configuration in roles/oauth2_proxy/tasks/lxc.yml
- [ ] T088 [P] [US5] Create OAuth2 Proxy installation task in roles/oauth2_proxy/tasks/install.yml
- [ ] T089 [P] [US5] Create OAuth2 Proxy configuration template in roles/oauth2_proxy/templates/oauth2-proxy.cfg.j2
- [ ] T090 [US5] Configure OAuth2 Proxy with Keycloak OIDC provider in roles/oauth2_proxy/tasks/configure.yml
- [ ] T091 [US5] Configure OAuth2 Proxy client ID and secret from Ansible Vault in roles/oauth2_proxy/tasks/configure.yml
- [ ] T092 [US5] Configure OAuth2 Proxy cookie settings (secret, domain, expiration) in roles/oauth2_proxy/tasks/configure.yml
- [ ] T093 [US5] Configure OAuth2 Proxy upstreams and allowed groups in roles/oauth2_proxy/tasks/configure.yml
- [ ] T094 [US5] Create OAuth2 Proxy systemd service in roles/oauth2_proxy/templates/oauth2-proxy.service.j2
- [ ] T095 [US5] Enable and start OAuth2 Proxy service in roles/oauth2_proxy/tasks/configure.yml

**Traefik Forward Auth Configuration:**

- [ ] T096 [P] [US5] Create Traefik forward auth middleware configuration task in roles/traefik/tasks/forwardauth.yml
- [ ] T097 [P] [US5] Create Traefik middleware configuration template using contracts/traefik-forwardauth-config.yml in roles/traefik/templates/middleware-forwardauth.yml.j2
- [ ] T098 [US5] Configure Traefik forwardAuth middleware pointing to OAuth2 Proxy in roles/traefik/tasks/forwardauth.yml
- [ ] T099 [US5] Configure Traefik to inject authentication headers (X-Auth-Request-User, X-Auth-Request-Email, X-Auth-Request-Groups) in roles/traefik/tasks/forwardauth.yml
- [ ] T100 [US5] Create Traefik dynamic configuration for protected routes in roles/traefik/templates/dynamic-config.yml.j2
- [ ] T101 [US5] Update Traefik routing rules to apply forward auth middleware to custom services in roles/traefik/tasks/routes.yml
- [ ] T102 [US5] Add Traefik configuration reload handler in roles/traefik/handlers/main.yml

**Testing and Documentation:**

- [ ] T103 [P] [US5] Create demo protected static website for testing in roles/demo_site/files/index.html
- [ ] T104 [P] [US5] Deploy demo site with Traefik forward auth middleware in roles/demo_site/tasks/main.yml
- [ ] T105 [P] [US5] Create forward auth verification script in scripts/test-forward-auth.sh
- [ ] T106 [P] [US5] Document Traefik forward auth configuration in docs/deployment/traefik-forward-auth.md
- [ ] T107 [P] [US5] Add Zabbix monitoring for OAuth2 Proxy service health

**Checkpoint**: Traefik forward auth operational - custom services protected with Google authentication

---

## Phase 7: User Story 2 - Legacy LDAP User Migration (Priority: P2)

**Goal**: Enable existing LDAP users to continue authenticating and provide account linking tools

**Independent Test**: Existing LDAP user logs into GitLab using traditional username/password successfully

**Note**: Implemented last because existing LDAP authentication is already working and requires no changes - this phase adds optional migration tools

### Implementation for User Story 2

**Account Linking Utilities:**

- [ ] T108 [P] [US2] Create account linking utility script in scripts/link-ldap-account.sh
- [ ] T109 [P] [US2] Implement email-based account detection (find Keycloak and LDAP accounts with matching email) in scripts/link-ldap-account.sh
- [ ] T110 [US2] Implement Keycloak account federation linking via REST API in scripts/link-ldap-account.sh
- [ ] T111 [US2] Implement confirmation workflow for manual account linking in scripts/link-ldap-account.sh
- [ ] T112 [US2] Add logging and audit trail for account linking operations in scripts/link-ldap-account.sh

**LDAP Fallback Configuration:**

- [ ] T113 [P] [US2] Verify GitLab maintains LDAP authentication alongside OIDC in roles/gitlab/tasks/oidc_config.yml
- [ ] T114 [P] [US2] Verify Nextcloud maintains LDAP authentication alongside OIDC in roles/nextcloud/tasks/oidc_config.yml
- [ ] T115 [P] [US2] Verify Grafana maintains LDAP authentication alongside OIDC in roles/grafana/tasks/oidc_config.yml
- [ ] T116 [US2] Test dual authentication (OIDC + LDAP) for all services in scripts/test-authentication.sh

**Migration Documentation:**

- [ ] T117 [P] [US2] Create account linking procedure guide in docs/operations/account-linking.md
- [ ] T118 [P] [US2] Create user migration communication template in docs/operations/user-migration-guide.md
- [ ] T119 [P] [US2] Document rollback procedure (disable Google IdP, revert to LDAP-only) in docs/operations/rollback-procedure.md
- [ ] T120 [P] [US2] Create LDAP user migration checklist in docs/operations/migration-checklist.md

**Checkpoint**: Existing LDAP users verified working - migration tools available

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements, documentation, and validation

- [ ] T121 [P] Update main orchestration playbook playbooks/google-oauth-rollout.yml to call all sub-playbooks in correct order
- [ ] T122 [P] Add pre-flight checks to verify Google OAuth credentials before deployment in playbooks/google-oauth-rollout.yml
- [ ] T123 [P] Add post-deployment validation tasks in playbooks/google-oauth-rollout.yml
- [ ] T124 [P] Create deployment guide following quickstart.md structure in docs/deployment/google-oauth-deployment.md
- [ ] T125 [P] Document troubleshooting common Google OAuth issues in docs/operations/google-oauth-troubleshooting.md
- [ ] T126 [P] Document Keycloak backup and restore procedures in docs/operations/keycloak-backup-restore.md
- [ ] T127 [P] Create Zabbix dashboard for authentication system monitoring
- [ ] T128 [P] Verify all secrets are in Ansible Vault with secret scanning script
- [ ] T129 [P] Update NetBox documentation to reflect new authentication architecture
- [ ] T130 [P] Run complete integration test following quickstart.md validation steps in scripts/test-authentication.sh
- [ ] T131 [P] Measure and document authentication performance (login time, sync time) in docs/operations/performance-metrics.md
- [ ] T132 Update main README.md with Google OAuth architecture overview
- [ ] T133 [P] Create GitLab CI pipeline for testing Ansible playbooks in .gitlab-ci.yml
- [ ] T134 Run ansible-lint and yamllint on all modified roles and playbooks
- [ ] T135 Generate role README files with updated authentication information using scripts/generate_role_readmes.sh

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-7)**: All depend on Foundational phase completion
  - US1 (Google Sign-In): Can start after Foundational
  - US3 (LDAP Sync): Depends on US1 (needs Google IdP for user creation to trigger sync)
  - US4 (Service OIDC): Can start after Foundational (parallel with US1)
  - US5 (Traefik Forward Auth): Depends on US1 (needs OIDC provider working)
  - US2 (LDAP Migration): Can start after US3 (needs sync working to migrate users)
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1 - Google Sign-In)**: Depends on Foundational (Phase 2)
  - T014-T022: Google IdP configuration in Keycloak

- **User Story 3 (P3 - LDAP Sync)**: Depends on US1 completion
  - T023-T042: LDAP sync implementation
  - Rationale: Sync needs Google-authenticated users to exist in Keycloak

- **User Story 4 (P4 - Service OIDC)**: Depends on Foundational (Phase 2)
  - T043-T086: Service OIDC integration
  - Can run in parallel with US1, but requires US1 for end-to-end testing

- **User Story 5 (P5 - Traefik Forward Auth)**: Depends on US1 completion
  - T087-T107: OAuth2 Proxy and Traefik middleware
  - Rationale: Forward auth requires working OIDC provider

- **User Story 2 (P2 - LDAP Migration)**: Depends on US3 completion
  - T108-T120: Account linking tools and migration documentation
  - Rationale: Migration requires LDAP sync to be operational

### Within Each User Story

**User Story 1 (Google Sign-In):**
- Templates (T015) before API calls (T016-T020)
- IdP configuration (T014-T020) before monitoring (T022)
- All tasks sequential except T014-T015 can run in parallel

**User Story 3 (LDAP Sync):**
- Parallel: T023-T025 (sync script), T032-T033 (systemd units), T040-T042 (docs/monitoring)
- Sequential: Script (T026-T031) → LDAP config (T034-T039)
- Service account (T036-T037) before sync deployment (T035)

**User Story 4 (Service OIDC):**
- OIDC client registration (T043-T049) BEFORE any service configuration
- After client registration, all services can be configured in parallel:
  - GitLab: T050-T055 (parallel)
  - Nextcloud: T056-T061 (parallel)
  - Grafana: T062-T067 (parallel)
  - Mattermost: T068-T072 (parallel)
  - NetBox: T073-T077 (parallel)
  - Zabbix: T078-T081 (parallel)
- Orchestration (T082-T086) after all services configured

**User Story 5 (Traefik Forward Auth):**
- Parallel: OAuth2 Proxy setup (T087-T095) and Traefik config (T096-T102)
- Testing (T103-T107) after both deployments complete

**User Story 2 (LDAP Migration):**
- All tasks can run in parallel (T108-T120)
- Mostly documentation and verification, no strict dependencies

### Parallel Opportunities

- **Phase 1 (Setup)**: T002, T003, T004 can run in parallel
- **Phase 2 (Foundational)**: T006-T007, T009-T010, T012-T013 can run in parallel
- **Phase 3 (US1)**: T014-T015 can run in parallel
- **Phase 4 (US3)**: T023-T025, T032-T033, T040-T042 each group can run in parallel
- **Phase 5 (US4)**: After T043-T049, all service configurations (T050-T081) can run in parallel
- **Phase 6 (US5)**: T087-T095 parallel with T096-T102, then T103-T107 in parallel
- **Phase 7 (US2)**: All tasks (T108-T120) can run in parallel
- **Phase 8 (Polish)**: Most tasks can run in parallel (T121-T135)

---

## Parallel Example: User Story 4 (Service OIDC Integration)

```bash
# After OIDC client registration (T043-T049), launch all service configurations in parallel:

# GitLab configuration
Task T050: "Create GitLab OIDC configuration task"
Task T051: "Create GitLab OIDC configuration template"
Task T052-T055: "Configure GitLab OmniAuth and OIDC"

# Nextcloud configuration (parallel)
Task T056: "Create Nextcloud OIDC configuration task"
Task T057: "Install Nextcloud user_oidc app"
Task T058-T061: "Configure Nextcloud OIDC"

# Grafana configuration (parallel)
Task T062: "Create Grafana OIDC configuration task"
Task T063: "Create Grafana OIDC configuration template"
Task T064-T067: "Configure Grafana OAuth"

# Mattermost, NetBox, Zabbix (parallel)
# ... similar parallel execution
```

---

## Implementation Strategy

### MVP First (User Stories 1, 3, 4 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: US1 - Google Sign-In
4. Complete Phase 4: US3 - LDAP Sync
5. Complete Phase 5: US4 - Service OIDC Integration (minimum: GitLab + Grafana)
6. **STOP and VALIDATE**: Test complete authentication flow
   - User signs in with Google to GitLab
   - User account appears in LDAP
   - User can access Grafana with same session (SSO)
7. Deploy/demo MVP

**MVP Delivers**: Google authentication working across key services with LDAP compatibility

### Incremental Delivery

1. **Foundation Ready**: Setup + Foundational → Keycloak operational
2. **MVP** (P1 + P3 + P4 minimal): Google auth + LDAP sync + 2 services → Deploy/Demo
3. **Full Service Integration** (+P4 remaining): All services OIDC-enabled → Deploy/Demo
4. **Custom Services** (+P5): Traefik forward auth → Deploy/Demo
5. **Migration Tools** (+P2): Account linking utilities → Deploy/Demo
6. **Production Ready** (+Polish): Final validation and documentation → Deploy

Each increment adds value without breaking previous functionality.

### Parallel Team Strategy

With multiple developers:

1. **Team completes Setup + Foundational together**
2. **Once Foundational is done, split work:**
   - **Developer A**: US1 (Google Sign-In) + US3 (LDAP Sync) - Core authentication
   - **Developer B**: US4 (Service OIDC) - GitLab, Nextcloud, Grafana
   - **Developer C**: US4 (Service OIDC) - Mattermost, NetBox, Zabbix
   - **Developer D**: US5 (Traefik Forward Auth) + US2 (Migration tools)
3. **Stories complete and integrate independently**
4. **Team completes Polish phase together**

---

## Summary Statistics

- **Total Tasks**: 135 tasks
- **Setup Phase**: 4 tasks
- **Foundational Phase**: 9 tasks (CRITICAL blocking tasks)
- **User Story 1 (Google Sign-In)**: 9 tasks
- **User Story 3 (LDAP Sync)**: 20 tasks
- **User Story 4 (Service OIDC)**: 44 tasks (largest - 6 services)
- **User Story 5 (Traefik Forward Auth)**: 21 tasks
- **User Story 2 (LDAP Migration)**: 13 tasks
- **Polish Phase**: 15 tasks

**Parallelizable Tasks**: 78 tasks marked [P] (58% of total)

**MVP Scope** (US1 + US3 + US4 minimal):
- Setup: 4 tasks
- Foundational: 9 tasks
- US1: 9 tasks
- US3: 20 tasks
- US4: ~30 tasks (client registration + 2-3 services)
- **MVP Total**: ~72 tasks (~53% of project)

**Critical Path** (sequential dependencies):
1. Setup (4 tasks)
2. Foundational (9 tasks)
3. US1 Google IdP (9 tasks)
4. US3 LDAP Sync (20 tasks)
5. US4 OIDC Integration (44 tasks, many parallel)
6. US5 Forward Auth (21 tasks)
7. US2 Migration (13 tasks, many parallel)
8. Polish (15 tasks, many parallel)

**Estimated Implementation Time** (single developer):
- MVP (US1+US3+US4 minimal): 3-4 weeks
- Full implementation (all user stories): 6-8 weeks
- With parallel team (3-4 developers): 3-4 weeks for full implementation

---

## Notes

- [P] tasks can run in parallel (different files, no dependencies)
- [Story] label maps task to specific user story for traceability and independent testing
- Each user story should be independently completable and testable
- Stop at any checkpoint to validate story independently
- Commit after each task or logical group
- Tests were NOT included as they were not explicitly requested in specification
- All file paths follow Ansible project structure from plan.md
- Keycloak REST API tasks require admin credentials from Ansible Vault
- Service configurations require service-specific OIDC client secrets from Ansible Vault
- LDAP sync requires dedicated service account credentials from Ansible Vault

**Critical Success Factors**:
- Complete Foundational phase before starting user stories
- Test Google authentication flow end-to-end after US1
- Verify LDAP sync working before declaring US3 complete
- Test each service OIDC integration independently
- Verify SSO works across multiple services after US4
- Maintain existing LDAP authentication throughout deployment

**Risk Mitigation**:
- Keep LDAP authentication enabled during entire rollout (zero downtime)
- Test rollback procedure before production deployment
- Monitor Keycloak and LDAP sync health continuously
- Document all manual steps (Zabbix SAML config via web UI)
- Validate vault encryption before committing secrets
