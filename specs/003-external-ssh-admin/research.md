# Research: External SSH Access via viljo.se

**Feature**: External SSH Access via viljo.se
**Date**: 2025-10-20
**Purpose**: Document technology decisions, best practices, and implementation patterns

## Research Areas

### 1. SSH Hardening Best Practices

**Decision**: Implement OpenSSH hardening based on Mozilla SSH guidelines and CIS benchmarks

**Rationale**:
- Industry-standard approach to securing SSH against common attacks
- Well-documented and tested configurations
- Compatible with Debian/Proxmox base system
- Balances security with administrator usability

**Key Configuration Elements**:
- Disable password authentication (key-based only)
- Disable root password login (keys only)
- Use non-standard port (recommendation: 2222 or similar)
- Limit SSH protocol to version 2
- Configure strong ciphers and MACs
- Set ClientAliveInterval to prevent hung sessions
- Disable X11 forwarding (not needed for server management)
- Restrict SSH access to specific users/groups
- Enable SSH key rotation support

**Alternatives Considered**:
- **Port knocking**: Rejected - adds complexity without significant security benefit when combined with fail2ban
- **VPN-only access**: Rejected - out of scope, user wants direct SSH
- **OAuth/OIDC SSH**: Rejected - overly complex for single-host access, better suited for infrastructure-wide gateway

**Implementation Approach**:
- Template `/etc/ssh/sshd_config` via Jinja2
- Use Ansible's `lineinfile` or `template` module for idempotent config
- Handler to restart sshd service after config changes
- Validate config before restarting (`sshd -t`)

### 2. Fail2ban Configuration for SSH Protection

**Decision**: Use fail2ban with custom SSH jail configuration

**Rationale**:
- De-facto standard for brute force protection on Linux
- Lightweight and battle-tested
- Integrates with systemd-journald and syslog
- Highly configurable ban times and thresholds
- Already available in Debian repositories

**Configuration Strategy**:
- Monitor SSH auth logs via systemd-journal backend
- Ban after 5 failed attempts within 10 minutes
- Ban duration: 1 hour (escalating for repeat offenders)
- Whitelist internal network ranges (192.168.0.0/16)
- Send alerts to syslog for Wazuh ingestion (if available)

**Alternatives Considered**:
- **DenyHosts**: Rejected - less actively maintained than fail2ban
- **SSHGuard**: Rejected - fail2ban has better integration with existing infrastructure
- **IPTables rate limiting**: Rejected - less flexible than fail2ban, harder to manage whitelist

**Implementation Approach**:
- Install fail2ban via apt
- Template `/etc/fail2ban/jail.d/sshd.conf` with custom settings
- Enable and start fail2ban service
- Handler to restart fail2ban on config changes

### 3. Dynamic DNS with Loopia

**Decision**: Leverage existing `loopia_ddns` Ansible role for viljo.se DNS updates

**Rationale**:
- Loopia DDNS infrastructure already exists in codebase (roles/loopia_ddns/)
- Provides API-based DNS updates for dynamic IP addresses
- Eliminates need for manual DNS changes when ISP assigns new IP
- Constitutional requirement to reuse existing infrastructure

**Configuration Requirements**:
- Ensure loopia_ddns role is configured for viljo.se domain
- Set update interval (recommend: 5 minutes)
- Configure DNS A record pointing to external interface
- Store Loopia API credentials in Ansible Vault

**Alternatives Considered**:
- **Static IP**: Rejected - assumption states dynamic IP is possible, static IP has recurring cost
- **CloudFlare DDNS**: Rejected - Loopia infrastructure already exists
- **Manual DNS updates**: Rejected - violates automation principle

**Implementation Approach**:
- Review and verify existing loopia_ddns role
- Add viljo.se domain to DDNS configuration
- Ensure role runs on schedule (cron or systemd timer)

### 4. Port Forwarding Strategy

**Decision**: Document manual port forwarding steps with optional automation for supported routers

**Rationale**:
- Consumer routers rarely have standardized APIs for automation
- Manual configuration is one-time setup with low change frequency
- Enterprise routers (if available) may support UPnP or custom APIs
- Constitutional violation justified by hardware limitations

**Required Configuration**:
- Forward external port (recommend: non-standard like 2222) to 192.168.1.3:22
- Configure persistent static DHCP reservation for 192.168.1.3
- Ensure firewall permits inbound traffic on forwarded port
- Document rollback procedure (delete forwarding rule)

**Automation Possibilities** (router-dependent):
- **UPnP/NAT-PMP**: If supported, use miniupnpc or ansible-upnp module
- **Router API**: If router has REST API (e.g., EdgeRouter, MikroTik), use ansible.netcommon
- **Manual fallback**: Provide screenshot-based guide in quickstart.md

**Alternatives Considered**:
- **DMZ mode**: Rejected - exposes all ports, security risk
- **Reverse SSH tunnel**: Rejected - requires external VPS, adds complexity
- **Ngrok/similar**: Rejected - third-party dependency, potential security/privacy concern

**Implementation Approach**:
- Add port forwarding task to firewall role (if router supports automation)
- Otherwise, document manual steps in quickstart.md with screenshots
- Validate port forwarding via external connectivity test

### 5. DNS Configuration Best Practices

