# External Testing Methodology

## The Ultimate Goal: Disaster Recovery Automation

### Purpose of This Infrastructure

The primary goal of this infrastructure and all testing is to achieve **100% automated disaster recovery**:

1. **Take identical hardware** with a clean Proxmox installation
2. **Run Ansible playbooks** without any user intervention
3. **Restore backups** of data and configurations
4. **Achieve 100% functionality** - all services accessible and working

### Why Testing Methodology Matters for Disaster Recovery

For this goal to be achievable, **every aspect of the deployment must be reproducible and verifiable**:

- **Infrastructure as Code**: All configurations must be in Ansible playbooks
- **No Manual Steps**: If it requires manual intervention, it breaks disaster recovery
- **External Validation**: Services must work from the internet, not just internal networks
- **Automated DNS**: Dynamic IP changes must be handled automatically
- **Certificate Automation**: Let's Encrypt certificates must obtain without manual DNS changes
- **Backup Strategy**: Data restoration must be scripted and tested

### Testing Validates Automation

When we test from **external sources** (not just the admin network), we validate:

1. **Firewall rules work** - DNAT/SNAT configured correctly
2. **DNS automation works** - Loopia DDNS updates propagate
3. **Certificate automation works** - Let's Encrypt obtains certs without manual intervention
4. **Traefik routing works** - Services accessible via reverse proxy
5. **Network topology works** - DMZ isolation, management network separation

**If a service only works from the admin network**, it means automation failed somewhere, and disaster recovery would require manual intervention.

## Critical Lesson: Always Test from True External Sources

### The Problem

When deploying services that should be accessible from the internet, testing from the admin network (192.168.1.0/16) **does not guarantee external accessibility**, even if you test using the WAN IP address.

### Why Testing from Admin Network is Insufficient

1. **Hairpin NAT May Not Be Configured**: Some router/firewall configurations don't support accessing the WAN IP from internal networks
2. **Different Routing Paths**: Internal → WAN IP may route differently than External → WAN IP
3. **Asymmetric Routing**: Packets may enter correctly but responses may route incorrectly
4. **False Positives**: Success from admin network doesn't prove external routing works

### Example: Mattermost Deployment

During Mattermost deployment (container 163), testing showed:

```bash
# From admin network (192.168.1.3):
$ ssh root@192.168.1.3 "curl -I https://mattermost.viljo.se/"
HTTP/2 200
✅ Success!

# From external testing service:
$ External test result: "Unable to connect"
❌ Failed!
```

**Root Cause**: Testing from admin network used localhost/internal routing, not the actual WAN path through the firewall.

## Correct Testing Methodology

### Step 1: Internal Tests (Baseline)

Test internal connectivity first to ensure services are running:

```bash
# From Proxmox host
ssh root@192.168.1.3 "curl -I http://172.16.10.163:8065/"
# Should return: HTTP/1.1 200 OK
```

### Step 2: Internal → WAN IP Test (Partial Validation)

Test using WAN IP with correct Host header:

```bash
# From Proxmox host
ssh root@192.168.1.3 "curl -k -I -H 'Host: mattermost.viljo.se' https://85.24.186.100/"
# Should return: HTTP/2 200
```

**Note**: This validates Traefik routing and certificate but **does not** validate external accessibility!

### Step 3: External Testing (Required)

**Always** use true external testing before declaring success:

#### Method 1: External Testing Services

Use multiple services to avoid false negatives:

1. **HTTPie Online**: https://httpie.io/app
2. **Uptime Robot**: https://uptimerobot.com
3. **Down For Everyone**: https://downforeveryoneorjustme.com
4. **Is It Down Right Now**: https://www.isitdownrightnow.com
5. **SSL Labs**: https://www.ssllabs.com/ssltest/ (for certificate validation)

#### Method 2: Mobile Data

Use a phone on mobile data (not WiFi):

```bash
# From phone browser (mobile data, not WiFi)
https://mattermost.viljo.se/
```

#### Method 3: External VPS/Server

If you have access to an external VPS:

```bash
# From external VPS
curl -I https://mattermost.viljo.se/
```

#### Method 4: curl via Proxy

Use an HTTP proxy service:

```bash
# Via web proxy
curl -x http://proxy-service.com:8080 -I https://mattermost.viljo.se/
```

### Step 4: DNS Propagation Validation

Verify DNS has propagated to multiple resolvers:

```bash
for dns in 8.8.8.8 1.1.1.1 208.67.222.222 9.9.9.9; do
  echo "=== DNS Server $dns ==="
  dig +short mattermost.viljo.se @$dns
done
```

All should return the same WAN IP.

### Step 5: Port Accessibility Check

Test if ports are reachable from outside:

