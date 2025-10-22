# Zabbix Dashboard Quick Start Guide

Get your infrastructure monitoring dashboard up and running in under 30 minutes!

## Prerequisites

- Proxmox infrastructure deployed with PostgreSQL (container 50)
- Ansible configured with inventory
- Vault secrets set up

## Step 1: Configure Secrets (5 minutes)

Edit your vault secrets file:

```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Add these variables:

```yaml
# Zabbix secrets
vault_zabbix_root_password: "SecureRootPassword123!"
vault_zabbix_db_password: "SecureDatabasePassword456!"
vault_zabbix_admin_password: "SecureWebUIPassword789!"
```

Save and exit (`:wq` in vim).

## Step 2: Deploy Zabbix (20-25 minutes)

Run the Ansible playbook:

```bash
cd /path/to/Proxmox_config
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags zabbix
```

This will:
- ✅ Create LXC container (172.16.10.61)
- ✅ Install Zabbix server 7.0
- ✅ Configure PostgreSQL database
- ✅ Deploy agents to all containers
- ✅ Create infrastructure dashboard

**Grab a coffee while it runs!** ☕

## Step 3: Access Dashboard (2 minutes)

### Option A: Via Domain (Recommended)

1. Open browser: https://zabbix.viljo.se
2. Login:
   - Username: `Admin`
   - Password: Your `vault_zabbix_admin_password`

### Option B: Direct IP

1. Open browser: http://172.16.10.61
2. Same credentials as above

## Step 4: View Your Infrastructure (1 minute)

Once logged in:

1. Click **"Monitoring"** → **"Dashboards"**
2. Select **"Proxmox Infrastructure Overview"**
3. You should see 6 widgets displaying:
   - 📊 Infrastructure Problems
   - 💚 Container Status
   - 📈 Resource Usage
   - ⚠️ Top 10 Issues
   - 🔌 Container Availability
   - 📋 Services Overview

## Step 5: Security Hardening (3 minutes)

### IMPORTANT: Change Default Password

1. Go to **Administration** → **Users**
2. Click on **Admin**
3. Click **"Change password"**
4. Set a strong password
5. Update vault: `ansible-vault edit inventory/group_vars/all/secrets.yml`
6. Change `vault_zabbix_admin_password` to match

### Optional: Disable Guest Access

1. **Administration** → **Users**
2. Click **"guest"**
3. **Disabled** → Click **Update**

## What You're Monitoring

Your dashboard now monitors these containers:

| Service | IP | Status |
|---------|-----|--------|
| Firewall | 172.16.10.1 | ✅ |
| PostgreSQL | 172.16.10.50 | ✅ |
| Jellyfin | 172.16.10.56 | ✅ |
| Home Assistant | 172.16.10.57 | ✅ |
| Demo Site | 172.16.10.60 | ✅ |
| OpenMediaVault | 172.16.10.64 | ✅ |
| Zipline | 172.16.10.65 | ✅ |

## Quick Dashboard Tips

### Understanding Status Colors

- 🟢 **Green**: Everything normal
- 🔵 **Blue**: Information (no action needed)
- 🟡 **Yellow**: Warning (monitor)
- 🟠 **Orange**: High severity (investigate)
- 🔴 **Red**: Critical (immediate action)

### Useful Dashboard Features

- **Time Range**: Change view period (top-right dropdown)
- **Auto-Refresh**: Updates every 30 seconds automatically
- **Fullscreen**: Click expand icon on any widget
- **Filter**: Click on a service to see only its metrics

## Common Tasks

### Add Email Alerts

1. **Administration** → **Media types** → **Email**
2. Configure SMTP server
3. **Administration** → **Users** → **Admin** → **Media**
4. Add your email address

### Add More Containers

Edit `roles/zabbix/defaults/main.yml`:

```yaml
zabbix_monitored_containers:
  # Add your new container here
  - id: 99
    name: "My New Service"
    ip: 172.16.10.99
    templates:
      - Linux by Zabbix agent
```

Re-run: `ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags zabbix`

### Check Container Status

```bash
# View all container statuses
pct list

# Check specific container
pct status 61

# View Zabbix logs
pct exec 61 -- tail -f /var/log/zabbix/zabbix_server.log
```

## Troubleshooting

### Problem: Dashboard shows "No data"

**Solution**:
```bash
# Restart Zabbix server
pct exec 61 -- systemctl restart zabbix-server

# Wait 2 minutes, then refresh browser
```

### Problem: Container shows as unavailable

**Solution**:
```bash
# Check if agent is running
pct exec <container-id> -- systemctl status zabbix-agent

# Restart agent
pct exec <container-id> -- systemctl restart zabbix-agent
```

### Problem: Can't access web interface

**Solution**:
```bash
# Check container is running
pct status 61

# Start if stopped
pct start 61

# Check Apache
pct exec 61 -- systemctl status apache2
```

## Next Steps

Now that you have monitoring set up:

1. ✅ **Customize Alerts**: Set up email notifications for critical events
2. ✅ **Add More Hosts**: Monitor additional containers as you deploy them
3. ✅ **Create Reports**: Schedule weekly performance reports
4. ✅ **Tune Thresholds**: Adjust trigger sensitivity based on your environment
5. ✅ **Explore Templates**: Add service-specific monitoring templates

## Getting Help

- **Full Documentation**: See `docs/ZABBIX_DASHBOARD_IMPLEMENTATION.md`
- **Role README**: See `roles/zabbix/README.md`
- **Zabbix Docs**: https://www.zabbix.com/documentation/7.0/

## Success Checklist

- [ ] Zabbix container running (ID: 61)
- [ ] Web interface accessible
- [ ] Admin password changed
- [ ] Dashboard displays all 6 widgets
- [ ] All containers showing green status
- [ ] No critical alerts in "Infrastructure Problems"
- [ ] Vault secrets updated with new admin password

**Congratulations!** 🎉 Your infrastructure monitoring is now live!

---

**Quick Start Version**: 1.0
**Estimated Setup Time**: ~30 minutes
**Difficulty**: Beginner-friendly
