# Troubleshooting Traefik Let's Encrypt Certificate Acquisition

This guide covers common issues when deploying Traefik with automatic Let's Encrypt certificate acquisition via DNS challenge.

## Quick Diagnosis Checklist

```bash
# 1. Check Traefik is running
systemctl status traefik

# 2. Verify environment variables are loaded
PID=$(pgrep -x traefik)
cat /proc/$PID/environ | tr '\0' '\n' | grep -E '^(LOOPIA|DNS_)'

# 3. Check certificate status
openssl s_client -connect localhost:443 -servername yourdomain.com </dev/null 2>&1 | \
  openssl x509 -noout -subject -issuer -dates

# 4. Review Traefik logs
journalctl -u traefik --since "10 minutes ago" --no-pager | tail -50

# 5. Check ACME storage
ls -la /var/lib/traefik/acme.json
cat /var/lib/traefik/acme.json | python3 -m json.tool | grep -A2 '"main"'
```

---

## Problem: Environment Variables Not Loading

### Symptoms
- Traefik logs show: `cannot get ACME client loopia: some credentials information are missing`
- Environment variables like `LOOPIA_API_USER` and `LOOPIA_API_PASSWORD` are not present in Traefik process
- Certificate acquisition fails immediately

### Root Cause
The `traefik.env` file has incorrect permissions (usually 600), preventing the systemd service from reading it.

### Diagnosis
```bash
# Check file permissions
ls -la /etc/traefik/traefik.env

# Expected output (WRONG):
-rw------- 1 traefik traefik 67 Oct 21 00:50 /etc/traefik/traefik.env

# Check if variables are in process
PID=$(pgrep -x traefik)
cat /proc/$PID/environ | tr '\0' '\n' | grep LOOPIA
# No output = variables not loaded
```

### Solution
```bash
# Fix permissions (must be readable by systemd)
chmod 644 /etc/traefik/traefik.env

# Verify
ls -la /etc/traefik/traefik.env
# Expected: -rw-r--r-- 1 traefik traefik 67 Oct 21 00:50 /etc/traefik/traefik.env

# Reload systemd and restart Traefik
systemctl daemon-reload
systemctl restart traefik

# Verify variables are now loaded
sleep 3
PID=$(pgrep -x traefik)
cat /proc/$PID/environ | tr '\0' '\n' | grep LOOPIA
# Should show LOOPIA_API_USER and LOOPIA_API_PASSWORD
```

### Prevention
Always set environment file permissions to 644 when creating it:
```yaml
# In Ansible template task
- name: Create Traefik environment file
  ansible.builtin.template:
    src: traefik.env.j2
    dest: /etc/traefik/traefik.env
    owner: traefik
    group: traefik
    mode: '0644'  # Critical: must be readable
```

---

## Problem: "No ACME Certificate Generation Required" But No Certificate

### Symptoms
- Traefik logs show: `No ACME certificate generation required for domains ["yourdomain.com"]`
- But no valid certificate exists for that domain
- Default Traefik certificate is served instead

### Root Cause
Traefik thinks it already has a certificate for the domain when it doesn't, or the router configuration changed but Traefik cached the old decision.

### Diagnosis
```bash
# Enable DEBUG logging
sed -i 's/level: "INFO"/level: "DEBUG"/' /etc/traefik/traefik.yml
systemctl restart traefik

# Watch logs for ACME decisions
journalctl -u traefik -f | grep -E 'demosite|Looking for|No ACME'

# Check what's in ACME storage
cat /var/lib/traefik/acme.json | python3 -m json.tool | grep -B2 -A5 '"main"'
```

### Solution
#### Option 1: Remove old dynamic config files
```bash
# Stop Traefik
systemctl stop traefik

# Remove conflicting dynamic configs
rm -f /etc/traefik/dynamic/old-site.yml

# Restart
systemctl start traefik
```

