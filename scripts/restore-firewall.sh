#!/bin/bash
# Firewall Quick Restore Script
# Restores the firewall container (101) from the latest backup
#
# Purpose: The firewall provides NAT for DMZ network. Without it, DMZ containers
#          cannot access the internet during deployment or operation.
#
# Usage:
#   ./scripts/restore-firewall.sh                    # Restore from latest backup
#   ./scripts/restore-firewall.sh <backup-volid>     # Restore from specific backup
#
# Example:
#   ./scripts/restore-firewall.sh local:backup/vzdump-lxc-101-2025_10_23-23_43_18.tar.zst

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_ID=101
CONTAINER_NAME="firewall"
STORAGE="local-lvm"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Firewall Quick Restore${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running on Proxmox host
if ! command -v pct &> /dev/null; then
    echo -e "${RED}ERROR: This script must be run on the Proxmox host${NC}"
    echo "Connect to Proxmox first:"
    echo "  ssh root@192.168.1.3"
    exit 1
fi

# Check if container already exists
if pct status $CONTAINER_ID &> /dev/null; then
    echo -e "${YELLOW}WARNING: Container $CONTAINER_ID already exists${NC}"
    echo -n "Do you want to destroy it and restore from backup? (yes/no): "
    read -r response
    if [[ "$response" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi

    echo "Stopping container $CONTAINER_ID..."
    pct stop $CONTAINER_ID 2>/dev/null || true
    sleep 2

    echo "Destroying container $CONTAINER_ID..."
    pct destroy $CONTAINER_ID
    echo -e "${GREEN}Container destroyed${NC}"
fi

# Determine backup to use
if [ -n "$1" ]; then
    # Use specified backup
    BACKUP="$1"
    echo "Using specified backup: $BACKUP"
else
    # Find latest backup
    echo "Finding latest firewall backup..."
    BACKUP=$(pvesm list local | grep "vzdump-lxc-$CONTAINER_ID" | tail -1 | awk '{print $1}')

    if [ -z "$BACKUP" ]; then
        echo -e "${RED}ERROR: No backups found for container $CONTAINER_ID${NC}"
        echo "Available backups:"
        pvesm list local | grep "vzdump-lxc-" | head -10
        exit 1
    fi

    echo -e "${GREEN}Found latest backup: $BACKUP${NC}"
fi

# Extract backup info
BACKUP_FILE=$(echo "$BACKUP" | cut -d: -f2)
BACKUP_SIZE=$(pvesm list local | grep "$BACKUP_FILE" | awk '{print $4}')
BACKUP_SIZE_MB=$((BACKUP_SIZE / 1024 / 1024))

echo ""
echo "Backup details:"
echo "  Volume ID: $BACKUP"
echo "  Size: ${BACKUP_SIZE_MB}MB"
echo ""

# Restore container
echo "Restoring container $CONTAINER_ID from backup..."
echo "This may take 1-2 minutes..."
START_TIME=$(date +%s)

if pct restore $CONTAINER_ID "$BACKUP" --storage "$STORAGE"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo -e "${GREEN}✓ Container restored in ${DURATION} seconds${NC}"
else
    echo -e "${RED}✗ Restore failed${NC}"
    exit 1
fi

# Start container
echo ""
echo "Starting container $CONTAINER_ID..."
if pct start $CONTAINER_ID; then
    echo -e "${GREEN}✓ Container started${NC}"
else
    echo -e "${RED}✗ Failed to start container${NC}"
    exit 1
fi

# Wait for container to be ready
echo ""
echo "Waiting for firewall to initialize (10 seconds)..."
sleep 10

# Verify container is running
if pct status $CONTAINER_ID | grep -q "running"; then
    echo -e "${GREEN}✓ Firewall is running${NC}"
else
    echo -e "${RED}✗ Firewall is not running${NC}"
    echo "Status:"
    pct status $CONTAINER_ID
    exit 1
fi

# Verify NAT is working (check from a DMZ container if available)
echo ""
echo "Verifying firewall functionality..."

# Check if any DMZ containers are running to test NAT
DMZ_CONTAINER=$(pct list | grep -E "150|151|155|158|160" | head -1 | awk '{print $1}')

if [ -n "$DMZ_CONTAINER" ]; then
    echo "Testing NAT from DMZ container $DMZ_CONTAINER..."
    if pct exec $DMZ_CONTAINER -- ping -c 2 -W 5 8.8.8.8 &> /dev/null; then
        echo -e "${GREEN}✓ NAT is working (DMZ can reach internet)${NC}"
    else
        echo -e "${YELLOW}⚠ NAT test failed (DMZ cannot reach internet)${NC}"
        echo "  This may be normal if the container is not fully started"
        echo "  Or if no DMZ containers are running"
    fi
else
    echo -e "${YELLOW}⚠ No DMZ containers running to test NAT${NC}"
    echo "  Firewall is running but NAT functionality not verified"
fi

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Firewall Restore Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Container ID: $CONTAINER_ID"
echo "Status: Running"
echo "Network: vmbr2 (WAN), vmbr3 (DMZ), vmbr0 (Management)"
echo ""
echo "Next steps:"
echo "  1. Verify external SSH access: ssh root@ssh.viljo.se"
echo "  2. Deploy other services: ansible-playbook playbooks/full-deployment.yml"
echo "  3. Verify all services can access internet"
echo ""
echo "To check firewall status:"
echo "  pct status $CONTAINER_ID"
echo "  pct exec $CONTAINER_ID -- iptables -t nat -L POSTROUTING"
echo ""
