#!/bin/bash
# Infrastructure Status Check Script
# Checks connectivity, DNS, external access, and service health
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
# Format: "service_name:container_id:internal_port:domain"
# All services now deployed via Coolify API in LXC 200
SERVICES=(
    "Coolify LXC:200:8000:paas.viljo.se"
)

# Infrastructure containers (no external domain)
# Note: Most services moved to Coolify-managed containers in LXC 200
INFRA_CONTAINERS=()

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

# Check if Proxmox host is reachable
echo -e "${BLUE}[1] Checking Proxmox Host Connectivity${NC}"
if ssh -o ConnectTimeout=5 -o BatchMode=yes root@192.168.1.3 "echo 'connected'" &>/dev/null; then
    print_result "Proxmox SSH Access" "PASS" "(192.168.1.3)"
else
    print_result "Proxmox SSH Access" "FAIL" "(192.168.1.3 unreachable)"
    echo -e "${RED}Cannot reach Proxmox host - aborting remaining checks${NC}"
    exit 1
fi
echo ""

# Check Coolify LXC container status
echo -e "${BLUE}[2] Checking Coolify LXC Container (200)${NC}"
COOLIFY_STATUS=$(ssh root@192.168.1.3 "pct status 200" 2>/dev/null | grep -o "running\|stopped")
if [ "$COOLIFY_STATUS" = "running" ]; then
    print_result "Coolify LXC Container" "PASS" "(running)"

    # Check Docker service inside LXC
    DOCKER_STATUS=$(ssh root@192.168.1.3 "pct exec 200 -- systemctl is-active docker" 2>/dev/null)
    if [ "$DOCKER_STATUS" = "active" ]; then
        print_result "Docker in Coolify LXC" "PASS" "(active)"
    else
        print_result "Docker in Coolify LXC" "FAIL" "($DOCKER_STATUS)"
    fi

    # Check Coolify proxy container
    COOLIFY_PROXY=$(ssh root@192.168.1.3 "pct exec 200 -- docker ps --filter name=coolify-proxy --format '{{.Status}}' 2>/dev/null" 2>/dev/null | head -1)
    if [ -n "$COOLIFY_PROXY" ]; then
        print_result "Coolify Proxy" "PASS" "($COOLIFY_PROXY)"
    else
        print_result "Coolify Proxy" "FAIL" "(not running)"
    fi
else
    print_result "Coolify LXC Container" "FAIL" "($COOLIFY_STATUS)"
fi
echo ""

# Note: Traefik replaced by Coolify's built-in proxy (handled above)
# Legacy Traefik check removed - services now use Coolify proxy

# Check Loopia DDNS
echo -e "${BLUE}[4] Checking Loopia DDNS Service${NC}"
# Check the timer, not the service (it's a oneshot service triggered by timer)
DDNS_TIMER_STATUS=$(ssh root@192.168.1.3 "systemctl is-active loopia-ddns.timer" 2>/dev/null)
if [ "$DDNS_TIMER_STATUS" = "active" ]; then
    print_result "DDNS Timer" "PASS" "(active)"

    # Check last successful run
    LAST_RUN=$(ssh root@192.168.1.3 "systemctl status loopia-ddns.service | grep 'Finished' | tail -1 | awk '{print \$1, \$2, \$3}'" 2>/dev/null)
    if [ -n "$LAST_RUN" ]; then
        print_result "DDNS Last Update" "PASS" "($LAST_RUN)"
    else
        print_result "DDNS Last Update" "WARN" "(could not determine)"
    fi

    # Check next scheduled run
    NEXT_RUN=$(ssh root@192.168.1.3 "systemctl list-timers loopia-ddns.timer --no-pager | grep loopia-ddns | awk '{print \$1, \$2, \$3, \$4}'" 2>/dev/null)
    if [ -n "$NEXT_RUN" ]; then
        print_result "DDNS Next Run" "PASS" "($NEXT_RUN)"
    fi
else
    print_result "DDNS Timer" "FAIL" "($DDNS_TIMER_STATUS)"
fi
echo ""

# Check DNS resolution
echo -e "${BLUE}[5] Checking DNS Resolution${NC}"
for service_entry in "${SERVICES[@]}"; do
    IFS=: read -r name id port domain <<< "$service_entry"
    if [ "$domain" != "none" ]; then
        DNS_IP=$(dig +short "$domain" @1.1.1.1 2>/dev/null | head -1)
        if [ -n "$DNS_IP" ]; then
            if [ -n "$FW_WAN_IP" ] && [ "$DNS_IP" = "$FW_WAN_IP" ]; then
                print_result "DNS: $domain" "PASS" "($DNS_IP matches firewall WAN)"
            else
                print_result "DNS: $domain" "WARN" "($DNS_IP - may not match firewall)"
            fi
        else
            print_result "DNS: $domain" "FAIL" "(no resolution)"
        fi
    fi
