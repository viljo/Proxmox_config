# Feature Specification: Links Portal & Matrix Landing Page

**Feature Branch**: `010-links-portal`
**Created**: 2025-10-22
**Status**: Completed
**Replaces**: Demo Website (004) functionality

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Service Discovery Portal (Priority: P1)

Users need a centralized portal page that provides direct links to all public-facing services deployed in the infrastructure, replacing the demo website with a functional service directory.

**Why this priority**: This is the primary purpose - providing users with easy access to all available services through a single entry point.

**Independent Test**: Can be fully tested by navigating to `https://links.viljo.se` in a web browser and verifying all service links are present and functional.

**Acceptance Scenarios**:

1. **Given** user navigates to links.viljo.se, **When** page loads, **Then** browser shows all deployed services with descriptions and working links
2. **Given** user clicks on a service card, **When** link is activated, **Then** user is navigated to the correct service URL
3. **Given** user accesses the page on mobile device, **When** page loads, **Then** layout is responsive and cards are properly displayed

---

### User Story 2 - Matrix Landing Page for Root Domain (Priority: P1)

Users and visitors need an aesthetically pleasing landing page at the root domain (viljo.se) that showcases a matrix-style animation without any other content.

**Why this priority**: Provides a professional and visually interesting landing page for the root domain.

**Independent Test**: Can be tested by navigating to `https://viljo.se` and verifying the matrix rain animation displays correctly.

**Acceptance Scenarios**:

1. **Given** user navigates to viljo.se, **When** page loads, **Then** browser displays full-screen matrix rain animation
2. **Given** page is loaded, **When** user resizes browser window, **Then** animation adapts to new window size
3. **Given** user leaves page open, **When** time passes, **Then** animation continues smoothly without performance degradation

---

### User Story 3 - Automated Service Registry (Priority: P2)

Infrastructure administrators need all new public-facing services to automatically be listed in the links portal to maintain an up-to-date service directory.

**Why this priority**: Ensures the links page remains current as new services are added to the infrastructure.

**Independent Test**: Can be tested by deploying a new service and verifying it appears in the links page after template update.

**Acceptance Scenarios**:

1. **Given** new service is deployed, **When** administrator updates links template, **Then** new service appears in the portal
2. **Given** service is removed from infrastructure, **When** template is updated, **Then** service link is removed from portal
3. **Given** service metadata changes, **When** template is updated, **Then** updated information is reflected in portal

---

### Edge Cases

- What happens when a service is temporarily unavailable but link is still displayed?
- How does the portal handle services with long names or descriptions?
- What occurs if browser has JavaScript disabled (for matrix page)?
- How are service icons/emojis displayed on different browsers and devices?
- What happens if the external domain is misconfigured?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST serve links portal at https://links.viljo.se with all public services listed
- **FR-002**: System MUST serve matrix animation page at https://viljo.se
- **FR-003**: System MUST maintain backward compatibility with demo.viljo.se for existing demos
- **FR-004**: Links portal MUST display service name, description, icon, and URL for each service
- **FR-005**: Links portal MUST be responsive and work on mobile devices
- **FR-006**: Matrix page MUST display animated matrix rain effect using canvas
- **FR-007**: Matrix page MUST be full-screen with no other content
- **FR-008**: System MUST configure nginx to serve different content based on domain name
- **FR-009**: All HTML pages MUST be deployed via Ansible using templates

### Infrastructure Requirements *(for Proxmox deployments)*

- **IR-001**: Service MUST run in same unprivileged LXC container as demo site (CT 60)
- **IR-002**: Container MUST serve multiple domains through nginx virtual hosts
- **IR-003**: Nginx MUST be configured with server blocks for viljo.se, links.viljo.se, and demo.viljo.se
- **IR-004**: Traefik MUST route traffic for all three domains to the same container
- **IR-005**: DNS records MUST exist for @ (root), links, and demo subdomains
- **IR-006**: Configuration MUST be idempotent and managed via Ansible

### Security Requirements *(mandatory for all services)*

- **SR-001**: All domains MUST be accessible ONLY via HTTPS through Traefik
- **SR-002**: Static content MUST NOT contain sensitive information or credentials
- **SR-003**: Container MUST continue to run as unprivileged LXC
- **SR-004**: Content updates MUST be managed via Ansible (no manual edits)

