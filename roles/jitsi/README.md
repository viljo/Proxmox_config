# Jitsi Meet Video Conferencing Server

This Ansible role deploys a complete Jitsi Meet video conferencing solution in an LXC container with Docker Compose, integrated with Keycloak SSO for authentication.

## Overview

**Container ID**: 160
**Hostname**: jitsi
**IP Address**: 172.16.10.160/24
**Public URL**: https://meet.viljo.se
**Network**: vmbr3 (DMZ)

## Architecture

### Components

The deployment consists of five Docker containers orchestrated by Docker Compose:

1. **jitsi-web** - Nginx frontend web server
   - Serves the Jitsi Meet web interface
   - Handles HTTPS termination (proxied through Traefik)
   - Port: 8000 (HTTP, proxied by Traefik)

2. **jitsi-prosody** - XMPP server (Prosody)
   - Manages signaling and presence
   - Handles authentication and authorization
   - Internal ports: 5222, 5347, 5280

3. **jitsi-jicofo** - Jitsi Conference Focus
   - Manages conferences and room allocation
   - Coordinates between components
   - Selects video bridges for conferences

4. **jitsi-jvb** - Jitsi Videobridge
   - Handles WebRTC video/audio streams
   - UDP port: 10000 (exposed for direct media streams)
   - Uses STUN servers for NAT traversal

5. **jitsi-jibri** - Recording service (optional)
   - Records meetings to video files
   - Recordings stored on bind-mounted Proxmox host storage
   - Requires `/dev/snd` access and SYS_ADMIN capability

### Authentication Model

**Moderator Role Model**:
- **Authenticated users** (via Keycloak SSO): Automatically receive moderator privileges
- **Anonymous participants**: Join as guests with limited capabilities
- Moderators can: mute participants, remove users, grant/revoke moderator status

**SSO Flow**:
1. User accesses https://meet.viljo.se
2. If authentication is required (meeting created by moderator), redirect to Keycloak
3. Keycloak authenticates via GitLab OAuth
4. User returns to Jitsi with JWT token
5. Prosody validates token and grants moderator role

### Network Configuration

```
Internet → vmbr2 (Firewall) → Traefik (172.16.10.1) → Jitsi Web (172.16.10.160:8000)
                                                     → JVB UDP (172.16.10.160:10000/udp)
```

**Traffic Flows**:
- **HTTP/HTTPS (8000)**: Proxied through Traefik for web interface
- **UDP (10000)**: Direct port forward from firewall for WebRTC media streams
- **XMPP (Internal)**: All signaling happens within Docker network

**Why UDP Port Forwarding is Required**:
- WebRTC prefers UDP for low-latency media streaming
- Clients connect directly to JVB for optimal performance
- Firewall DNAT rule: `udp dport 10000 → 172.16.10.160:10000`

## Configuration

### Container Resources

- **CPU**: 4 cores
- **Memory**: 4096 MB
- **Swap**: 1024 MB
- **Disk**: 64 GB
- **Features**: nesting=1 (required for Docker)

### Storage

**Recordings**: Bind mount from Proxmox host
- **Host path**: `/mnt/storage/jitsi-recordings`
- **Container path**: `/recordings`
- **Purpose**: Persistent storage for meeting recordings, expandable without service interruption

### Environment Variables

Key configuration managed via `jitsi.env.j2`:

```yaml
# Authentication
ENABLE_AUTH: "1"              # Require auth for moderator
ENABLE_GUESTS: "1"            # Allow anonymous guests
AUTH_TYPE: token              # Use JWT tokens (OIDC)

# Recording
ENABLE_RECORDING: "1"
JIBRI_RECORDING_DIR: /recordings

# OIDC (Keycloak)
TOKEN_AUTH_URL: https://keycloak.viljo.se/realms/master/protocol/openid-connect/auth
```

## Installation

### Prerequisites

