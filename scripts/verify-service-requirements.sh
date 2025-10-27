#!/bin/bash
# Comprehensive service requirements verification
# Usage: ./scripts/verify-service-requirements.sh servicename
#
# Verifies that a service meets all 3 mandatory requirements:
# 1. DNS entry at Loopia
# 2. HTTPS certificate (Traefik + Let's Encrypt)
# 3. SSO integration via Keycloak
#
# Part of the infrastructure service implementation pipeline.
# See: docs/SERVICE_IMPLEMENTATION_PIPELINE.md

set -e

SERVICE_NAME="$1"
PUBLIC_DOMAIN="viljo.se"
FQDN="${SERVICE_NAME}.${PUBLIC_DOMAIN}"

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <servicename>"
    echo ""
    echo "Example: $0 jellyfin"
    echo ""
    echo "This script verifies that a service meets all 3 mandatory requirements:"
    echo "  1. DNS entry (resolves correctly)"
    echo "  2. HTTPS certificate (valid Let's Encrypt)"
    echo "  3. SSO integration (manual verification required)"
    exit 1
fi

echo "========================================"
echo "Service Requirements Verification"
echo "========================================"
echo "Service: $SERVICE_NAME"
echo "FQDN: $FQDN"
echo "Date: $(date)"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall status
OVERALL_STATUS=0

# Requirement 1: DNS Entry
echo "========================================"
echo "Requirement 1: DNS Entry"
echo "========================================"

DNS_IP=$(dig +short "$FQDN" @1.1.1.1 | head -1)
if [ -n "$DNS_IP" ]; then
    echo -e "${GREEN}✓ DNS resolves${NC}"
    echo "  IP Address: $DNS_IP"

    # Check if IP is public (not private)
    if echo "$DNS_IP" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.)'; then
        echo -e "${YELLOW}⚠ Warning: IP appears to be private (RFC1918)${NC}"
        echo "  This may be intentional for internal services"
    fi

    # Check multiple DNS resolvers for consistency
    DNS_IP_GOOGLE=$(dig +short "$FQDN" @8.8.8.8 | head -1)
    DNS_IP_CLOUDFLARE=$(dig +short "$FQDN" @1.0.0.1 | head -1)

    if [ "$DNS_IP" != "$DNS_IP_GOOGLE" ] || [ "$DNS_IP" != "$DNS_IP_CLOUDFLARE" ]; then
        echo -e "${YELLOW}⚠ Warning: DNS propagation may not be complete${NC}"
        echo "  1.1.1.1: $DNS_IP"
        echo "  8.8.8.8: $DNS_IP_GOOGLE"
        echo "  1.0.0.1: $DNS_IP_CLOUDFLARE"
    fi
else
    echo -e "${RED}✗ DNS does not resolve${NC}"
    echo "  Action: Add DNS entry to inventory/group_vars/all/main.yml"
    echo ""
    echo "  Add this to loopia_dns_records:"
    echo "    - host: $SERVICE_NAME"
    echo "      ttl: 600"
    echo ""
    echo "  Then run:"
    echo "    ansible-playbook -i inventory/hosts.yml playbooks/loopia-dns-deploy.yml --ask-vault-pass"
    OVERALL_STATUS=1
fi

# Requirement 2: HTTPS Certificate
echo ""
echo "========================================"
echo "Requirement 2: HTTPS Certificate"
echo "========================================"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$FQDN" --max-time 10 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" == "000" ]; then
    echo -e "${RED}✗ HTTPS connection failed${NC}"
    echo "  Could not connect to https://$FQDN"
    echo ""
    echo "  Action: Check Traefik configuration and certificate"
    echo "  1. Verify DNS resolves (Requirement 1 must pass first)"
    echo "  2. Add Traefik service entry to inventory/group_vars/all/main.yml:"
    echo "       traefik_services:"
    echo "         - name: $SERVICE_NAME"
    echo "           host: \"$SERVICE_NAME.{{ public_domain }}\""
    echo "           container_id: \"{{ ${SERVICE_NAME}_container_id }}\""
    echo "           port: 8080  # Adjust to actual port"
    echo "  3. Deploy: ansible-playbook playbooks/traefik-deploy.yml --ask-vault-pass"
    echo "  4. Monitor: pct exec 167 -- docker logs -f traefik"
    OVERALL_STATUS=1
elif [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 400 ]; then
    echo -e "${GREEN}✓ HTTPS accessible${NC}"
    echo "  HTTP Status: $HTTP_STATUS"

    # Check if redirect (3xx)
    if [ "$HTTP_STATUS" -ge 300 ] && [ "$HTTP_STATUS" -lt 400 ]; then
        echo -e "${BLUE}  Note: Service redirects (this may be expected)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ HTTPS connection returned non-success status${NC}"
    echo "  HTTP Status: $HTTP_STATUS"
    echo "  The service may not be fully configured yet"
fi

