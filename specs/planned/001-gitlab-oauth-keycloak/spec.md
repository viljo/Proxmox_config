# Feature Specification: GitLab.com OAuth Integration with Keycloak

**Feature Branch**: `001-gitlab-oauth-keycloak`
**Created**: 2025-10-20
**Updated**: 2025-10-25 (Changed from Google OAuth to GitLab.com OAuth)
**Status**: Draft

## Overview

Integrate GitLab.com as the primary OAuth authentication provider for Keycloak, enabling single sign-on across all infrastructure services. Users authenticate using their GitLab.com accounts, Keycloak acts as the identity broker, and all other services trust Keycloak for authentication.

**Benefits of GitLab.com OAuth over Google:**
- ✅ **Developer-focused**: Users are likely developers with existing GitLab.com accounts
- ✅ **Privacy-conscious**: GitLab has better privacy policies than Google
- ✅ **Free tier**: No cost for OAuth authentication
- ✅ **Good OAuth support**: Mature OAuth 2.0 implementation
- ✅ **Account availability**: Most developers already have GitLab.com accounts

**Architecture:**
```
GitLab.com (External OAuth Provider)
    ↓ (OAuth 2.0 flow - https://gitlab.com)
Keycloak (Identity Broker - CT 151)
    ↓ (OIDC/SAML)
Infrastructure Services (Nextcloud, Mattermost, Grafana, etc.)
    ↓ (One-way sync for legacy)
OpenLDAP (Read-only shadow directory - if deployed)
```

## User Scenarios & Testing *(mandatory)*

### User Story 1 - GitLab.com Sign-In for End Users (Priority: P1)

End users can authenticate to any infrastructure service using their GitLab.com account instead of remembering separate credentials. When visiting any service (Nextcloud, Mattermost, Grafana, etc.), users see a "Sign in with GitLab" option, click it, authenticate with their GitLab.com credentials, and gain immediate access to all services through single sign-on.

**Why this priority**: This is the core value proposition - eliminating password management burden for users while maintaining security through centralized authentication.

**Independent Test**: Can be fully tested by having a user with a GitLab.com account attempt to log into Nextcloud. Success means they click "Sign in with GitLab", authenticate with GitLab.com, and arrive at their Nextcloud dashboard without creating a separate Nextcloud password.

**Acceptance Scenarios**:

1. **Given** a user with a GitLab.com account who has never accessed Nextcloud, **When** they visit Nextcloud and click "Sign in with GitLab", **Then** they are redirected to gitlab.com login, authenticate successfully, grant OAuth permissions, and are redirected back to Nextcloud with an active session.

2. **Given** a user already authenticated to Nextcloud via GitLab.com, **When** they navigate to Mattermost within the same browser session, **Then** they are automatically logged into Mattermost without re-entering credentials (SSO).

3. **Given** a user who previously signed in with GitLab.com, **When** they return to any service after their session expires, **Then** they can click "Sign in with GitLab" and are logged in immediately if still authenticated to GitLab.com, or prompted only for GitLab.com credentials.

4. **Given** a user signed into multiple services via GitLab.com SSO, **When** they log out from one service, **Then** they are logged out from all services (single logout).

---

### User Story 2 - Legacy LDAP User Migration (Priority: P2)

Existing users who currently authenticate via LDAP can continue using their username and password during the transition period. Administrators can optionally link existing LDAP accounts to GitLab.com accounts for gradual migration without disrupting current workflows.

**Why this priority**: Ensures zero downtime and maintains business continuity. Existing users must not lose access during the rollout.

**Independent Test**: Can be fully tested by having an existing LDAP user log into Nextcloud using their traditional username/password. Success means they authenticate successfully and gain access exactly as before.

**Acceptance Scenarios**:

1. **Given** an existing LDAP user with username "jdoe" and password, **When** they visit Nextcloud and enter their LDAP credentials, **Then** they authenticate successfully and access their existing files and data.

2. **Given** an LDAP user who wants to switch to GitLab.com authentication, **When** an administrator links their LDAP account to their GitLab.com account in Keycloak, **Then** the user can authenticate with either LDAP credentials or GitLab.com OAuth, both accessing the same account and data.

