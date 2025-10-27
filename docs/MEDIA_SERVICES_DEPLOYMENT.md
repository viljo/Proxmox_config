# Media Services Deployment Guide

**Feature Branch**: `009-jellyfin-media-server` and `009-bittorrent-client`
**Created**: 2025-10-27
**Status**: Implementation Ready

## Overview

This guide covers the deployment of the complete media services infrastructure consisting of:

1. **Jellyfin Media Server** (Container 56) - Media streaming and management
2. **qBittorrent Client** (Container 59) - BitTorrent download client

These services are integrated to provide a complete media acquisition and consumption workflow.

## Architecture

### Network Configuration

Both services are deployed on the DMZ network (vmbr3, 172.16.10.0/24):

| Service | Container ID | IP Address | Internal Port | External Domain |
|---------|--------------|------------|---------------|-----------------|
| Jellyfin | 56 | 172.16.10.56 | 8096 | jellyfin.viljo.se |
| qBittorrent | 59 | 172.16.10.59 | 8080 | qbittorrent.viljo.se |

### Storage Architecture

```
Proxmox Host: /srv/media/
├── downloads/          # qBittorrent storage (mounted to container 59)
│   ├── incomplete/     # Active downloads
│   └── complete/       # Completed downloads
│       ├── movies/     # Movie downloads
│       ├── tv/         # TV show downloads
│       └── music/      # Music downloads
├── movies/             # Organized movie library (mounted to Jellyfin)
├── tv/                 # Organized TV library (mounted to Jellyfin)
└── music/              # Music library (mounted to Jellyfin)

qBittorrent Container (59): /srv/downloads/
└── Mounted from host: /srv/media/downloads/

Jellyfin Container (56): /media/
├── movies/             # Mounted from host: /srv/media/movies/
├── tv/                 # Mounted from host: /srv/media/tv/
├── music/              # Mounted from host: /srv/media/music/
└── downloads/          # Mounted from host: /srv/media/downloads/complete/
```

### Data Flow

```
User → qBittorrent Web UI → Download Torrent
                                    ↓
                          /srv/downloads/incomplete/
                                    ↓
                          (Download completes)
                                    ↓
                          /srv/downloads/complete/
                                    ↓
                      (User organizes or automation moves)
                                    ↓
            /srv/media/{movies,tv,music}/
                                    ↓
                    Jellyfin Library Scan
                                    ↓
                          User streams via Jellyfin
```

## Prerequisites

### Required Infrastructure

- ✅ Proxmox VE host with LXC support
- ✅ Debian 13 (Trixie) template downloaded
- ✅ DMZ network (vmbr3) configured
- ✅ Firewall container (101) operational
- ✅ Traefik reverse proxy configured
- ✅ DNS records configured in Loopia

### Required Vault Variables

Ensure these variables are set in `inventory/group_vars/all/secrets.yml`:

```yaml
vault_jellyfin_root_password: "strong-password-here"
vault_qbittorrent_root_password: "strong-password-here"
```

Generate strong passwords:

```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Add entries if they don't exist:

```yaml
vault_jellyfin_root_password: "{{ lookup('password', '/dev/null length=32 chars=ascii_letters,digits') }}"
vault_qbittorrent_root_password: "{{ lookup('password', '/dev/null length=32 chars=ascii_letters,digits') }}"
```

## Deployment Options

### Option 1: Deploy Complete Media Stack (Recommended)

Deploy both services together with full integration:

```bash
cd /Users/anders/git/Proxmox_config

# Deploy both services
ansible-playbook -i inventory/hosts.yml playbooks/media-services-deploy.yml

# With check mode (dry run)
ansible-playbook -i inventory/hosts.yml playbooks/media-services-deploy.yml --check

# Deploy specific service only
ansible-playbook -i inventory/hosts.yml playbooks/media-services-deploy.yml --tags qbittorrent
ansible-playbook -i inventory/hosts.yml playbooks/media-services-deploy.yml --tags jellyfin
```

### Option 2: Deploy Services Individually

#### Deploy Jellyfin Only

```bash
ansible-playbook -i inventory/hosts.yml playbooks/jellyfin-deploy.yml
```

#### Deploy qBittorrent Only

```bash
ansible-playbook -i inventory/hosts.yml playbooks/qbittorrent-deploy.yml
```

## Post-Deployment Configuration

### 1. Configure qBittorrent

#### Access Web Interface

```bash
# Check qBittorrent status
ssh root@192.168.1.3 pct status 59