done
echo ""

# Check container status
echo -e "${BLUE}[6] Checking Container Status${NC}"
for service_entry in "${SERVICES[@]}"; do
    IFS=: read -r name id port domain <<< "$service_entry"
    CONTAINER_STATUS=$(ssh root@192.168.1.3 "pct status $id 2>/dev/null" | grep -o "running\|stopped")
    if [ "$CONTAINER_STATUS" = "running" ]; then
        print_result "Container $id ($name)" "PASS" "(running)"
    else
        print_result "Container $id ($name)" "FAIL" "($CONTAINER_STATUS or not found)"
    fi
done

# Check infrastructure containers
for infra_entry in "${INFRA_CONTAINERS[@]}"; do
    IFS=: read -r name id <<< "$infra_entry"
    CONTAINER_STATUS=$(ssh root@192.168.1.3 "pct status $id 2>/dev/null" | grep -o "running\|stopped")
    if [ "$CONTAINER_STATUS" = "running" ]; then
        print_result "Container $id ($name)" "PASS" "(running)"
    else
        print_result "Container $id ($name)" "FAIL" "($CONTAINER_STATUS or not found)"
    fi
done
echo ""

# Check external HTTP/HTTPS access
echo -e "${BLUE}[7] Checking External Service Access${NC}"
if [ -n "$FW_WAN_IP" ]; then
    for service_entry in "${SERVICES[@]}"; do
        IFS=: read -r name id port domain <<< "$service_entry"
        if [ "$domain" != "none" ]; then
            # Test HTTP access (should redirect to HTTPS)
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $domain" --connect-timeout 5 --max-time 10 http://$FW_WAN_IP/ 2>/dev/null)
            if [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "308" ] || [ "$HTTP_CODE" = "200" ]; then
                print_result "HTTP: $name" "PASS" "(HTTP $HTTP_CODE)"
            elif [ "$HTTP_CODE" = "000" ]; then
                print_result "HTTP: $name" "FAIL" "(connection timeout)"
            else
                print_result "HTTP: $name" "WARN" "(HTTP $HTTP_CODE - unexpected)"
            fi
        fi
    done
else
    print_result "External Access Tests" "FAIL" "(no firewall WAN IP - skipping)"
fi
echo ""

# Note: Individual service health checks removed - services now managed via Coolify API
# Use Coolify dashboard or API for detailed service health monitoring

# Coolify-managed services health check
echo -e "${BLUE}[3] Coolify-Managed Services Health${NC}"
if [ "$COOLIFY_STATUS" = "running" ]; then
    # Count running Docker containers in Coolify LXC
    DOCKER_CONTAINERS=$(ssh root@192.168.1.3 "pct exec 200 -- docker ps --format '{{.Names}}' 2>/dev/null" 2>/dev/null | wc -l)
    if [ "$DOCKER_CONTAINERS" -gt 0 ]; then
        print_result "Coolify Docker Containers" "PASS" "($DOCKER_CONTAINERS containers running)"
    else
        print_result "Coolify Docker Containers" "WARN" "(no containers found)"
    fi

    # Check Coolify API health
    COOLIFY_API=$(ssh root@192.168.1.3 "pct exec 200 -- curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/health 2>/dev/null" 2>/dev/null)
    if [ "$COOLIFY_API" = "200" ]; then
        print_result "Coolify API Health" "PASS" "(HTTP 200)"
    else
        print_result "Coolify API Health" "WARN" "(HTTP $COOLIFY_API)"
    fi
else
    print_result "Coolify Services" "FAIL" "(Coolify LXC not running)"
fi
echo ""

# SSL Certificate expiration checks
echo -e "${BLUE}[10] SSL Certificate Expiration${NC}"
for service_entry in "${SERVICES[@]}"; do
    IFS=: read -r name id port domain <<< "$service_entry"
    if [ "$domain" != "none" ]; then
        CERT_EXPIRY=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [ -n "$CERT_EXPIRY" ]; then
            # Calculate days until expiration
            EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$CERT_EXPIRY" +%s 2>/dev/null || date -d "$CERT_EXPIRY" +%s 2>/dev/null)
            NOW_EPOCH=$(date +%s)
            DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

            if [ $DAYS_LEFT -gt 30 ]; then
                print_result "Cert: $domain" "PASS" "(expires in $DAYS_LEFT days)"
            elif [ $DAYS_LEFT -gt 7 ]; then
                print_result "Cert: $domain" "WARN" "(expires in $DAYS_LEFT days - renew soon)"
            else
                print_result "Cert: $domain" "FAIL" "(expires in $DAYS_LEFT days - URGENT)"
            fi
        else
            print_result "Cert: $domain" "WARN" "(could not check expiration)"
        fi
    fi
done
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
