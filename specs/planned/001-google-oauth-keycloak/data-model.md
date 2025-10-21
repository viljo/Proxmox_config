# Data Model: Google OAuth Integration with Keycloak

**Feature**: Google OAuth Integration with Keycloak
**Date**: 2025-10-20

## Overview

This document defines the data entities, attributes, and relationships for the Google OAuth/Keycloak/LDAP integration. All entities are technology-agnostic representations of the logical data model.

---

## 1. User Account Entity

**Description**: Represents an individual user with identity attributes. Exists in Keycloak (authoritative) and synchronized to LDAP (replica).

### Attributes

| Attribute | Type | Required | Description | Validation Rules | Source |
|-----------|------|----------|-------------|------------------|--------|
| `id` | UUID | Yes | Unique identifier | System-generated | Keycloak |
| `username` | String | Yes | Unique username | 3-255 chars, lowercase recommended | Google email or custom |
| `email` | String | Yes | Email address | Valid email format, unique | Google OAuth |
| `emailVerified` | Boolean | Yes | Email verification status | true/false | Google OAuth |
| `firstName` | String | Yes | Given name | 1-255 chars | Google OAuth |
| `lastName` | String | Yes | Family name | 1-255 chars | Google OAuth |
| `displayName` | String | No | Full display name | Auto-generated or custom | Derived from firstName + lastName |
| `picture` | URL | No | Profile picture URL | Valid HTTPS URL | Google OAuth |
| `locale` | String | No | User locale | ISO 639-1 language code | Google OAuth |
| `created` | Timestamp | Yes | Account creation time | ISO 8601 format | Keycloak |
| `lastLogin` | Timestamp | No | Last authentication time | ISO 8601 format | Keycloak |
| `enabled` | Boolean | Yes | Account active status | true/false, default: true | Keycloak |
| `groups` | Array<String> | No | Group memberships | Group names or paths | Keycloak |
| `roles` | Array<String> | No | Assigned roles | Role names | Keycloak |

### LDAP-Specific Attributes

| Attribute | Type | Required | Description | Generation Strategy |
|-----------|------|----------|-------------|---------------------|
| `uidNumber` | Integer | Yes | POSIX user ID | Auto-allocated from counter (10001+) |
| `gidNumber` | Integer | Yes | Primary group ID | Default: 10000 (users group) |
| `homeDirectory` | String | Yes | Home directory path | `/home/{username}` |
| `loginShell` | String | No | Default shell | `/bin/bash` |
| `gecos` | String | No | User description | `{firstName} {lastName}` |

### State Transitions

```
[New Google User] → [First Login] → [Keycloak Account Created] → [LDAP Entry Synced]
                                   ↓
                          [Review Profile (optional)]
                                   ↓
                          [Account Active]

[Existing LDAP User] → [Google Login] → [Account Linking Prompt] → [Manual Confirmation] → [Accounts Linked]
```

### Validation Rules

1. **Email Uniqueness**: Each email can only be associated with one Keycloak account
2. **Username Uniqueness**: Usernames must be unique across Keycloak realm
3. **UID Number Uniqueness**: Each uidNumber must be unique in LDAP (enforced by slapo-unique)
4. **Required Fields**: username, email, firstName, lastName must be populated before account activation
5. **Email Verification**: trustEmail setting allows auto-verification from Google

---

## 2. Identity Provider Entity

**Description**: External authentication source (Google) that validates user credentials and returns OAuth tokens.

### Attributes

| Attribute | Type | Required | Description | Example Value |
|-----------|------|----------|-------------|---------------|
| `alias` | String | Yes | Unique provider identifier | `google` |
| `displayName` | String | Yes | User-facing name | `Sign in with Google` |
| `providerId` | String | Yes | Provider type | `google` (Keycloak built-in) |
| `enabled` | Boolean | Yes | Provider active status | `true` |
| `clientId` | String | Yes | OAuth client ID | `123456-xyz.apps.googleusercontent.com` |
| `clientSecret` | String (Secret) | Yes | OAuth client secret | Stored in vault |
| `issuerUrl` | URL | Auto | OAuth issuer endpoint | `https://accounts.google.com` |
| `authorizationUrl` | URL | Auto | OAuth authorization endpoint | Auto-discovered |
| `tokenUrl` | URL | Auto | OAuth token endpoint | Auto-discovered |
| `scopes` | Array<String> | Yes | Requested OAuth scopes | `[openid, profile, email]` |
| `trustEmail` | Boolean | Yes | Auto-verify emails | `true` (Google verified) |
| `storeToken` | Boolean | Yes | Store OAuth tokens | `false` (security) |
| `syncMode` | Enum | Yes | Attribute sync strategy | `IMPORT` (first login only) |

