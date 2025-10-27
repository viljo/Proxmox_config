# Authentication Infrastructure Fix Plan

**Date**: 2025-10-27
**Related Audit**: AUTHENTICATION_AUDIT_2025-10-27.md
**Priority**: HIGH
**Branch**: 001-jitsi-server

## Overview

This document outlines the fixes required to resolve authentication issues identified in the authentication audit. The primary issue is Webtop not being accessible via HTTPS due to missing Traefik routing configuration.

## Issues to Fix

### Issue #1: Webtop Missing from Traefik Routing (HIGH PRIORITY)

**Impact**: Service completely inaccessible externally via HTTPS
**Affected Service**: Webtop (browser.viljo.se)
**Root Cause**: Missing configuration in multiple locations

## Fix Implementation Plan

### Fix #1: Add Webtop to Traefik Routing

**Priority**: HIGH
**Complexity**: Low
**Risk**: Low (additive change only)
**Estimated Time**: 15 minutes

#### Changes Required

1. **Add DNS Record** - Update `inventory/group_vars/all/main.yml`
   - Add "browser" to `loopia_dns_records`
   - Location: Line 13 (after "auth")

2. **Add Traefik Service** - Update `inventory/group_vars/all/main.yml`
   - Add Webtop/browser entry to `traefik_services`
   - Location: After "auth" service (around line 37)
   - Configuration:
     ```yaml
     - name: browser
       host: "browser.{{ public_domain }}"
       container_id: 170
       port: 3000
     ```

3. **Optional: Add oauth2-proxy Forward Auth**
   - Decision point: Should Webtop require SSO authentication?
   - If yes: Add `middlewares: ["oauth2-proxy-auth"]` to Traefik service config
   - If no: Leave as-is (Webtop will use its native authentication)
   - Recommendation: Start without oauth2-proxy, add later if needed

#### Implementation Steps

1. Edit `inventory/group_vars/all/main.yml`:
   - Add "browser" to DNS records list
   - Add browser service to traefik_services list

2. Deploy Traefik configuration:
   ```bash
   ansible-playbook playbooks/site.yml --tags traefik
   ```

3. Deploy Loopia DNS:
   ```bash
   ansible-playbook playbooks/site.yml --tags loopia_dns
   ```

4. Verify DNS propagation:
   ```bash
   dig browser.viljo.se
   ```

5. Test HTTPS access:
   ```bash
   curl -I https://browser.viljo.se
   ```

6. Verify Traefik routing:
   ```bash
   ssh root@192.168.1.3 "cat /etc/traefik/dynamic/services.yml | grep -A10 browser"
   ```

#### Validation Criteria

- DNS record created for browser.viljo.se
- Traefik routing configured for browser service
- HTTPS access working via https://browser.viljo.se
- SSL certificate issued by Let's Encrypt
- Service responds with Webtop login page
- No errors in Traefik logs

#### Rollback Plan

If issues occur:
1. Remove "browser" from traefik_services in main.yml
2. Re-run Traefik deployment
3. Service returns to internal-only access (no external change)

### Fix #2: Update SSO Strategy Documentation (LOW PRIORITY)

**Priority**: LOW
**Complexity**: Low
**Risk**: None (documentation only)
**Estimated Time**: 5 minutes

#### Changes Required

Update `docs/SSO_STRATEGY.md`:
- Add Webtop to service table with updated status
- Document that Webtop is accessible but uses native auth
- Note oauth2-proxy forward auth as optional future enhancement

#### Implementation Steps

1. Edit `docs/SSO_STRATEGY.md`
2. Update Webtop section:
   - Change status from "⚠️ No SSO (native authentication)" to "✅ Accessible (native authentication)"
   - Update notes about forward auth being optional

#### Validation Criteria

- Documentation accurately reflects Webtop status
- Forward auth option clearly marked as optional

## Implementation Order

Execute fixes in this order:

1. **Fix #1: Webtop Traefik Routing** (HIGH PRIORITY)
   - Immediate impact: Makes service accessible
   - Dependencies: None
   - Estimated time: 15 minutes

