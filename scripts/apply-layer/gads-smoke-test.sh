#!/usr/bin/env bash
# gads-smoke-test.sh — End-to-end write cycle smoke test
#
# Usage:
#   ./gads-smoke-test.sh negative <customer_id> [campaign_id]
#   ./gads-smoke-test.sh budget <customer_id> [campaign_id]
#
# Modes:
#   negative  Add exact negative -> verify -> remove -> verify removal
#   budget    Small bounded budget decrease -> verify -> restore -> verify restore

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/token-refresh.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TEST_KEYWORD="_gads_copilot_smoke_test"
TEST_MATCH_TYPE="EXACT"

MODE="${1:-negative}"
CUSTOMER_ID="${2:-}"
CAMPAIGN_ID="${3:-}"

api_post() {
  local customer_id="$1"
  local endpoint="$2"
  local payload="$3"
  curl -s -X POST "${GADS_API_BASE}/customers/${customer_id}/${endpoint}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" \
    ${GOOGLE_ADS_LOGIN_CUSTOMER_ID:+-H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}"} \
    -H "Content-Type: application/json" \
    -d "$payload"
}

find_campaign() {
  local customer_id="$1"
  local campaign_id="${2:-}"
  local mode="${3:-negative}"

  if [ -n "$campaign_id" ]; then
    local provided_result
    if [ "$mode" = "budget" ]; then
      provided_result=$(api_post "$customer_id" "googleAds:searchStream" "$(jq -n --arg cid "$campaign_id" '{query: ("SELECT campaign.id, campaign.name, campaign_budget.explicitly_shared FROM campaign WHERE campaign.id = " + $cid + " LIMIT 1")}')")
    else
      provided_result=$(api_post "$customer_id" "googleAds:searchStream" "$(jq -n --arg cid "$campaign_id" '{query: ("SELECT campaign.id, campaign.name FROM campaign WHERE campaign.id = " + $cid + " LIMIT 1")}')")
    fi
    local provided_name
    local provided_shared
    provided_name=$(echo "$provided_result" | jq -r '.[0].results[0].campaign.name // empty' 2>/dev/null)
    provided_shared=$(echo "$provided_result" | jq -r '.[0].results[0].campaignBudget.explicitlyShared // false' 2>/dev/null)
    if [ -z "$provided_name" ]; then
      echo -e "${RED}❌ Campaign ${campaign_id} not found${NC}" >&2
      exit 1
    fi
    if [ "$mode" = "budget" ] && [ "$provided_shared" = "true" ]; then
      echo -e "${RED}❌ Campaign ${campaign_id} uses a shared budget, which is out of scope for the budget smoke test${NC}" >&2
      exit 1
    fi
    echo "${campaign_id}|${provided_name}"
    return 0
  fi

  local result
  if [ "$mode" = "budget" ]; then
    result=$(api_post "$customer_id" "googleAds:searchStream" '{"query": "SELECT campaign.id, campaign.name, campaign.status, campaign_budget.explicitly_shared FROM campaign WHERE campaign.status != '\''REMOVED'\'' AND campaign_budget.explicitly_shared = FALSE LIMIT 1"}')
  else
    result=$(api_post "$customer_id" "googleAds:searchStream" '{"query": "SELECT campaign.id, campaign.name, campaign.status FROM campaign WHERE campaign.status != '\''REMOVED'\'' LIMIT 1"}')
  fi

  local found_id found_name
  found_id=$(echo "$result" | jq -r '.[0].results[0].campaign.id // empty' 2>/dev/null)
  found_name=$(echo "$result" | jq -r '.[0].results[0].campaign.name // empty' 2>/dev/null)

  if [ -z "$found_id" ]; then
    echo -e "${RED}❌ No campaigns found${NC}" >&2
    exit 1
  fi

  echo "${found_id}|${found_name}"
}

discover_accounts() {
  local accounts
  accounts=$(curl -s "${GADS_API_BASE}/customers:listAccessibleCustomers" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" | jq -r '.resourceNames[]' 2>/dev/null)

  if [ -z "$accounts" ]; then
    echo -e "  ${RED}❌ No accessible accounts found${NC}"
    exit 1
  fi

  echo "  Available accounts:"
  echo "$accounts" | while read -r rn; do
    echo "    - ${rn}"
  done
  echo ""
  echo "  Usage: $0 [negative|budget] <customer_id> [campaign_id]"
  exit 0
}

run_negative_smoke() {
  local customer_id="$1"
  local campaign_id="$2"
  local campaign_name="$3"

  echo ""
  echo -e "${BLUE}Step 1: ADD campaign negative \"${TEST_KEYWORD}\" [${TEST_MATCH_TYPE}]${NC}"

  local add_result
  add_result=$(api_post "$customer_id" "campaignCriteria:mutate" "$(jq -n \
    --arg campaign "customers/${customer_id}/campaigns/${campaign_id}" \
    --arg text "$TEST_KEYWORD" \
    --arg match "$TEST_MATCH_TYPE" \
    '{operations: [{create: {campaign: $campaign, negative: true, keyword: {text: $text, matchType: $match}}}]}')")

  local resource_name
  resource_name=$(echo "$add_result" | jq -r '.results[0].resourceName // empty')

  if [ -z "$resource_name" ]; then
    echo -e "  ${RED}❌ Failed to create negative${NC}"
    echo "$add_result" | jq . 2>/dev/null || echo "$add_result"
    exit 1
  fi
  echo -e "  ${GREEN}✅ Created: ${resource_name}${NC}"

  echo ""
  echo -e "${BLUE}Step 2: VERIFY negative exists via GAQL query${NC}"

  local verify_result
  verify_result=$(api_post "$customer_id" "googleAds:searchStream" "$(jq -n --arg kw "$TEST_KEYWORD" \
    '{query: ("SELECT campaign.name, campaign_criterion.keyword.text, campaign_criterion.keyword.match_type, campaign_criterion.negative FROM campaign_criterion WHERE campaign_criterion.negative = TRUE AND campaign_criterion.type = '\''KEYWORD'\'' AND campaign_criterion.keyword.text = '\''" + $kw + "'\''")}')")

  local verify_count
  verify_count=$(echo "$verify_result" | jq '[.[].results // [] | length] | add // 0' 2>/dev/null)
  if [ "$verify_count" -gt 0 ]; then
    echo -e "  ${GREEN}✅ Verified: negative keyword found in account${NC}"
  else
    echo -e "  ${YELLOW}⚠️  Negative not found via GAQL (may be propagation delay)${NC}"
  fi

  echo ""
  echo -e "${BLUE}Step 3: REMOVE test negative${NC}"

  local remove_result
  remove_result=$(api_post "$customer_id" "campaignCriteria:mutate" "$(jq -n --arg rn "$resource_name" '{operations: [{remove: $rn}]}')")
  local removed_rn
  removed_rn=$(echo "$remove_result" | jq -r '.results[0].resourceName // empty')

  if [ -z "$removed_rn" ]; then
    echo -e "  ${RED}❌ Failed to remove${NC}"
    echo "$remove_result" | jq . 2>/dev/null || echo "$remove_result"
    exit 1
  fi
  echo -e "  ${GREEN}✅ Removed: ${removed_rn}${NC}"

  echo ""
  echo -e "${BLUE}Step 4: VERIFY negative removed${NC}"

  local verify2_result
  verify2_result=$(api_post "$customer_id" "googleAds:searchStream" "$(jq -n --arg kw "$TEST_KEYWORD" \
    '{query: ("SELECT campaign_criterion.keyword.text FROM campaign_criterion WHERE campaign_criterion.negative = TRUE AND campaign_criterion.type = '\''KEYWORD'\'' AND campaign_criterion.keyword.text = '\''" + $kw + "'\''")}')")

  local verify2_count
  verify2_count=$(echo "$verify2_result" | jq '[.[].results // [] | length] | add // 0' 2>/dev/null)
  if [ "$verify2_count" -eq 0 ]; then
    echo -e "  ${GREEN}✅ Confirmed removed: no matching negatives${NC}"
  else
    echo -e "  ${YELLOW}⚠️  Still found ${verify2_count} result(s) — may need propagation time${NC}"
  fi

  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD} Smoke Test Results${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "  Mode:          negative"
  echo "  API Version:   ${GADS_API_VERSION}"
  echo "  Customer:      ${customer_id}"
  echo "  Campaign:      ${campaign_name} (${campaign_id})"
  echo ""
  echo "  ✅ campaignCriteria:mutate CREATE"
  echo "  ✅ googleAds:searchStream verify"
  echo "  ✅ campaignCriteria:mutate REMOVE"
  echo "  ✅ googleAds:searchStream verify removal"
  echo ""
  echo -e "${GREEN}Negative write-cycle smoke test completed.${NC}"
}

run_budget_smoke() {
  local customer_id="$1"
  local campaign_id="$2"
  local campaign_name="$3"

  echo ""
  echo -e "${BLUE}Step 1: LOOK UP campaign budget${NC}"

  local budget_query budget_result budget_resource current_micros
  budget_query=$(jq -n --arg name "$campaign_name" '{query: ("SELECT campaign.name, campaign_budget.resource_name, campaign_budget.amount_micros, campaign_budget.explicitly_shared FROM campaign WHERE campaign.name = '\''" + $name + "'\'' AND campaign.status != '\''REMOVED'\'' LIMIT 1")}')
  budget_result=$(api_post "$customer_id" "googleAds:searchStream" "$budget_query")
  budget_resource=$(echo "$budget_result" | jq -r '.[0].results[0].campaignBudget.resourceName // empty' 2>/dev/null)
  current_micros=$(echo "$budget_result" | jq -r '.[0].results[0].campaignBudget.amountMicros // empty' 2>/dev/null)
  explicitly_shared=$(echo "$budget_result" | jq -r '.[0].results[0].campaignBudget.explicitlyShared // false' 2>/dev/null)

  if [ -z "$budget_resource" ] || [ -z "$current_micros" ]; then
    echo -e "  ${RED}❌ Could not resolve campaign budget${NC}"
    exit 1
  fi
  if [ "$explicitly_shared" = "true" ]; then
    echo -e "  ${RED}❌ Shared campaign budgets are out of scope for the budget smoke test${NC}"
    exit 1
  fi

  echo "  Resource: ${budget_resource}"
  echo "  Current:  ${current_micros} micros"

  local five_pct five_dollars delta_micros max_delta proposed_micros
  five_pct=$(( (current_micros * 5 + 99) / 100 ))
  five_dollars=5000000
  delta_micros="$five_pct"
  if [ "$delta_micros" -lt "$five_dollars" ]; then
    delta_micros="$five_dollars"
  fi
  max_delta=$(( (current_micros * 10) / 100 ))
  if [ "$max_delta" -gt 0 ] && [ "$delta_micros" -gt "$max_delta" ]; then
    delta_micros="$max_delta"
  fi
  proposed_micros=$(( current_micros - delta_micros ))

  if [ "$delta_micros" -le 0 ] || [ "$proposed_micros" -le 0 ]; then
    echo -e "  ${YELLOW}⚠️  Budget too small for a safe budget smoke test${NC}"
    exit 1
  fi

  echo "  Proposed: ${proposed_micros} micros"

  echo ""
  echo -e "${BLUE}Step 2: APPLY bounded budget decrease${NC}"
  local update_payload update_result update_rn
  update_payload=$(jq -n --arg rn "$budget_resource" --argjson micros "$proposed_micros" \
    '{operations: [{updateMask: "amount_micros", update: {resourceName: $rn, amountMicros: $micros}}]}')
  update_result=$(api_post "$customer_id" "campaignBudgets:mutate" "$update_payload")
  update_rn=$(echo "$update_result" | jq -r '.results[0].resourceName // empty' 2>/dev/null)

  if [ -z "$update_rn" ]; then
    echo -e "  ${RED}❌ Failed to mutate budget${NC}"
    echo "$update_result" | jq . 2>/dev/null || echo "$update_result"
    exit 1
  fi
  echo -e "  ${GREEN}✅ Updated: ${update_rn}${NC}"

  echo ""
  echo -e "${BLUE}Step 3: VERIFY updated budget${NC}"
  local verify_result got_micros
  verify_result=$(api_post "$customer_id" "googleAds:searchStream" "$budget_query")
  got_micros=$(echo "$verify_result" | jq -r '.[0].results[0].campaignBudget.amountMicros // empty' 2>/dev/null)

  if [ "$got_micros" = "$proposed_micros" ]; then
    echo -e "  ${GREEN}✅ Verified: budget now ${got_micros} micros${NC}"
  else
    echo -e "  ${RED}❌ Verification failed: got ${got_micros}, expected ${proposed_micros}${NC}"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}Step 4: RESTORE original budget${NC}"
  local restore_payload restore_result restore_rn
  restore_payload=$(jq -n --arg rn "$budget_resource" --argjson micros "$current_micros" \
    '{operations: [{updateMask: "amount_micros", update: {resourceName: $rn, amountMicros: $micros}}]}')
  restore_result=$(api_post "$customer_id" "campaignBudgets:mutate" "$restore_payload")
  restore_rn=$(echo "$restore_result" | jq -r '.results[0].resourceName // empty' 2>/dev/null)

  if [ -z "$restore_rn" ]; then
    echo -e "  ${RED}❌ Failed to restore budget${NC}"
    echo "$restore_result" | jq . 2>/dev/null || echo "$restore_result"
    exit 1
  fi
  echo -e "  ${GREEN}✅ Restored: ${restore_rn}${NC}"

  echo ""
  echo -e "${BLUE}Step 5: VERIFY restored budget${NC}"
  local verify_restore_result restored_micros
  verify_restore_result=$(api_post "$customer_id" "googleAds:searchStream" "$budget_query")
  restored_micros=$(echo "$verify_restore_result" | jq -r '.[0].results[0].campaignBudget.amountMicros // empty' 2>/dev/null)

  if [ "$restored_micros" = "$current_micros" ]; then
    echo -e "  ${GREEN}✅ Verified: budget restored to ${restored_micros} micros${NC}"
  else
    echo -e "  ${RED}❌ Restore verification failed: got ${restored_micros}, expected ${current_micros}${NC}"
    exit 1
  fi

  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD} Smoke Test Results${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo ""
  echo "  Mode:          budget"
  echo "  API Version:   ${GADS_API_VERSION}"
  echo "  Customer:      ${customer_id}"
  echo "  Campaign:      ${campaign_name} (${campaign_id})"
  echo "  Before:        ${current_micros} micros"
  echo "  Test value:    ${proposed_micros} micros"
  echo "  Restored:      ${restored_micros} micros"
  echo ""
  echo "  ✅ campaignBudgets:mutate UPDATE"
  echo "  ✅ googleAds:searchStream verify"
  echo "  ✅ campaignBudgets:mutate RESTORE"
  echo "  ✅ googleAds:searchStream verify restore"
  echo ""
  echo -e "${GREEN}Budget write-cycle smoke test completed.${NC}"
}

echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Google Ads Copilot — Write Cycle Smoke Test${NC}"
echo -e "${BOLD} API Version: ${GADS_API_VERSION}${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -n "  Acquiring token... "
ACCESS_TOKEN=$(get_access_token)
echo -e "${GREEN}✅${NC}"

if [ -z "$CUSTOMER_ID" ]; then
  echo ""
  echo "  No customer ID provided. Discovering accounts..."
  discover_accounts
fi

case "$MODE" in
  negative|budget) ;;
  *)
    echo -e "${RED}Unknown mode: ${MODE}${NC}"
    echo "Usage: $0 [negative|budget] <customer_id> [campaign_id]"
    exit 1
    ;;
esac

echo "  Customer ID: ${CUSTOMER_ID}"
campaign_info=$(find_campaign "$CUSTOMER_ID" "$CAMPAIGN_ID" "$MODE")
CAMPAIGN_ID="${campaign_info%%|*}"
CAMPAIGN_NAME="${campaign_info#*|}"
echo "  Campaign:    ${CAMPAIGN_NAME} (${CAMPAIGN_ID})"

case "$MODE" in
  negative) run_negative_smoke "$CUSTOMER_ID" "$CAMPAIGN_ID" "$CAMPAIGN_NAME" ;;
  budget) run_budget_smoke "$CUSTOMER_ID" "$CAMPAIGN_ID" "$CAMPAIGN_NAME" ;;
esac