### Configuration

```yaml
Discovery: Enabled (auto-configure endpoints)
JWKS URL Validation: Enabled
Signature Validation: RSA256
Hosted Domain: "" (allow consumer accounts) or "example.com" (Google Workspace only)
```

---

## 3. OIDC Client Entity

**Description**: Represents an infrastructure service (GitLab, Nextcloud, etc.) that trusts Keycloak for authentication.

### Attributes

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `clientId` | String | Yes | Unique client identifier | `gitlab` |
| `name` | String | Yes | Client display name | `GitLab` |
| `description` | String | No | Client purpose | `GitLab SSO via Keycloak` |
| `protocol` | Enum | Yes | Authentication protocol | `openid-connect` or `saml` |
| `accessType` | Enum | Yes | Client type | `confidential` (server-side) |
| `clientSecret` | String (Secret) | Yes | Client authentication secret | Stored in vault |
| `redirectUris` | Array<URL> | Yes | Valid redirect URIs | `[https://gitlab.example.com/callback]` |
| `webOrigins` | Array<URL> | No | CORS allowed origins | `[https://gitlab.example.com]` |
| `scopes` | Array<String> | Yes | Requested scopes | `[openid, profile, email, groups]` |
| `enabled` | Boolean | Yes | Client active status | `true` |
| `created` | Timestamp | Yes | Client creation time | ISO 8601 |

### Protocol-Specific Settings

**OIDC Clients**:
- Standard Flow: Enabled (authorization code flow)
- Direct Access Grants: Disabled (use SSO)
- Implicit Flow: Disabled (deprecated)
- Service Accounts: Disabled (user authentication only)

**SAML Clients** (Zabbix):
- Sign Documents: Enabled
- Signature Algorithm: RSA_SHA256
- Name ID Format: email or username

### Client Mappers

Each client includes attribute mappers for:
- Username (`preferred_username`)
- Email (`email`)
- First Name (`given_name`)
- Last Name (`family_name`)
- Groups (`groups`) - optional
- Roles (`roles`) - optional

---

## 4. LDAP Sync Job Entity

**Description**: Automated process that synchronizes user accounts from Keycloak to OpenLDAP directory.

### Attributes

| Attribute | Type | Required | Description | Value |
|-----------|------|----------|-------------|-------|
| `schedule` | Cron | Yes | Execution schedule | `*/15 * * * *` (every 15 min) |
| `syncMode` | Enum | Yes | Synchronization strategy | `one-way` (Keycloak → LDAP) |
| `sourceUrl` | URL | Yes | Keycloak API endpoint | `https://keycloak.example.com/admin/realms/master/users` |
| `targetUrl` | URL | Yes | LDAP server endpoint | `ldap://172.16.10.51:389` |
| `batchSize` | Integer | Yes | Users per sync batch | `100` |
| `retryCount` | Integer | Yes | Max retries on failure | `3` |
| `retryDelay` | Integer | Yes | Delay between retries (seconds) | `60` |
| `lastRun` | Timestamp | No | Last execution time | ISO 8601 |
| `lastSuccess` | Timestamp | No | Last successful sync | ISO 8601 |
| `status` | Enum | Yes | Current job status | `idle`, `running`, `failed` |

### Sync Operations

**Create User** (new Keycloak user):
1. Allocate uidNumber from LDAP counter
2. Map Keycloak attributes to LDAP schema
3. Create LDAP entry with objectClasses: `inetOrgPerson`, `posixAccount`
4. Set default gidNumber (10000)
5. Generate homeDirectory path