2. **Fix #2: Documentation Update** (LOW PRIORITY)
   - Can be done anytime after Fix #1
   - Dependencies: Fix #1 completion
   - Estimated time: 5 minutes

## Testing Plan

### Test 1: DNS Resolution
```bash
# Should return IP address
dig browser.viljo.se +short
```
**Expected**: Returns public IP (same as viljo.se)

### Test 2: HTTPS Access
```bash
# Should return 200 or 302 (redirect to login)
curl -I https://browser.viljo.se
```
**Expected**: HTTP 200 or 302, valid SSL certificate

### Test 3: Traefik Configuration
```bash
# Should show browser service configuration
ssh root@192.168.1.3 "cat /etc/traefik/dynamic/services.yml | grep -A10 browser"
```
**Expected**: Shows browser router and service configuration

### Test 4: Service Functionality
1. Open browser to https://browser.viljo.se
2. Verify Webtop login page appears
3. Login with Webtop credentials
4. Verify desktop environment loads

**Expected**: Full Webtop functionality via HTTPS

### Test 5: SSL Certificate
```bash
# Check certificate validity
echo | openssl s_client -connect browser.viljo.se:443 -servername browser.viljo.se 2>/dev/null | openssl x509 -noout -subject -issuer
```
**Expected**: Valid Let's Encrypt certificate

## Risk Assessment

### Fix #1: Webtop Traefik Routing

**Technical Risks**: LOW
- Additive change only (no modification to existing services)
- Well-tested Traefik pattern (same as other services)
- Easy rollback (remove configuration)

**Impact Risks**: LOW
- Only affects Webtop access (currently non-functional externally)
- No impact on other services
- No downtime for existing services

**Security Risks**: LOW
- Exposes Webtop login page publicly (same as other services)
- Webtop has native authentication
- Consider adding oauth2-proxy forward auth for additional security layer

### Fix #2: Documentation Update

**Risks**: NONE (documentation only)

## Decision Points

### Decision #1: oauth2-proxy Forward Auth for Webtop

**Question**: Should we add oauth2-proxy forward authentication to Webtop?

**Option A: No Forward Auth (Recommended)**
- Pros:
  - Simpler configuration
  - Users only need Webtop credentials
  - Consistent with current Webtop deployment model
- Cons:
  - No SSO integration
  - Separate credential management
  - No centralized access control

**Option B: Add Forward Auth**
- Pros:
  - Adds SSO layer (GitLab.com authentication required first)
  - Centralized access control via Keycloak
  - Additional security layer
- Cons:
  - Double authentication (oauth2-proxy + Webtop login)
  - More complex user experience
  - Not true SSO (Webtop still requires separate login)

**Recommendation**: Option A (No Forward Auth)
**Rationale**:
- Webtop doesn't support native OIDC, so forward auth provides URL protection but not true SSO
- Double authentication creates poor user experience
- If access control is needed later, can add forward auth incrementally
- Focus on services with native OAuth support for better SSO experience

**Decision**: Start with Option A, revisit if security requirements change

## Post-Implementation Actions

After completing fixes:

1. **Update Service Status**
   - Mark Webtop as "deployed_working" in services.yml
   - Update status notes to indicate HTTPS access working

2. **Test From External Network**
   - Verify access from outside the local network
   - Confirm SSL certificate validity
   - Test login functionality

3. **Update Infrastructure Documentation**
   - Add Webtop to working services list
   - Document access URL and authentication method
   - Update network topology diagrams if needed

4. **Monitor for Issues**
   - Check Traefik logs for errors
   - Monitor Webtop container logs
   - Watch for SSL certificate renewal
   - Check for any performance issues

5. **Document Access Instructions**
   - Create user guide for Webtop access
   - Document credential management
   - Add to links portal (if desired)

## Future Considerations

### OAuth2-Proxy Forward Auth

If security requirements change:
1. Add middleware to Webtop Traefik service
2. Test double authentication flow
3. Document user experience trade-offs
4. Consider alternative access control methods