# Check certificate details
echo ""
echo "Checking certificate..."
CERT_INFO=$(echo | openssl s_client -connect "$FQDN:443" -servername "$FQDN" 2>/dev/null | openssl x509 -noout -issuer -subject -dates 2>/dev/null || echo "")

if [ -z "$CERT_INFO" ]; then
    echo -e "${RED}✗ Could not retrieve certificate${NC}"
    echo "  Service may not be responding on port 443"
    OVERALL_STATUS=1
elif echo "$CERT_INFO" | grep -q "Let's Encrypt\|Let's Encrypt"; then
    echo -e "${GREEN}✓ Valid Let's Encrypt certificate${NC}"

    # Extract and display expiry
    NOT_AFTER=$(echo "$CERT_INFO" | grep "notAfter" | cut -d= -f2)
    echo "  Expires: $NOT_AFTER"

    # Check if expiring soon (< 30 days)
    # Note: Date parsing is platform-specific
    if command -v gdate >/dev/null 2>&1; then
        # macOS with GNU coreutils
        EXPIRY_EPOCH=$(gdate -d "$NOT_AFTER" +%s 2>/dev/null || echo "0")
    else
        # Linux or macOS without GNU coreutils
        EXPIRY_EPOCH=$(date -d "$NOT_AFTER" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$NOT_AFTER" +%s 2>/dev/null || echo "0")
    fi

    if [ "$EXPIRY_EPOCH" != "0" ]; then
        NOW_EPOCH=$(date +%s)
        DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

        if [ "$DAYS_UNTIL_EXPIRY" -lt 30 ]; then
            echo -e "${YELLOW}⚠ Certificate expires in $DAYS_UNTIL_EXPIRY days${NC}"
            echo "  Traefik should auto-renew; monitor renewal logs"
        elif [ "$DAYS_UNTIL_EXPIRY" -lt 0 ]; then
            echo -e "${RED}✗ Certificate is EXPIRED${NC}"
            echo "  Restart Traefik to trigger renewal: pct exec 167 -- docker restart traefik"
            OVERALL_STATUS=1
        else
            echo -e "${GREEN}  Certificate valid for $DAYS_UNTIL_EXPIRY days${NC}"
        fi
    fi

    # Display subject
    SUBJECT=$(echo "$CERT_INFO" | grep "subject" | cut -d= -f2-)
    echo "  Subject: $SUBJECT"
else
    echo -e "${RED}✗ Certificate not from Let's Encrypt or invalid${NC}"
    echo "  Certificate issuer:"
    echo "$CERT_INFO" | grep "issuer" || echo "  (Could not determine issuer)"
    echo ""
    echo "  Action: Check Traefik logs for certificate issuance errors"
    echo "    pct exec 167 -- docker logs traefik 2>&1 | grep -i error"
    echo "    pct exec 167 -- docker logs traefik 2>&1 | grep -i certificate"
    OVERALL_STATUS=1
fi

# Requirement 3: SSO Integration
echo ""
echo "========================================"
echo "Requirement 3: SSO Integration"
echo "========================================"

# Check if Keycloak is accessible
DISCOVERY_URL="https://keycloak.${PUBLIC_DOMAIN}/realms/master/.well-known/openid-configuration"
DISCOVERY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DISCOVERY_URL" 2>/dev/null || echo "000")

if [ "$DISCOVERY_STATUS" == "200" ]; then
    echo -e "${GREEN}✓ Keycloak discovery endpoint accessible${NC}"
    echo "  Discovery URL: $DISCOVERY_URL"
else
    echo -e "${RED}✗ Keycloak discovery endpoint not accessible${NC}"
    echo "  Status: $DISCOVERY_STATUS"
    echo "  URL: $DISCOVERY_URL"
    echo ""
    echo "  Action: Verify Keycloak is running"
    echo "    pct list | grep keycloak"
    echo "    pct exec 151 -- docker ps | grep keycloak"
    OVERALL_STATUS=1
fi

# Check for SSO integration indicators (HTML page check)
echo ""
echo "Checking for SSO integration..."
PAGE_CONTENT=$(curl -s "https://$FQDN" --max-time 10 2>/dev/null || echo "")

if echo "$PAGE_CONTENT" | grep -qi "sso\|sign in with\|oauth\|keycloak\|gitlab.*sso\|login.*gitlab"; then
    echo -e "${GREEN}✓ SSO integration appears to be present${NC}"
    echo "  (Found SSO/OAuth references in HTML)"
elif echo "$PAGE_CONTENT" | grep -qi "login\|sign in\|authenticate"; then
    echo -e "${YELLOW}⚠ Login page found but SSO integration unclear${NC}"
    echo "  Action: Manually verify SSO login flow"
    echo "    1. Open: https://$FQDN"
    echo "    2. Look for 'Sign in with GitLab SSO' or similar button"
    echo "    3. Test complete login flow"
else
    echo -e "${YELLOW}⚠ Cannot automatically verify SSO integration${NC}"
    echo "  Service may not have a login page or SSO not configured"
    echo ""
    echo "  Action: Manually test SSO login flow"
    echo "    1. Open: https://$FQDN (in incognito mode)"
    echo "    2. Click SSO/OAuth login button"
    echo "    3. Authenticate via Keycloak → GitLab.com"
    echo "    4. Verify successful return to service"
fi

# Check inventory configuration
echo ""
echo "========================================"
echo "Configuration Checks"
echo "========================================"

INVENTORY_FILE="$PROJECT_ROOT/inventory/group_vars/all/main.yml"
if [ -f "$INVENTORY_FILE" ]; then
    # Check DNS entry
    if grep -q "host: $SERVICE_NAME" "$INVENTORY_FILE"; then
        echo -e "${GREEN}✓ DNS entry found in inventory${NC}"
        echo "  File: inventory/group_vars/all/main.yml"
    else
        echo -e "${YELLOW}⚠ DNS entry not found in inventory${NC}"
        echo "  Action: Add to loopia_dns_records in $INVENTORY_FILE"
        echo "    - host: $SERVICE_NAME"
        echo "      ttl: 600"
    fi

    # Check Traefik service entry
    if grep -q "name: $SERVICE_NAME" "$INVENTORY_FILE"; then
        echo -e "${GREEN}✓ Traefik service entry found in inventory${NC}"
        echo "  File: inventory/group_vars/all/main.yml"
    else
        echo -e "${YELLOW}⚠ Traefik service entry not found in inventory${NC}"
        echo "  Action: Add to traefik_services in $INVENTORY_FILE"
        echo "    - name: $SERVICE_NAME"
        echo "      host: \"$SERVICE_NAME.{{ public_domain }}\""
        echo "      container_id: \"{{ ${SERVICE_NAME}_container_id }}\""
        echo "      port: 8080  # Adjust to actual service port"
    fi
else
    echo -e "${RED}✗ Inventory file not found${NC}"
    echo "  Expected: $INVENTORY_FILE"
    echo "  Are you running from the project root?"
fi

# Check for Keycloak client (requires vault access)
SECRETS_FILE="$PROJECT_ROOT/inventory/group_vars/all/secrets.yml"
if [ -f "$SECRETS_FILE" ]; then
    echo -e "${BLUE}  Note: Keycloak client secret check requires vault password${NC}"
    echo "  To verify manually:"
    echo "    ansible-vault view inventory/group_vars/all/secrets.yml | grep ${SERVICE_NAME}_oidc"
else
    echo -e "${YELLOW}⚠ Secrets vault file not found${NC}"
    echo "  Expected: $SECRETS_FILE"
fi

# Final summary
echo ""
echo "========================================"
echo "Summary"
echo "========================================"

echo ""
echo "Core Requirements:"
if [ -n "$DNS_IP" ]; then
    echo -e "  [1] DNS Entry:          ${GREEN}PASS${NC}"
else
    echo -e "  [1] DNS Entry:          ${RED}FAIL${NC}"
fi

if echo "$CERT_INFO" | grep -q "Let's Encrypt"; then
    echo -e "  [2] HTTPS Certificate:  ${GREEN}PASS${NC}"
else
    echo -e "  [2] HTTPS Certificate:  ${RED}FAIL${NC}"
fi

echo -e "  [3] SSO Integration:    ${YELLOW}MANUAL VERIFICATION REQUIRED${NC}"

echo ""
echo "Next Steps:"
echo "  1. Manually test SSO login flow at https://$FQDN"
echo "     - Open in incognito/private browsing mode"
echo "     - Click 'Sign in with GitLab SSO' or similar"
echo "     - Complete authentication flow"
echo "     - Verify user auto-provisioned"
echo "  2. Grant admin access if needed (service-specific command)"
echo "  3. Update service documentation with SSO details"
echo "  4. Add service to production monitoring"
echo ""

if [ "$OVERALL_STATUS" -eq 0 ] && [ -n "$DNS_IP" ] && echo "$CERT_INFO" | grep -q "Let's Encrypt"; then
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}Automated checks: PASSED${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo "Complete manual SSO testing before production deployment."
    echo ""
    echo "Documentation:"
    echo "  - Implementation Guide: docs/SERVICE_IMPLEMENTATION_PIPELINE.md"
    echo "  - Quick Reference: docs/SSO_DNS_HTTPS_QUICKREF.md"
    echo "  - Workflow Guide: docs/NEW_SERVICE_WORKFLOW.md"
    exit 0
else
    echo -e "${RED}================================${NC}"
    echo -e "${RED}Automated checks: FAILED${NC}"
    echo -e "${RED}================================${NC}"
    echo ""
    echo "Fix issues above before proceeding to production."
    echo ""
    echo "Documentation:"
    echo "  - Implementation Guide: docs/SERVICE_IMPLEMENTATION_PIPELINE.md"
    echo "  - Troubleshooting: See guide Section B for detailed fixes"
    exit 1
fi