### Service Registry Requirements *(new global requirement)*

- **SRR-001**: ALL new public-facing services MUST be added to links.viljo.se template
- **SRR-002**: Service entries MUST include: name, description, icon/emoji, and full URL
- **SRR-003**: Services MUST be listed in logical groupings (infrastructure, collaboration, media, etc.)
- **SRR-004**: Deprecated or removed services MUST be removed from links template

### Key Entities

- **Links Portal**: HTML page listing all public services with cards and descriptions
- **Matrix Landing Page**: HTML5 canvas-based matrix rain animation
- **Nginx Virtual Hosts**: Server blocks routing traffic based on domain name
- **Service Cards**: Individual service entries with icon, name, description, and link
- **Traefik Routes**: Multiple routes directing different domains to same container
- **DNS Records**: Three DNS entries (root, links, demo) pointing to infrastructure

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Links portal displays all 10+ deployed public services with correct URLs
- **SC-002**: All service links are functional and navigate to correct destinations
- **SC-003**: Matrix animation runs at 30+ FPS on standard desktop browsers
- **SC-004**: Pages load in under 2 seconds from external networks
- **SC-005**: Nginx serves correct page based on domain name 100% of the time
- **SC-006**: Responsive design works correctly on devices from 320px to 4K resolution
- **SC-007**: All three domains (viljo.se, links.viljo.se, demo.viljo.se) accessible via HTTPS

## Current Services Listed

The links portal includes the following deployed services:

1. **GitLab** - Repository management and CI/CD platform (gitlab.viljo.se)
2. **Nextcloud** - File storage and collaboration platform (nextcloud.viljo.se)
3. **Jellyfin** - Media streaming and management server (jellyfin.viljo.se)
4. **Home Assistant** - IoT and home automation platform (homeassistant.viljo.se)
5. **NetBox** - Infrastructure documentation and IPAM (netbox.viljo.se)
6. **Keycloak** - Identity and access management (keycloak.viljo.se)
7. **Wazuh** - Security monitoring and threat detection (wazuh.viljo.se)
8. **OpenMediaVault** - Network-attached storage solution (openmediavault.viljo.se)
9. **Zipline** - Screenshot sharing and image hosting (zipline.viljo.se)
10. **qBittorrent** - Torrent client and download manager (qbittorrent.viljo.se)

## Assumptions

- All services listed in links portal are deployed and accessible
- Traefik reverse proxy is operational and can handle multiple routes to same backend
- DNS provider supports multiple records for same domain
- Nginx supports server name-based virtual hosting
- Modern browsers with JavaScript enabled for matrix animation
- Service URLs follow pattern: service-name.viljo.se

## Dependencies

- Existing demo_site role and container (CT 60)
- Traefik reverse proxy with HTTPS/TLS termination
- DNS configuration supporting root and subdomain records
- Ansible for configuration management
- Nginx with virtual host support

## Out of Scope

- Real-time service health checking or status indicators
- User authentication or access control for links page
- Service-specific configuration or management interfaces
- Automated service discovery (manual template updates required)
- Analytics or usage tracking
- Custom branding or theming beyond current design
- Integration with service management APIs
- Automated service registration via CI/CD

## Implementation Notes

### Files Modified/Created

- `roles/demo_site/templates/links.html.j2` - Links portal template (new)
- `roles/demo_site/templates/matrix.html.j2` - Matrix animation template (new)
- `roles/demo_site/templates/nginx-site.conf.j2` - Nginx virtual hosts config (new)
- `roles/demo_site/tasks/main.yml` - Updated to deploy new templates
- `inventory/group_vars/all/main.yml.example` - Updated Traefik/DNS config

### Design Decisions

- **Virtual Hosts**: Nginx server blocks used instead of multiple containers for efficiency
- **Static Content**: Pure HTML/CSS/JS (no backend) for simplicity and performance
- **Same Container**: Reuses demo site container to minimize resource usage
- **Canvas Animation**: Matrix effect uses HTML5 canvas for smooth performance
- **Responsive Grid**: CSS Grid used for service cards with mobile-first design
- **Emoji Icons**: Using emoji instead of icon fonts for zero dependencies

---

**Last Updated**: 2025-10-22
**Implemented By**: Claude Code
**Deployment**: Same container as demo site (CT 60 at 172.16.10.60)
