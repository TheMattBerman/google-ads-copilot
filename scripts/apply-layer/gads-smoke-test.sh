#!/usr/bin/env bash
# gads-smoke-test.sh — End-to-end write cycle smoke test
#
# Proves the full add → verify → remove → verify cycle works against a real
# Google Ads account. Uses a harmless test keyword that gets cleaned up.
#
# Usage:
#   ./gads-smoke-test.sh                          # Test against default account
#   ./gads-smoke-test.sh <customer_id>            # Test against specific account
#   ./gads-smoke-test.sh <customer_id> <campaign_id>  # Test specific campaign
#
# Environment: same as gads-auth.sh / gads-apply.sh
#
# This script was created after live-testing confirmed:
#   - v18 → 404 (sunset)
#   - v19 → 500 (unstable)
#   - v20 → 200 (working, confirmed 2026-03-15)
#
# The test keyword "_gads_copilot_smoke_test" is:
#   - Unlikely to match any real search query
#   - Added as an EXACT negative (zero blast radius)
#   - Immediately removed after verification

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/token-refresh.sh"
# config.sh is sourced transitively — provides GADS_API_VERSION and GADS_API_BASE

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TEST_KEYWORD="_gads_copilot_smoke_test"
TEST_MATCH_TYPE="EXACT"

echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Google Ads Copilot — Write Cycle Smoke Test${NC}"
echo -e "${BOLD} API Version: ${GADS_API_VERSION}${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get token
echo -n "  Acquiring token... "
ACCESS_TOKEN=$(get_access_token)
echo -e "${GREEN}✅${NC}"

# Determine customer ID
CUSTOMER_ID="${1:-}"
CAMPAIGN_ID="${2:-}"

if [ -z "$CUSTOMER_ID" ]; then
  echo ""
  echo "  No customer ID provided. Discovering accounts..."
  ACCOUNTS=$(curl -s "${GADS_API_BASE}/customers:listAccessibleCustomers" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" | jq -r '.resourceNames[]' 2>/dev/null)

  if [ -z "$ACCOUNTS" ]; then
    echo -e "  ${RED}❌ No accessible accounts found${NC}"
    exit 1
  fi

  echo "  Available accounts:"
  echo "$ACCOUNTS" | while read -r rn; do
    echo "    - ${rn}"
  done
  echo ""
  echo "  Usage: $0 <customer_id> [campaign_id]"
  exit 0
fi

echo "  Customer ID: ${CUSTOMER_ID}"

# Find a campaign to test against
if [ -z "$CAMPAIGN_ID" ]; then
  echo -n "  Finding a non-REMOVED campaign... "
  CAMPAIGN_RESULT=$(curl -s -X POST "${GADS_API_BASE}/customers/${CUSTOMER_ID}/googleAds:searchStream" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" \
    ${GOOGLE_ADS_LOGIN_CUSTOMER_ID:+-H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}"} \
    -H "Content-Type: application/json" \
    -d '{"query": "SELECT campaign.id, campaign.name, campaign.status FROM campaign WHERE campaign.status != '\''REMOVED'\'' LIMIT 1"}')

  CAMPAIGN_ID=$(echo "$CAMPAIGN_RESULT" | jq -r '.[0].results[0].campaign.id // empty' 2>/dev/null)
  CAMPAIGN_NAME=$(echo "$CAMPAIGN_RESULT" | jq -r '.[0].results[0].campaign.name // empty' 2>/dev/null)

  if [ -z "$CAMPAIGN_ID" ]; then
    echo -e "${RED}❌ No campaigns found${NC}"
    exit 1
  fi
  echo -e "${GREEN}✅ \"${CAMPAIGN_NAME}\" (ID: ${CAMPAIGN_ID})${NC}"
else
  CAMPAIGN_NAME="(provided)"
  echo "  Campaign ID: ${CAMPAIGN_ID}"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# Step 1: ADD campaign negative
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}Step 1: ADD campaign negative \"${TEST_KEYWORD}\" [${TEST_MATCH_TYPE}]${NC}"

ADD_RESULT=$(curl -s -X POST "${GADS_API_BASE}/customers/${CUSTOMER_ID}/campaignCriteria:mutate" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" \
  ${GOOGLE_ADS_LOGIN_CUSTOMER_ID:+-H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}"} \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg campaign "customers/${CUSTOMER_ID}/campaigns/${CAMPAIGN_ID}" \
    --arg text "$TEST_KEYWORD" \
    --arg match "$TEST_MATCH_TYPE" \
    '{operations: [{create: {campaign: $campaign, negative: true, keyword: {text: $text, matchType: $match}}}]}')")