3. **Given** multiple services configured for both LDAP and OIDC authentication, **When** an LDAP user logs in with username/password, **Then** all services recognize the same user identity across authentication methods.

---

### User Story 3 - Automatic LDAP Synchronization (Priority: P3)

When users authenticate via GitLab.com OAuth and are created in Keycloak, their user accounts are automatically synchronized to OpenLDAP in read-only mode. This ensures legacy services that only support LDAP (Postfix mail relay, Linux PAM) can access user information without manual account creation.

**Why this priority**: Enables full infrastructure compatibility with legacy authentication. This is P3 because it's only needed once P1 (GitLab.com auth) is working and users are being created.

**Independent Test**: Can be fully tested by having a new user sign in with GitLab.com, then verifying their account appears in LDAP with correct attributes (email, username, groups). Success means a new GitLab.com-authenticated user can immediately send/receive email via Postfix and SSH into systems using PAM.

**Acceptance Scenarios**:

1. **Given** a new user authenticates via GitLab.com OAuth for the first time, **When** Keycloak creates their user profile, **Then** their account is automatically created in OpenLDAP with username from GitLab.com, basic attributes populated, and assigned to default user groups.

2. **Given** a user changes their display name or profile information on GitLab.com, **When** they next authenticate to Keycloak, **Then** Keycloak updates the user profile and synchronizes changes to LDAP within 5 minutes.

3. **Given** an administrator disables a user account in Keycloak, **When** the sync process runs, **Then** the corresponding LDAP account is marked as disabled and the user cannot authenticate via LDAP-dependent services.

4. **Given** LDAP is temporarily unavailable, **When** users authenticate via GitLab.com OAuth, **Then** authentication succeeds through Keycloak and OIDC-enabled services remain accessible, with LDAP sync queued for retry.

---

### User Story 4 - Service OIDC Integration (Priority: P4)

Infrastructure administrators can configure each service (Nextcloud, Mattermost, Grafana, NetBox, etc.) to authenticate users via Keycloak OIDC instead of direct LDAP binding. Each service receives standardized OIDC tokens from Keycloak containing user identity and group membership.

**Why this priority**: This is the technical enablement for P1 (user GitLab.com sign-in). Services must be configured to trust Keycloak as an identity provider.

**Independent Test**: Can be fully tested by configuring one service (e.g., Grafana) to use Keycloak OIDC, then logging in via GitLab.com. Success means the service redirects to Keycloak, Keycloak shows GitLab.com login, and the user lands in Grafana with proper permissions based on their groups.

**Acceptance Scenarios**:

1. **Given** Nextcloud is configured with Keycloak OIDC credentials, **When** a user visits Nextcloud and selects "Sign in with GitLab", **Then** they are redirected to Keycloak, authenticate with GitLab.com, and return to Nextcloud with proper user roles and group memberships.

2. **Given** multiple services are configured for Keycloak OIDC, **When** a user authenticates to one service, **Then** tokens are shared and the user can access other services without re-authentication during token validity period (SSO).

3. **Given** a service does not support OIDC, **When** it is configured for SAML, **Then** Keycloak issues SAML assertions and the service authenticates users successfully.

---

### User Story 5 - Traefik Forward Auth for Custom Websites (Priority: P5)

Custom websites and services that lack native OIDC support are protected by Traefik forward authentication middleware. When an unauthenticated user accesses a protected site, Traefik redirects them to Keycloak for authentication via GitLab.com, then allows access once authenticated.

**Why this priority**: Extends GitLab.com OAuth protection to custom applications and static websites. This enables 100% coverage for all infrastructure endpoints.

**Independent Test**: Can be fully tested by deploying a simple static website behind Traefik with the forward auth middleware enabled. Success means an unauthenticated user is redirected to Keycloak login, authenticates with GitLab.com, and is allowed to access the protected website.

**Acceptance Scenarios**:

1. **Given** a custom web application without built-in authentication behind Traefik, **When** an unauthenticated user accesses it, **Then** Traefik intercepts the request, redirects to Keycloak, user authenticates with GitLab.com, and Traefik allows the original request through with user headers injected.

2. **Given** a user already authenticated to other services, **When** they access a Traefik-protected website, **Then** Traefik recognizes the existing Keycloak session and allows immediate access without re-authentication.