```bash
# From external location
nc -zv mattermost.viljo.se 443
# Should show: Connection to mattermost.viljo.se port 443 [tcp/https] succeeded!
```

## Common Issues and Solutions

### Issue 1: Works Internally, Fails Externally

**Symptoms**:
- curl from admin network: ✅ Success
- External testing service: ❌ Failed

**Possible Causes**:
1. ISP blocking inbound ports 80/443
2. Firewall DNAT not configured correctly
3. Asymmetric routing (packets in, but responses go wrong path)
4. Port forwarding not enabled on WAN interface

**Debug Steps**:

```bash
# 1. Check firewall NAT rules
ssh root@192.168.1.3 "pct exec 101 -- nft list table ip nat"

# 2. Verify port forwarding in PREROUTING
ssh root@192.168.1.3 "pct exec 101 -- nft list chain ip nat prerouting"

# 3. Check for asymmetric routing issues
ssh root@192.168.1.3 "pct exec 101 -- nft list chain ip nat postrouting"

# 4. Verify SNAT/masquerade rules exist for WAN → DMZ traffic
```

### Issue 2: HTTP Works, HTTPS Fails

**Symptoms**:
- curl http://...: ✅ Success
- curl https://...: ❌ Failed

**Possible Causes**:
1. Port 443 not forwarded in firewall
2. Let's Encrypt certificate acquisition failed
3. Traefik TLS configuration incorrect

**Debug Steps**:

```bash
# 1. Check certificate status
ssh root@192.168.1.3 "cat /var/lib/traefik/acme.json | python3 -m json.tool | grep -A5 'mattermost'"

# 2. Check Traefik logs for ACME errors
ssh root@192.168.1.3 "journalctl -u traefik --since '10 minutes ago' --no-pager | grep -i 'acme\|certificate\|mattermost'"

# 3. Verify port 443 forwarding
ssh root@192.168.1.3 "pct exec 101 -- nft list ruleset | grep 'tcp dport 443'"
```

### Issue 3: DNS Not Propagating

**Symptoms**:
- dig @8.8.8.8: ✅ Returns correct IP
- dig @1.1.1.1: ❌ Returns old IP or NXDOMAIN

**Solution**:
- Lower TTL before changes (300 seconds recommended)
- Wait for TTL expiration (up to 24 hours for some resolvers)
- Use `dig +trace` to see propagation path

### Issue 4: Certificate Validation Fails

**Symptoms**:
- Browser shows "Your connection is not private"
- curl shows certificate error

**Possible Causes**:
1. Certificate not obtained yet (DNS challenge pending)
2. Certificate obtained for wrong domain
3. SNI not working correctly

**Debug Steps**:

```bash
# 1. Check certificate details
openssl s_client -connect mattermost.viljo.se:443 -servername mattermost.viljo.se </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates

# 2. Verify Let's Encrypt obtained certificate
ssh root@192.168.1.3 "cat /var/lib/traefik/acme.json | python3 -m json.tool | grep -B2 'mattermost.viljo.se'"
```

## Testing Checklist Template

Use this checklist for every new service deployment:

```markdown
## Service Deployment Testing: [SERVICE_NAME]

### Phase 1: Internal Connectivity
- [ ] Container running: `pct status [CONTAINER_ID]`
- [ ] Service responding: `curl -I http://[INTERNAL_IP]:[PORT]/`
- [ ] Docker container healthy (if applicable): `docker ps`

### Phase 2: Traefik Routing
- [ ] Dynamic config file created: `/etc/traefik/dynamic/[service].yml`
- [ ] Traefik loaded config: `journalctl -u traefik | grep [service]`
- [ ] Route responding: `curl -k -I -H 'Host: [domain]' https://localhost/`

### Phase 3: DNS Configuration
- [ ] DNS record created: `dig +short [domain] @8.8.8.8`
- [ ] Added to DDNS script: `/usr/local/lib/loopia-ddns/update.py`
- [ ] DNS propagated to multiple resolvers

### Phase 4: Certificate
- [ ] Certificate obtained: `cat /var/lib/traefik/acme.json | grep [domain]`
- [ ] Certificate valid: `openssl s_client -connect [domain]:443`
- [ ] No browser warnings

### Phase 5: Firewall Routing
- [ ] DNAT rule exists: `nft list chain ip nat prerouting | grep 443`
- [ ] SNAT rule exists: `nft list chain ip nat postrouting`
- [ ] Test from WAN IP: `curl -I https://[WAN_IP]/`

### Phase 6: External Testing (REQUIRED)
- [ ] Test from external service: [URL of test result]
- [ ] Test from mobile data: [Success/Fail]
- [ ] Test from external VPS (if available): [Success/Fail]
- [ ] Port scan shows 443 open: `nc -zv [domain] 443`