#### Option 2: Force certificate re-acquisition
```bash
# Backup ACME storage
cp /var/lib/traefik/acme.json /var/lib/traefik/acme.json.backup

# Remove certificate entry (edit acme.json manually or delete entire file)
# WARNING: This will remove ALL certificates
systemctl stop traefik
rm /var/lib/traefik/acme.json
systemctl start traefik

# Traefik will now request certificates for all configured domains
```

### Prevention
- Use consistent domain names in dynamic configuration
- Avoid having multiple routers for the same domain
- Use DEBUG logging when testing new configurations

---

## Problem: DNS Challenge Fails

### Symptoms
- Traefik logs show DNS challenge errors
- Certificate acquisition times out
- Let's Encrypt rate limiting errors

### Diagnosis
```bash
# Check DNS provider credentials are correct
# For Loopia:
python3 << 'EOF'
import xmlrpc.client

USER = "your-user@loopiaapi"
PASSWORD = "your-password"
DOMAIN = "yourdomain.com"

client = xmlrpc.client.ServerProxy("https://api.loopia.se/RPCSERV", allow_none=True)

# Test API access
try:
    records = client.getZoneRecords(USER, PASSWORD, DOMAIN, "@")
    print(f"✅ API access works. Records: {len(records)}")
except Exception as e:
    print(f"❌ API access failed: {e}")
EOF

# Check Traefik can resolve domain
dig +short yourdomain.com

# Check DNS propagation
dig @1.1.1.1 +short yourdomain.com
dig @8.8.8.8 +short yourdomain.com
```

### Solution
```bash
# Verify DNS credentials in traefik.env
cat /etc/traefik/traefik.env

# Test DNS provider manually
# Create a test TXT record to verify API works

# Increase delay before DNS check (in traefik.yml)
certificatesResolvers:
  dns:
    acme:
      dnsChallenge:
        provider: loopia
        delayBeforeCheck: 300  # Increase from 120 to 300 seconds

# Restart Traefik
systemctl restart traefik
```

### Prevention
- Test DNS API credentials before deployment
- Use appropriate delayBeforeCheck for your DNS provider
- Monitor DNS propagation times for your provider

---

## Problem: Certificate Serves but Shows "TRAEFIK DEFAULT CERT"

### Symptoms
- HTTPS works but browser shows self-signed certificate
- Certificate subject is "CN=TRAEFIK DEFAULT CERT"
- No Let's Encrypt certificate obtained

### Diagnosis
```bash
# Check what certificate is being served
openssl s_client -connect your-ip:443 -servername yourdomain.com </dev/null 2>&1 | \
  openssl x509 -noout -subject -issuer

# If you see:
# subject=CN=TRAEFIK DEFAULT CERT
# This is the default self-signed certificate

# Check for errors in Traefik logs
journalctl -u traefik --since "1 hour ago" | grep -iE 'error|fail|acme'
```

### Solution
Review previous sections - this is usually caused by:
1. Environment variables not loading (see first section)
2. DNS challenge failing (see DNS section)
3. Traefik thinks cert exists but doesn't (see second section)

---

## Problem: Multiple Domains, Some Get Certificates, Others Don't

### Symptoms
- Some domains get Let's Encrypt certificates successfully
- Other domains remain on default certificate
- All use same certResolver configuration

### Diagnosis
```bash
# Check all dynamic configurations
ls -la /etc/traefik/dynamic/
cat /etc/traefik/dynamic/*.yml

# Look for domains in ACME storage
cat /var/lib/traefik/acme.json | python3 -m json.tool | grep '"main"'

# Check logs for specific domain
journalctl -u traefik | grep -i 'problematic-domain.com'
```

### Solution
```bash
# Enable DEBUG logging
sed -i 's/level: "INFO"/level: "DEBUG"/' /etc/traefik/traefik.yml
systemctl restart traefik

# Monitor logs for the specific domain
journalctl -u traefik -f | grep 'problematic-domain.com'

# Look for:
# - "Looking for provided certificate(s) to validate"
# - "Trying to challenge certificate for domain"
# - Any errors related to DNS or ACME
```

