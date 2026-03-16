#!/usr/bin/env bash
# gads-auth.sh — Test and display Google Ads API authentication status
#
# Usage:
#   ./gads-auth.sh               # Check auth status
#   ./gads-auth.sh --refresh     # Force token refresh
#   ./gads-auth.sh --token       # Print current access token (for debugging)
#
# This script validates that the apply layer can authenticate
# with the Google Ads API using the stored OAuth2 credentials.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/token-refresh.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

MODE="${1:-check}"

echo -e "${BOLD}Google Ads API — Authentication Check${NC}"
echo -e "  API version: ${GADS_API_VERSION}"
echo ""

# Check environment
echo -n "  GOOGLE_APPLICATION_CREDENTIALS: "
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  if [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo -e "${GREEN}✅ $(basename "$GOOGLE_APPLICATION_CREDENTIALS")${NC}"
  else
    echo -e "${RED}❌ File not found${NC}"
    exit 1
  fi
else
  echo -e "${RED}❌ Not set${NC}"
  exit 1
fi

echo -n "  GOOGLE_ADS_DEVELOPER_TOKEN:     "
if [ -n "${GOOGLE_ADS_DEVELOPER_TOKEN:-}" ]; then
  echo -e "${GREEN}✅ ${GOOGLE_ADS_DEVELOPER_TOKEN:0:8}...${NC}"
else
  echo -e "${RED}❌ Not set${NC}"
  exit 1
fi

echo -n "  GOOGLE_ADS_LOGIN_CUSTOMER_ID:   "
if [ -n "${GOOGLE_ADS_LOGIN_CUSTOMER_ID:-}" ]; then
  echo -e "${GREEN}${GOOGLE_ADS_LOGIN_CUSTOMER_ID}${NC}"
else
  echo -e "${YELLOW}(not set — direct account access)${NC}"
fi

echo ""

# Token refresh
case "$MODE" in
  --refresh)
    echo "Forcing token refresh..."
    rm -f "$TOKEN_CACHE"
    ;;
  --token)
    ;;
esac

echo -n "  Acquiring access token... "
if ACCESS_TOKEN=$(get_access_token 2>/dev/null); then
  echo -e "${GREEN}✅${NC}"

  if [ "$MODE" = "--token" ]; then
    echo ""
    echo "  Token: ${ACCESS_TOKEN}"
  fi

  # Show cache info
  if [ -f "$TOKEN_CACHE" ]; then
    expires_at=$(jq -r '.expires_at' "$TOKEN_CACHE")
    refreshed_at=$(jq -r '.refreshed_at' "$TOKEN_CACHE")
    now=$(date +%s)
    remaining=$(( expires_at - now ))

    echo "  Refreshed: ${refreshed_at}"
    echo "  Expires in: ${remaining}s"
  fi
else
  echo -e "${RED}❌ Token refresh failed${NC}"
  echo ""
  echo "  Common fixes:"
  echo "  - Check that GOOGLE_APPLICATION_CREDENTIALS points to an authorized_user JSON"
  echo "  - Ensure the refresh_token is still valid"
  echo "  - Re-run OAuth2 flow if token was revoked"
  exit 1
fi

echo ""

# Quick API test: list accessible customers
echo -n "  Testing API access (list_accessible_customers)... "

RESULT=$(curl -s -w "\n%{http_code}" \
  "${GADS_API_BASE}/customers:listAccessibleCustomers" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}")

HTTP_CODE=$(echo "$RESULT" | tail -1)
BODY=$(echo "$RESULT" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  CUSTOMER_COUNT=$(echo "$BODY" | jq '.resourceNames | length' 2>/dev/null || echo "?")
  echo -e "${GREEN}✅ ${CUSTOMER_COUNT} accessible account(s)${NC}"

  echo ""
  echo "  Accounts:"
  echo "$BODY" | jq -r '.resourceNames[]' 2>/dev/null | while read -r rn; do
    echo "    - ${rn}"
  done
else
  echo -e "${RED}❌ HTTP ${HTTP_CODE}${NC}"
  echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
fi

echo ""
echo -e "${GREEN}Auth check complete.${NC}"
