# Feature Specification: Webtop Browser Instance

**Feature Branch**: `005-webtop-browser`
**Created**: 2025-10-20
**Status**: Draft
**Input**: User description: "A webtop instance published on browser.viljo.se"

## Clarifications

### Session 2025-10-20

- Q: Should Webtop be deployed in an LXC container or a full VM? → A: LXC container (unprivileged)
- Q: Which network segment should host the webtop instance? → A: DMZ network (vmbr3) at 172.16.10.0/24
- Q: What network access should users inside the webtop desktop environment have? → A: Full internet access

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browser-Based Desktop Access (Priority: P1)

Users need to access a full Linux desktop environment through their web browser at browser.viljo.se without installing any client software, enabling remote work, application testing, and secure browsing from any device.

**Why this priority**: This is the core value proposition - providing instant, browser-based access to a full desktop environment. Users can work remotely, test applications, or perform tasks requiring a Linux desktop without local installation.

**Independent Test**: Can be fully tested by navigating to `https://browser.viljo.se` in a web browser, authenticating, and verifying that a functional desktop environment loads with working mouse, keyboard, and window management.

**Acceptance Scenarios**:

1. **Given** user navigates to browser.viljo.se, **When** they authenticate, **Then** a full desktop environment loads in the browser within 10 seconds
2. **Given** desktop is loaded, **When** user interacts with mouse and keyboard, **Then** inputs are responsive with minimal latency (<100ms)
3. **Given** user is working in desktop, **When** they open applications (file manager, terminal, web browser), **Then** applications launch and function normally
4. **Given** user resizes browser window, **When** resolution changes, **Then** desktop dynamically adjusts to new dimensions

---

### User Story 2 - Secure HTTPS Access with Authentication (Priority: P2)

Users must access the webtop instance securely through HTTPS with proper authentication to prevent unauthorized access and protect data in transit.

**Why this priority**: Security is critical for remote desktop access but depends on the desktop being functional first. Authentication prevents unauthorized access while HTTPS protects session data.

**Independent Test**: Can be tested by attempting to access browser.viljo.se without credentials (denied), with valid credentials (granted), and verifying HTTPS certificate is valid.

**Acceptance Scenarios**:

1. **Given** user navigates to browser.viljo.se, **When** they are not authenticated, **Then** they are presented with login page or authentication challenge
2. **Given** user provides invalid credentials, **When** they attempt login, **Then** access is denied with clear error message
3. **Given** user provides valid credentials, **When** they authenticate, **Then** desktop session is granted
4. **Given** user connects to browser.viljo.se, **When** checking connection security, **Then** browser shows valid HTTPS certificate with no warnings

---

### User Story 3 - Persistent User Sessions and Data (Priority: P3)

Users need their desktop customizations, open applications, and files to persist across browser sessions so they can resume work where they left off.

**Why this priority**: Enhances user experience by maintaining state, but basic desktop functionality works without persistence. This is valuable for power users but not essential for initial deployment.

**Independent Test**: Can be tested by customizing desktop settings, closing browser, reconnecting, and verifying customizations remain.

**Acceptance Scenarios**:

1. **Given** user customizes desktop (wallpaper, panel settings), **When** they disconnect and reconnect, **Then** customizations are preserved
2. **Given** user creates files in home directory, **When** they disconnect and reconnect, **Then** files are still accessible
3. **Given** user session is idle for extended period, **When** they reconnect, **Then** session either resumes or cleanly restarts with preserved data

---

### User Story 4 - Multi-User Support (Priority: P4)

Multiple users should be able to access the webtop instance simultaneously with isolated sessions to support team collaboration and shared infrastructure usage.

**Why this priority**: Valuable for multi-user environments but not essential for initial single-user deployment. Can be added later as usage scales.

**Independent Test**: Can be tested by two users connecting to browser.viljo.se simultaneously and verifying they have separate, isolated desktop sessions.

**Acceptance Scenarios**:

1. **Given** multiple users connect simultaneously, **When** they authenticate with different credentials, **Then** each receives isolated desktop session
2. **Given** user A is working in session, **When** user B connects, **Then** user A's session is unaffected
3. **Given** users have separate sessions, **When** they create files, **Then** files are not visible to other users

---

### Edge Cases

- What happens when user's browser loses network connectivity during active session?
- How does system handle browser tab/window closure (session termination vs. suspension)?
- What occurs if container runs out of disk space during user session?
- How are idle sessions handled to free resources?
- What happens when multiple browser tabs connect to same session?
- How does system handle clipboard operations between local machine and webtop?
- What occurs if user attempts to access high-resource applications (video editing, 3D rendering)?
- How are audio streams handled from applications running in webtop?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide full Linux desktop environment accessible through web browser
- **FR-002**: System MUST support standard desktop interactions (mouse clicks, keyboard input, window management, drag-and-drop)
- **FR-003**: System MUST render desktop at user's browser resolution with dynamic scaling
- **FR-004**: System MUST provide working terminal access within desktop environment
- **FR-005**: System MUST include essential desktop applications (file manager, text editor, web browser)
- **FR-006**: System MUST support copy/paste operations between local machine and webtop
- **FR-007**: System MUST maintain desktop session state during browser reconnection
- **FR-008**: System MUST provide clear feedback on connection status and session health
- **FR-009**: System MUST accessible via browser.viljo.se domain
- **FR-010**: System MUST support common file operations (create, edit, delete, upload, download)