### Phase 7: Functional Testing
- [ ] Service login page loads
- [ ] Can create account/login
- [ ] Basic functionality works
- [ ] No JavaScript/CSS errors in browser console
```

## Best Practices

1. **Never assume success without external testing** - Even if internal tests pass
2. **Use multiple external testing services** - Avoid false negatives
3. **Test from different networks** - Mobile data, VPS, friends' connections
4. **Wait for DNS propagation** - Allow up to 10 minutes for TTL expiration
5. **Check firewall logs** - Look for blocked connections
6. **Verify certificate before declaring success** - Use SSL Labs or similar
7. **Document test results** - Include external test URLs in commit messages
8. **Test both HTTP and HTTPS** - Ensure redirects work correctly

## Related Documentation

- [SSH Access Methods](./ssh-access-methods.md)
- [Troubleshooting Firewall NAT](./troubleshooting-firewall-nat.md)
- [Traefik Let's Encrypt Troubleshooting](./troubleshooting-traefik-letsencrypt.md)

## Example: Correct Test Sequence

```bash
# 1. Internal test
$ ssh root@192.168.1.3 "curl -I http://172.16.10.163:8065/"
HTTP/1.1 200 OK ✅

# 2. WAN IP test (validates Traefik but not external routing!)
$ ssh root@192.168.1.3 "curl -k -I -H 'Host: mattermost.viljo.se' https://85.24.186.100/"
HTTP/2 200 ✅

# 3. DNS propagation
$ dig +short mattermost.viljo.se @8.8.8.8
85.24.186.100 ✅

# 4. External test (THE CRITICAL STEP)
$ # Use https://httpie.io/app or similar
$ # Enter URL: https://mattermost.viljo.se/
$ # Result: [Document actual result here]

# 5. Port accessibility
$ nc -zv mattermost.viljo.se 443
Connection to mattermost.viljo.se port 443 [tcp/https] succeeded! ✅
```

## Why External Testing Matters

| Test Method | What It Validates | What It Doesn't Validate |
|-------------|-------------------|---------------------------|
| Internal (container IP) | Service running | Traefik, firewall, DNS, external routing |
| WAN IP with Host header | Traefik routing, certificate | External firewall routing, ISP blocks |
| DNS resolution | DNS record exists | Port accessibility, firewall rules |
| External testing service | **EVERYTHING** | Nothing - this is the gold standard |

## Mattermost Deployment Status

**Current Status**: Uncertain - needs external validation

**Tests Passed**:
- ✅ Container running and healthy
- ✅ Internal access working (HTTP/1.1 200)
- ✅ Traefik routing working (HTTP/2 200 via WAN IP)
- ✅ DNS propagated (resolves to 85.24.186.100)
- ✅ Let's Encrypt certificate obtained

**Tests Needed**:
- ⏳ External testing service validation
- ⏳ Mobile data access test
- ⏳ Port 443 accessibility from outside
- ⏳ External VPS test (if available)

## Disaster Recovery Validation

### The Complete Recovery Test

To validate that disaster recovery automation works, you should be able to:

1. **Document the current state**:
   - Take snapshots of all container configurations
   - Backup all data volumes
   - Export current DNS records
   - Document current WAN IP (will change after rebuild)

2. **Destroy everything**:
   - Delete all containers: `pct destroy [CONTAINER_ID]`
   - Delete all Traefik configurations
   - Clear DNS records (or wait for DDNS to update)

3. **Rebuild from scratch**:
   ```bash
   # On fresh Proxmox install with admin network access
   git clone [repository]
   cd Proxmox_config

   # Configure vault password
   ansible-vault edit inventory/group_vars/all/secrets.yml

   # Run main playbook
   ansible-playbook -i inventory/hosts.yml playbooks/site.yml

   # Restore data backups
   ./scripts/restore-backups.sh
   ```

4. **Validate 100% functionality**:
   - All containers running: `pct list`
   - All services accessible via HTTPS from internet
   - All certificates valid (Let's Encrypt auto-obtained)
   - DNS updated automatically (Loopia DDNS)
   - Data restored correctly
   - **Zero manual interventions required**

### Manual Steps Indicate Automation Gaps

If any of these require manual steps, the automation is incomplete:

❌ **Manual certificate request** → Traefik DNS challenge not configured correctly
❌ **Manual DNS update** → Loopia DDNS not working or not configured
❌ **Manual firewall rule** → Firewall Ansible role incomplete
❌ **Manual Traefik config** → Service role doesn't create dynamic config
❌ **Manual service configuration** → Ansible role missing templates or tasks
❌ **Service only works internally** → Firewall DNAT/SNAT not automated

✅ **Goal**: Run one Ansible playbook, restore data backups, and everything works from the internet.

### Documenting Manual Interventions

For the Mattermost deployment in this session, the following were **manual**:

1. ✅ **PostgreSQL database creation** - Executed via SSH, should be in role
2. ✅ **Container creation** - Executed via pct, should be in Ansible role
3. ✅ **Docker installation** - Executed via SSH, should be in Ansible role
4. ✅ **Docker Compose file** - Created via SSH, should be templated in role
5. ✅ **Traefik configuration** - Created via SSH, should be in role
6. ✅ **DNS record creation** - Executed via SSH/Python, should be in role or script
7. ✅ **Permission fixes** - Executed via SSH, should be in role with correct ownership

**Next Steps**: Create `roles/mattermost_api/` with all these steps automated.

### Testing Checklist for Disaster Recovery

Use this checklist to validate automation completeness:

```markdown
## Disaster Recovery Validation: [SERVICE_NAME]

