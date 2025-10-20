# Feature Specification: External SSH Access via viljo.se

**Feature Branch**: `003-external-ssh-admin`
**Created**: 2025-10-20
**Status**: Draft
**Input**: User description: "external ssh admin link"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - External SSH Access to Proxmox Host (Priority: P1)

Administrator needs to securely access the Proxmox host (mother @ 192.168.1.3) from external networks using a friendly domain name (viljo.se). The Proxmox infrastructure uses a Debian firewall LXC container that sits on vmbr2 (WAN) with a public IP, and the Proxmox host itself is on vmbr0 (management network). SSH connections will be port-forwarded through the firewall LXC to reach the Proxmox host.

**Why this priority**: This is the core requirement - enabling remote administration of the Proxmox infrastructure through a simple, memorable domain name.

**Independent Test**: Can be fully tested by connecting from an external network using `ssh root@viljo.se` (or similar) and verifying successful authentication and access to the Proxmox host.

**Acceptance Scenarios**:

1. **Given** administrator is on external network, **When** they connect via `ssh root@viljo.se`, **Then** connection is forwarded through firewall LXC to Proxmox host at 192.168.1.3:22
2. **Given** administrator has valid SSH credentials/keys, **When** they authenticate, **Then** they gain shell access to Proxmox host
3. **Given** DNS is properly configured, **When** administrator uses the viljo.se domain, **Then** name resolution succeeds and connection establishes

---

### User Story 2 - Firewall Port Forwarding (Priority: P2)

The firewall LXC container must forward SSH traffic from WAN (vmbr2) to the Proxmox host management network (192.168.1.3 on vmbr0), ensuring persistent configuration across reboots.

**Why this priority**: Required for external access to work but can be configured once SSH hardening and DNS are working.

**Independent Test**: Can be tested by verifying external SSH connections on port 22 are forwarded to 192.168.1.3 and connections persist after firewall container restarts.

**Acceptance Scenarios**:

1. **Given** firewall port forwarding is configured, **When** external SSH traffic arrives on WAN port 22, **Then** it is forwarded to 192.168.1.3:22
2. **Given** firewall container reboots, **When** system comes back online, **Then** port forwarding rules are automatically restored
3. **Given** connection is established, **When** administrator runs commands, **Then** they execute on the Proxmox host

---

### User Story 3 - Security Hardening (Priority: P3)

SSH access should be secured against common attacks while maintaining usability for legitimate administrators.

**Why this priority**: Enhances security posture but basic SSH security already exists in default Proxmox installation.

**Independent Test**: Can be tested by attempting brute force attacks and verifying they are blocked or rate-limited.

**Acceptance Scenarios**:

1. **Given** multiple failed authentication attempts, **When** threshold is exceeded, **Then** source IP is temporarily blocked
2. **Given** SSH service is exposed externally on standard port 22, **When** fail2ban is active, **Then** brute force attacks are mitigated
3. **Given** security policies are defined, **When** administrator connects, **Then** only secure authentication methods are accepted

---

### Edge Cases

- What happens when viljo.se DNS resolution fails?
- How does system handle dynamic IP changes on vmbr2 interface?
- What occurs if Proxmox host is offline when connection attempt is made?
- How are connection failures communicated to administrators?
- How does system handle multiple simultaneous administrative sessions?
- What happens if vmbr2 interface loses internet connectivity?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST route SSH connections from viljo.se domain to Proxmox host vmbr2 interface
- **FR-002**: System MUST maintain DNS configuration mapping viljo.se to vmbr2 external IP address
- **FR-003**: System MUST configure firewall rules on vmbr2 to allow SSH on port 22
- **FR-004**: System MUST support standard SSH authentication (keys and/or password)
- **FR-005**: System MUST handle dynamic external IP changes on vmbr2 through DNS update mechanism
- **FR-006**: Configuration MUST persist across system reboots
- **FR-007**: System MUST log SSH connection attempts for security auditing
- **FR-008**: System MUST provide clear error messages when connections fail