3. **Given** a protected website requires specific group membership, **When** Traefik forward auth middleware is configured with group requirements, **Then** only users in allowed groups can access the site, others see an authorization error.

---

### Edge Cases

- **What happens when GitLab.com is temporarily unavailable?** Existing LDAP authentication continues to work as a fallback. Users with linked accounts can use LDAP credentials. Services relying solely on OIDC may be inaccessible until GitLab.com recovers.

- **What happens when a user's GitLab.com account is disabled or deleted?** On next authentication attempt, Keycloak receives an error from GitLab.com and denies access. The user's account in Keycloak and LDAP remains but cannot authenticate via GitLab.com OAuth.

- **What happens when LDAP sync fails due to network or LDAP server issues?** Authentication via OIDC-enabled services continues unaffected. LDAP-only services (Postfix, PAM) may not see newly created users until sync resumes. Sync process retries automatically with exponential backoff.

- **What happens when a user exists in both LDAP and authenticates with GitLab.com for the first time?** Keycloak account linking detects duplicate email addresses. Administrator must manually resolve conflicts by linking accounts or renaming the LDAP user.

- **What happens when Keycloak itself is unavailable?** All OIDC-dependent services lose authentication capability. Services with direct LDAP fallback can continue operating. This highlights the importance of Keycloak high availability.

- **What happens when a user revokes GitLab.com OAuth permissions?** On next authentication attempt, GitLab.com denies access and Keycloak shows an error. User must re-grant permissions or use alternative authentication (LDAP if linked). Session tokens remain valid until expiration.

- **What happens to service accounts and automation tokens?** Service accounts (GitLab runners, monitoring agents, backup jobs) continue using API tokens and service credentials stored in Ansible Vault. They are unaffected by user authentication changes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST enable GitLab.com as an identity provider in Keycloak, allowing users to authenticate using their GitLab.com accounts via OAuth 2.0.

- **FR-002**: System MUST support both GitLab.com OAuth and traditional LDAP authentication simultaneously during migration period, with users able to choose their preferred method at login.

- **FR-003**: System MUST automatically create user accounts in Keycloak when users authenticate via GitLab.com for the first time, extracting username, email, display name from GitLab.com OAuth tokens.

- **FR-004**: System MUST synchronize user accounts from Keycloak to OpenLDAP in one-way (read-only) mode, ensuring LDAP reflects Keycloak as the authoritative source.

- **FR-005**: System MUST map GitLab.com user attributes to LDAP schema, including username, mail, displayName, givenName, and sn attributes.

- **FR-006**: System MUST support single sign-on (SSO) across all OIDC-enabled services, allowing users to authenticate once and access multiple services without re-entering credentials.

- **FR-007**: System MUST support single logout (SLO), where logging out from one service terminates sessions across all connected services.

- **FR-008**: System MUST allow administrators to manually link existing LDAP accounts to GitLab.com accounts, enabling users to authenticate via either method while accessing the same data and permissions.

- **FR-009**: System MUST configure Traefik forward authentication middleware to protect services without native OIDC support, redirecting unauthenticated requests to Keycloak.

- **FR-010**: System MUST inject user identity headers (X-Auth-User, X-Auth-Email, X-Auth-Groups) into requests proxied by Traefik after successful authentication.

- **FR-011**: System MUST assign new GitLab.com-authenticated users to default LDAP groups (e.g., "users") automatically during account creation.

- **FR-012**: System MUST preserve existing LDAP user passwords and authentication during and after migration, ensuring no disruption to users who prefer traditional credentials.

- **FR-013**: System MUST configure each infrastructure service (Nextcloud, Mattermost, Grafana, NetBox) with Keycloak OIDC client credentials for authentication.

- **FR-014**: System MUST support SAML authentication for services without OIDC support, with Keycloak acting as SAML identity provider.

- **FR-015**: System MUST handle authentication failures gracefully, displaying user-friendly error messages for common scenarios (GitLab.com account not authorized, insufficient permissions, sync errors).

- **FR-016**: System MUST log all authentication events (successful logins, failures, account creations, permission changes) to support security auditing.