1. Proxmox host with vmbr3 (DMZ) network configured
2. Keycloak instance running at keycloak.viljo.se
3. Traefik reverse proxy configured
4. DNS record for meet.viljo.se pointing to WAN IP
5. Vault secrets configured (see below)

### Deployment

Run the playbook (when created):

```bash
ansible-playbook -i inventory/proxmox.ini site.yml --tags jitsi
```

Or apply the role directly:

```yaml
- hosts: proxmox
  roles:
    - jitsi
```

### Post-Deployment Steps

1. **Configure Keycloak Client**:
   - Create OIDC client named `jitsi` in Keycloak master realm
   - Set valid redirect URIs: `https://meet.viljo.se/*`
   - Set client authentication: ON
   - Save client secret to Ansible Vault as `vault_jitsi_oidc_client_secret`

2. **Configure Firewall Port Forward**:
   Add to firewall nftables configuration:
   ```nft
   # UDP port for Jitsi JVB media streams
   iifname "eth0" udp dport 10000 dnat to 172.16.10.160:10000
   ```

3. **Verify Traefik Routing**:
   Check that Traefik has picked up the route:
   ```bash
   curl -I https://meet.viljo.se
   ```

## Vault Secrets

The following secrets must be defined in `inventory/group_vars/all/secrets.yml` (encrypted with `ansible-vault`):

```yaml
# Container root password
vault_jitsi_root_password: "secure_random_password"

# XMPP component secrets (generate with: openssl rand -hex 32)
vault_jitsi_jicofo_component_secret: "random_hex_string"
vault_jitsi_jicofo_auth_password: "random_hex_string"
vault_jitsi_jvb_auth_password: "random_hex_string"

# Recording service secrets
vault_jitsi_jibri_recorder_password: "random_hex_string"
vault_jitsi_jibri_xmpp_password: "random_hex_string"

# Keycloak OIDC client secret (from Keycloak admin console)
vault_jitsi_oidc_client_secret: "keycloak_client_secret"
```

### Generating Secrets

```bash
# Generate strong random passwords
openssl rand -hex 32

# Edit encrypted vault file
ansible-vault edit inventory/group_vars/all/secrets.yml
```

## Usage

### Creating a Meeting

1. Navigate to https://meet.viljo.se
2. Enter a meeting room name (e.g., "team-standup")
3. If authenticated via SSO: Automatically granted moderator role
4. If anonymous: Join as guest with limited privileges

### Moderator Capabilities

- Start/stop recording
- Mute participants
- Remove participants from meeting
- Grant moderator role to guests
- Enable lobby mode (waiting room)
- Set password for room

### Guest Limitations

- Cannot mute others
- Cannot remove participants
- Cannot start recording
- Can be muted by moderators

### Screen Sharing

All participants (moderators and guests) can share their screens:
1. Click "Share screen" button
2. Select window or entire screen
3. All participants see the shared content

### Recording Meetings

Moderators can record meetings:
1. Click "Start recording"
2. Recording saved to `/mnt/storage/jitsi-recordings` on Proxmox host
3. Files named with timestamp and room name
4. Accessible via bind mount for archival or distribution

## Monitoring

### Container Status

```bash
ssh root@192.168.1.3 "pct status 160"
```

### Docker Container Health

```bash
ssh root@192.168.1.3 "pct exec 160 -- docker ps"
ssh root@192.168.1.3 "pct exec 160 -- docker compose -f /opt/jitsi/docker-compose.yml logs -f"
```

### Service Logs

```bash
# All services
pct exec 160 -- docker compose -f /opt/jitsi/docker-compose.yml logs -f

# Specific service
pct exec 160 -- docker logs jitsi-web -f
pct exec 160 -- docker logs jitsi-jvb -f
pct exec 160 -- docker logs jitsi-prosody -f
```

### Network Connectivity

```bash
# Test container internet access
pct exec 160 -- ping -c 2 1.1.1.1

# Test web service
curl -I https://meet.viljo.se

# Check JVB UDP port
nc -zuv <public_ip> 10000
```

