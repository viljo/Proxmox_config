#!/bin/bash
# Infrastructure Status Check Script
# Checks DNS, HTTPS, SSL certificates for external services
# Run this after deployments or to verify infrastructure status

set -o pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Service definitions
# Format: "service_name:domain"
SERVICES=(
    "Links Portal:links.viljo.se"
    "Jitsi Meet:meet.viljo.se"
    "Cloud Storage:cloud.viljo.se"
    "Media Services:media.viljo.se"
    "OAuth2 Proxy:auth.viljo.se"
)

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Infrastructure Status Check${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Function to print test result
print_result() {
    local test_name="$1"
    local status="$2"
    local details="$3"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name: ${GREEN}PASS${NC} $details"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $test_name: ${YELLOW}WARNING${NC} $details"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}✗${NC} $test_name: ${RED}FAIL${NC} $details"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Check DNS resolution
echo -e "${BLUE}[1] Checking DNS Resolution${NC}"
for service_entry in "${SERVICES[@]}"; do
    IFS=: read -r name domain <<< "$service_entry"
    DNS_IP=$(dig +short "$domain" @1.1.1.1 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
    if [ -n "$DNS_IP" ]; then
        print_result "DNS: $name" "PASS" "($DNS_IP)"
    else
        print_result "DNS: $name" "FAIL" "(no resolution - needs DNS configuration)"
    fi
done
echo ""

# Check HTTPS accessibility
echo -e "${BLUE}[2] Checking HTTPS Access${NC}"
for service_entry in "${SERVICES[@]}"; do
    IFS=: read -r name domain <<< "$service_entry"

    # Skip if no DNS
    DNS_IP=$(dig +short "$domain" @1.1.1.1 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
    if [ -z "$DNS_IP" ]; then
        continue
    fi

    HTTP_CODE=$(curl -I -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "https://$domain" 2>&1)

    if [ "$HTTP_CODE" = "000" ]; then
        print_result "HTTPS: $name" "FAIL" "(connection timeout)"
    elif [ "$HTTP_CODE" = "200" ]; then
        print_result "HTTPS: $name" "PASS" "(HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        print_result "HTTPS: $name" "PASS" "(HTTP $HTTP_CODE - auth required)"
    elif [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
        print_result "HTTPS: $name" "PASS" "(HTTP $HTTP_CODE - redirect)"
    elif [ "$HTTP_CODE" = "404" ]; then
        print_result "HTTPS: $name" "WARN" "(HTTP $HTTP_CODE - not found)"
    else
        print_result "HTTPS: $name" "WARN" "(HTTP $HTTP_CODE)"
    fi
done
echo ""

# Check SSL certificates
echo -e "${BLUE}[3] Checking SSL Certificates${NC}"
for service_entry in "${SERVICES[@]}"; do
    IFS=: read -r name domain <<< "$service_entry"

    # Skip if no DNS
    DNS_IP=$(dig +short "$domain" @1.1.1.1 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
    if [ -z "$DNS_IP" ]; then
        continue
    fi

    CERT_EXPIRY=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -n "$CERT_EXPIRY" ]; then
        # Calculate days until expiration
        if command -v gdate >/dev/null 2>&1; then
            # macOS with GNU coreutils
            EXPIRY_EPOCH=$(gdate -d "$CERT_EXPIRY" +%s 2>/dev/null || echo "0")
        else
            # Try macOS native date format
            EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$CERT_EXPIRY" +%s 2>/dev/null || echo "0")
        fi

        if [ "$EXPIRY_EPOCH" != "0" ]; then
            NOW_EPOCH=$(date +%s)
            DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

            if [ $DAYS_LEFT -lt 7 ]; then
                print_result "SSL: $name" "FAIL" "(expires in $DAYS_LEFT days - URGENT)"
            elif [ $DAYS_LEFT -lt 30 ]; then
                print_result "SSL: $name" "WARN" "(expires in $DAYS_LEFT days)"
            else
                print_result "SSL: $name" "PASS" "(expires in $DAYS_LEFT days)"
            fi
        else
            print_result "SSL: $name" "WARN" "(could not parse expiry)"
        fi
    else
        print_result "SSL: $name" "FAIL" "(could not retrieve certificate)"
    fi
done
echo ""

# Check HTTP to HTTPS redirect
echo -e "${BLUE}[4] Checking HTTP to HTTPS Redirect${NC}"
# Test with first working service
WORKING_DOMAIN=""
for service_entry in "${SERVICES[@]}"; do
    IFS=: read -r name domain <<< "$service_entry"
    DNS_IP=$(dig +short "$domain" @1.1.1.1 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
    if [ -n "$DNS_IP" ]; then
        WORKING_DOMAIN="$domain"
        break
    fi
done

if [ -n "$WORKING_DOMAIN" ]; then
    HTTP_REDIRECT=$(curl -s -I --connect-timeout 5 "http://$WORKING_DOMAIN" 2>&1 | grep -i "^location:" | grep -i "https")
    if [ -n "$HTTP_REDIRECT" ]; then
        print_result "HTTP Redirect" "PASS" "(redirects to HTTPS)"
    else
        print_result "HTTP Redirect" "WARN" "(no redirect detected)"
    fi
else
    print_result "HTTP Redirect" "FAIL" "(no working domain to test)"
fi
echo ""

# Summary
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Total checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo ""

SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
if [ $SUCCESS_RATE -ge 90 ]; then
    echo -e "${GREEN}✓ Infrastructure Status: HEALTHY ($SUCCESS_RATE%)${NC}"
    exit 0
elif [ $SUCCESS_RATE -ge 70 ]; then
    echo -e "${YELLOW}⚠ Infrastructure Status: DEGRADED ($SUCCESS_RATE%)${NC}"
    exit 0
else
    echo -e "${RED}✗ Infrastructure Status: CRITICAL ($SUCCESS_RATE%)${NC}"
    exit 1
fi