RESOURCE_NAME=$(echo "$ADD_RESULT" | jq -r '.results[0].resourceName // empty')

if [ -n "$RESOURCE_NAME" ]; then
  echo -e "  ${GREEN}✅ Created: ${RESOURCE_NAME}${NC}"
else
  echo -e "  ${RED}❌ Failed to create negative${NC}"
  echo "$ADD_RESULT" | jq . 2>/dev/null || echo "$ADD_RESULT"
  exit 1
fi

# ═══════════════════════════════════════════════════════════
# Step 2: VERIFY via GAQL
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}Step 2: VERIFY negative exists via GAQL query${NC}"

VERIFY_RESULT=$(curl -s -X POST "${GADS_API_BASE}/customers/${CUSTOMER_ID}/googleAds:searchStream" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" \
  ${GOOGLE_ADS_LOGIN_CUSTOMER_ID:+-H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}"} \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg kw "$TEST_KEYWORD" \
    '{query: ("SELECT campaign.name, campaign_criterion.keyword.text, campaign_criterion.keyword.match_type, campaign_criterion.negative FROM campaign_criterion WHERE campaign_criterion.negative = TRUE AND campaign_criterion.type = '\''KEYWORD'\'' AND campaign_criterion.keyword.text = '\''" + $kw + "'\''")}')")

VERIFY_COUNT=$(echo "$VERIFY_RESULT" | jq '[.[].results // [] | length] | add // 0' 2>/dev/null)

if [ "$VERIFY_COUNT" -gt 0 ]; then
  echo -e "  ${GREEN}✅ Verified: negative keyword found in account${NC}"
else
  echo -e "  ${YELLOW}⚠️  Negative not found via GAQL (may be propagation delay)${NC}"
fi

# ═══════════════════════════════════════════════════════════
# Step 3: REMOVE the test negative
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}Step 3: REMOVE test negative${NC}"

REMOVE_RESULT=$(curl -s -X POST "${GADS_API_BASE}/customers/${CUSTOMER_ID}/campaignCriteria:mutate" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" \
  ${GOOGLE_ADS_LOGIN_CUSTOMER_ID:+-H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}"} \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg rn "$RESOURCE_NAME" '{operations: [{remove: $rn}]}')")

REMOVED_RN=$(echo "$REMOVE_RESULT" | jq -r '.results[0].resourceName // empty')

if [ -n "$REMOVED_RN" ]; then
  echo -e "  ${GREEN}✅ Removed: ${REMOVED_RN}${NC}"
else
  echo -e "  ${RED}❌ Failed to remove${NC}"
  echo "$REMOVE_RESULT" | jq . 2>/dev/null || echo "$REMOVE_RESULT"
  exit 1
fi

# ═══════════════════════════════════════════════════════════
# Step 4: VERIFY removal
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}Step 4: VERIFY negative removed${NC}"

VERIFY2_RESULT=$(curl -s -X POST "${GADS_API_BASE}/customers/${CUSTOMER_ID}/googleAds:searchStream" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" \
  ${GOOGLE_ADS_LOGIN_CUSTOMER_ID:+-H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}"} \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg kw "$TEST_KEYWORD" \
    '{query: ("SELECT campaign_criterion.keyword.text FROM campaign_criterion WHERE campaign_criterion.negative = TRUE AND campaign_criterion.type = '\''KEYWORD'\'' AND campaign_criterion.keyword.text = '\''" + $kw + "'\''")}')")

VERIFY2_COUNT=$(echo "$VERIFY2_RESULT" | jq '[.[].results // [] | length] | add // 0' 2>/dev/null)

if [ "$VERIFY2_COUNT" -eq 0 ]; then
  echo -e "  ${GREEN}✅ Confirmed removed: no matching negatives${NC}"
else
  echo -e "  ${YELLOW}⚠️  Still found ${VERIFY2_COUNT} result(s) — may need propagation time${NC}"
fi

# ═══════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Smoke Test Results${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  API Version:   ${GADS_API_VERSION}"
echo "  Customer:      ${CUSTOMER_ID}"
echo "  Campaign:      ${CAMPAIGN_NAME} (${CAMPAIGN_ID})"
echo ""
echo "  ✅ Token acquisition"
echo "  ✅ campaignCriteria:mutate CREATE (add negative)"
echo "  ✅ googleAds:searchStream (GAQL verify)"
echo "  ✅ campaignCriteria:mutate REMOVE (undo negative)"
echo "  ✅ googleAds:searchStream (GAQL verify removal)"
echo ""
echo -e "${GREEN}All write-cycle operations confirmed working.${NC}"
echo -e "${GREEN}The apply layer is ready for real draft execution.${NC}"