### Infrastructure Requirements *(for Proxmox deployments)*

- **IR-001**: Service MUST run in unprivileged LXC container for optimal resource efficiency
- **IR-002**: Container MUST be deployed on DMZ network (vmbr3) at 172.16.10.0/24 subnet
- **IR-003**: Instance MUST allocate sufficient resources for desktop environment (minimum 2GB RAM, 2 CPU cores recommended)
- **IR-004**: Instance MUST integrate with Traefik for HTTPS termination and routing to browser.viljo.se
- **IR-005**: Configuration MUST be managed via Ansible for reproducibility
- **IR-006**: Instance MUST support volume mounting for persistent user data
- **IR-007**: System MUST expose port 3000 (KasmVNC default) or configured web port internally

### Security Requirements *(mandatory for all services)*

- **SR-001**: Service MUST require authentication before granting desktop access
- **SR-002**: Service MUST be accessible ONLY via HTTPS through Traefik (no direct HTTP access)
- **SR-003**: Service MUST run with minimal privileges (unprivileged LXC if containerized)
- **SR-004**: Credentials MUST be stored in Ansible Vault (no plaintext passwords in configuration)
- **SR-005**: Service MUST use self-signed or Let's Encrypt certificate for TLS
- **SR-006**: Desktop environment MUST run with user-level privileges (not root)
- **SR-007**: Desktop environment MUST have full internet access to enable web browsing, package installation, and external service access

### Key Entities

- **Webtop Container/VM**: Docker-based or LXC/VM instance running KasmVNC and Linux desktop environment
- **Desktop Environment**: XFCE, KDE, or other lightweight desktop providing GUI interface
- **KasmVNC Server**: VNC server optimized for browser-based access with modern protocols
- **User Session**: Individual desktop session with isolated workspace and persistent data
- **Traefik Route**: Reverse proxy configuration routing browser.viljo.se to webtop instance
- **Persistent Volume**: Storage for user home directories, settings, and application data
- **Authentication Provider**: Mechanism for verifying user identity (built-in, Keycloak, LDAP)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can access functional desktop environment within 10 seconds of authentication
- **SC-002**: Desktop interaction latency remains under 100ms for mouse and keyboard inputs under normal network conditions
- **SC-003**: System supports minimum 5 concurrent user sessions without performance degradation
- **SC-004**: Desktop environment maintains 30fps minimum for typical office applications
- **SC-005**: File upload/download operations complete successfully for files up to 100MB
- **SC-006**: User session data persists across browser reconnections with zero data loss
- **SC-007**: Service maintains 99% uptime during evaluation period
- **SC-008**: Users can successfully launch and use 3 different application types (terminal, file manager, web browser)

## Assumptions

- DNS record for browser.viljo.se is configured and points to Traefik/firewall WAN IP
- Loopia DDNS keeps DNS updated with current external IP
- Traefik reverse proxy is deployed and operational
- Firewall LXC forwards HTTPS traffic to Traefik
- Users access webtop from devices with modern web browsers (Chrome, Firefox, Safari, Edge)
- Network bandwidth sufficient for VNC streaming (minimum 5 Mbps recommended per session)
- Proxmox host has sufficient CPU and RAM for desktop environment overhead
- Storage backend supports user data persistence (ZFS, LVM, or shared storage)
- Administrator has Ansible access to Proxmox host for deployment

## Dependencies

- Proxmox VE host with LXC/VM support
- Docker support (if deploying Webtop as Docker container in LXC)
- Traefik reverse proxy configured in infrastructure
- Firewall LXC forwarding HTTPS traffic
- DNS service for browser.viljo.se domain
- Ansible for configuration management
- Base container template or VM image (Debian, Ubuntu, or Alpine)
- Sufficient network bandwidth for VNC streaming
- Authentication provider (built-in, Keycloak OIDC, or LDAP)

## Out of Scope

- GPU acceleration for 3D graphics or gaming
- Hardware device passthrough (USB, webcam, audio devices)
- Multi-monitor support for user sessions
- Recording or streaming of desktop sessions
- Integration with existing VDI solutions (Citrix, VMware Horizon)
- Mobile app clients (iOS/Android native apps)
- Collaborative features (screen sharing, multi-user on same session)
- Advanced audio routing and conferencing capabilities
- Custom desktop environment beyond standard Linux distributions
- Integration with external storage providers (Google Drive, Dropbox, OneDrive)
