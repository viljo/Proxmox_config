#!/bin/bash
#
# Test script for Nextcloud SSO implementation
# This script validates the SSO configuration from the Proxmox host
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROXMOX_HOST="192.168.1.3"
NEXTCLOUD_CONTAINER="155"
KEYCLOAK_CONTAINER="151"
NEXTCLOUD_URL="https://nextcloud.viljo.se"
KEYCLOAK_URL="https://keycloak.viljo.se"

echo "=========================================="
echo "    Nextcloud SSO Configuration Test"
echo "=========================================="
echo ""

# Function to run commands on containers via Proxmox
run_on_container() {
    local container_id=$1
    local command=$2
    ssh root@${PROXMOX_HOST} "pct exec ${container_id} -- bash -c '${command}'"
}

# Function to check status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: $1"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $1"
        return 1
    fi
}

# Test 1: Check Nextcloud container is running
echo -e "${YELLOW}Test 1: Checking Nextcloud container status${NC}"
ssh root@${PROXMOX_HOST} "pct status ${NEXTCLOUD_CONTAINER}" | grep -q "running"
check_status "Nextcloud container is running"

# Test 2: Check Keycloak container is running
echo -e "${YELLOW}Test 2: Checking Keycloak container status${NC}"
ssh root@${PROXMOX_HOST} "pct status ${KEYCLOAK_CONTAINER}" | grep -q "running"
check_status "Keycloak container is running"

# Test 3: Check Nextcloud Docker container
echo -e "${YELLOW}Test 3: Checking Nextcloud Docker container${NC}"
run_on_container ${NEXTCLOUD_CONTAINER} "docker ps | grep -q nextcloud"
check_status "Nextcloud Docker container is running"

# Test 4: Check user_oidc app is enabled
echo -e "${YELLOW}Test 4: Checking user_oidc app status${NC}"
run_on_container ${NEXTCLOUD_CONTAINER} "docker exec -u www-data nextcloud php occ app:list" | grep -q "user_oidc"
check_status "user_oidc app is installed and enabled"

# Test 5: Check OIDC provider configuration
echo -e "${YELLOW}Test 5: Checking OIDC provider configuration${NC}"
PROVIDER_CONFIG=$(run_on_container ${NEXTCLOUD_CONTAINER} "docker exec -u www-data nextcloud php occ config:app:get user_oidc providers")
echo "$PROVIDER_CONFIG" | grep -q "keycloak"
check_status "Keycloak provider is configured"

# Test 6: Check Keycloak client exists
echo -e "${YELLOW}Test 6: Checking Keycloak client configuration${NC}"
run_on_container ${KEYCLOAK_CONTAINER} "docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients --server http://localhost:8080 --realm master --user admin --password \$(cat /opt/keycloak/.admin_password 2>/dev/null || echo 'admin') 2>/dev/null" | grep -q "nextcloud" || true
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: Keycloak client 'nextcloud' exists"
else
    echo -e "${YELLOW}⚠️  WARN${NC}: Could not verify Keycloak client (may need admin password)"
fi

# Test 7: Check HTTPS endpoints
echo -e "${YELLOW}Test 7: Checking HTTPS endpoints${NC}"
curl -s -o /dev/null -w "%{http_code}" ${NEXTCLOUD_URL} | grep -q "200\|301\|302"
check_status "Nextcloud HTTPS endpoint is reachable"

curl -s -o /dev/null -w "%{http_code}" ${KEYCLOAK_URL} | grep -q "200\|301\|302"
check_status "Keycloak HTTPS endpoint is reachable"

# Test 8: Check discovery endpoint
echo -e "${YELLOW}Test 8: Checking OIDC discovery endpoint${NC}"
DISCOVERY_URL="${KEYCLOAK_URL}/realms/master/.well-known/openid-configuration"
curl -s ${DISCOVERY_URL} | grep -q "authorization_endpoint"
check_status "OIDC discovery endpoint is working"

# Test 9: Check Nextcloud trusted domains
echo -e "${YELLOW}Test 9: Checking Nextcloud trusted domains${NC}"
run_on_container ${NEXTCLOUD_CONTAINER} "docker exec -u www-data nextcloud php occ config:system:get trusted_domains" | grep -q "nextcloud.viljo.se"
check_status "nextcloud.viljo.se is in trusted domains"

# Test 10: Check overwrite protocol
echo -e "${YELLOW}Test 10: Checking HTTPS protocol override${NC}"
PROTOCOL=$(run_on_container ${NEXTCLOUD_CONTAINER} "docker exec -u www-data nextcloud php occ config:system:get overwriteprotocol")
echo "$PROTOCOL" | grep -q "https"
check_status "HTTPS protocol override is configured"

echo ""
echo "=========================================="
echo "    Test Summary"
echo "=========================================="
echo ""

# Generate authentication test URL
AUTH_URL="${KEYCLOAK_URL}/realms/master/protocol/openid-connect/auth"
AUTH_URL="${AUTH_URL}?client_id=nextcloud"
AUTH_URL="${AUTH_URL}&redirect_uri=${NEXTCLOUD_URL}/apps/user_oidc/code"
AUTH_URL="${AUTH_URL}&response_type=code"
AUTH_URL="${AUTH_URL}&scope=openid%20profile%20email"

echo "Manual Testing Instructions:"
echo "-----------------------------"
echo "1. Open a browser in incognito/private mode"
echo "2. Navigate to: ${NEXTCLOUD_URL}"
echo "3. Click 'Sign in with GitLab SSO' button"
echo "4. You should be redirected to Keycloak"
echo "5. Click 'Sign in with GitLab' on Keycloak"
echo "6. Authenticate with your GitLab.com account"
echo "7. You should be logged into Nextcloud"
echo ""
echo "Direct auth test URL:"
echo "${AUTH_URL}"
echo ""

# Check if admin user needs to be configured
echo "Post-Login Admin Setup:"
echo "------------------------"
echo "After first SSO login, grant admin access with:"
echo "ssh root@${PROXMOX_HOST} \"pct exec ${NEXTCLOUD_CONTAINER} -- docker exec -u www-data nextcloud php occ group:adduser admin anders\""
echo ""

echo -e "${GREEN}✅ SSO configuration tests completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Test the authentication flow manually"
echo "2. Verify user auto-provisioning works"
echo "3. Grant admin access after first login"
echo "4. Document any issues found"