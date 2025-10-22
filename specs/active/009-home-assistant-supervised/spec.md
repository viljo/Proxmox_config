# Feature Specification: Home Assistant Supervised

**Feature Branch**: `009-home-assistant-supervised`
**Created**: 2025-10-22
**Status**: Active
**Input**: User requirement: "implement homeassistant with ability to run its own additions like Hass.io"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Home Automation Control with Add-ons (Priority: P1)

Users need a fully-featured Home Assistant installation that supports add-ons (formerly Hass.io) to extend functionality with additional services like MQTT brokers, database managers, file editors, and community integrations.

**Why this priority**: This is the primary purpose - providing a Home Assistant installation that can run the full ecosystem of add-ons, not just the core platform.

**Independent Test**: Can be fully tested by accessing the Home Assistant web interface at `https://ha.viljo.se` (or configured domain), navigating to Settings > Add-ons, and verifying the Add-on Store is accessible with available add-ons.

**Acceptance Scenarios**:

1. **Given** Home Assistant is deployed, **When** user accesses web interface, **Then** Home Assistant loads with valid HTTPS and shows Supervisor in sidebar
2. **Given** user navigates to Add-on Store, **When** store loads, **Then** official and community add-ons are available for installation
3. **Given** user installs an add-on, **When** installation completes, **Then** add-on starts and integrates with Home Assistant
4. **Given** user configures automation, **When** trigger conditions are met, **Then** actions execute correctly across core and add-on services

---

### User Story 2 - Container Deployment with Docker Support (Priority: P2)

Infrastructure administrators need Home Assistant Supervised deployed in an LXC container with Docker support, allowing the Supervisor to manage add-on containers.

**Why this priority**: Required for add-on functionality - the Supervisor uses Docker to run add-ons as isolated containers.

**Independent Test**: Can be tested by verifying LXC container (CT 57) exists with Docker installed, Home Assistant Supervisor is running, and can list Docker containers for add-ons.

**Acceptance Scenarios**:

1. **Given** Ansible playbook is executed, **When** deployment completes, **Then** LXC container 57 exists with Docker and Home Assistant Supervised installed
2. **Given** container is running, **When** administrator checks Docker status, **Then** Docker service is active and Supervisor containers are running
3. **Given** add-on is installed, **When** add-on starts, **Then** new Docker container appears for the add-on
4. **Given** Proxmox host reboots, **When** system comes back online, **Then** container starts and all Home Assistant services resume

---

### User Story 3 - Persistent Configuration and Updates (Priority: P3)

Home Assistant configuration, automations, and add-on data must persist across container restarts and support automatic updates through the Supervisor.

**Why this priority**: Enhances reliability and maintainability, but basic functionality works without automatic updates.

**Independent Test**: Can be tested by creating automation, restarting container, and verifying automation persists. Then checking Supervisor for available updates.

**Acceptance Scenarios**:

1. **Given** user creates automations and configurations, **When** container restarts, **Then** all configurations persist correctly
2. **Given** Home Assistant update is available, **When** user triggers update through Supervisor, **Then** update installs without data loss
3. **Given** add-on update is available, **When** user updates add-on, **Then** add-on updates with configuration preserved
4. **Given** backup is created through Supervisor, **When** backup completes, **Then** full system backup is available for restore

---

### Edge Cases

- What happens when Docker service crashes inside the container?
- How does system handle add-on container resource exhaustion?
- What occurs if Supervisor loses connection to Docker?
- How are add-on installation failures communicated to users?
- What happens if disk space runs out during add-on installation?
- How does system handle conflicting port assignments between add-ons?
- What occurs when Home Assistant Core updates break add-on compatibility?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy Home Assistant Supervised in LXC container on management network
- **FR-002**: System MUST install Docker as prerequisite for Supervisor
- **FR-003**: System MUST install Home Assistant Supervisor for add-on management
- **FR-004**: System MUST expose Home Assistant web interface on port 8123
- **FR-005**: System MUST provide access to Supervisor Add-on Store
- **FR-006**: System MUST support installation and management of official add-ons
- **FR-007**: System MUST support installation and management of community add-ons
- **FR-008**: System MUST persist configuration data across container restarts
- **FR-009**: System MUST configure container to start automatically on Proxmox boot
- **FR-010**: System MUST maintain idempotent deployment (safe to re-run Ansible)
- **FR-011**: System MUST support Supervisor-managed backups and restores
- **FR-012**: System MUST allow updates through Supervisor interface

### Infrastructure Requirements *(for Proxmox deployments)*

- **IR-001**: Service MUST run in privileged LXC container (CT 57) for Docker/nesting support
- **IR-002**: Container MUST be deployed on vmbr2 (Management) at 172.16.10.57/24
- **IR-003**: Container MUST use minimum 2GB RAM, 2 CPU cores, 32GB disk (configurable)
- **IR-004**: Container MUST enable nesting feature for Docker container support
- **IR-005**: Container MUST integrate with Traefik for external HTTPS access
- **IR-006**: Configuration MUST be managed via Ansible for reproducibility
- **IR-007**: Container MUST use Debian 12 as base (required for Home Assistant Supervised)
- **IR-008**: Container MUST have sufficient resources for multiple add-ons
- **IR-009**: Container MUST support systemd for Supervisor service management

### Security Requirements *(mandatory for all services)*

