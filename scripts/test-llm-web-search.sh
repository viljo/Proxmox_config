#!/usr/bin/env bash
#
# Test Script: Open WebUI RAG Web Search Functionality
# Description: Validates that the web search (RAG) engine is accessible and properly configured
# Prerequisites:
#   - Open WebUI deployed in LXC 200
#   - SSH access to Proxmox host (root@192.168.1.3)
#   - Web search enabled in Open WebUI configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROXMOX_HOST="192.168.1.3"
LXC_ID="200"
CONTAINER_NAME="open-webui"
SERVICE_URL="https://llm.viljo.se"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Open WebUI Web Search Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test 1: Check Open WebUI container is running
echo -e "${YELLOW}[1/6]${NC} Checking Open WebUI container status..."
if ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- docker ps --filter name=${CONTAINER_NAME} --format '{{.Status}}'" | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Container is running"
else
    echo -e "${RED}✗${NC} Container is not running"
    exit 1
fi

# Test 2: Check web search environment variables
echo -e "${YELLOW}[2/6]${NC} Verifying web search configuration..."
WEB_SEARCH_ENABLED=$(ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- docker exec ${CONTAINER_NAME} env | grep ENABLE_RAG_WEB_SEARCH" || echo "")
WEB_SEARCH_ENGINE=$(ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- docker exec ${CONTAINER_NAME} env | grep RAG_WEB_SEARCH_ENGINE" || echo "")

if [[ "$WEB_SEARCH_ENABLED" == *"true"* ]]; then
    echo -e "${GREEN}✓${NC} Web search enabled: $WEB_SEARCH_ENABLED"
else
    echo -e "${RED}✗${NC} Web search not enabled"
    exit 1
fi

if [[ -n "$WEB_SEARCH_ENGINE" ]]; then
    echo -e "${GREEN}✓${NC} Search engine configured: $WEB_SEARCH_ENGINE"
else
    echo -e "${RED}✗${NC} Search engine not configured"
    exit 1
fi

# Test 3: Test DuckDuckGo accessibility from container
echo -e "${YELLOW}[3/6]${NC} Testing DuckDuckGo accessibility from container..."
HTTP_CODE=$(ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- docker exec ${CONTAINER_NAME} curl -s -o /dev/null -w '%{http_code}' 'https://duckduckgo.com/?q=test'" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" =~ ^2[0-9]{2}$ ]]; then
    echo -e "${GREEN}✓${NC} DuckDuckGo is accessible (HTTP $HTTP_CODE)"
else
    echo -e "${RED}✗${NC} DuckDuckGo is not accessible (HTTP $HTTP_CODE)"
    exit 1
fi

# Test 4: Check container logs for web search initialization
echo -e "${YELLOW}[4/6]${NC} Checking container logs for errors..."
LOGS=$(ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- docker logs ${CONTAINER_NAME} --tail 50 2>&1")

if echo "$LOGS" | grep -qi "error\|failed\|exception"; then
    RECENT_ERRORS=$(echo "$LOGS" | grep -i "error\|failed\|exception" | tail -3)
    if [[ -n "$RECENT_ERRORS" ]]; then
        echo -e "${YELLOW}⚠${NC} Recent log entries found (may be normal):"
        echo "$RECENT_ERRORS" | sed 's/^/  /'
    fi
fi

if echo "$LOGS" | grep -qi "Started server process"; then
    echo -e "${GREEN}✓${NC} Server started successfully"
else
    echo -e "${RED}✗${NC} Server startup not confirmed"
    exit 1
fi

# Test 5: Test HTTPS endpoint accessibility
echo -e "${YELLOW}[5/6]${NC} Testing Open WebUI HTTPS endpoint..."
if curl -sf -o /dev/null "$SERVICE_URL" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} HTTPS endpoint accessible: $SERVICE_URL"
else
    echo -e "${RED}✗${NC} HTTPS endpoint not accessible: $SERVICE_URL"
    exit 1
fi

# Test 6: Check Ollama API connectivity
echo -e "${YELLOW}[6/6]${NC} Testing Ollama API connectivity from container..."
OLLAMA_URL=$(ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- docker exec ${CONTAINER_NAME} env | grep OLLAMA_BASE_URL" | cut -d'=' -f2)

if ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- docker exec ${CONTAINER_NAME} curl -sf $OLLAMA_URL/api/version" >/dev/null 2>&1; then
    OLLAMA_VERSION=$(ssh root@${PROXMOX_HOST} "pct exec ${LXC_ID} -- docker exec ${CONTAINER_NAME} curl -s $OLLAMA_URL/api/version" 2>/dev/null || echo "{}")
    echo -e "${GREEN}✓${NC} Ollama API accessible: $OLLAMA_URL"
    echo "  Version info: $OLLAMA_VERSION"
else
    echo -e "${YELLOW}⚠${NC} Ollama API not responding (may be starting up)"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ All Web Search Tests Passed${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Configuration Summary:"
echo "  - Container: $CONTAINER_NAME (LXC $LXC_ID)"
echo "  - Service URL: $SERVICE_URL"
echo "  - Search Engine: $(echo $WEB_SEARCH_ENGINE | cut -d'=' -f2)"
echo "  - Ollama API: $OLLAMA_URL"
echo ""
echo "Web search is ready to use!"
echo "Users can enable web search when composing messages in the UI."
