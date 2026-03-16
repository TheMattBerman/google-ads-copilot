#!/usr/bin/env bash
# test-mcp.sh — Quick health check for google-ads-mcp connectivity
#
# Usage:
#   ./scripts/test-mcp.sh                  # Basic connectivity test
#   ./scripts/test-mcp.sh <customer_id>    # Test with a specific account
#
# Prerequisites:
#   - mcporter installed and configured with google-ads-mcp
#   - Environment variables set:
#     GOOGLE_APPLICATION_CREDENTIALS  — path to credentials JSON
#     GOOGLE_CLOUD_PROJECT            — Google Cloud project ID (NOT GOOGLE_PROJECT_ID)
#     GOOGLE_ADS_DEVELOPER_TOKEN      — Google Ads developer token
#     GOOGLE_ADS_LOGIN_CUSTOMER_ID    — (optional) MCC manager ID

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CUSTOMER_ID="${1:-}"

echo "═══════════════════════════════════════════"
echo " Google Ads MCP — Health Check"
echo "═══════════════════════════════════════════"
echo ""

# Step 1: Check mcporter is available
echo -n "1. mcporter available... "
if command -v mcporter &>/dev/null; then
  echo -e "${GREEN}✅${NC}"
else
  echo -e "${RED}❌ mcporter not found${NC}"
  echo "   Install: npm install -g mcporter"
  exit 1
fi

# Step 2: Check environment variables
echo -n "2. Environment variables... "
MISSING=""
[ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && MISSING="$MISSING GOOGLE_APPLICATION_CREDENTIALS"
[ -z "${GOOGLE_CLOUD_PROJECT:-}" ] && MISSING="$MISSING GOOGLE_CLOUD_PROJECT"
[ -z "${GOOGLE_ADS_DEVELOPER_TOKEN:-}" ] && MISSING="$MISSING GOOGLE_ADS_DEVELOPER_TOKEN"

if [ -z "$MISSING" ]; then
  echo -e "${GREEN}✅${NC}"
else
  echo -e "${YELLOW}⚠️  Missing:${MISSING}${NC}"
  echo "   Note: GOOGLE_CLOUD_PROJECT is correct (not GOOGLE_PROJECT_ID)"
fi

# Step 3: Check credentials file exists
echo -n "3. Credentials file... "
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  echo -e "${GREEN}✅ ${GOOGLE_APPLICATION_CREDENTIALS}${NC}"
else
  echo -e "${RED}❌ File not found: ${GOOGLE_APPLICATION_CREDENTIALS:-'(not set)'}${NC}"
fi

# Step 4: List accessible customers
echo ""
echo "4. Calling list_accessible_customers..."
echo "   (This tests full MCP connectivity)"
echo ""

if RESULT=$(mcporter call google-ads-mcp list_accessible_customers '{}' 2>&1); then
  echo -e "${GREEN}✅ MCP server responded successfully${NC}"
  echo ""
  echo "   Accessible accounts:"
  echo "   $RESULT" | head -20
else
  echo -e "${RED}❌ MCP call failed${NC}"
  echo "   Error: $RESULT"
  echo ""
  echo "   Common fixes:"
  echo "   - Check GOOGLE_CLOUD_PROJECT (not GOOGLE_PROJECT_ID)"
  echo "   - Verify credentials file path"
  echo "   - Ensure Google Ads API is enabled in Cloud project"
  echo "   - Check developer token status"
  exit 1
fi

# Step 5: If customer_id provided, test a data query
if [ -n "$CUSTOMER_ID" ]; then
  echo ""
  echo "5. Testing data query for customer $CUSTOMER_ID..."
  echo ""

  if CAMPAIGN_RESULT=$(mcporter call google-ads-mcp search --args "{\"customer_id\": \"$CUSTOMER_ID\", \"resource\": \"campaign\", \"fields\": [\"campaign.name\", \"campaign.status\", \"campaign.advertising_channel_type\"], \"conditions\": [\"campaign.status != 'REMOVED'\"], \"limit\": 10}" --output raw 2>&1); then
    echo -e "${GREEN}✅ Campaign query succeeded${NC}"
    echo ""
    echo "   Campaigns:"
    echo "   $CAMPAIGN_RESULT" | head -30
  else
    echo -e "${RED}❌ Campaign query failed${NC}"
    echo "   Error: $CAMPAIGN_RESULT"
    echo "   Check that customer_id $CUSTOMER_ID is in the accessible list"
  fi
fi

echo ""
echo "═══════════════════════════════════════════"
echo " Health check complete"
echo "═══════════════════════════════════════════"