# Get temporary password from logs
ssh root@192.168.1.3 pct exec 59 -- journalctl -u qbittorrent | grep -i password
```

Access: https://qbittorrent.viljo.se

**Default Credentials:**
- Username: `admin`
- Password: Check logs (output above)

#### Initial Configuration Steps

1. **Change Password Immediately**
   - Go to Tools → Options → Web UI
   - Change default password
   - Save settings

2. **Configure Download Paths**
   - Go to Tools → Options → Downloads
   - Default Save Path: `/srv/downloads/complete/`
   - Keep incomplete torrents in: `/srv/downloads/incomplete/`
   - Enable "Keep incomplete torrents in"
   - Save settings

3. **Configure Categories** (Optional but recommended)
   - Right-click in category panel → Add category
   - Add categories:
     - `movies` → `/srv/downloads/complete/movies/`
     - `tv` → `/srv/downloads/complete/tv/`
     - `music` → `/srv/downloads/complete/music/`

4. **Configure Bandwidth Limits**
   - Go to Tools → Options → Speed
   - Set global rate limits:
     - Upload: 5000 KiB/s (adjust based on your connection)
     - Download: 10000 KiB/s
   - Enable alternative rate limits for scheduling
   - Save settings

5. **Configure Connection**
   - Go to Tools → Options → Connection
   - Listening Port: Use default or configure specific port
   - Enable UPnP / NAT-PMP if needed
   - Save settings

6. **Configure BitTorrent**
   - Go to Tools → Options → BitTorrent
   - Privacy → Enable encryption
   - Seeding Limits:
     - Ratio: 2.0 (adjust based on your policy)
     - Time: 10080 minutes (1 week)
   - Save settings

### 2. Configure Jellyfin

#### Access Setup Wizard

Access: https://jellyfin.viljo.se

On first access, you'll see the setup wizard.

#### Setup Wizard Steps

1. **Language Selection**
   - Choose your preferred language
   - Click Next

2. **Create Admin Account**
   - Username: Choose admin username
   - Password: Create strong password
   - Confirm password
   - Click Next

3. **Setup Media Libraries**

   Click "Add Media Library" for each library:

   **Movies Library:**
   - Content type: Movies
   - Display name: Movies
   - Folders: `/media/movies`
   - Click OK

   **TV Shows Library:**
   - Content type: Shows
   - Display name: TV Shows
   - Folders: `/media/tv`
   - Click OK

   **Music Library:**
   - Content type: Music
   - Display name: Music
   - Folders: `/media/music`
   - Click OK

   **Downloads Library:** (for recently downloaded content)
   - Content type: Movies (or Mixed)
   - Display name: Recent Downloads
   - Folders: `/media/downloads`
   - Click OK

4. **Preferred Metadata Language**
   - Select your preferred language for metadata
   - Click Next

5. **Remote Access**
   - Enable remote connections: Yes
   - Enable automatic port mapping: No (we use Traefik)
   - Click Next

6. **Finish Setup**
   - Click Finish
   - Login with your admin account

#### Post-Setup Configuration

1. **Configure Transcoding**
   - Go to Dashboard → Playback
   - Hardware acceleration: None (or configure if GPU available)
   - Transcoding thread count: 4
   - Save

2. **Configure Library Scanning**
   - Go to Dashboard → Libraries
   - For each library, click three dots → Manage Library
   - Enable "Scan library on a schedule"
   - Set schedule (e.g., every 6 hours)
   - Save

3. **Configure Users** (Optional)
   - Go to Dashboard → Users
   - Add additional users as needed
   - Configure library access per user
   - Set parental controls if needed

4. **Configure Plugins** (Optional)
   - Go to Dashboard → Plugins → Catalog
   - Install useful plugins:
     - Open Subtitles
     - TMDb
     - Trakt (if you use Trakt)

### 3. Configure Traefik Routing

The Traefik configuration should already include both services. Verify:

```bash
# Test Jellyfin routing
curl -I https://jellyfin.viljo.se

# Test qBittorrent routing
curl -I https://qbittorrent.viljo.se
```

Expected response: `HTTP/2 200` or redirect to login page.

If routing is not working, ensure services are in `traefik_services` list in `inventory/group_vars/all/main.yml`:

```yaml
traefik_services:
  - name: jellyfin
    host: "jellyfin.{{ public_domain }}"
    container_id: "{{ jellyfin_container_id }}"
    port: 8096
  - name: qbittorrent
    host: "qbittorrent.{{ public_domain }}"
    container_id: "{{ qbittorrent_container_id }}"
    port: "{{ qbittorrent_web_port }}"
