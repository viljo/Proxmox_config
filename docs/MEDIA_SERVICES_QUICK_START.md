# Media Services Quick Start Guide

Quick reference for deploying and managing Jellyfin and qBittorrent media services.

## Quick Deploy

```bash
# Deploy both services
cd /Users/anders/git/Proxmox_config
ansible-playbook -i inventory/hosts.yml playbooks/media-services-deploy.yml

# Deploy individually
ansible-playbook -i inventory/hosts.yml playbooks/jellyfin-deploy.yml
ansible-playbook -i inventory/hosts.yml playbooks/qbittorrent-deploy.yml
```

## Container Information

| Service | ID | IP | Domain | Port |
|---------|----|----|--------|------|
| Jellyfin | 56 | 172.16.10.56 | jellyfin.viljo.se | 8096 |
| qBittorrent | 59 | 172.16.10.59 | qbittorrent.viljo.se | 8080 |

## Quick Access

- **Jellyfin**: https://jellyfin.viljo.se
- **qBittorrent**: https://qbittorrent.viljo.se (admin / check logs for password)

## Essential Commands

### Container Management

```bash
# Status
ssh root@192.168.1.3 pct status 56  # Jellyfin
ssh root@192.168.1.3 pct status 59  # qBittorrent

# Start/Stop/Restart
ssh root@192.168.1.3 pct start 56
ssh root@192.168.1.3 pct stop 56
ssh root@192.168.1.3 pct restart 56

# Shell access
ssh root@192.168.1.3 pct enter 56
```

### Service Management

```bash
# Check service status
ssh root@192.168.1.3 pct exec 56 -- systemctl status jellyfin
ssh root@192.168.1.3 pct exec 59 -- systemctl status qbittorrent

# Restart services
ssh root@192.168.1.3 pct exec 56 -- systemctl restart jellyfin
ssh root@192.168.1.3 pct exec 59 -- systemctl restart qbittorrent

# View logs
ssh root@192.168.1.3 pct exec 56 -- journalctl -u jellyfin -f
ssh root@192.168.1.3 pct exec 59 -- journalctl -u qbittorrent -f
```

### Storage Management

```bash
# Check disk space
ssh root@192.168.1.3 df -h /srv/media

# List downloads
ssh root@192.168.1.3 ls -lh /srv/media/downloads/complete/

# Check file permissions
ssh root@192.168.1.3 ls -la /srv/media/
```

## First-Time Setup

### qBittorrent

1. Get temporary password:
   ```bash
   ssh root@192.168.1.3 pct exec 59 -- journalctl -u qbittorrent | grep -i password
   ```

2. Login at https://qbittorrent.viljo.se
   - Username: `admin`
   - Password: (from logs)

3. **Change password immediately**: Tools → Options → Web UI

4. Configure paths: Tools → Options → Downloads
   - Default: `/srv/downloads/complete/`
   - Incomplete: `/srv/downloads/incomplete/`

### Jellyfin

1. Access https://jellyfin.viljo.se

2. Complete setup wizard:
   - Create admin account
   - Add media libraries:
     - Movies: `/media/movies`
     - TV: `/media/tv`
     - Music: `/media/music`
     - Downloads: `/media/downloads`

3. Configure transcoding: Dashboard → Playback

## Common Tasks

### Add Media to Jellyfin

1. Place files in appropriate directory:
   ```bash
   ssh root@192.168.1.3 cp /path/to/movie.mp4 /srv/media/movies/
   ```

2. Trigger scan in Jellyfin:
   - Dashboard → Libraries → Scan All Libraries

### Download Torrent

1. Access https://qbittorrent.viljo.se
2. Click "+" to add torrent
3. Paste magnet link or upload .torrent file
4. Select category (movies/tv/music)
5. Click "Download"

### Move Downloaded Content

```bash
# Move completed download to movies
ssh root@192.168.1.3 mv /srv/media/downloads/complete/Movie.mp4 /srv/media/movies/

# Trigger Jellyfin scan
# (via web interface or wait for automatic scan)
```

## Troubleshooting

### Service Not Responding

```bash
# Check if container is running
ssh root@192.168.1.3 pct status 56

# Check service status
ssh root@192.168.1.3 pct exec 56 -- systemctl status jellyfin

# Restart if needed
ssh root@192.168.1.3 pct restart 56
```

### Can't Access Web Interface

1. Check container is running
2. Check service is active
3. Test internal connectivity:
   ```bash
   ssh root@192.168.1.3 curl -I http://172.16.10.56:8096
   ```
4. Check Traefik routing:
   ```bash
   curl -I https://jellyfin.viljo.se
   ```

### Disk Space Full

```bash
# Check usage
ssh root@192.168.1.3 df -h /srv/media

# Find large files
ssh root@192.168.1.3 du -sh /srv/media/* | sort -h

# Clean up old downloads
ssh root@192.168.1.3 rm -rf /srv/media/downloads/complete/old-file
```

## Configuration Files

### Jellyfin
- **Container config**: `/etc/pve/lxc/56.conf`
- **App config**: `/var/lib/jellyfin/` (in container)
- **Inventory vars**: `inventory/group_vars/all/jellyfin.yml`
- **Role**: `roles/jellyfin/`

### qBittorrent
- **Container config**: `/etc/pve/lxc/59.conf`
- **App config**: `/etc/qbittorrent/` (in container)
- **Inventory vars**: `inventory/group_vars/all/qbittorrent.yml`
- **Role**: `roles/qbittorrent/`

## Storage Paths

### On Proxmox Host
- `/srv/media/` - Root media directory
- `/srv/media/downloads/` - qBittorrent storage
- `/srv/media/movies/` - Movie library
- `/srv/media/tv/` - TV library
- `/srv/media/music/` - Music library

### In qBittorrent Container (59)
- `/srv/downloads/` - Mounted from host
- `/srv/downloads/incomplete/` - Active downloads
- `/srv/downloads/complete/` - Completed downloads

### In Jellyfin Container (56)
- `/media/movies/` - Movies
- `/media/tv/` - TV shows
- `/media/music/` - Music
- `/media/downloads/` - Recent downloads

## Documentation

- **Full Guide**: [MEDIA_SERVICES_DEPLOYMENT.md](MEDIA_SERVICES_DEPLOYMENT.md)
- **Jellyfin Spec**: [specs/planned/009-jellyfin-media-server/](../specs/planned/009-jellyfin-media-server/)
- **qBittorrent Spec**: [specs/planned/009-bittorrent-client/](../specs/planned/009-bittorrent-client/)

## Support Resources

- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [qBittorrent Wiki](https://github.com/qbittorrent/qBittorrent/wiki)
- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)

---

**Version**: 1.0
**Last Updated**: 2025-10-27