### Pre-Deployment
- [ ] Ansible role exists for service
- [ ] All configuration files templated (no manual edits)
- [ ] Database creation scripted (if applicable)
- [ ] Firewall rules in firewall role
- [ ] DNS record creation scripted or in DDNS
- [ ] Traefik config generated by role
- [ ] No hardcoded IPs (use variables)
- [ ] Secrets in vault, not in code

### Post-Deployment
- [ ] Service accessible from internet (external test)
- [ ] Certificate obtained automatically
- [ ] DNS updated automatically
- [ ] No manual steps required
- [ ] Role is idempotent (can run multiple times)
- [ ] Role includes rollback capability

### Recovery Test
- [ ] Destroy container: `pct destroy [ID]`
- [ ] Re-run playbook: `ansible-playbook -i inventory/hosts.yml playbooks/[service].yml`
- [ ] Service accessible again from internet
- [ ] No errors during playbook execution
- [ ] Certificate re-obtained automatically
- [ ] DNS updated automatically

### Documentation
- [ ] README.md in role directory
- [ ] Variables documented
- [ ] Dependencies listed
- [ ] Example usage provided
- [ ] Troubleshooting section included
```

### Current Automation Status

**Fully Automated Services** (can recover with just Ansible):
- ❓ To be determined (most were deployed manually in this session)

**Partially Automated Services** (require manual steps):
- PostgreSQL (database/user creation manual)
- Keycloak (manual deployment via pct exec)
- GitLab (manual deployment via pct exec)
- Nextcloud (manual deployment via pct exec)
- Mattermost (manual deployment via pct exec)
- Webtop (manual deployment via pct exec)

**Infrastructure Services**:
- ✅ Loopia DDNS (script-based, can be templated)
- ✅ Traefik (systemd service, config files)
- ⚠️ Firewall (container creation manual, nftables config manual)

**Goal**: Move all services from "Partially Automated" to "Fully Automated" by creating comprehensive Ansible roles.

### Example: Automated Service Role Structure

```
roles/mattermost_api/
├── defaults/
│   └── main.yml          # All variables (IPs, ports, resources)
├── handlers/
│   └── main.yml          # Service restart handlers
├── tasks/
│   ├── main.yml          # Orchestration
│   ├── container.yml     # LXC container creation via Proxmox API
│   ├── docker.yml        # Docker installation
│   ├── database.yml      # PostgreSQL database/user creation
│   ├── compose.yml       # Docker Compose file deployment
│   ├── traefik.yml       # Traefik dynamic config creation
│   └── dns.yml           # DNS record creation (optional)
├── templates/
│   ├── docker-compose.yml.j2     # Mattermost Docker Compose
│   ├── traefik-config.yml.j2     # Traefik routing config
│   └── env.j2                    # Environment variables
├── files/
│   └── (static files if needed)
└── README.md             # Usage documentation
```

With this structure, disaster recovery becomes:

```bash
# Rebuild entire infrastructure
ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# Or rebuild single service
ansible-playbook -i inventory/hosts.yml playbooks/mattermost-deploy.yml
```

## Conclusion

**Golden Rule**: A service is not truly deployed until it has been verified accessible from a true external source (mobile data, external VPS, or external testing service).

**Disaster Recovery Rule**: A service is not production-ready until it can be rebuilt completely from Ansible playbooks without manual intervention.

Testing from the admin network, even using the WAN IP, provides false confidence and can lead to declaring success when:
1. The service is inaccessible from the internet
2. The deployment is not reproducible
3. Disaster recovery would fail

**The ultimate validation**: Delete everything, run one Ansible command, restore data backups, and all services work from the internet with valid certificates.
