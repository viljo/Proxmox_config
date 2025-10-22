# Feature Specification: BitTorrent Client (qBittorrent)

**Feature Branch**: `009-bittorrent-client`
**Created**: 2025-10-22
**Status**: Draft
**Input**: User request: "Add BitTorrent client to the planned list"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Download Torrents via Web Interface (Priority: P1)

Users can access a web-based BitTorrent client to download and manage torrent files. When visiting the qBittorrent web interface, users can add torrents via file upload, magnet links, or RSS feeds, monitor download progress in real-time, and manage completed downloads.

**Why this priority**: This is the core functionality - enabling users to download and seed torrents through a convenient web interface. Without this, the feature provides no value.

**Independent Test**: Can be fully tested by accessing the qBittorrent web UI, adding a legal torrent (e.g., Ubuntu ISO), and verifying it downloads successfully to the designated storage location.

**Acceptance Scenarios**:

1. **Given** a user with access to the BitTorrent service, **When** they visit the qBittorrent web interface, **Then** they see the dashboard with current torrents, upload/download speeds, and storage usage.

2. **Given** a user wants to download a torrent, **When** they add a magnet link or upload a .torrent file, **Then** the download starts automatically and progress is displayed in real-time.

3. **Given** a torrent has completed downloading, **When** the user views the completed section, **Then** they can access the files via SMB/NFS share or web file browser.

4. **Given** multiple users are downloading torrents, **When** bandwidth limits are configured, **Then** downloads are throttled according to global and per-torrent limits to prevent network saturation.

---

### User Story 2 - Authenticate via Keycloak SSO (Priority: P2)

Users authenticate to qBittorrent using their existing Keycloak/LDAP credentials through Traefik forward authentication. This eliminates separate login credentials and integrates with the infrastructure's single sign-on system.

**Why this priority**: Ensures security and user convenience through centralized authentication. This is P2 because the client must work (P1) before authentication can be tested.

**Independent Test**: Can be fully tested by attempting to access qBittorrent without authentication (should redirect to Keycloak), authenticating with Google OAuth or LDAP credentials, and being granted access.

**Acceptance Scenarios**:

1. **Given** an unauthenticated user attempts to access qBittorrent, **When** they visit the URL, **Then** Traefik redirects them to Keycloak for authentication.

2. **Given** a user authenticated via Keycloak, **When** they are redirected back to qBittorrent, **Then** they have immediate access without entering separate qBittorrent credentials.

3. **Given** a user logs out from any infrastructure service, **When** they attempt to access qBittorrent again, **Then** they must re-authenticate through Keycloak (single logout).

---

### User Story 3 - Access Downloaded Files via Network Share (Priority: P3)

Downloaded files are stored in a location accessible via SMB/NFS network shares, allowing users to access content from their local machines, media players, or other infrastructure services (e.g., Nextcloud, Jellyfin).

**Why this priority**: Enables actual use of downloaded content. This is P3 because downloads must work first (P1), and it's a supporting feature for consumption rather than core functionality.

**Independent Test**: Can be fully tested by downloading a torrent, then accessing the completed files via SMB share from a Windows/Linux client, or via Nextcloud file browser.

**Acceptance Scenarios**:

1. **Given** a torrent has completed downloading, **When** a user accesses the configured SMB/NFS share, **Then** they see the downloaded files organized by torrent name.

2. **Given** a user has permission-restricted access, **When** they browse the share, **Then** they can only access files in their user directory or shared public directory based on LDAP group membership.

3. **Given** a large file is downloaded, **When** the user streams it from the share, **Then** sufficient network bandwidth and file permissions allow smooth playback without buffering (assuming adequate client-side bandwidth).

---

### User Story 4 - Automated RSS Feed Downloads (Priority: P4)

Users can configure RSS feed monitoring to automatically download new torrents matching specified filters (e.g., TV shows, podcasts, Linux distributions). This enables automated content acquisition without manual intervention.

**Why this priority**: Convenience feature for power users. This is P4 because it's an enhancement to the core download functionality (P1), not required for basic operation.

**Independent Test**: Can be fully tested by adding an RSS feed URL (e.g., podcast torrent feed), setting up filter rules, waiting for new content to appear in the feed, and verifying automatic download.

**Acceptance Scenarios**:

1. **Given** a user configures an RSS feed with a filter pattern, **When** new torrents matching the filter appear in the feed, **Then** qBittorrent automatically downloads them within the configured refresh interval.

2. **Given** multiple RSS feeds are configured, **When** new content appears across feeds, **Then** all matching torrents are downloaded according to priority and bandwidth limits.

3. **Given** a user updates RSS filter rules, **When** the next refresh occurs, **Then** only torrents matching the new filters are downloaded, and previously matched torrents are not re-downloaded.

---

### User Story 5 - Monitor and Control via Mobile/Desktop Apps (Priority: P5)

Users can monitor and control qBittorrent remotely using mobile apps (iOS/Android) or desktop apps that support the qBittorrent Web API, enabling torrent management from anywhere.