```

Then reconfigure Traefik (if you have a Traefik configuration playbook).

### 4. Test Integration

#### Test Download Workflow

1. **Add a test torrent** (use legal content like Ubuntu ISO):
   ```
   Ubuntu 24.04 LTS Desktop ISO:
   https://ubuntu.com/download/desktop
   ```

2. **Monitor download in qBittorrent**:
   - Watch progress in Web UI
   - File should download to `/srv/downloads/incomplete/`
   - When complete, moves to `/srv/downloads/complete/`

3. **Verify file on host**:
   ```bash
   ssh root@192.168.1.3 ls -lh /srv/media/downloads/complete/
   ```

4. **Trigger Jellyfin library scan**:
   - Go to Jellyfin Dashboard → Libraries
   - Click "Scan All Libraries"
   - Or wait for automatic scan

5. **Verify in Jellyfin**:
   - Go to "Recent Downloads" library
   - File should appear (may take a few minutes)

## Optional Enhancements

### 1. Enable SSO Authentication (Traefik Forward Auth)

To enable single sign-on via Keycloak:

1. Configure oauth2-proxy middleware in Traefik
2. Add forward auth to qBittorrent and Jellyfin services
3. Disable qBittorrent built-in authentication
4. Configure Jellyfin LDAP/OIDC plugin

Refer to: `specs/planned/001-gitlab-oauth-keycloak`

### 2. VPN Integration for qBittorrent

To route qBittorrent traffic through VPN:

1. Deploy WireGuard container (spec: `006-wireguard-vpn`)
2. Configure qBittorrent to bind to VPN interface
3. Set up kill switch to prevent IP leaks
4. Test with: https://ipleak.net/

### 3. Automated Media Organization

Tools to automate moving files from downloads to organized libraries:

- **Sonarr**: TV show automation
- **Radarr**: Movie automation
- **Lidarr**: Music automation

These tools can:
- Monitor qBittorrent for completed downloads
- Rename files to standard format
- Move files to appropriate media directories
- Trigger Jellyfin library scans
- Manage quality profiles and upgrades

### 4. Hardware Transcoding

To enable GPU transcoding in Jellyfin:

1. **Intel QuickSync** (if available):
   ```bash
   # Add to Jellyfin container config
   lxc.cgroup2.devices.allow: c 226:* rwm
   lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
   ```

2. **Configure in Jellyfin**:
   - Dashboard → Playback
   - Hardware acceleration: Intel QuickSync
   - Save and restart Jellyfin

### 5. Remote Access Optimization

For optimal remote streaming:

1. **Configure Jellyfin remote access**:
   - Dashboard → Networking
   - Public HTTPS port: 443 (via Traefik)
   - Enable "Allow remote connections to this server"
   - Save

2. **Configure quality settings**:
   - Dashboard → Playback
   - Set maximum streaming bitrate for remote users
   - Configure transcoding profiles

3. **Mobile apps**:
   - iOS: Jellyfin app from App Store
   - Android: Jellyfin app from Play Store
   - Configure server URL: https://jellyfin.viljo.se

## Monitoring and Maintenance

### Container Health Checks

```bash
# Check container status
ssh root@192.168.1.3 pct status 56  # Jellyfin
ssh root@192.168.1.3 pct status 59  # qBittorrent

# Check service status
ssh root@192.168.1.3 pct exec 56 -- systemctl status jellyfin
ssh root@192.168.1.3 pct exec 59 -- systemctl status qbittorrent

# View logs
ssh root@192.168.1.3 pct exec 56 -- journalctl -u jellyfin -f
ssh root@192.168.1.3 pct exec 59 -- journalctl -u qbittorrent -f
```

### Storage Monitoring

```bash
# Check disk usage
ssh root@192.168.1.3 df -h /srv/media