- **FR-017**: System MUST synchronize user account status (enabled/disabled) from Keycloak to LDAP, ensuring disabled accounts cannot authenticate via any method.

- **FR-018**: System MUST retry failed LDAP synchronization operations automatically with exponential backoff, up to a maximum retry count of 10 attempts.

### Infrastructure Requirements *(for Proxmox deployments)*

- **IR-001**: Keycloak service MUST continue running in existing LXC container (CT 151) with increased resource allocation if needed (minimum 2GB RAM recommended for production).

- **IR-002**: System MUST have outbound HTTPS connectivity to gitlab.com for OAuth token validation.

- **IR-003**: OpenLDAP service MUST continue running in existing LXC container (if deployed), configured to accept sync updates from Keycloak.

- **IR-004**: System MUST update NetBox inventory to reflect Keycloak as the authoritative identity source and LDAP as a synchronized replica.

- **IR-005**: System MUST ensure automated backups include Keycloak database (user accounts, OIDC client configs, IdP settings) and LDAP directory data.

- **IR-006**: Traefik configuration MUST be updated to include forward auth middleware definitions and routing rules for protected services.

### Security Requirements *(mandatory for all services)*

- **SR-001**: GitLab.com OAuth application credentials (application ID and secret) MUST be stored in Ansible Vault and never committed in plaintext.

- **SR-002**: OIDC client secrets for each service MUST be generated with cryptographically secure random values and stored in Ansible Vault.

- **SR-003**: Keycloak MUST validate GitLab.com OAuth tokens and enforce token expiration, with maximum session lifetime configurable (default 8 hours recommended).

- **SR-004**: LDAP synchronization credentials MUST use a dedicated service account with minimal privileges (read/write only to user organizational unit).

- **SR-005**: Traefik forward auth MUST validate Keycloak session tokens on every request and reject expired or invalid tokens.

- **SR-006**: System MUST enforce HTTPS for all authentication flows, with no plaintext credential transmission.

- **SR-007**: Keycloak MAY be configured to require email verification for new GitLab.com-authenticated users before granting access to infrastructure services (optional based on risk tolerance).

- **SR-008**: System SHOULD leverage GitLab.com's MFA capabilities, encouraging users to enable 2FA on their GitLab.com accounts.

- **SR-009**: LDAP directory MUST be configured as read-only for all non-sync operations, preventing accidental or malicious modifications outside Keycloak.

- **SR-010**: System MUST log all authentication failures with sufficient detail (username, timestamp, failure reason) for security incident investigation.

### Key Entities

- **User Account**: Represents an individual user with identity attributes (username, email, display name, groups). Exists in Keycloak (authoritative) and synchronized to LDAP (replica). Can authenticate via GitLab.com OAuth or LDAP credentials (if linked).

- **Identity Provider (GitLab.com)**: External authentication source (gitlab.com) that validates user credentials and returns OAuth tokens to Keycloak. Configured with application ID, secret, and authorized redirect URIs.

- **OIDC Client**: Represents an infrastructure service (Nextcloud, Mattermost, etc.) that trusts Keycloak for authentication. Configured with client ID, secret, redirect URIs, and requested scopes.

- **LDAP Sync Job**: Automated process that periodically reads user accounts from Keycloak and creates/updates corresponding entries in OpenLDAP directory. Runs every 5 minutes (configurable).

- **User Group**: Collection of users with common permissions. Defined in Keycloak and synchronized to LDAP as posixGroup entries. Used for authorization in services and file system permissions.

- **Traefik Forward Auth Middleware**: Traefik configuration component that intercepts requests to protected services, validates authentication with Keycloak, and injects user identity headers before forwarding requests.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can authenticate to any infrastructure service using GitLab.com credentials in under 10 seconds from clicking "Sign in with GitLab" to landing on the service dashboard.

- **SC-002**: Single sign-on works across all OIDC-enabled services, with users authenticating once and accessing at least 5 different services without re-entering credentials during the same session.

- **SC-003**: 100% of new users created via GitLab.com OAuth appear in OpenLDAP within 5 minutes of first authentication, with all required attributes populated correctly.

- **SC-004**: Existing LDAP users can continue authenticating with username/password with zero authentication failures due to the GitLab.com OAuth rollout.