## Troubleshooting

### Meeting Won't Start

**Symptoms**: Users see "Connecting..." indefinitely

**Diagnosis**:
1. Check JVB logs: `pct exec 160 -- docker logs jitsi-jvb`
2. Verify UDP port 10000 is reachable from internet
3. Check firewall DNAT rule for UDP 10000

**Solution**:
- Ensure firewall has UDP port forward configured
- Verify JVB_PORT matches exposed port
- Check STUN server connectivity

### Authentication Not Working

**Symptoms**: SSO redirect fails or returns error

**Diagnosis**:
1. Verify Keycloak is accessible: `curl https://keycloak.viljo.se`
2. Check TOKEN_AUTH_URL matches Keycloak realm
3. Verify OIDC client secret matches Vault

**Solution**:
- Confirm redirect URI in Keycloak client settings
- Check client secret in .env file (regenerate if needed)
- Review Prosody logs for auth errors

### No Audio/Video

**Symptoms**: Participants join but can't see/hear each other

**Diagnosis**:
1. Check browser console for WebRTC errors
2. Verify UDP 10000 is open (not just TCP)
3. Check JVB logs for connection attempts

**Solution**:
- Confirm firewall allows UDP traffic
- Check STUN server configuration
- Verify browser has camera/mic permissions

### Recording Fails

**Symptoms**: "Start recording" button grayed out or fails

**Diagnosis**:
1. Check Jibri container status: `pct exec 160 -- docker ps | grep jibri`
2. Verify recording directory exists and is writable
3. Check Jibri logs: `pct exec 160 -- docker logs jitsi-jibri`

**Solution**:
- Ensure bind mount is configured correctly
- Verify /dev/snd is accessible
- Check SYS_ADMIN capability is granted

## Scaling Considerations

### Current Limits

- **Participants per room**: 10-15 (recommended with 4 cores)
- **Concurrent rooms**: 5 (with current resource allocation)
- **Recording capacity**: Limited by host storage space

### Horizontal Scaling

To support more users:

1. **Add JVB instances**: Deploy additional JVB containers for more video bridge capacity
2. **Increase resources**: Allocate more CPU/memory to container
3. **External JVB**: Run JVB on separate host with more network bandwidth

### Storage Expansion

Recordings stored on Proxmox host:
- Monitor `/mnt/storage/jitsi-recordings` usage
- Expand underlying storage as needed
- Consider automatic cleanup of old recordings

## Security Considerations

### Network Isolation

- Container on DMZ (vmbr3) with limited access
- Only HTTP/HTTPS and UDP 10000 exposed
- No direct SSH access from internet

### Authentication

- SSO via Keycloak ensures centralized identity management
- Moderator privileges only for authenticated users
- Anonymous guests have restricted capabilities

### Encryption

- All signaling encrypted via HTTPS (Traefik)
- WebRTC media encrypted with DTLS-SRTP
- Recordings stored on secure host filesystem

### Best Practices

1. Regularly update Jitsi Docker images
2. Monitor access logs for suspicious activity
3. Implement room passwords for sensitive meetings
4. Review and prune old recordings
5. Keep Keycloak and OAuth credentials secure

## Related Documentation

- [Jitsi Meet Documentation](https://jitsi.github.io/handbook/)
- [Jitsi Docker Setup](https://github.com/jitsi/docker-jitsi-meet)
- [Network Architecture](../../docs/NETWORK_ARCHITECTURE.md)
- [Keycloak Integration](../keycloak/README.md)
- [Traefik Configuration](../traefik/README.md)

## Support

For issues or questions:
1. Check logs: `pct exec 160 -- docker compose logs`
2. Review this documentation
3. Consult Jitsi community forums
4. Check Keycloak SSO configuration

## Version Information

- **Jitsi Meet Version**: stable-9882
- **Docker Compose**: v3.9
- **Container OS**: Debian 13 (Trixie)
- **Ansible Role Version**: 1.0.0