### Alternative Services

If Webtop authentication becomes problematic:
- Evaluate alternative browser-based desktop solutions
- Consider services with native OIDC support
- Assess if VPN access is more appropriate for this use case

### Jitsi Meet Integration

Current branch (001-jitsi-server) is adding Jitsi:
- Use learnings from this audit for Jitsi SSO implementation
- Follow authentication decision tree from audit
- Implement JWT authentication with Keycloak for moderator roles
- Ensure anonymous access works without authentication

## Appendix A: Configuration Snippets

### DNS Record Addition (main.yml)
```yaml
loopia_dns_records:
  - host: "@"
    ttl: 600
  - host: links
  - host: auth
  - host: browser  # ADD THIS LINE
  - host: gitlab
  # ... rest of records
```

### Traefik Service Addition (main.yml)
```yaml
traefik_services:
  # ... existing services
  - name: auth
    host: "auth.{{ public_domain }}"
    url: "http://172.16.10.167:4180"
  - name: browser  # ADD THIS BLOCK
    host: "browser.{{ public_domain }}"
    container_id: 170
    port: 3000
  - name: gitlab
    host: "gitlab.{{ public_domain }}"
  # ... rest of services
```

### Optional: With oauth2-proxy Forward Auth
```yaml
  - name: browser
    host: "browser.{{ public_domain }}"
    container_id: 170
    port: 3000
    middlewares:
      - oauth2-proxy-auth  # ADD THIS IF FORWARD AUTH DESIRED
```

## Appendix B: Verification Commands

### Check Container Status
```bash
ssh root@192.168.1.3 "pct status 170"
```

### Check Container Network
```bash
ssh root@192.168.1.3 "pct exec 170 -- hostname -I"
```

### Check Docker Container
```bash
ssh root@192.168.1.3 "pct exec 170 -- docker ps"
```

### Check Webtop Logs
```bash
ssh root@192.168.1.3 "pct exec 170 -- docker logs webtop"
```

### Check Traefik Routes
```bash
ssh root@192.168.1.3 "curl -s http://localhost:8080/api/http/routers | jq '.[] | select(.name | contains(\"browser\"))'"
```

## Appendix C: Testing Checklist

- [ ] DNS record exists for browser.viljo.se
- [ ] DNS resolves to correct IP
- [ ] Traefik configuration includes browser service
- [ ] HTTPS access returns 200/302 status
- [ ] SSL certificate is valid and issued by Let's Encrypt
- [ ] Webtop login page displays correctly
- [ ] Can login with Webtop credentials
- [ ] Desktop environment loads properly
- [ ] No errors in Traefik logs
- [ ] No errors in Webtop container logs
- [ ] Access works from external network
- [ ] Documentation updated
- [ ] SSO_STRATEGY.md reflects current state

## Appendix D: Contact and Resources

**Documentation References**:
- Main audit: `docs/AUTHENTICATION_AUDIT_2025-10-27.md`
- SSO strategy: `docs/SSO_STRATEGY.md`
- Nextcloud SSO implementation: `docs/NEXTCLOUD_DEPLOYMENT_COMPLETE.md`

**Configuration Files**:
- Main configuration: `inventory/group_vars/all/main.yml`
- OAuth2-proxy config: `inventory/group_vars/all/oauth2_proxy.yml`
- Keycloak config: `inventory/group_vars/all/keycloak.yml`
- Webtop config: `roles/webtop_api/defaults/main.yml`

**Playbooks**:
- Full deployment: `playbooks/site.yml`
- Webtop deployment: `playbooks/webtop-deploy.yml`

## Conclusion

This fix plan addresses the single high-priority authentication issue (Webtop HTTPS access) with low-risk, well-tested configuration changes. The infrastructure's authentication system is fundamentally sound - this is simply completing the Traefik routing configuration that was missed during Webtop deployment.

Implementation is straightforward and can be completed in under 20 minutes with immediate verification of results.
