# External Testing Methodology

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

## Conclusion

**Golden Rule**: A service is not truly deployed until it has been verified accessible from a true external source (mobile data, external VPS, or external testing service).

Testing from the admin network, even using the WAN IP, provides false confidence and can lead to declaring success when the service is actually inaccessible from the internet.
