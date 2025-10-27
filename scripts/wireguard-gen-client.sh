#!/usr/bin/env bash
# Script: wireguard-gen-client.sh
# Purpose: Generate WireGuard client configuration with keys
# Usage: ./scripts/wireguard-gen-client.sh <client-name> <vpn-ip> <server-public-key> <endpoint>
#
# Example:
#   ./scripts/wireguard-gen-client.sh john-laptop 192.168.100.10 "SERVER_PUBLIC_KEY_HERE=" vpn.viljo.se:51820

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check dependencies
command -v wg >/dev/null 2>&1 || { echo -e "${RED}Error: WireGuard 'wg' command not found. Please install wireguard-tools.${NC}" >&2; exit 1; }
command -v qrencode >/dev/null 2>&1 && HAS_QRENCODE=1 || HAS_QRENCODE=0

# Usage information
usage() {
    cat <<EOF
Usage: $0 <client-name> <vpn-ip> <server-public-key> <endpoint>

Arguments:
  client-name         Descriptive name for the client (e.g., john-laptop, alice-phone)
  vpn-ip              VPN IP address to assign to client (e.g., 192.168.100.10)
  server-public-key   WireGuard server's public key
  endpoint            Server endpoint address:port (e.g., vpn.viljo.se:51820 or 1.2.3.4:51820)

Example:
  $0 john-laptop 192.168.100.10 "AbCdEf1234567890abcdef1234567890abcdef12=" vpn.viljo.se:51820

Notes:
  - Client private/public keys will be auto-generated
  - Configuration file will be created in ./wireguard-clients/ directory
  - QR code will be generated for mobile clients (if qrencode is installed)
  - You must manually add the client's public key to Ansible inventory

EOF
    exit 1
}

# Validate arguments
if [ $# -ne 4 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}"
    usage
fi

CLIENT_NAME="$1"
VPN_IP="$2"
SERVER_PUBLIC_KEY="$3"
ENDPOINT="$4"

# Validate client name (alphanumeric and hyphens only)
if ! [[ "$CLIENT_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo -e "${RED}Error: Client name must contain only alphanumeric characters and hyphens${NC}"
    exit 1
fi

# Validate VPN IP format
if ! [[ "$VPN_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${RED}Error: Invalid VPN IP format. Expected format: 192.168.100.10${NC}"
    exit 1
fi

# Validate endpoint format
if ! [[ "$ENDPOINT" =~ ^[a-zA-Z0-9.-]+:[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid endpoint format. Expected format: hostname:port or ip:port${NC}"
    exit 1
fi

# Create output directory
OUTPUT_DIR="./wireguard-clients"
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WireGuard Client Configuration Generator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Client Name:${NC}       $CLIENT_NAME"
echo -e "${YELLOW}VPN IP:${NC}            $VPN_IP/32"
echo -e "${YELLOW}Server Public Key:${NC} ${SERVER_PUBLIC_KEY:0:20}...${SERVER_PUBLIC_KEY: -4}"
echo -e "${YELLOW}Endpoint:${NC}          $ENDPOINT"
echo ""

# Generate client keys
echo -e "${GREEN}Generating client keys...${NC}"
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Create client configuration file
CONFIG_FILE="$OUTPUT_DIR/${CLIENT_NAME}.conf"

cat > "$CONFIG_FILE" <<EOF
[Interface]
# Client: ${CLIENT_NAME}
# VPN IP: ${VPN_IP}/32
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${VPN_IP}/32
DNS = 192.168.1.1

[Peer]
# WireGuard VPN Server
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${ENDPOINT}
AllowedIPs = 192.168.0.0/16
PersistentKeepalive = 25
EOF

chmod 600 "$CONFIG_FILE"

echo -e "${GREEN}Client configuration created: ${CONFIG_FILE}${NC}"
echo ""

# Display keys
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Client Keys${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Private Key:${NC}"
echo "$CLIENT_PRIVATE_KEY"
echo ""
echo -e "${YELLOW}Public Key:${NC}"
echo "$CLIENT_PUBLIC_KEY"
echo ""

# Generate QR code for mobile clients
if [ $HAS_QRENCODE -eq 1 ]; then
    QR_FILE="$OUTPUT_DIR/${CLIENT_NAME}-qr.png"
    qrencode -t PNG -o "$QR_FILE" -r "$CONFIG_FILE"
    echo -e "${GREEN}QR code created: ${QR_FILE}${NC}"
    echo ""

    echo -e "${BLUE}QR Code (terminal):${NC}"
    qrencode -t ANSIUTF8 -r "$CONFIG_FILE"
    echo ""
else
    echo -e "${YELLOW}Note: qrencode not installed - QR code generation skipped${NC}"
    echo -e "${YELLOW}Install with: sudo apt install qrencode (Debian/Ubuntu) or brew install qrencode (macOS)${NC}"
    echo ""
fi

# Display Ansible configuration
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Next Steps${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}1. Add this peer to Ansible inventory:${NC}"
echo ""
cat <<EOF
# Add to inventory/group_vars/all/wireguard.yml
wireguard_peer_configs:
  - name: "${CLIENT_NAME}"
    public_key: "${CLIENT_PUBLIC_KEY}"
    allowed_ips: "${VPN_IP}/32"
    persistent_keepalive: 25
EOF
echo ""
echo -e "${GREEN}2. Redeploy WireGuard configuration:${NC}"
echo "   ansible-playbook playbooks/wireguard-deploy.yml --ask-vault-pass"
echo ""
echo -e "${GREEN}3. Distribute client configuration securely:${NC}"
echo "   - Desktop clients: Share ${CONFIG_FILE} via encrypted channel"
echo "   - Mobile clients: Share ${OUTPUT_DIR}/${CLIENT_NAME}-qr.png or display QR code"
echo ""
echo -e "${GREEN}4. Test connectivity:${NC}"
echo "   - Connect client to VPN"
echo "   - Ping VPN gateway: ping 192.168.100.1"
echo "   - Ping management network: ping 192.168.1.1"
echo "   - Check server status: ssh root@proxmox 'pct exec 190 -- wg show'"
echo ""
echo -e "${BLUE}========================================${NC}"

# Security reminder
echo -e "${RED}SECURITY REMINDER:${NC}"
echo -e "${RED}  - Protect client configuration files (contain private keys!)${NC}"
echo -e "${RED}  - Use secure channels to distribute configurations${NC}"
echo -e "${RED}  - Delete QR codes after clients scan them${NC}"
echo -e "${RED}  - Never commit client private keys to version control${NC}"
echo ""
