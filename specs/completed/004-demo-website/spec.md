# Feature Specification: Demo Website

**Feature Branch**: `004-demo-website`
**Created**: 2025-10-20
**Status**: Draft
**Input**: User description: "demo website"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Public HTTPS Demo Site (Priority: P1)

Users need to access a demonstration website that showcases the Proxmox infrastructure's ability to host public-facing HTTPS applications with automatic TLS certificate management through Traefik.

**Why this priority**: This is the primary purpose - demonstrating that the infrastructure can securely host web applications with proper TLS termination.

**Independent Test**: Can be fully tested by navigating to `https://demo.viljo.se` (or configured domain) in a web browser and verifying the page loads with valid HTTPS certificate.

**Acceptance Scenarios**:

1. **Given** user navigates to demo website URL, **When** page loads, **Then** browser shows valid HTTPS certificate and demo content displays
2. **Given** user access demo site without HTTPS, **When** they use HTTP protocol, **Then** they are redirected to HTTPS
3. **Given** demo site is configured, **When** user views page source, **Then** customizable title and message are displayed

---

### User Story 2 - Container Deployment and Management (Priority: P2)

Infrastructure administrators need the demo website deployed as an LXC container in the DMZ network, automatically configured and started on boot.

**Why this priority**: Required for the website to be accessible but can be implemented once the container infrastructure is established.

**Independent Test**: Can be tested by verifying LXC container (CT 2300) exists, is running, and nginx service is active inside the container.

**Acceptance Scenarios**:

1. **Given** Ansible playbook is executed, **When** deployment completes, **Then** LXC container 2300 exists on DMZ network (172.16.10.60)
2. **Given** Proxmox host reboots, **When** system comes back online, **Then** demo site container automatically starts
3. **Given** container is running, **When** administrator checks nginx status, **Then** nginx service is active and serving content

---

### User Story 3 - Traefik Integration and Routing (Priority: P3)

The demo website must be accessible through Traefik reverse proxy with automatic HTTPS certificate provisioning and routing rules.

**Why this priority**: Enhances the demo by showing proper production-grade reverse proxy integration, but basic container functionality works independently.

**Independent Test**: Can be tested by verifying Traefik routes traffic to the demo site container and automatic certificate issuance works.

**Acceptance Scenarios**:

1. **Given** Traefik is configured, **When** request arrives for demo domain, **Then** traffic is routed to container on port 80
2. **Given** demo site is accessed externally, **When** HTTPS connection is established, **Then** Traefik serves valid Let's Encrypt certificate
3. **Given** certificate expires, **When** renewal period arrives, **Then** Traefik automatically renews certificate

---

### Edge Cases

- What happens when nginx service crashes inside the container?
- How does system handle container resource exhaustion (memory/CPU)?
- What occurs if Traefik cannot reach the demo site container?
- How are container startup failures communicated to administrators?
- What happens if DNS record for demo site is misconfigured?
- How does system handle multiple simultaneous HTTP requests?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy demo website in LXC container on DMZ network (vmbr3)
- **FR-002**: System MUST install and configure nginx web server in container
- **FR-003**: System MUST serve static HTML content with customizable title and message
- **FR-004**: System MUST expose website on port 80 within DMZ network
- **FR-005**: System MUST configure container to start automatically on Proxmox boot
- **FR-006**: System MUST maintain idempotent deployment (safe to re-run Ansible)
- **FR-007**: Website content MUST be customizable via Ansible variables
- **FR-008**: System MUST provide status visibility (container running, nginx active)

### Infrastructure Requirements *(for Proxmox deployments)*

- **IR-001**: Service MUST run in unprivileged LXC container (CT 2300)
- **IR-002**: Container MUST be deployed on vmbr3 (DMZ) at 172.16.10.60/24
- **IR-003**: Container MUST use 1GB RAM, 1 CPU core, 8GB disk (configurable)
- **IR-004**: Container MUST integrate with Traefik for external HTTPS access
- **IR-005**: Configuration MUST be managed via Ansible for reproducibility
- **IR-006**: Container MUST use Debian 13 template as base image

### Security Requirements *(mandatory for all services)*

- **SR-001**: Container MUST run as unprivileged LXC
- **SR-002**: Container root password MUST be stored in Ansible Vault
- **SR-003**: Website MUST be accessible ONLY via HTTPS through Traefik (no direct HTTP)
- **SR-004**: Container MUST run with minimal privileges (nesting enabled for demo purposes)
- **SR-005**: Content updates MUST be managed via Ansible (no manual file edits)

### Key Entities

- **Demo Site Container**: LXC container (CT 2300) running nginx on Debian 13
- **Nginx Service**: Web server serving static HTML content on port 80
- **Demo Content**: HTML pages (index.html, hello.html) with customizable branding
- **Traefik Route**: Reverse proxy configuration directing external traffic to container
- **DNS Record**: Domain mapping (e.g., demo.viljo.se) pointing to Traefik
- **TLS Certificate**: Let's Encrypt certificate automatically managed by Traefik

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully access demo website via HTTPS with valid certificate
- **SC-002**: Page load time completes in under 2 seconds from external networks
- **SC-003**: Container starts automatically within 30 seconds of Proxmox host boot
- **SC-004**: Website maintains 99% uptime during evaluation period
- **SC-005**: Ansible deployment completes in under 5 minutes (full container provisioning)
- **SC-006**: Certificate renewal succeeds automatically with zero manual intervention
- **SC-007**: Website handles minimum 100 concurrent HTTP requests without degradation

## Assumptions

- Traefik reverse proxy is deployed and operational in DMZ network
- DNS record for demo site domain is configured and points to Traefik/firewall WAN IP
- Loopia DDNS keeps DNS updated with current external IP
- vmbr3 (DMZ network) exists with 172.16.10.0/24 addressing
- Firewall LXC forwards port 80/443 traffic to Traefik
- Debian 13 template is available for container creation
- Administrator has Ansible access to Proxmox host
- Basic web browsing from internet to infrastructure is permitted

## Dependencies

- Proxmox VE host with LXC support
- vmbr3 (DMZ network) configured and operational
- Traefik reverse proxy deployed in DMZ
- Firewall LXC forwarding HTTP/HTTPS traffic
- DNS service for demo site domain (via Loopia or other provider)
- Ansible for configuration management
- Debian 13 template for LXC containers

## Out of Scope

- Dynamic content generation (PHP, Python, Node.js applications)
- Database integration (MySQL, PostgreSQL)
- User authentication or login functionality
- Content management system (WordPress, etc.)
- Custom application deployment beyond static HTML
- Load balancing across multiple containers
- Geographic distribution or CDN integration
- Advanced monitoring beyond basic container/nginx status checks
