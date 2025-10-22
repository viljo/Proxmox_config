# Feature Specification: Jellyfin Media Server

**Feature Branch**: `009-jellyfin-media-server`
**Created**: 2025-10-22
**Status**: Planned
**Priority**: Medium
**Complexity**: Medium

## Overview

Deploy Jellyfin media server as an LXC container on the Proxmox infrastructure to provide streaming access to media content (videos, music, photos) with hardware transcoding support and integration with the existing authentication and reverse proxy infrastructure.

## User Scenarios & Testing

### User Story 1 - Media Streaming Access (Priority: P1)

Users can access their media library through a web interface at https://jellyfin.viljo.se and stream content to various devices including web browsers, mobile apps, and smart TVs.

**Why this priority**: This is the core functionality of Jellyfin - providing media access and streaming capabilities.

**Independent Test**: User navigates to https://jellyfin.viljo.se, logs in, and can browse and play media content with smooth playback.

**Acceptance Scenarios**:

1. **Given** a user with valid credentials, **When** they visit https://jellyfin.viljo.se, **Then** they see the Jellyfin web interface over HTTPS with valid certificates.

2. **Given** an authenticated user browsing the media library, **When** they select a video file, **Then** playback begins with automatic quality adjustment based on network conditions.

3. **Given** media is being streamed, **When** the original format is not supported by the client, **Then** Jellyfin automatically transcodes the content in real-time.

4. **Given** a user on a mobile device, **When** they access Jellyfin, **Then** the interface is responsive and optimized for mobile viewing.

---

### User Story 2 - Secure External Access (Priority: P2)

Jellyfin is accessible from the internet through Traefik reverse proxy with automatic HTTPS certificates and DNS resolution.

**Why this priority**: Enables remote access to media library while maintaining security through proper TLS and reverse proxy configuration.

**Independent Test**: User accesses https://jellyfin.viljo.se from outside the local network and successfully streams media.

**Acceptance Scenarios**:

1. **Given** Traefik is configured with Jellyfin routing, **When** a request arrives for jellyfin.viljo.se, **Then** it is routed to the Jellyfin container at 172.16.10.56:8096.

2. **Given** DNS is configured via Loopia, **When** jellyfin.viljo.se is queried, **Then** it resolves to the public IP address.

3. **Given** HTTPS is enforced, **When** a user attempts HTTP access, **Then** they are automatically redirected to HTTPS.

---

### User Story 3 - Media Storage Integration (Priority: P3)

Jellyfin has access to media storage locations through mounted volumes, with proper permissions and organization.

**Why this priority**: Essential for accessing the actual media files, but can be configured after basic deployment.

**Independent Test**: Administrator adds media storage mounts and Jellyfin can scan and index the content.

**Acceptance Scenarios**:

1. **Given** media files are stored on the host or NAS, **When** volumes are mounted into the Jellyfin container, **Then** Jellyfin can read and index the media files.

2. **Given** new media files are added, **When** a library scan is triggered, **Then** new content appears in the Jellyfin library within minutes.

3. **Given** media files in different formats, **When** Jellyfin scans the library, **Then** it correctly identifies metadata including titles, posters, descriptions, and organizes content appropriately.

---

## Technical Architecture

### Container Specifications

- **Container ID**: 56
- **IP Address**: 172.16.10.56/24
- **Gateway**: 172.16.10.1 (Firewall)
- **DNS**: 172.16.10.1, 1.1.1.1
- **Bridge**: vmbr3 (DMZ network)
- **Resources**:
  - CPU: 4 cores
  - RAM: 4096 MB
  - Swap: 1024 MB
  - Disk: 64 GB
- **Features**: nesting=1 (for potential container features)

### Service Configuration

- **Service Port**: 8096 (HTTP)
- **External URL**: https://jellyfin.viljo.se
- **Hostname**: jellyfin
- **Domain**: viljo.se

### Network Architecture

```
Internet → Firewall (172.16.10.1) → Traefik (Proxmox Host) → Jellyfin (172.16.10.56:8096)
```

### Software Stack

- **Base OS**: Debian 13 (Trixie)
- **Jellyfin**: Latest stable from official Jellyfin repository
- **Repository**: https://repo.jellyfin.org/debian bookworm

## Implementation Plan

### Phase 1: Container Deployment

1. Update Jellyfin role with correct container ID (56) and network configuration
2. Configure static IP (172.16.10.56) on DMZ network (vmbr3)
3. Deploy Debian 13 LXC container with appropriate resources
4. Install Jellyfin from official repository
5. Configure Jellyfin service to start on boot