### Infrastructure Requirements *(for Proxmox deployments)*

- **IR-001**: DNS records for viljo.se MUST point to current vmbr2 external IP address
- **IR-002**: Proxmox host firewall MUST allow SSH on port 22 via vmbr2 interface
- **IR-003**: vmbr2 interface MUST have direct internet connectivity
- **IR-004**: Configuration MUST be managed via Ansible for reproducibility
- **IR-005**: Dynamic DNS update mechanism MUST run if vmbr2 external IP is not static

### Security Requirements *(mandatory for all services)*

- **SR-001**: SSH service MUST use key-based authentication for external access (via firewall)
- **SR-002**: SSH service MAY allow password authentication from internal networks (192.168.x.x)
- **SR-003**: SSH keys MUST be managed securely (no plaintext storage in repositories)
- **SR-004**: System MUST implement fail2ban or similar brute force protection
- **SR-005**: System MUST log all connection attempts (successful and failed)
- **SR-006**: Firewall LXC MUST forward external SSH traffic (WAN:22) to Proxmox host (192.168.1.3:22)
- **SR-007**: Firewall MUST use nftables with persistent configuration across reboots

### Key Entities

- **Proxmox Host**: The primary management server ("mother") at 192.168.1.3 on vmbr0 (management network)
- **Firewall LXC**: Debian container (CT 1) providing NAT/routing between WAN (vmbr2) and internal networks
- **vmbr0**: Management network bridge (192.168.1.0/24) where Proxmox host resides
- **vmbr2**: WAN bridge with public IP (DHCP from ISP) connected to firewall LXC eth0
- **vmbr3**: DMZ bridge (172.16.10.0/24) for service containers
- **External Domain**: viljo.se domain name pointing to firewall WAN IP on vmbr2
- **DNS Record**: Mapping between viljo.se domain and current firewall WAN IP
- **Port Forwarding Rule**: nftables DNAT rule in firewall LXC forwarding WAN:22 → 192.168.1.3:22
- **SSH Audit Log**: Record of connection attempts including timestamp, source IP, and authentication outcome

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Administrator can successfully connect via `ssh root@viljo.se` from any external network
- **SC-002**: DNS resolution for viljo.se completes in under 2 seconds
- **SC-003**: SSH connection establishment completes in under 10 seconds from external networks
- **SC-004**: 100% of connection attempts are logged for security audit
- **SC-005**: Firewall port forwarding and SSH configuration persists through 100% of system reboots
- **SC-006**: Zero unauthorized access incidents during evaluation period
- **SC-007**: Firewall WAN IP changes on vmbr2 are reflected in DNS within 5 minutes

## Assumptions

- Firewall LXC container (CT 1) is deployed and operational on vmbr2/vmbr3
- vmbr2 WAN bridge gets public IP via DHCP from ISP
- Proxmox host is at 192.168.1.3 on vmbr0 management network
- viljo.se domain is registered and DNS can be configured
- Administrator has existing SSH credentials/keys for Proxmox host
- Loopia DDNS already configured and updating viljo.se with firewall WAN IP
- Standard port 22 will be used for SSH access
- Password authentication acceptable from 192.168.x.x internal networks
- Key-based authentication required for external access (via firewall)

## Dependencies

- Firewall LXC container (roles/firewall) - already exists
- DNS service for viljo.se domain configuration
- Loopia DDNS service - already configured to update viljo.se with vmbr2 IP
- Ansible for configuration management
- fail2ban or similar security tooling for brute force protection
- nftables on firewall LXC (already installed)

## Out of Scope

- VPN access (using direct SSH instead)
- Web-based Proxmox console access via viljo.se (SSH only)
- Access to VMs/containers running on Proxmox (only host access)
- Certificate management for HTTPS services
- Multi-factor authentication (can be added later)