**Decision**: Configure viljo.se A record via Loopia DNS API with TTL of 300 seconds (5 minutes)

**Rationale**:
- Short TTL enables faster IP change propagation
- Loopia API allows programmatic DNS updates
- Integrates with existing loopia_ddns role
- Meets requirement of <5 minute DNS update (SC-007)

**Configuration Details**:
- DNS record type: A record
- Hostname: viljo.se (or ssh.viljo.se if subdomain preferred)
- TTL: 300 seconds
- Value: Current external IP (updated by DDNS)

**Alternatives Considered**:
- **Long TTL (1 hour+)**: Rejected - fails to meet 5-minute update requirement
- **CNAME to DDNS provider**: Rejected - adds dependency and DNS query overhead
- **Multiple A records**: Rejected - not needed for single host

**Implementation Approach**:
- Use existing loopia_dns role (if separate from loopia_ddns)
- Configure initial A record via Loopia web UI or API
- Ensure loopia_ddns updates this record on IP changes

### 6. SSH Key Management

**Decision**: Use ed25519 SSH keys stored in Ansible Vault for automated deployments

**Rationale**:
- Ed25519 provides better security than RSA at smaller key sizes
- Ansible Vault ensures keys aren't committed in plaintext
- Supports administrator's personal keys for manual access
- Follows constitutional requirement for secret management

**Key Management Strategy**:
- Store deployment keys in `group_vars/all/secrets.yml` (Ansible Vault)
- Support multiple authorized_keys for team members
- Template `~/.ssh/authorized_keys` on Proxmox host
- Rotate keys annually (document in runbook)

**Alternatives Considered**:
- **RSA 4096**: Rejected - ed25519 is more efficient and secure
- **Certificate-based SSH**: Rejected - overly complex for small team
- **Manual key distribution**: Rejected - violates automation principle

**Implementation Approach**:
- Generate ed25519 keys: `ssh-keygen -t ed25519`
- Encrypt keys in Ansible Vault
- Template authorized_keys file via Ansible
- Handler to set correct permissions (600)

### 7. Audit Logging and Monitoring

**Decision**: Log SSH connections to syslog/journald with optional Wazuh SIEM integration

**Rationale**:
- Meets constitutional requirement for audit logging
- Syslog is standard on Debian/Proxmox
- Wazuh integration provides centralized security monitoring (if deployed)
- Fail2ban logs provide brute force attack visibility

**Logging Strategy**:
- SSH logs: `/var/log/auth.log` and journald
- Fail2ban logs: `/var/log/fail2ban.log`
- Log format: Include timestamp, source IP, username, outcome
- Retention: 90 days local, longer in Wazuh if available

**Alternatives Considered**:
- **Session recording**: Rejected - out of scope (spec states metadata only)
- **Splunk/ELK**: Rejected - Wazuh already exists in infrastructure
- **No logging**: Rejected - violates security requirements

**Implementation Approach**:
- Configure sshd LogLevel to VERBOSE
- Ensure rsyslog/journald is running
- Configure Wazuh agent (if available) to forward auth logs
- Create fail2ban log monitoring alerts

## Technology Stack Summary

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Automation | Ansible | 2.15+ | Configuration management |
| SSH Server | OpenSSH | 8.x+ | Remote access |
| Brute Force Protection | fail2ban | 0.11+ | Attack mitigation |
| Dynamic DNS | Loopia DDNS | Existing role | IP address updates |
| DNS Management | Loopia DNS API | Latest | A record configuration |
| Secret Management | Ansible Vault | Built-in | Credential encryption |
| Audit Logging | syslog/journald | System default | Connection tracking |
| Monitoring | Wazuh (optional) | Existing | SIEM integration |

## Implementation Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Locked out due to SSH misconfiguration | Medium | High | Test in staging first, maintain console access, backup config |
| Brute force attacks overwhelm fail2ban | Low | Medium | Conservative ban thresholds, monitor logs, consider IP whitelist |
| Dynamic IP change breaks access | Low | Medium | Short DNS TTL, reliable DDNS monitoring, fallback via VPN if available |
| Router port forwarding resets | Low | Medium | Document manual reconfiguration, consider static NAT rules |
| DNS propagation delays | Low | Low | 300s TTL minimizes delay, verify with multiple DNS resolvers |

## Open Questions Resolved

1. **Q: Which SSH port should be exposed externally?**
   - A: Use non-standard port (e.g., 2222) to reduce automated scan traffic, configure via Ansible variable

2. **Q: Should we use password or key-based authentication?**
   - A: Key-based only for external access, disable password authentication per security requirements

3. **Q: How to handle SSH key rotation?**
   - A: Manual annual rotation documented in runbook, automated rotation out of scope for v1

4. **Q: Can router port forwarding be automated?**
   - A: Router-dependent - attempt automation if API available, otherwise document manual steps

5. **Q: Should we create subdomain (ssh.viljo.se) or use apex (viljo.se)?**
   - A: Use apex domain (viljo.se) per spec requirement, can be made configurable via Ansible variable

## Next Steps

Phase 1 artifacts to be created:
1. **data-model.md**: Configuration entities and their relationships
2. **contracts/**: SSH configuration contracts (sshd_config template)
3. **quickstart.md**: Step-by-step setup guide for administrators