**Why this priority**: Convenience feature for remote access. This is P5 because it's an optional enhancement - the web UI (P1) already provides full functionality.

**Independent Test**: Can be fully tested by installing a qBittorrent remote control app (e.g., qBittorrent Controller on Android), configuring it with the service URL and credentials, and adding/removing torrents remotely.

**Acceptance Scenarios**:

1. **Given** a user has installed a qBittorrent remote app, **When** they configure it with the service URL and authenticate, **Then** they see all active torrents and can pause/resume/delete them.

2. **Given** a user is away from home, **When** they add a magnet link via mobile app, **Then** the download starts immediately on the server and they can monitor progress in real-time.

---

### Edge Cases

- **What happens when storage fills up?** qBittorrent pauses all active downloads and displays an error. Administrators receive Zabbix alerts when storage exceeds 90% capacity. Users must delete completed torrents or expand storage.

- **What happens when the VPN connection drops (if using VPN)?** qBittorrent's network binding ensures downloads stop if the VPN interface goes down, preventing IP leaks. Service automatically resumes when VPN reconnects. Monitoring alerts administrators of VPN failures.

- **What happens when a user uploads malicious torrent files?** qBittorrent has no built-in malware scanning. Administrators should integrate with ClamAV or similar antivirus for automatic scanning of completed downloads, with infected files quarantined.

- **What happens with copyright-protected content?** This is a legal/policy issue, not technical. Administrators must establish acceptable use policies. The infrastructure does not filter or monitor torrent content, but logs are retained for compliance purposes.

- **What happens when multiple users try to download the same torrent?** qBittorrent creates separate instances per user (if multi-user setup) or a single shared download if using a communal configuration. Shared setup saves bandwidth/storage but requires clear file organization policies.

- **What happens during container restart or updates?** qBittorrent saves state to persistent storage. On restart, all torrents resume from their last checkpoint. Seeding continues automatically for completed torrents.

- **What happens if port forwarding fails?** qBittorrent can still download torrents but may have reduced peer connectivity and slower speeds. Seeding is significantly impacted. Administrators should configure proper port forwarding or UPnP for optimal performance.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy qBittorrent-nox (headless, web UI only) in an LXC container on the Proxmox host.

- **FR-002**: System MUST expose qBittorrent web UI via Traefik reverse proxy with HTTPS termination and valid TLS certificate.

- **FR-003**: System MUST protect qBittorrent access using Traefik forward authentication middleware integrated with Keycloak.

- **FR-004**: System MUST configure qBittorrent to store downloaded files in a persistent volume separate from the container root filesystem.

- **FR-005**: System MUST configure qBittorrent to listen only on internal network interfaces, with no direct exposure to WAN.

- **FR-006**: System MUST configure qBittorrent Web API to accept connections from authorized IP ranges and reject unauthorized access.

- **FR-007**: System MUST support torrent addition via .torrent file upload, magnet links, and URLs.

- **FR-008**: System MUST display real-time download/upload statistics including speed, ETA, peer count, and torrent health.

- **FR-009**: System MUST support global and per-torrent bandwidth limits configurable by administrators.

- **FR-010**: System MUST support RSS feed subscription with automatic download based on filter rules.

- **FR-011**: System MUST support seeding ratio limits and seed time limits to manage upload bandwidth and storage.

- **FR-012**: System MUST support torrent categories and tags for user organization.

- **FR-013**: System MUST support search plugins for popular torrent indexers (configurable by administrators).

- **FR-014**: System MUST log all torrent additions, completions, and deletions with user attribution (via Traefik headers).

- **FR-015**: System MUST support automatic torrent deletion after specified seeding time or ratio is met.

- **FR-016**: System MUST expose downloaded files via SMB and/or NFS network shares with LDAP-based access control.

- **FR-017**: System MUST support both HTTP and HTTPS for Web UI access (HTTPS enforced via Traefik).

- **FR-018**: System MUST support integration with external download managers and remote control applications via Web API.

### Infrastructure Requirements *(for Proxmox deployments)*

- **IR-001**: System MUST provision a new LXC container with Debian 13 (Trixie) template, assigned container ID in the service range (e.g., 70).

- **IR-002**: LXC container MUST be assigned a static IP address on the DMZ network (172.16.10.0/24).

- **IR-003**: LXC container MUST be allocated at least 1 GB RAM and 2 vCPU cores (minimum), with ability to increase for high-traffic usage.

- **IR-004**: System MUST provision persistent storage volume for downloads (minimum 100 GB, expandable to 1+ TB based on use case).

- **IR-005**: System MUST configure firewall rules allowing qBittorrent to access BitTorrent tracker ports (typically 6881-6889 TCP/UDP) and DHT (UDP 6881).

- **IR-006**: System MUST register qBittorrent service in NetBox inventory with IP address, container ID, hostname, and purpose.

- **IR-007**: System MUST configure Zabbix monitoring for qBittorrent process health, disk usage, and network bandwidth.

- **IR-008**: System MUST configure automatic backups for qBittorrent configuration files (config.conf, RSS rules) but exclude downloaded content.