Common causes:
1. Domain name mismatch (check spelling in dynamic config)
2. DNS not pointing to correct IP
3. Rate limiting (wait 1 hour, use staging server for testing)
4. DNS provider API limits

---

## Problem: Traefik Service Won't Start

### Symptoms
- `systemctl start traefik` fails
- Status shows: `Failed to start traefik.service`
- Journal shows configuration errors

### Diagnosis
```bash
# Check systemd service status
systemctl status traefik

# Check Traefik configuration syntax
/usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml

# Check for permission issues
ls -la /etc/traefik/
ls -la /var/lib/traefik/
ls -la /var/log/traefik/

# Check if port 80/443 already in use
ss -tlnp | grep -E ':(80|443)'
```

### Solution
```bash
# Fix common permission issues
chown -R traefik:traefik /etc/traefik/
chown -R traefik:traefik /var/lib/traefik/
chown -R traefik:traefik /var/log/traefik/

# Fix ACME storage permissions
chmod 600 /var/lib/traefik/acme.json

# Validate configuration syntax
/usr/local/bin/traefik --configFile=/etc/traefik/traefik.yml --dry-run

# If port conflict, find conflicting process
ss -tlnp | grep ':80'
# Kill or reconfigure conflicting service

# Try starting again
systemctl start traefik
systemctl status traefik
```

---

## Debugging Tools and Commands

### Enable DEBUG Logging
```bash
# Temporarily enable DEBUG
sed -i 's/level: "INFO"/level: "DEBUG"/' /etc/traefik/traefik.yml
systemctl restart traefik

# Monitor logs
journalctl -u traefik -f

# Restore INFO level when done
sed -i 's/level: "DEBUG"/level: "INFO"/' /etc/traefik/traefik.yml
systemctl restart traefik
```

### Check Certificate Details
```bash
# View certificate being served
openssl s_client -connect localhost:443 -servername yourdomain.com </dev/null 2>&1 | \
  openssl x509 -noout -text

# Just subject, issuer, dates
openssl s_client -connect localhost:443 -servername yourdomain.com </dev/null 2>&1 | \
  openssl x509 -noout -subject -issuer -dates
```

### Inspect ACME Storage
```bash
# Pretty-print ACME JSON
cat /var/lib/traefik/acme.json | python3 -m json.tool

# List all domains with certificates
cat /var/lib/traefik/acme.json | python3 -m json.tool | \
  grep -A1 '"main"' | grep -v '^--$' | grep -v 'main'

# Check specific domain
cat /var/lib/traefik/acme.json | python3 -m json.tool | \
  grep -B5 -A10 'yourdomain.com'
```

### Test DNS Challenge Manually
```bash
# Loopia API test
python3 << 'EOF'
import xmlrpc.client

DOMAIN = "viljo.se"
USER = "viljo@loopiaapi"
PASSWORD = "your-password"

client = xmlrpc.client.ServerProxy("https://api.loopia.se/RPCSERV", allow_none=True)

# List current records
records = client.getZoneRecords(USER, PASSWORD, DOMAIN, "@")
for r in records:
    print(f"{r.get('type')}: {r.get('rdata')} (TTL: {r.get('ttl')})")
EOF
```

### Monitor Certificate Renewal
```bash
# Check when certificates expire
cat /var/lib/traefik/acme.json | python3 -m json.tool | \
  python3 -c "
import sys, json, base64, x509
data = json.load(sys.stdin)
for cert in data['dns']['Certificates']:
    print(f\"Domain: {cert['domain']['main']}\")
    # Certificate is base64 encoded
"

# Traefik automatically renews 30 days before expiry
# Watch logs during renewal period
journalctl -u traefik | grep -i renew
```

---

## Best Practices

### 1. Use Staging Server for Testing
```yaml
# In traefik.yml - use staging to avoid rate limits
certificatesResolvers:
  dns:
    acme:
      caServer: "https://acme-staging-v02.api.letsencrypt.org/directory"  # Staging
      # caServer: "https://acme-v02.api.letsencrypt.org/directory"  # Production
```

