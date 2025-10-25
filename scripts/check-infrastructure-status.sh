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
SERVICES=(
    "Keycloak:151:8080:keycloak.viljo.se"
    "GitLab:153:80:gitlab.viljo.se"
    "Nextcloud:155:80:nextcloud.viljo.se"
    "Redis:158:6379:none"
    "Links Portal:160:80:links.viljo.se"
    "Mattermost:163:8065:mattermost.viljo.se"
    "Webtop:170:3000:browser.viljo.se"
)

# Infrastructure containers (no external domain)
INFRA_CONTAINERS=(
    "Firewall:101"
    "Bastion:110"
    "PostgreSQL:150"
    "GitLab Runner:154"
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

# Check firewall container status
echo -e "${BLUE}[2] Checking Firewall Container (101)${NC}"
FW_STATUS=$(ssh root@192.168.1.3 "pct status 101" 2>/dev/null | grep -o "running\|stopped")
if [ "$FW_STATUS" = "running" ]; then
    print_result "Firewall Container" "PASS" "(running)"
    
    # Get WAN IP from firewall
    FW_WAN_IP=$(ssh root@192.168.1.3 "pct exec 101 -- ip -4 addr show eth0 | grep 'inet ' | awk '{print \$2}' | cut -d/ -f1" 2>/dev/null)
    if [ -n "$FW_WAN_IP" ]; then
        print_result "Firewall WAN IP" "PASS" "($FW_WAN_IP on vmbr2/Bahnhof)"
    else
        print_result "Firewall WAN IP" "FAIL" "(could not determine)"
    fi
    
    # Check NAT rules
    NAT_RULES=$(ssh root@192.168.1.3 "pct exec 101 -- nft list table ip nat 2>/dev/null | grep -c dnat" 2>/dev/null)
    if [ "$NAT_RULES" -gt 0 ]; then
        print_result "Firewall NAT Rules" "PASS" "($NAT_RULES DNAT rules configured)"
    else
        print_result "Firewall NAT Rules" "FAIL" "(no DNAT rules found)"
    fi
else
    print_result "Firewall Container" "FAIL" "($FW_STATUS)"
fi
echo ""

# Check Traefik status
echo -e "${BLUE}[3] Checking Traefik Reverse Proxy${NC}"
TRAEFIK_STATUS=$(ssh root@192.168.1.3 "systemctl is-active traefik" 2>/dev/null)
if [ "$TRAEFIK_STATUS" = "active" ]; then
    print_result "Traefik Service" "PASS" "(active)"
    
    # Check if Traefik is listening on ports 80 and 443
    LISTENING_80=$(ssh root@192.168.1.3 "ss -tlnp | grep traefik | grep -c ':80 '" 2>/dev/null)
    LISTENING_443=$(ssh root@192.168.1.3 "ss -tlnp | grep traefik | grep -c ':443 '" 2>/dev/null)
    
    if [ "$LISTENING_80" -gt 0 ] && [ "$LISTENING_443" -gt 0 ]; then
        print_result "Traefik Ports" "PASS" "(listening on 80 and 443)"
    else
        print_result "Traefik Ports" "FAIL" "(not listening on required ports)"
    fi
    
    # Check dynamic configs
    DYNAMIC_CONFIGS=$(ssh root@192.168.1.3 "ls /etc/traefik/dynamic/*.yml 2>/dev/null | wc -l" 2>/dev/null)
    if [ "$DYNAMIC_CONFIGS" -gt 0 ]; then
        print_result "Traefik Configs" "PASS" "($DYNAMIC_CONFIGS dynamic configs loaded)"
    else
        print_result "Traefik Configs" "WARN" "(no dynamic configs found)"
    fi
else
    print_result "Traefik Service" "FAIL" "($TRAEFIK_STATUS)"
fi
echo ""

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

# Advanced service health checks
echo -e "${BLUE}[8] Advanced Service Health Checks${NC}"
if [ -n "$FW_WAN_IP" ]; then
    # Mattermost API ping
    MATTERMOST_PING=$(curl -s --connect-timeout 5 http://172.16.10.163:8065/api/v4/system/ping 2>/dev/null)
    if [ -n "$MATTERMOST_PING" ]; then
        print_result "Mattermost API" "PASS" "(ping successful)"
    else
        print_result "Mattermost API" "FAIL" "(no response)"
    fi

    # GitLab version API
    GITLAB_VERSION=$(curl -s --connect-timeout 5 http://172.16.10.153/api/v4/version 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$GITLAB_VERSION" ]; then
        print_result "GitLab API" "PASS" "(version: $GITLAB_VERSION)"
    else
        print_result "GitLab API" "FAIL" "(no response)"
    fi

    # Nextcloud status.php
    NEXTCLOUD_STATUS=$(curl -s --connect-timeout 5 http://172.16.10.155/status.php 2>/dev/null | grep -o '"installed":true')
    if [ -n "$NEXTCLOUD_STATUS" ]; then
        print_result "Nextcloud Status" "PASS" "(installed and configured)"
    else
        print_result "Nextcloud Status" "FAIL" "(not responding)"
    fi

    # Keycloak realms endpoint
    KEYCLOAK_REALMS=$(curl -s --connect-timeout 5 http://172.16.10.151:8080/realms/master 2>/dev/null | grep -o '"realm":"master"')
    if [ -n "$KEYCLOAK_REALMS" ]; then
        print_result "Keycloak Realms" "PASS" "(master realm accessible)"
    else
        print_result "Keycloak Realms" "FAIL" "(no response)"
    fi

    # PostgreSQL connection test
    PG_CONNECTABLE=$(ssh root@192.168.1.3 "pct exec 150 -- su - postgres -c 'psql -c \"SELECT version()\"' 2>/dev/null | grep -c PostgreSQL" 2>/dev/null)
    if [ "$PG_CONNECTABLE" -gt 0 ]; then
        print_result "PostgreSQL Connection" "PASS" "(accepting connections)"
    else
        print_result "PostgreSQL Connection" "FAIL" "(not responding)"
    fi

    # Redis ping test
    REDIS_PING=$(ssh root@192.168.1.3 "pct exec 158 -- redis-cli ping 2>/dev/null" 2>/dev/null)
    if [ "$REDIS_PING" = "PONG" ]; then
        print_result "Redis Ping" "PASS" "(PONG received)"
    else
        print_result "Redis Ping" "FAIL" "(no PONG)"
    fi

    # Links Portal content check
    LINKS_CONTENT=$(curl -s --connect-timeout 5 http://172.16.10.160/ 2>/dev/null | grep -c "Viljo\|matrix\|canvas")
    if [ "$LINKS_CONTENT" -gt 0 ]; then
        print_result "Links Portal Content" "PASS" "(page content loaded)"
    else
        print_result "Links Portal Content" "WARN" "(content not detected)"
    fi
else
    print_result "Advanced Health Checks" "FAIL" "(no firewall WAN IP - skipping)"
fi
echo ""

# Docker container health checks
echo -e "${BLUE}[9] Docker Container Health (inside LXC)${NC}"
for service_entry in "${SERVICES[@]}"; do
    IFS=: read -r name id port domain <<< "$service_entry"
    # Skip Redis as it doesn't use Docker
    if [ "$id" != "158" ]; then
        CONTAINER_STATUS=$(ssh root@192.168.1.3 "pct status $id 2>/dev/null" | grep -o "running")
        if [ "$CONTAINER_STATUS" = "running" ]; then
            DOCKER_PS=$(ssh root@192.168.1.3 "pct exec $id -- docker ps 2>/dev/null | grep -v CONTAINER" 2>/dev/null | wc -l)
            if [ "$DOCKER_PS" -gt 0 ]; then
                print_result "Docker in $name ($id)" "PASS" "($DOCKER_PS containers running)"
            else
                print_result "Docker in $name ($id)" "WARN" "(no containers found)"
            fi
        fi
    fi
done
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
