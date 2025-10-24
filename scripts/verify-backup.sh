#!/bin/bash
# Backup Verification Script
# Tests that backups can be successfully restored
#
# Purpose: Automatically verify backups by restoring to temporary containers
#          and checking they start successfully. Helps catch corrupted backups early.
#
# Usage:
#   ./scripts/verify-backup.sh <container-id>           # Verify specific container
#   ./scripts/verify-backup.sh all                      # Verify all containers
#   ./scripts/verify-backup.sh --latest                 # Verify latest backups only
#
# Example:
#   ./scripts/verify-backup.sh 150                      # Verify PostgreSQL backup
#   ./scripts/verify-backup.sh all                      # Verify all backups

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEST_CONTAINER_ID=999  # Temporary container ID for testing
STORAGE="local-lvm"
VERIFY_TIMEOUT=60  # Seconds to wait for container to start

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Check if running on Proxmox host
if ! command -v pct &> /dev/null; then
    echo -e "${RED}ERROR: This script must be run on the Proxmox host${NC}"
    echo "Connect to Proxmox first: ssh root@192.168.1.3"
    exit 1
fi

# Cleanup function
cleanup() {
    if pct status $TEST_CONTAINER_ID &> /dev/null; then
        echo "Cleaning up test container..."
        pct stop $TEST_CONTAINER_ID 2>/dev/null || true
        sleep 2
        pct destroy $TEST_CONTAINER_ID 2>/dev/null || true
    fi
}

# Set up cleanup on exit
trap cleanup EXIT

# Test single backup
test_backup() {
    local container_id=$1
    local backup=$2

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Testing Container $container_id${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "Backup: $backup"
    echo ""

    # Clean up any existing test container
    cleanup

    # Restore to test container
    echo "Restoring to test container $TEST_CONTAINER_ID..."
    if ! pct restore $TEST_CONTAINER_ID "$backup" --storage "$STORAGE" 2>&1; then
        echo -e "${RED}✗ FAILED: Could not restore backup${NC}"
        echo ""
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Try to start container
    echo "Starting test container..."
    if ! pct start $TEST_CONTAINER_ID 2>&1; then
        echo -e "${RED}✗ FAILED: Could not start container${NC}"
        echo ""
        FAILED_TESTS=$((FAILED_TESTS + 1))
        cleanup
        return 1
    fi

    # Wait for container to be fully started
    echo "Waiting for container to initialize (up to ${VERIFY_TIMEOUT}s)..."
    local elapsed=0
    while [ $elapsed -lt $VERIFY_TIMEOUT ]; do
        if pct status $TEST_CONTAINER_ID | grep -q "running"; then
            # Container is running, try to execute a command
            if pct exec $TEST_CONTAINER_ID -- echo "test" &> /dev/null; then
                echo -e "${GREEN}✓ PASSED: Container restored and running${NC}"
                echo ""
                PASSED_TESTS=$((PASSED_TESTS + 1))
                cleanup
                return 0
            fi
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    echo -e "${RED}✗ FAILED: Container did not start properly (timeout)${NC}"
    echo ""
    FAILED_TESTS=$((FAILED_TESTS + 1))
    cleanup
    return 1
}

# Get container IDs to test
get_container_ids() {
    case "$1" in
        all)
            # All production containers
            echo "101 110 150 151 153 154 155 158 160 170"
            ;;
        --latest)
            # Get unique container IDs from latest backups
            pvesm list local | grep vzdump-lxc | awk -F'-' '{print $3}' | sort -u
            ;;
        [0-9]*)
            # Single container ID
            echo "$1"
            ;;
        *)
            echo -e "${RED}ERROR: Invalid argument: $1${NC}"
            echo "Usage: $0 {all|--latest|<container-id>}"
            exit 1
            ;;
    esac
}

# Main
main() {
    if [ $# -eq 0 ]; then
        echo -e "${RED}ERROR: No container specified${NC}"
        echo "Usage: $0 {all|--latest|<container-id>}"
        exit 1
    fi

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Backup Verification${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "Started: $(date)"
    echo ""

    # Get container IDs to test
    container_ids=$(get_container_ids "$1")

    echo "Testing backups for containers: $container_ids"
    echo ""

    # Test each container
    for id in $container_ids; do
        # Find latest backup
        backup=$(pvesm list local | grep "vzdump-lxc-$id" | tail -1 | awk '{print $1}')

        if [ -z "$backup" ]; then
            echo -e "${YELLOW}⚠ WARNING: No backup found for container $id${NC}"
            echo ""
            continue
        fi

        # Test the backup
        test_backup "$id" "$backup"
    done

    # Summary
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Verification Summary${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "Completed: $(date)"
    echo ""
    echo "Total tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    if [ $FAILED_TESTS -gt 0 ]; then
        echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    else
        echo -e "${GREEN}Failed: $FAILED_TESTS${NC}"
    fi
    echo ""

    # Calculate success rate
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo "Success rate: ${success_rate}%"

        if [ $success_rate -eq 100 ]; then
            echo -e "${GREEN}✓ All backups verified successfully${NC}"
            exit 0
        elif [ $success_rate -ge 80 ]; then
            echo -e "${YELLOW}⚠ Some backups failed verification${NC}"
            exit 1
        else
            echo -e "${RED}✗ Many backups failed verification${NC}"
            exit 2
        fi
    fi
}

# Run main function
main "$@"