- **SR-001**: Container MAY run as privileged LXC due to Docker requirements (security trade-off)
- **SR-002**: Container root password MUST be stored in Ansible Vault
- **SR-003**: Home Assistant MUST be accessible ONLY via HTTPS through Traefik
- **SR-004**: Add-on containers MUST be isolated from each other via Docker networking
- **SR-005**: Supervisor API access MUST be restricted to authenticated users
- **SR-006**: Container MUST run with nesting enabled for Docker (documented security consideration)
- **SR-007**: Sensitive configuration MUST be stored in Home Assistant secrets.yaml
- **SR-008**: Backup files MUST be stored securely with encryption option available

### Key Entities

- **Home Assistant Container**: LXC container (CT 57) running Debian 12 with Docker
- **Docker Service**: Container runtime for Home Assistant Supervisor and add-ons
- **Home Assistant Supervisor**: Management system for Home Assistant, add-ons, and updates
- **Home Assistant Core**: Core home automation platform
- **Add-on Containers**: Docker containers managed by Supervisor for extended functionality
- **Configuration Data**: Persistent storage at `/usr/share/hassio` for all HA data
- **Traefik Route**: Reverse proxy configuration directing external traffic to port 8123
- **DNS Record**: Domain mapping (ha.viljo.se) pointing to Traefik
- **TLS Certificate**: Let's Encrypt certificate automatically managed by Traefik

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully access Home Assistant via HTTPS with valid certificate
- **SC-002**: Add-on Store is accessible and can install/manage add-ons
- **SC-003**: Home Assistant starts automatically within 60 seconds of Proxmox host boot
- **SC-004**: System maintains 99% uptime during evaluation period
- **SC-005**: Ansible deployment completes in under 10 minutes (full container provisioning with Docker)
- **SC-006**: Add-on installation completes in under 5 minutes for typical add-ons
- **SC-007**: Configuration persists correctly across container restarts
- **SC-008**: Supervisor updates can be applied successfully without data loss
- **SC-009**: System can run minimum 5 concurrent add-ons without performance degradation
- **SC-010**: Backup creation completes in under 10 minutes for standard configuration

## Assumptions

- Traefik reverse proxy is deployed and operational in DMZ/Management network
- DNS record for Home Assistant domain is configured and points to Traefik
- vmbr2 (Management network) exists with 172.16.10.0/24 addressing
- Firewall forwards necessary traffic to Traefik
- Debian 12 template is available for container creation (Debian 13 not yet supported by HA Supervised)
- Administrator has Ansible access to Proxmox host
- Internet access is available for downloading Docker images and add-ons
- Sufficient storage is available on Proxmox for container and Docker volumes

## Dependencies

- Proxmox VE host with LXC support
- vmbr2 (Management network) configured and operational
- Traefik reverse proxy deployed for HTTPS termination
- Firewall LXC forwarding HTTP/HTTPS traffic
- DNS service for Home Assistant domain
- Ansible for configuration management
- Debian 12 template for LXC containers
- Internet connectivity for Docker Hub and Home Assistant repositories
- AppArmor support in kernel for Docker security

## Out of Scope

- Home Assistant OS installation (full OS vs Supervised on Debian)
- Custom add-on development
- Integration with specific IoT devices (user configurable)
- Advanced network configurations (VLANs for IoT devices)
- High availability or clustering
- Custom Supervisor modifications
- Migration from existing Home Assistant installations
- Specific automation blueprints or configurations
- Third-party integration setup (user's responsibility)
- Database optimization for large installations
- Advanced monitoring beyond Supervisor's built-in tools

## Implementation Notes

### Home Assistant Installation Methods

Home Assistant offers several installation methods:

1. **Home Assistant OS**: Full operating system (not suitable for LXC)
2. **Home Assistant Supervised**: Full installation with Supervisor on Linux (chosen approach)
3. **Home Assistant Container**: Docker container without Supervisor (no add-ons)
4. **Home Assistant Core**: Python venv installation (no add-ons, previous implementation)

This specification implements **Home Assistant Supervised** to enable add-on support while running in an LXC container.

### Technical Requirements for Supervised Installation

- **Operating System**: Debian 12 (Bookworm) required
- **Architecture**: amd64/x86_64
- **Docker**: Version 20.10 or newer
- **systemd**: Required for Supervisor service
- **Dependencies**: apparmor, jq, wget, curl, udisks2, libglib2.0-bin, network-manager, dbus
- **Kernel**: AppArmor support required

### Resource Recommendations

Based on Home Assistant documentation and add-on usage:

- **Minimum**: 2GB RAM, 2 cores, 32GB disk
- **Recommended**: 4GB RAM, 4 cores, 64GB disk
- **Optimal**: 8GB RAM, 4-6 cores, 128GB disk (for many add-ons and media)

### Container Configuration

The container MUST be configured with:
- `features: nesting=1` - Required for Docker
- Privileged mode - Required for full Docker support
- Sufficient memory for multiple containers
- Adequate disk space for Docker images and volumes

## Migration from Core Installation

Users with existing Home Assistant Core installations (Python venv) need to understand:

1. This is a different installation method
2. Configuration files (configuration.yaml, automations, etc.) can be migrated
3. Custom components need to be reinstalled
4. Database may need migration for historical data
5. Backup recommended before transition

## References

- [Home Assistant Installation Methods](https://www.home-assistant.io/installation/)
- [Home Assistant Supervised Installation](https://github.com/home-assistant/supervised-installer)
- [Home Assistant Add-on Development](https://developers.home-assistant.io/docs/add-ons)
- [Docker in LXC Containers](https://pve.proxmox.com/wiki/Linux_Container#pct_container_features)