**Update User** (existing user modified):
1. Detect attribute changes (email, name, enabled status)
2. Update LDAP entry with modified attributes
3. Preserve uidNumber and homeDirectory

**Delete User** (disabled in Keycloak):
1. Set LDAP account status to disabled
2. Do NOT delete LDAP entry (preserve UID)

**Sync Groups**:
1. Fetch Keycloak groups
2. Create/update LDAP posixGroup entries
3. Sync memberUid attributes (username list)

### Error Handling

- **LDAP Connection Failure**: Retry with exponential backoff
- **UID Collision**: Log error, skip user, alert admin
- **Missing Required Attribute**: Use fallback (e.g., lastName = username)
- **Partial Sync Failure**: Continue with remaining users, log failures

---

## 5. User Group Entity

**Description**: Collection of users with common permissions. Defined in Keycloak and synchronized to LDAP as posixGroup.

### Attributes

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `id` | UUID | Yes | Unique group identifier | System-generated |
| `name` | String | Yes | Group name | `developers` |
| `path` | String | Yes | Hierarchical path | `/engineering/developers` |
| `description` | String | No | Group purpose | `Development team members` |
| `members` | Array<UserID> | No | User memberships | List of user IDs |
| `roles` | Array<String> | No | Assigned roles | `[admin, editor]` |
| `created` | Timestamp | Yes | Group creation time | ISO 8601 |

### LDAP-Specific Attributes

| Attribute | Type | Required | Description | Generation |
|-----------|------|----------|-------------|------------|
| `gidNumber` | Integer | Yes | POSIX group ID | Auto-allocated from counter |
| `memberUid` | Array<String> | No | Member usernames | Extract from members list |

### LDAP Schema

```
objectClass: posixGroup
cn: {name}
gidNumber: {gidNumber}
memberUid: {username1}
memberUid: {username2}
...
```

### Default Groups

| Group Name | GID | Purpose | Auto-Assignment |
|------------|-----|---------|-----------------|
| `users` | 10000 | Default user group | All new users |
| `admins` | 10001 | Administrative access | Manual assignment |
| `developers` | 10002 | Development access | Manual assignment |

---

## 6. Traefik Forward Auth Middleware Entity

**Description**: OAuth2 Proxy configuration for protecting services without native OIDC support.

### Attributes

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `provider` | String | Yes | OIDC provider type | `keycloak-oidc` |
| `issuerUrl` | URL | Yes | Keycloak realm endpoint | `https://keycloak.example.com/realms/master` |
| `clientId` | String | Yes | OAuth2 Proxy client ID | `oauth2-proxy` |
| `clientSecret` | String (Secret) | Yes | Client secret | Stored in vault |
| `redirectUrl` | URL | Yes | OAuth callback URL | `https://auth.example.com/oauth2/callback` |
| `cookieSecret` | String (Secret) | Yes | Session encryption key | 32-byte base64 encoded |
| `cookieDomain` | String | Yes | Cookie domain scope | `.example.com` |
| `cookieExpire` | Duration | Yes | Session lifetime | `168h` (7 days) |
| `allowedGroups` | Array<String> | No | Group-based access control | `[/admins]` |
| `allowedRoles` | Array<String> | No | Role-based access control | `[admin]` |
| `upstreamUrl` | URL | Yes | Backend service URL | `http://172.16.10.XX:PORT` |

### Injected Headers

OAuth2 Proxy injects these headers to backend services:

| Header | Description | Example |
|--------|-------------|---------|
| `X-Auth-Request-User` | Username | `johndoe` |
| `X-Auth-Request-Email` | User email | `johndoe@example.com` |
| `X-Auth-Request-Groups` | Group memberships | `admins,developers` |
| `Authorization` | Bearer token | `Bearer eyJhbGci...` |

### Authorization Flow

```
[Unauthenticated Request] → [Traefik] → [OAuth2 Proxy] → [Redirect to Keycloak]
                                                               ↓
[User Authenticates] → [Google OAuth] → [Keycloak] → [OAuth2 Proxy]
                                                               ↓
[Set Session Cookie] → [Traefik] → [Backend Service] (with headers)
```