### 2. Backup ACME Storage
```bash
# Before making changes
cp /var/lib/traefik/acme.json /var/lib/traefik/acme.json.$(date +%Y%m%d_%H%M%S)
```

### 3. Monitor Logs During Deployment
```bash
# In one terminal
journalctl -u traefik -f | grep -iE 'error|acme|certificate|your-domain'

# In another, deploy your changes
systemctl restart traefik
```

### 4. Verify Environment Variables After Each Restart
```bash
# Always check after restart
PID=$(pgrep -x traefik)
cat /proc/$PID/environ | tr '\0' '\n' | grep -E '^(LOOPIA|DNS_)'
```

### 5. Use Consistent Domain Names
- Don't mix `demo.viljo.se` and `demo-site.viljo.se` for the same service
- Remove old dynamic configs when renaming domains
- One router per domain

---

## Common Traefik Configuration Issues

### Incorrect EntryPoint Configuration
```yaml
# WRONG - tls config in wrong place
entryPoints:
  websecure:
    address: ":443"
    tls:  # Don't put tls here
      certResolver: dns

# CORRECT
entryPoints:
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: dns
```

### Missing EnvironmentFile in Systemd
```ini
# /etc/systemd/system/traefik.service
[Service]
...
EnvironmentFile=-/etc/traefik/traefik.env  # Don't forget the minus sign!
...
```

The minus sign (`-`) means "don't fail if file doesn't exist" but file MUST exist for DNS challenge to work.

### Wrong DNS Provider Name
```yaml
# Check the correct provider name for your DNS service
# Traefik uses lego library - see: https://go-acme.github.io/lego/dns/

# Examples:
# - Loopia: "loopia"
# - Cloudflare: "cloudflare"
# - Route53: "route53"

certificatesResolvers:
  dns:
    acme:
      dnsChallenge:
        provider: "loopia"  # Must match exact provider name
```

---

## Rate Limiting

Let's Encrypt has rate limits:
- **50 certificates per registered domain per week**
- **5 duplicate certificates per week**
- **300 new orders per account per 3 hours**

If you hit rate limits:
1. Wait the specified time (usually 1 week)
2. Use staging server for testing: `https://acme-staging-v02.api.letsencrypt.org/directory`
3. Plan certificate requests carefully

Check if you're rate limited:
```bash
journalctl -u traefik | grep -i "rate limit"
```

---

## Getting Help

If none of these solutions work:

1. **Collect diagnostic information**:
   ```bash
   # Run all diagnostic commands and save output
   {
     echo "=== Traefik Status ==="
     systemctl status traefik

     echo -e "\n=== Environment Variables ==="
     PID=$(pgrep -x traefik)
     cat /proc/$PID/environ | tr '\0' '\n' | grep -E '^(LOOPIA|DNS_)'

     echo -e "\n=== Recent Logs ==="
     journalctl -u traefik --since "1 hour ago" --no-pager | tail -100

     echo -e "\n=== Configuration ==="
     cat /etc/traefik/traefik.yml
     cat /etc/traefik/dynamic/*.yml

     echo -e "\n=== ACME Domains ==="
     cat /var/lib/traefik/acme.json | python3 -m json.tool | grep -A2 '"main"'
   } > /tmp/traefik-debug.txt
   ```

2. **Check documentation**:
   - Traefik docs: https://doc.traefik.io/traefik/
   - Lego DNS providers: https://go-acme.github.io/lego/dns/

3. **Review this project's docs**:
   - `docs/development/automation-refactoring-plan.md`
   - `specs/completed/004-demo-website/COMPLETION.md`

---

## Related Documentation

- [Firewall NAT Troubleshooting](./troubleshooting-firewall-nat.md)
- [Container Mapping Reference](../architecture/container-mapping.md)
- [Demo Website Completion Summary](../../specs/completed/004-demo-website/COMPLETION.md)