### Phase 2: Traefik Integration

1. Register Jellyfin service in Traefik services list
2. Configure routing rule for jellyfin.viljo.se
3. Enable automatic HTTPS with Let's Encrypt DNS challenge
4. Test external access and certificate validation

### Phase 3: Media Storage Setup

1. Configure media mount points (future expansion)
2. Set up library scanning schedules
3. Configure transcoding settings
4. Set up user accounts and permissions

### Phase 4: Optional Enhancements (Future)

1. LDAP/OIDC authentication integration with Keycloak
2. Hardware transcoding with GPU passthrough
3. Integration with download clients (qBittorrent)
4. Automated media organization tools

## Dependencies

### Required Services

- ✅ Firewall (Container 1) - Network gateway
- ✅ Traefik (Proxmox host) - Reverse proxy
- ✅ Loopia DNS - Domain management

### Optional Services

- ⚠️ Keycloak (Container 51) - SSO integration (future)
- ⚠️ OpenMediaVault (Container 64) - Media storage (future)
- ⚠️ qBittorrent (Container 59) - Media acquisition (future)

## Security Considerations

1. **Container Isolation**: Unprivileged LXC container for security
2. **Network Segmentation**: Deployed on DMZ network (vmbr3)
3. **HTTPS Enforcement**: All traffic encrypted via Traefik
4. **Authentication**: Built-in Jellyfin authentication (LDAP/OIDC future enhancement)
5. **Firewall Rules**: Only port 8096 accessible from Traefik
6. **Media Permissions**: Read-only access to media storage

## Monitoring & Maintenance

### Health Checks

- Service availability monitoring
- Resource usage tracking (CPU, RAM, disk)
- Transcoding performance metrics
- Network bandwidth monitoring

### Backup Strategy

- Container configuration backup (PVE snapshots)
- Jellyfin configuration and metadata backup
- Media files backed up separately (large dataset)

### Maintenance Tasks

- Regular Jellyfin updates via apt
- Library scanning and cleanup
- Transcode cache management
- Log rotation

## Known Limitations

1. **Hardware Transcoding**: Not configured in initial deployment (requires GPU passthrough)
2. **Authentication**: Uses built-in Jellyfin auth initially (Keycloak integration future)
3. **Media Storage**: Requires external storage configuration (not included in initial deployment)
4. **Mobile Apps**: Require separate client configuration

## Future Enhancements

1. **Hardware Acceleration**: Configure Intel QuickSync or NVIDIA GPU for transcoding
2. **SSO Integration**: Connect to Keycloak for unified authentication
3. **Plugin Ecosystem**: Install useful Jellyfin plugins
4. **Automated Media Management**: Integration with Sonarr/Radarr (if needed)
5. **Multi-User Support**: User profiles and parental controls
6. **Remote Access**: Jellyfin mobile app configuration

## Testing Checklist

### Deployment Testing
- [ ] Container created with ID 56
- [ ] Static IP 172.16.10.56 assigned and reachable
- [ ] Jellyfin service installed and running
- [ ] Web interface accessible at http://172.16.10.56:8096

### Integration Testing
- [ ] Traefik routing configured for jellyfin.viljo.se
- [ ] HTTPS certificate obtained and valid
- [ ] External access working from internet
- [ ] HTTP redirects to HTTPS

### Functional Testing
- [ ] Initial setup wizard completes successfully
- [ ] Can create admin user account
- [ ] Can add media libraries
- [ ] Can scan and index media
- [ ] Can play video content
- [ ] Transcoding works for incompatible formats

## References

- [Jellyfin Official Documentation](https://jellyfin.org/docs/)
- [Container Mapping](../../docs/architecture/container-mapping.md)
- [Network Topology](../../docs/architecture/network-topology.md)
- [ADR-002: Container ID Standardization](../../docs/adr/002-container-id-standardization.md)

## Success Criteria

The Jellyfin implementation is considered successful when:

1. ✅ Container is deployed with correct ID (56) and network configuration
2. ✅ Jellyfin is accessible at https://jellyfin.viljo.se with valid certificates
3. ✅ Users can authenticate and access the web interface
4. ✅ Media playback works for various formats
5. ✅ Service is integrated with Traefik reverse proxy
6. ✅ Documentation is complete and accurate
7. ✅ Service starts automatically on container boot

---

**Last Updated**: 2025-10-22
**Next Review**: After implementation completion