---

## 7. Session Entity

**Description**: Represents an active user authentication session in Keycloak.

### Attributes

| Attribute | Type | Required | Description | Lifecycle |
|-----------|------|----------|-------------|-----------|
| `sessionId` | UUID | Yes | Unique session identifier | System-generated |
| `userId` | UUID | Yes | Associated user ID | From user login |
| `created` | Timestamp | Yes | Session start time | On authentication |
| `lastAccess` | Timestamp | Yes | Last activity time | Updated on request |
| `expires` | Timestamp | Yes | Session expiration | Created + max lifetime |
| `idleTimeout` | Duration | Yes | Inactivity timeout | 30 minutes (default) |
| `maxLifetime` | Duration | Yes | Maximum session duration | 10 hours (default) |
| `ipAddress` | IP | Yes | Client IP address | From request |
| `userAgent` | String | Yes | Client user agent | From request |
| `broker` | String | No | Identity provider used | `google` (if via Google OAuth) |

### Token Components

Each session has associated tokens:

| Token Type | Lifetime | Purpose | Refresh |
|------------|----------|---------|---------|
| Access Token | 15 minutes | API authorization | Via refresh token |
| Refresh Token | Session lifetime | Obtain new access token | Revoked on use |
| ID Token | 15 minutes | User identity claims | N/A (one-time use) |

### State Transitions

```
[User Login] → [Session Created] → [Active]
                                      ↓
                    [Idle Timeout] → [Expired] → [Deleted]
                                      ↓
                    [Logout] → [Terminated] → [Deleted]
```

---

## 8. Audit Event Entity

**Description**: Records authentication and authorization events for security auditing.

### Attributes

| Attribute | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `eventId` | UUID | Yes | Unique event identifier | System-generated |
| `timestamp` | Timestamp | Yes | Event occurrence time | ISO 8601 |
| `eventType` | Enum | Yes | Event category | `LOGIN`, `LOGIN_ERROR`, `LOGOUT` |
| `userId` | UUID | No | Associated user | If user-related |
| `username` | String | No | Username | For display |
| `ipAddress` | IP | Yes | Client IP | From request |
| `clientId` | String | No | Client application | `gitlab`, `nextcloud` |
| `identityProvider` | String | No | Authentication method | `google` |
| `errorMessage` | String | No | Failure reason | If event failed |
| `details` | JSON | No | Additional context | Varies by event type |

### Event Types

**User Events**:
- `LOGIN` - Successful authentication
- `LOGIN_ERROR` - Failed authentication attempt
- `LOGOUT` - User-initiated logout
- `REGISTER` - New user registration
- `UPDATE_PROFILE` - User profile modification
- `UPDATE_EMAIL` - Email address change
- `IDENTITY_PROVIDER_LOGIN` - OAuth/SAML login
- `IDENTITY_PROVIDER_LOGIN_ERROR` - OAuth/SAML failure

**Admin Events**:
- `CREATE_USER` - User created by admin
- `UPDATE_USER` - User modified by admin
- `DELETE_USER` - User deleted by admin
- `RESET_PASSWORD` - Password reset by admin

### Retention

- Event logs: 7 days (default)
- Admin logs: 30 days
- Export to external logging (Loki): Permanent

---

## 9. Data Relationships

### Entity Relationship Diagram (Logical)

```
User Account (1) ←→ (N) User Groups
    ↓ (1:N)
Identity Provider Link
    ↓ (N:1)
Identity Provider (Google)

User Account (1) ←→ (N) Sessions
    ↓ (1:1)
LDAP Entry

User Account (1) ←→ (N) OIDC Clients (via sessions)

OIDC Client (N) ←→ (1) Keycloak Realm

LDAP Sync Job (1) → (N) User Accounts
LDAP Sync Job (1) → (N) User Groups

OAuth2 Proxy Middleware (N) → (1) Keycloak Realm
OAuth2 Proxy Middleware (N) → (N) Protected Services

Audit Event (N) → (1) User Account
Audit Event (N) → (1) OIDC Client
```

### Cardinality Rules