- **IR-009**: System MUST configure Traefik router and middleware for qBittorrent with hostname (e.g., torrent.viljo.se).

- **IR-010**: System SHOULD consider optional VPN integration (WireGuard/OpenVPN) to route torrent traffic through VPN for privacy.

### Security Requirements *(mandatory for all services)*

- **SR-001**: qBittorrent Web UI MUST be accessible only via HTTPS with valid TLS certificate (enforced by Traefik).

- **SR-002**: qBittorrent MUST authenticate users via Traefik forward auth, with no bypass mechanism allowing direct access.

- **SR-003**: qBittorrent Web API password MUST be stored in Ansible Vault and generated with cryptographically secure random values.

- **SR-004**: System MUST disable qBittorrent's built-in authentication if using Traefik forward auth, preventing credential duplication.

- **SR-005**: Downloaded files MUST be stored with appropriate filesystem permissions (e.g., user-specific directories with 0700, shared directories with 0755).

- **SR-006**: System MUST implement firewall rules restricting qBittorrent container access to only required outbound ports (DHT, trackers, peers).

- **SR-007**: System MUST log all Web UI access attempts with source IP and authentication status for security auditing.

- **SR-008**: System MUST prevent directory traversal attacks by restricting qBittorrent's file access to designated download paths only.

- **SR-009**: System MUST implement rate limiting on Web UI to prevent brute-force attacks or API abuse (Traefik middleware).

- **SR-010**: System SHOULD integrate with ClamAV or similar antivirus for scanning completed downloads (optional but recommended).

- **SR-011**: System MUST NOT store any plaintext passwords in qBittorrent configuration files or Ansible playbooks.

- **SR-012**: System SHOULD implement VPN kill switch if VPN is used, ensuring torrent traffic never leaks to WAN if VPN fails.

### Key Entities

- **Torrent**: A file download task consisting of a .torrent metadata file or magnet link, tracked by BitTorrent protocol. Contains files, trackers, piece hashes, and metadata. Managed by qBittorrent.

- **Download Queue**: Collection of active, paused, and completed torrents with their current state (downloading, seeding, paused, error). Persisted to qBittorrent state file.

- **RSS Feed**: External URL providing torrent announcements in RSS format. Monitored by qBittorrent at configurable intervals. Triggers automatic downloads based on filter rules.

- **Web UI Session**: Authenticated user session allowing access to qBittorrent dashboard. Created after successful Traefik forward auth validation.

- **Storage Volume**: Persistent filesystem location where downloaded files are stored. Mounted into LXC container and exposed via SMB/NFS shares.

- **Category**: User-defined organizational label for torrents (e.g., "Movies", "Linux ISOs", "Podcasts"). Used for sorting and applying different download paths.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can add a torrent and begin downloading within 15 seconds of submitting magnet link or .torrent file.

- **SC-002**: qBittorrent web interface loads and displays torrent list in under 3 seconds on initial page load.

- **SC-003**: Downloaded files are accessible via SMB/NFS share within 60 seconds of torrent completion.

- **SC-004**: Authentication via Traefik/Keycloak completes successfully with zero unauthorized access attempts succeeding in security testing.

- **SC-005**: RSS feeds are checked every 15 minutes (configurable) and new matching torrents begin downloading automatically within 1 minute of detection.

- **SC-006**: qBittorrent maintains 99% uptime over 30-day period post-deployment, excluding planned maintenance.

- **SC-007**: Container resource usage (CPU, RAM, disk I/O) remains within allocated limits during sustained torrent activity (10+ active torrents).

- **SC-008**: Backup and restore procedures successfully recover qBittorrent configuration and torrent state without data loss.

- **SC-009**: Mobile app integration successfully connects and controls torrents remotely with under 5 seconds latency for add/pause/resume operations.

- **SC-010**: Port forwarding (if configured) achieves at least 50% peer connectivity improvement compared to non-forwarded setup, measured by average peer count.

## Assumptions

- Proxmox host has sufficient storage capacity for anticipated torrent downloads (100 GB minimum, 1 TB+ recommended).
- Network bandwidth supports BitTorrent traffic without severely impacting other infrastructure services (recommend QoS if shared bandwidth).
- Users will primarily download legal content (Linux distributions, open-source software, Creative Commons media). Acceptable use policy enforcement is administrative, not technical.
- qBittorrent latest stable version is available in Debian repositories or can be installed via official PPA/binaries.
- Traefik reverse proxy is already deployed and configured for forward authentication middleware.
- Keycloak SSO integration is functional (may depend on spec 001-google-oauth-keycloak being completed).
- SMB/NFS file sharing services are already deployed or will be configured as part of this implementation.
- Users have basic understanding of BitTorrent protocol and torrent management (adding, seeding, ratio management).
- Network firewall allows outbound BitTorrent traffic (TCP/UDP 6881-6889, DHT UDP 6881) or specific ports can be configured.
- Optional VPN integration (if desired) requires separate WireGuard/OpenVPN configuration (could reference spec 006-wireguard-vpn).
- No enterprise-grade torrent management features required (e.g., multi-user quotas, billing, usage analytics beyond basic logs).