- **SC-005**: Custom websites protected by Traefik forward auth successfully block unauthenticated access and allow authenticated users through within 3 seconds of Keycloak authentication.

- **SC-006**: Authentication system maintains 99.5% uptime with GitLab.com OAuth as primary method and LDAP as fallback, measured over 30-day period post-deployment.

- **SC-007**: Zero plaintext credentials exist in configuration files or version control after deployment, verified through automated secret scanning.

- **SC-008**: User account synchronization from Keycloak to LDAP completes successfully for at least 95% of user changes within 5 minutes, with failed syncs retried and logged.

- **SC-009**: Administrators can complete the entire service OIDC configuration for one service (e.g., Grafana) in under 30 minutes using provided playbooks and documentation.

- **SC-010**: Single logout successfully terminates sessions across all connected services within 60 seconds of user logout action, verified by testing access to 5 different services.

## Assumptions

- GitLab.com service is accessible and maintains 99.9%+ uptime
- Users accessing infrastructure services have or can create free GitLab.com accounts
- Existing Keycloak installation is version 20.0 or higher with support for OpenID Connect and user federation
- OpenLDAP supports standard LDAP protocol (LDAPv3) and accepts writes from Keycloak sync service account
- Infrastructure services listed (Nextcloud, Mattermost, Grafana, etc.) support OIDC or SAML authentication in their current versions
- Network connectivity allows outbound HTTPS to gitlab.com for OAuth flows
- Administrator has ability to create OAuth applications on GitLab.com (requires GitLab.com account)
- Traefik version supports forward authentication middleware (v2.0+)
- User email addresses in existing LDAP directory can be matched with GitLab.com accounts for account linking purposes
- Token lifetime and session duration requirements align with standard web application security practices (8-hour sessions, 1-hour token refresh)

## Dependencies

- **GitLab.com** - External OAuth provider (https://gitlab.com)
- **Keycloak** (CT 151) - Identity broker
- **OpenLDAP** (if deployed) - Legacy authentication fallback
- **Traefik** - Reverse proxy with forward auth middleware
- **Ansible Vault** - Secure credential storage
- **Internet connectivity** - Outbound HTTPS to gitlab.com

## Out of Scope

- Self-hosted GitLab integration (use self-hosted GitLab as OAuth provider)
- Other external OAuth providers (Google, GitHub, Microsoft)
- User provisioning via GitLab.com API (users must have GitLab.com accounts)
- Automated GitLab.com group synchronization to Keycloak roles (manual mapping initially)
- High availability / clustering of Keycloak (future enhancement)
- Custom Keycloak themes or branding
- Migration of existing service-specific user accounts to Keycloak (beyond LDAP users)

## Implementation Notes

### GitLab.com OAuth Application Setup

1. Sign in to GitLab.com with administrator account
2. Navigate to User Settings → Applications
3. Create new OAuth application for Keycloak:
   - Name: "Keycloak - Viljo Infrastructure"
   - Redirect URI: `https://keycloak.viljo.se/realms/master/broker/gitlab/endpoint`
   - Scopes: `read_user`, `openid`, `profile`, `email`
4. Save application ID and secret to Ansible Vault

### Keycloak Configuration

1. Add GitLab.com as identity provider in Keycloak
2. Configure OAuth endpoints:
   - Authorization URL: `https://gitlab.com/oauth/authorize`
   - Token URL: `https://gitlab.com/oauth/token`
   - User Info URL: `https://gitlab.com/oauth/userinfo`
3. Enable user account creation on first login
4. Configure attribute mapping (username, email, groups)
5. Set up LDAP sync federation (if using LDAP)

### Service Integration Order

**Phase 1** (Low-risk services):
1. Grafana - monitoring dashboards
2. Custom internal tools - via Traefik forward auth

**Phase 2** (Collaboration services):
3. Nextcloud - file storage
4. Mattermost - team chat

**Phase 3** (Critical services):
5. NetBox - infrastructure documentation
6. Other services as needed

---

**Last Updated**: 2025-10-25
**Changed**: Replaced Google OAuth with GitLab.com OAuth for developer-focused SSO
**Architecture**: GitLab.com (External) → Keycloak → Services → LDAP (optional sync)
