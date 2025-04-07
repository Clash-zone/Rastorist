#!/bin/bash

# Outline Server Auto-Setup Script
# This script installs the Outline Server and registers it with the admin panel

# Exit on error
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Banner
echo -e "${GREEN}"
echo "============================================"
echo "      Outline VPN Server Auto-Setup"
echo "============================================"
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit 1
fi

# Configuration
PANEL_URL=""
PANEL_SECRET=""
SERVER_NAME=""
SERVER_LOCATION=""

# Request configuration
echo -e "${YELLOW}Please provide the following information:${NC}"
read -p "Admin Panel URL (e.g., https://yourdomain.com): " PANEL_URL
read -p "Panel Secret (from .env): " PANEL_SECRET
read -p "Server Name (e.g., Server01): " SERVER_NAME
read -p "Server Location (e.g., Germany): " SERVER_LOCATION

# Validate input
if [[ -z "$PANEL_URL" || -z "$PANEL_SECRET" || -z "$SERVER_NAME" || -z "$SERVER_LOCATION" ]]; then
    echo -e "${RED}Error: All fields are required${NC}"
    exit 1
fi

# Trim trailing slash from panel URL
PANEL_URL=${PANEL_URL%/}

echo -e "${YELLOW}Installing Outline Server...${NC}"

# Create a temporary directory
TMP_DIR=$(mktemp -d)

# Download Outline Server installer
curl -L https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh > $TMP_DIR/install_server.sh
chmod +x $TMP_DIR/install_server.sh

# Run the installer
$TMP_DIR/install_server.sh || {
    echo -e "${RED}Outline installation failed${NC}"
    rm -rf $TMP_DIR
    exit 1
}

# Find the API URL and certificate from the installer output
API_URL=$(grep -o "apiUrl\":\"\(.*\)\"" /opt/outline/access.json | cut -d "\"" -f 4)
API_CERT_SHA256=$(grep -o "certSha256\":\"\(.*\)\"" /opt/outline/access.json | cut -d "\"" -f 4)
API_TOKEN=$(grep -o "apiUrl\":\"\(.*\)\"" /opt/outline/access.json | cut -d ":" -f 3 | cut -d "@" -f 1)

echo -e "${GREEN}Outline Server installed successfully!${NC}"
echo -e "API URL: ${API_URL}"
echo -e "API Cert SHA256: ${API_CERT_SHA256}"

# Register server with the panel
echo -e "${YELLOW}Registering server with the admin panel...${NC}"

# Prepare JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "name": "$SERVER_NAME",
  "api_url": "$API_URL",
  "api_token": "$API_TOKEN",
  "cert_sha256": "$API_CERT_SHA256",
  "location": "$SERVER_LOCATION"
}
EOF
)

# Send request to register server
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "X-Panel-Secret: $PANEL_SECRET" \
  -d "$JSON_PAYLOAD" \
  "${PANEL_URL}/register_server")

# Check response
if echo "$RESPONSE" | grep -q "success"; then
    SERVER_ID=$(echo "$RESPONSE" | grep -o "server_id\":\"\(.*\)\"" | cut -d "\"" -f 4)
    echo -e "${GREEN}Server registered successfully!${NC}"
    echo -e "Server ID: ${SERVER_ID}"
    echo -e "${GREEN}You can now manage this server from the admin panel.${NC}"
else
    echo -e "${RED}Failed to register server with the panel:${NC}"
    echo "$RESPONSE"
    exit 1
fi

# Clean up
rm -rf $TMP_DIR

echo -e "${GREEN}Setup completed successfully!${NC}"