1. **User ↔ Identity Provider**: One user can link to one Google account (1:1 after linking)
2. **User ↔ Groups**: One user can belong to multiple groups (N:N)
3. **User ↔ Sessions**: One user can have multiple active sessions (1:N)
4. **OIDC Client ↔ Users**: One client serves many users (N:N via sessions)
5. **Sync Job ↔ Users**: One job syncs all users (1:N)

---

## 10. Data Integrity Constraints

### Uniqueness Constraints

1. **User.email**: UNIQUE across Keycloak realm
2. **User.username**: UNIQUE across Keycloak realm
3. **LDAP.uidNumber**: UNIQUE across LDAP directory (enforced by slapo-unique)
4. **LDAP.gidNumber**: UNIQUE across LDAP directory (enforced by slapo-unique)
5. **Group.name**: UNIQUE within Keycloak realm
6. **OIDC Client.clientId**: UNIQUE within Keycloak realm

### Referential Integrity

1. **Session → User**: Session must reference valid user (CASCADE on user deletion)
2. **Group Membership → User**: Membership requires valid user and group
3. **LDAP Entry → User**: LDAP entry corresponds to Keycloak user (eventual consistency)
4. **Audit Event → User**: Event may reference user (NULL if user deleted)

### Data Consistency Rules

1. **User Account**: If enabled in Keycloak, LDAP entry must NOT be disabled (eventual)
2. **Email Verification**: If trustEmail=true and provider=google, emailVerified=true
3. **LDAP Sync**: uidNumber in LDAP matches User custom attribute in Keycloak
4. **Group Membership**: memberUid in LDAP matches group members in Keycloak (eventual)

---

## 11. Data Flow Diagrams

### User Registration Flow

```
[New User] → [Google OAuth Login] → [Keycloak Creates Account]
                                           ↓
                                    [Review Profile Screen]
                                           ↓
                                    [Account Activated]
                                           ↓
                                    [LDAP Sync Job (15 min)]
                                           ↓
                                    [LDAP Entry Created]
                                           ↓
                                    [User Can Access Services]
```

### Authentication Flow

```
[User Accesses Service] → [Traefik Middleware] → [OAuth2 Proxy]
                                                       ↓
                                                [No Valid Session?]
                                                       ↓
                                                [Redirect to Keycloak]
                                                       ↓
                                                [Keycloak Auth]
                                                       ↓
                                                [Identity Provider Selection]
                                                       ↓
                                                [Google OAuth]
                                                       ↓
                                                [Google Authenticates]
                                                       ↓
                                                [Keycloak Creates Session]
                                                       ↓
                                                [OAuth2 Proxy Sets Cookie]
                                                       ↓
                                                [Traefik Forwards Request + Headers]
                                                       ↓
                                                [Backend Service Receives Authenticated Request]
```

### LDAP Synchronization Flow

```
[Systemd Timer Triggers] → [Sync Script Starts]
                                    ↓
                            [Authenticate to Keycloak API]
                                    ↓
                            [Fetch All Users]
                                    ↓
                            [For Each User:]
                                    ↓
                            [Check LDAP Entry Exists?]
                                    ↓
                    [No] → [Allocate uidNumber] → [Create LDAP Entry]
                                    ↓
                    [Yes] → [Compare Attributes] → [Update if Changed]
                                    ↓
                            [Sync Groups]
                                    ↓
                            [Log Results]
                                    ↓
                            [Update Metrics]
```

---

## Summary

This data model defines 9 core entities:
1. **User Account** - Identity with Keycloak + LDAP representations
2. **Identity Provider** - Google OAuth configuration
3. **OIDC Client** - Service authentication configurations
4. **LDAP Sync Job** - Automated synchronization process
5. **User Group** - Role-based access control groups
6. **Traefik Forward Auth Middleware** - OAuth2 Proxy protection
7. **Session** - Active authentication sessions
8. **Audit Event** - Security event logging
9. **Relationships** - Entity connections and cardinality

All entities are defined in technology-agnostic terms, ready for implementation in the chosen technology stack (Keycloak + OpenLDAP + OAuth2 Proxy).