# Check download directory size
ssh root@192.168.1.3 du -sh /srv/media/downloads/*

# List large files
ssh root@192.168.1.3 find /srv/media -type f -size +1G -exec ls -lh {} \;
```

### Backup Strategy

#### What to Backup

1. **Container Configurations**:
   - `/etc/pve/lxc/56.conf`
   - `/etc/pve/lxc/59.conf`

2. **Application Configurations**:
   - Jellyfin: `/var/lib/jellyfin/` (in container 56)
   - qBittorrent: `/etc/qbittorrent/` (in container 59)

3. **Media Files** (optional, large dataset):
   - `/srv/media/` (host)

#### Backup Commands

```bash
# Backup container configurations
ssh root@192.168.1.3 cp /etc/pve/lxc/56.conf /root/backups/jellyfin-container.conf
ssh root@192.168.1.3 cp /etc/pve/lxc/59.conf /root/backups/qbittorrent-container.conf

# Backup Jellyfin configuration
ssh root@192.168.1.3 pct exec 56 -- tar czf /tmp/jellyfin-config.tar.gz /var/lib/jellyfin
ssh root@192.168.1.3 pct pull 56 /tmp/jellyfin-config.tar.gz /root/backups/jellyfin-config.tar.gz

# Backup qBittorrent configuration
ssh root@192.168.1.3 pct exec 59 -- tar czf /tmp/qbittorrent-config.tar.gz /etc/qbittorrent
ssh root@192.168.1.3 pct pull 59 /tmp/qbittorrent-config.tar.gz /root/backups/qbittorrent-config.tar.gz

# Backup media (use separate backup solution for large datasets)
# Consider: Proxmox Backup Server, Restic, Borg, or commercial backup solution
```

### Regular Maintenance Tasks

#### Weekly

- Check disk space usage
- Review qBittorrent seeding ratios
- Clean up old downloads

#### Monthly

- Update container packages:
  ```bash
  ssh root@192.168.1.3 pct exec 56 -- apt update && apt upgrade -y
  ssh root@192.168.1.3 pct exec 59 -- apt update && apt upgrade -y
  ```
- Review Jellyfin transcoding cache
- Check for Jellyfin/qBittorrent updates

#### Quarterly

- Full configuration backup
- Review and optimize media library organization
- Review user access and permissions

## Troubleshooting

### Jellyfin Issues

#### Jellyfin not accessible

```bash
# Check container is running
ssh root@192.168.1.3 pct status 56

# Check service status
ssh root@192.168.1.3 pct exec 56 -- systemctl status jellyfin

# Check if port is listening
ssh root@192.168.1.3 pct exec 56 -- netstat -tlnp | grep 8096

# Check logs
ssh root@192.168.1.3 pct exec 56 -- journalctl -u jellyfin -n 100
```

#### Media not showing in library

1. Check mount points:
   ```bash
   ssh root@192.168.1.3 pct exec 56 -- mount | grep media
   ssh root@192.168.1.3 pct exec 56 -- ls -la /media/
   ```

2. Check file permissions:
   ```bash
   ssh root@192.168.1.3 ls -la /srv/media/
   ```

3. Trigger manual scan:
   - Jellyfin Dashboard → Libraries → Scan All Libraries

4. Check scan logs:
   ```bash
   ssh root@192.168.1.3 pct exec 56 -- journalctl -u jellyfin | grep -i scan
   ```

#### Transcoding issues

1. Check transcoding logs:
   ```bash
   ssh root@192.168.1.3 pct exec 56 -- tail -f /var/lib/jellyfin/log/ffmpeg*.log
   ```

2. Verify FFmpeg is installed:
   ```bash
   ssh root@192.168.1.3 pct exec 56 -- which ffmpeg
   ssh root@192.168.1.3 pct exec 56 -- ffmpeg -version
   ```

3. Check transcoding settings:
   - Dashboard → Playback → Transcoding

### qBittorrent Issues

#### qBittorrent not accessible

```bash
# Check container is running
ssh root@192.168.1.3 pct status 59

# Check service status
ssh root@192.168.1.3 pct exec 59 -- systemctl status qbittorrent

# Check if port is listening
ssh root@192.168.1.3 pct exec 59 -- netstat -tlnp | grep 8080

# Check logs
ssh root@192.168.1.3 pct exec 59 -- journalctl -u qbittorrent -n 100
```

#### Downloads not starting

1. Check disk space:
   ```bash
   ssh root@192.168.1.3 df -h /srv/media/downloads
   ```

2. Check directory permissions:
   ```bash
   ssh root@192.168.1.3 pct exec 59 -- ls -la /srv/downloads/
   ```

3. Check qBittorrent settings:
   - Tools → Options → Downloads
   - Verify paths are correct

4. Check network connectivity:
   ```bash
   ssh root@192.168.1.3 pct exec 59 -- ping -c 4 8.8.8.8
   ssh root@192.168.1.3 pct exec 59 -- curl -I https://example.com
   ```

#### Low download speeds

1. Check bandwidth limits:
   - Tools → Options → Speed
   - Verify limits are appropriate

2. Check connection settings:
   - Tools → Options → Connection
   - Enable UPnP/NAT-PMP if needed
   - Configure port forwarding on firewall

3. Check tracker status:
   - Select torrent → Trackers tab
   - Verify trackers are responding

4. Check peer connections:
   - Select torrent → Peers tab
   - Verify connections to peers

### Storage Issues

#### Disk space full

```bash
# Check disk usage
ssh root@192.168.1.3 df -h /srv/media

# Find large files
ssh root@192.168.1.3 du -sh /srv/media/* | sort -h

# Clean up old downloads
ssh root@192.168.1.3 find /srv/media/downloads/complete -type f -mtime +30 -ls

# Clean up Jellyfin cache
ssh root@192.168.1.3 pct exec 56 -- rm -rf /var/lib/jellyfin/transcoding-temp/*
```

#### Mount point not accessible

1. Check mount on host:
   ```bash
   ssh root@192.168.1.3 mount | grep /srv/media
   ```

2. Check LXC configuration:
   ```bash
   ssh root@192.168.1.3 cat /etc/pve/lxc/56.conf | grep mp
   ssh root@192.168.1.3 cat /etc/pve/lxc/59.conf | grep mp
   ```

3. Restart container:
   ```bash
   ssh root@192.168.1.3 pct restart 56
   ssh root@192.168.1.3 pct restart 59
   ```

## Security Considerations

### Access Control

1. **Change Default Passwords**: Always change default passwords immediately after deployment
2. **Strong Passwords**: Use strong, unique passwords (minimum 16 characters)
3. **Enable HTTPS**: Only access services via HTTPS (enforced by Traefik)
4. **Firewall Rules**: Ensure only necessary ports are open
5. **Regular Updates**: Keep all software up to date

### Network Security

1. **DMZ Isolation**: Both services are on DMZ network, isolated from management network
2. **No Direct WAN Access**: All external access is through Traefik reverse proxy
3. **TLS Termination**: Traefik handles TLS with Let's Encrypt certificates
4. **Rate Limiting**: Consider adding rate limiting in Traefik for web interfaces

### Content Security

1. **Legal Content Only**: Establish acceptable use policy for torrents
2. **Malware Scanning**: Consider integrating ClamAV for download scanning
3. **User Permissions**: Configure appropriate library access per user in Jellyfin
4. **Audit Logs**: Review access logs regularly

### Privacy Considerations

1. **VPN for Torrents**: Consider routing qBittorrent through VPN for privacy
2. **Encryption**: Enable protocol encryption in qBittorrent
3. **Tracker Privacy**: Use private trackers when possible
4. **IP Leak Prevention**: Test for IP leaks if using VPN

## Performance Optimization

### Jellyfin Performance

1. **Transcoding**: Enable hardware transcoding if GPU available
2. **Cache**: Increase cache size if experiencing buffering
3. **Network**: Ensure sufficient bandwidth for number of concurrent streams
4. **Storage**: Use SSD for Jellyfin metadata and cache

### qBittorrent Performance

1. **Connection Limits**: Adjust max connections based on network capacity
2. **Disk I/O**: Use separate disk for downloads if possible
3. **Memory**: Increase container memory if handling many torrents
4. **Port Forwarding**: Configure port forwarding for better peer connectivity

### Storage Performance

1. **File System**: Consider ZFS or BTRFS for advanced features
2. **RAID**: Use RAID for redundancy and performance
3. **Cache**: Use SSD cache for frequently accessed media
4. **Compression**: Consider filesystem compression for space savings

## References

- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [qBittorrent Documentation](https://github.com/qbittorrent/qBittorrent/wiki)
- [Specification: Jellyfin Media Server](../specs/planned/009-jellyfin-media-server/spec.md)
- [Specification: qBittorrent Client](../specs/planned/009-bittorrent-client/spec.md)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

## Support

For issues or questions:

1. Check this documentation
2. Review service logs
3. Check relevant specification documents
4. Consult official documentation for Jellyfin/qBittorrent
5. Review Proxmox LXC documentation

---

**Document Version**: 1.0
**Last Updated**: 2025-10-27
**Maintained By**: Infrastructure Team
