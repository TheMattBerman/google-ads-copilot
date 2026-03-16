#!/usr/bin/env bash
# gads-apply.sh — Main apply-layer orchestrator
#
# Usage:
#   ./gads-apply.sh <draft-file>               # Full apply flow
#   ./gads-apply.sh --dry-run <draft-file>      # Show dry run only, don't execute
#   ./gads-apply.sh --parse-only <draft-file>   # Parse draft to JSON only
#
# Flow: parse → resolve IDs → dry-run → confirm → execute → verify → audit
#
# Environment:
#   GOOGLE_APPLICATION_CREDENTIALS  — path to OAuth2 credentials JSON
#   GOOGLE_ADS_DEVELOPER_TOKEN      — Google Ads API developer token
#   GOOGLE_ADS_LOGIN_CUSTOMER_ID    — (optional) MCC manager account ID

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Load libraries (config.sh loaded transitively via token-refresh.sh)
source "$LIB_DIR/token-refresh.sh"
source "$LIB_DIR/parse-draft.sh"
source "$LIB_DIR/api-mutate.sh"
source "$LIB_DIR/api-verify.sh"
source "$LIB_DIR/audit-write.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════
# Parse arguments
# ═══════════════════════════════════════════════════════════
DRY_RUN_ONLY=false
PARSE_ONLY=false
DRAFT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN_ONLY=true; shift ;;
    --parse-only) PARSE_ONLY=true; shift ;;
    -h|--help)
      echo "Usage: gads-apply.sh [--dry-run|--parse-only] <draft-file>"
      echo ""
      echo "Options:"
      echo "  --dry-run      Show what would change without executing"
      echo "  --parse-only   Parse the draft to JSON and exit"
      echo ""
      echo "The draft file should be a markdown file from workspace/ads/drafts/"
      echo ""
      echo "API version: ${GADS_API_VERSION}"
      exit 0
      ;;
    *)
      DRAFT_FILE="$1"; shift ;;
  esac
done

if [ -z "$DRAFT_FILE" ]; then
  echo -e "${RED}ERROR: No draft file specified${NC}"
  echo "Usage: gads-apply.sh [--dry-run|--parse-only] <draft-file>"
  exit 1
fi

# Resolve relative paths against project root
if [[ "$DRAFT_FILE" != /* ]]; then
  DRAFT_FILE="${PROJECT_ROOT}/${DRAFT_FILE}"
fi

if [ ! -f "$DRAFT_FILE" ]; then
  echo -e "${RED}ERROR: Draft file not found: ${DRAFT_FILE}${NC}"
  exit 1
fi

# ═══════════════════════════════════════════════════════════
# Step 1: Parse the draft
# ═══════════════════════════════════════════════════════════
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Google Ads Copilot — Apply Layer (API ${GADS_API_VERSION})${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Step 1: Parsing draft...${NC}"

PARSED=$(parse_draft "$DRAFT_FILE")
CUSTOMER_ID=$(echo "$PARSED" | jq -r '.customer_id')
CUSTOMER_NAME=$(echo "$PARSED" | jq -r '.customer_name')
ACTION_COUNT=$(echo "$PARSED" | jq -r '.action_count')
DRAFT_STATUS=$(echo "$PARSED" | jq -r '.status')

echo "  Account:  ${CUSTOMER_NAME} (${CUSTOMER_ID})"
echo "  Actions:  ${ACTION_COUNT}"
echo "  Status:   ${DRAFT_STATUS}"

if [ "$ACTION_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}No actions found in draft. Nothing to apply.${NC}"
  exit 0
fi

if $PARSE_ONLY; then
  echo ""
  echo "$PARSED" | jq '.'
  exit 0
fi

# ═══════════════════════════════════════════════════════════
# Step 2: Validate & resolve IDs
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}Step 2: Validating and resolving resource IDs...${NC}"

# Get access token (validates credentials)
ACCESS_TOKEN=$(get_access_token)
echo "  ✅ OAuth2 token acquired"

# Build a resolved actions array with IDs
RESOLVED_ACTIONS="[]"
VALIDATION_ERRORS=0

for i in $(seq 0 $((ACTION_COUNT - 1))); do
  action=$(echo "$PARSED" | jq ".actions[$i]")
  action_type=$(echo "$action" | jq -r '.type')
  campaign_name=$(echo "$action" | jq -r '.campaign')
  keyword=$(echo "$action" | jq -r '.keyword')
  match_type=$(echo "$action" | jq -r '.match_type')
  scope=$(echo "$action" | jq -r '.scope')
  adgroup_name=$(echo "$action" | jq -r '.adgroup // empty')

  # Resolve campaign ID
  campaign_id=$(lookup_campaign_id "$CUSTOMER_ID" "$campaign_name")
  if [ -z "$campaign_id" ]; then
    echo -e "  ${RED}❌ Campaign not found: \"${campaign_name}\"${NC}"
    action=$(echo "$action" | jq '. + {valid: false, error: "Campaign not found"}')
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
  else
    action=$(echo "$action" | jq --arg cid "$campaign_id" '. + {campaign_id: $cid}')
    echo -e "  ✅ Campaign: \"${campaign_name}\" → ID ${campaign_id}"
  fi

  # Resolve ad group ID if needed
  if [ "$scope" = "AD_GROUP" ] && [ -n "$adgroup_name" ]; then
    adgroup_id=$(lookup_adgroup_id "$CUSTOMER_ID" "$campaign_name" "$adgroup_name")
    if [ -z "$adgroup_id" ]; then
      echo -e "  ${RED}❌ Ad group not found: \"${adgroup_name}\"${NC}"
      action=$(echo "$action" | jq '. + {valid: false, error: "Ad group not found"}')
      VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    else
      action=$(echo "$action" | jq --arg agid "$adgroup_id" '. + {adgroup_id: $agid}')
    fi
  fi

  # For keyword pause actions, resolve the keyword criterion ID
  if [ "$action_type" = "PAUSE_KEYWORD" ] && [ -n "$adgroup_name" ]; then
    criterion_id=$(lookup_keyword_criterion_id "$CUSTOMER_ID" "$campaign_name" "$adgroup_name" "$keyword" "$match_type")
    if [ -z "$criterion_id" ]; then
      echo -e "  ${RED}❌ Keyword criterion not found: \"${keyword}\" [${match_type}]${NC}"
      action=$(echo "$action" | jq '. + {valid: false, error: "Keyword criterion not found"}')
      VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    else
      action=$(echo "$action" | jq --arg crit "$criterion_id" '. + {criterion_id: $crit}')
    fi
  fi

  # For ad group pause actions, resolve the ad group ID
  if [ "$action_type" = "PAUSE_ADGROUP" ]; then
    if [ -z "$adgroup_name" ]; then
      # Use keyword field as the ad group name for pause-draft template format
      adgroup_name="$keyword"
    fi
    if [ -n "$campaign_id" ]; then
      adgroup_id=$(lookup_adgroup_id "$CUSTOMER_ID" "$campaign_name" "$adgroup_name")
    else
      # Fallback: look up without campaign
      adgroup_id=$(lookup_adgroup_id_by_name "$CUSTOMER_ID" "$adgroup_name")
    fi
    if [ -z "$adgroup_id" ]; then
      echo -e "  ${RED}❌ Ad group not found for pause: \"${adgroup_name}\"${NC}"
      action=$(echo "$action" | jq '. + {valid: false, error: "Ad group not found for pause"}')
      VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    else
      action=$(echo "$action" | jq --arg agid "$adgroup_id" '. + {adgroup_id: $agid}')
      echo -e "  ✅ Ad group (pause): \"${adgroup_name}\" → ID ${adgroup_id}"
    fi
  fi

  # Mark as valid if no errors added
  action=$(echo "$action" | jq 'if .valid == null then . + {valid: true} else . end')

  RESOLVED_ACTIONS=$(echo "$RESOLVED_ACTIONS" | jq --argjson a "$action" '. + [$a]')
done

VALID_COUNT=$(echo "$RESOLVED_ACTIONS" | jq '[.[] | select(.valid == true)] | length')
echo ""
echo "  Valid actions: ${VALID_COUNT}/${ACTION_COUNT}"

if [ "$VALID_COUNT" -eq 0 ]; then
  echo -e "${RED}No valid actions. Cannot proceed.${NC}"
  exit 1
fi

# ═══════════════════════════════════════════════════════════
# Step 3: Display dry run
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} DRY RUN: $(basename "$DRAFT_FILE")${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Account: ${CUSTOMER_NAME} (CID: ${CUSTOMER_ID})"
echo "Actions: ${VALID_COUNT} valid / ${ACTION_COUNT} total"
echo ""

printf "%-4s %-16s %-35s %-30s %-6s\n" "#" "Action" "Target" "Detail" "Risk"
printf "%-4s %-16s %-35s %-30s %-6s\n" "---" "----------------" "-----------------------------------" "------------------------------" "------"

for i in $(seq 0 $((ACTION_COUNT - 1))); do
  action=$(echo "$RESOLVED_ACTIONS" | jq ".[$i]")
  valid=$(echo "$action" | jq -r '.valid')
  index=$(echo "$action" | jq -r '.index')
  action_type=$(echo "$action" | jq -r '.type')
  keyword=$(echo "$action" | jq -r '.keyword')
  match_type=$(echo "$action" | jq -r '.match_type')
  campaign=$(echo "$action" | jq -r '.campaign')
  adgroup=$(echo "$action" | jq -r '.adgroup // "-"')

  display_type=""
  display_target=""
  display_detail=""
  display_risk="Low"

  case "$action_type" in
    ADD_NEGATIVE)
      display_type="ADD NEG"
      display_target="Campaign: ${campaign}"
      display_detail="\"${keyword}\" [${match_type}]"
      ;;
    PAUSE_KEYWORD)
      display_type="PAUSE KW"
      display_target="AG: ${adgroup}"
      display_detail="\"${keyword}\" [${match_type}]"
      ;;
    PAUSE_ADGROUP)
      display_type="PAUSE AG"
      display_target="Campaign: ${campaign}"
      display_detail="${adgroup}"
      ;;
  esac

  if [ "$valid" = "false" ]; then
    display_risk="SKIP"
  fi

  printf "%-4s %-16s %-35s %-30s %-6s\n" "$index" "$display_type" "${display_target:0:35}" "${display_detail:0:30}" "$display_risk"
done

# ─── Dry Run Summary ───
echo ""
echo -e "${BOLD}Summary:${NC}"

# Count by action type
NEG_COUNT=$(echo "$RESOLVED_ACTIONS" | jq '[.[] | select(.valid == true and .type == "ADD_NEGATIVE")] | length')
PAUSE_KW_COUNT=$(echo "$RESOLVED_ACTIONS" | jq '[.[] | select(.valid == true and .type == "PAUSE_KEYWORD")] | length')
PAUSE_AG_COUNT=$(echo "$RESOLVED_ACTIONS" | jq '[.[] | select(.valid == true and .type == "PAUSE_ADGROUP")] | length')
SKIP_COUNT=$(echo "$RESOLVED_ACTIONS" | jq '[.[] | select(.valid == false)] | length')

[ "$NEG_COUNT" -gt 0 ] && echo -e "  • ${NEG_COUNT} negative keyword addition(s)"
[ "$PAUSE_KW_COUNT" -gt 0 ] && echo -e "  • ${PAUSE_KW_COUNT} keyword pause(s)"
[ "$PAUSE_AG_COUNT" -gt 0 ] && echo -e "  • ${PAUSE_AG_COUNT} ad group pause(s)"
[ "$SKIP_COUNT" -gt 0 ] && echo -e "  • ${YELLOW}${SKIP_COUNT} skipped (validation errors)${NC}"
echo -e "  • Reversibility: ${GREEN}All actions reversible${NC}"

if [ "$VALIDATION_ERRORS" -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}⚠️  ${VALIDATION_ERRORS} action(s) will be skipped due to validation errors.${NC}"
fi

echo ""
echo -e "${RED}⚠️  This will make REAL changes to Google Ads account ${CUSTOMER_ID}.${NC}"

if $DRY_RUN_ONLY; then
  echo ""
  echo -e "${BLUE}(Dry run mode — no changes will be made)${NC}"
  echo ""
  echo -e "Next steps:"
  echo -e "  • Remove --dry-run to apply:  ${DIM}gads-apply.sh <draft-file>${NC}"
  echo -e "  • Review the draft:           ${DIM}cat <draft-file>${NC}"
  echo -e "  • Check operator status:      ${DIM}gads-status.sh${NC}"
  exit 0
fi

# ═══════════════════════════════════════════════════════════
# Step 4: Human confirmation
# ═══════════════════════════════════════════════════════════
echo ""
echo -n "Type 'confirm' to proceed, or 'cancel' to abort: "
read -r confirmation

if [ "$confirmation" != "confirm" ]; then
  echo -e "${YELLOW}Cancelled. No changes made.${NC}"
  exit 0
fi

echo ""
echo -e "${GREEN}Confirmed. Executing ${VALID_COUNT} actions...${NC}"

# ═══════════════════════════════════════════════════════════
# Step 5: Execute mutations
# ═══════════════════════════════════════════════════════════
init_apply_session "$DRAFT_FILE" "$CUSTOMER_ID" "$CUSTOMER_NAME" "$VALID_COUNT"

SUCCEEDED=0
FAILED=0

for i in $(seq 0 $((ACTION_COUNT - 1))); do
  action=$(echo "$RESOLVED_ACTIONS" | jq ".[$i]")
  valid=$(echo "$action" | jq -r '.valid')

  if [ "$valid" = "false" ]; then
    log_action_result \
      "$(echo "$action" | jq -r '.index')" \
      "$(echo "$action" | jq -r '.type')" \
      "skipped" \
      "$(echo "$action" | jq -r '.error // "validation failed"')" \
      "⏭️ Skipped" \
      "-"
    continue
  fi

  action_type=$(echo "$action" | jq -r '.type')
  keyword=$(echo "$action" | jq -r '.keyword')
  match_type=$(echo "$action" | jq -r '.match_type')
  campaign_name=$(echo "$action" | jq -r '.campaign')
  campaign_id=$(echo "$action" | jq -r '.campaign_id')
  adgroup_name=$(echo "$action" | jq -r '.adgroup // empty')
  adgroup_id=$(echo "$action" | jq -r '.adgroup_id // empty')
  criterion_id=$(echo "$action" | jq -r '.criterion_id // empty')
  action_index=$(echo "$action" | jq -r '.index')

  echo -n "  [${action_index}] ${action_type}: \"${keyword}\" ... "

  result=""
  resource_name=""
  reversal_id=$(next_reversal_id)

  case "$action_type" in
    ADD_NEGATIVE)
      if [ "$(echo "$action" | jq -r '.scope')" = "AD_GROUP" ]; then
        result=$(mutate_add_negative_adgroup "$CUSTOMER_ID" "$adgroup_id" "$keyword" "$match_type")
      else
        result=$(mutate_add_negative_campaign "$CUSTOMER_ID" "$campaign_id" "$keyword" "$match_type")
      fi
      ;;
    PAUSE_KEYWORD)
      result=$(mutate_pause_keyword "$CUSTOMER_ID" "$adgroup_id" "$criterion_id")
      ;;
    PAUSE_ADGROUP)
      result=$(mutate_pause_adgroup "$CUSTOMER_ID" "$adgroup_id")
      ;;
  esac

  success=$(echo "$result" | jq -r '.success')
  resource_name=$(echo "$result" | jq -r '.resource_name // empty')
  already_exists=$(echo "$result" | jq -r '.already_exists // false')

  if [ "$success" = "true" ]; then
    if [ "$already_exists" = "true" ]; then
      echo -e "${YELLOW}already exists${NC}"
      log_action_result "$action_index" "$action_type" "$campaign_name" "\"$keyword\" [$match_type]" "⏭️ Already exists" "-"
    else
      echo -e "${GREEN}✅${NC}"
      SUCCEEDED=$((SUCCEEDED + 1))

      # Build reversal record
      reversal_action=""
      reversal_resource=""
      case "$action_type" in
        ADD_NEGATIVE)
          if [ "$(echo "$action" | jq -r '.scope')" = "AD_GROUP" ]; then
            reversal_action="REMOVE_NEGATIVE_ADGROUP"
          else
            reversal_action="REMOVE_NEGATIVE_CAMPAIGN"
          fi
          reversal_resource="$resource_name"
          ;;
        PAUSE_KEYWORD)
          reversal_action="ENABLE_KEYWORD"
          reversal_resource="$resource_name"
          ;;
        PAUSE_ADGROUP)
          reversal_action="ENABLE_ADGROUP"
          reversal_resource="$resource_name"
          ;;
      esac

      reversal_record=$(jq -n \
        --arg id "$reversal_id" \
        --arg action "$action_type" \
        --arg keyword "$keyword" \
        --arg matchType "$match_type" \
        --arg scope "$(echo "$action" | jq -r '.scope')" \
        --arg campaignName "$campaign_name" \
        --arg campaignId "$campaign_id" \
        --arg accountId "$CUSTOMER_ID" \
        --arg appliedAt "$(gads_now_iso)" \
        --arg draftSource "$(basename "$DRAFT_FILE")" \
        --arg reversalAction "$reversal_action" \
        --arg reversalResource "$reversal_resource" \
        --arg resourceName "$resource_name" \
        '{
          id: $id,
          action: $action,
          keyword: $keyword,
          matchType: $matchType,
          scope: $scope,
          campaignName: $campaignName,
          campaignId: $campaignId,
          accountId: $accountId,
          appliedAt: $appliedAt,
          appliedBy: "operator",
          draftSource: $draftSource,
          reversalAction: $reversalAction,
          reversalResourceName: $reversalResource,
          resourceName: $resourceName,
          status: "active",
          undoneAt: null
        }')

      add_reversal_record "$reversal_record"
      log_action_result "$action_index" "$action_type" "$campaign_name" "\"$keyword\" [$match_type]" "✅ Applied" "$reversal_id" "$resource_name"
    fi
  else
    error=$(echo "$result" | jq -r '.error // "Unknown"')
    echo -e "${RED}❌ ${error}${NC}"
    FAILED=$((FAILED + 1))
    log_action_result "$action_index" "$action_type" "$campaign_name" "\"$keyword\" [$match_type]" "❌ Failed: $error" "-"
  fi

  # Rate limit: small delay between mutations
  sleep 0.5
done

# ═══════════════════════════════════════════════════════════
# Step 6: Verify
# ═══════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}Step 6: Verifying changes...${NC}"

VERIFY_PASS=0
VERIFY_FAIL=0

for i in $(seq 0 $((ACTION_COUNT - 1))); do
  action=$(echo "$RESOLVED_ACTIONS" | jq ".[$i]")
  valid=$(echo "$action" | jq -r '.valid')
  [ "$valid" = "false" ] && continue

  action_type=$(echo "$action" | jq -r '.type')
  keyword=$(echo "$action" | jq -r '.keyword')
  match_type=$(echo "$action" | jq -r '.match_type')
  campaign_name=$(echo "$action" | jq -r '.campaign')
  adgroup_name=$(echo "$action" | jq -r '.adgroup // empty')

  verify_result=""

  case "$action_type" in
    ADD_NEGATIVE)
      if [ "$(echo "$action" | jq -r '.scope')" = "AD_GROUP" ]; then
        verify_result=$(verify_negative_adgroup_exists "$CUSTOMER_ID" "$campaign_name" "$adgroup_name" "$keyword" "$match_type")
      else
        verify_result=$(verify_negative_exists "$CUSTOMER_ID" "$campaign_name" "$keyword" "$match_type")
      fi
      ;;
    PAUSE_KEYWORD)
      verify_result=$(verify_keyword_paused "$CUSTOMER_ID" "$campaign_name" "$adgroup_name" "$keyword")
      ;;
    PAUSE_ADGROUP)
      verify_result=$(verify_adgroup_paused "$CUSTOMER_ID" "$campaign_name" "$adgroup_name")
      ;;
  esac

  verified=$(echo "$verify_result" | jq -r '.verified')
  detail=$(echo "$verify_result" | jq -r '.detail')

  if [ "$verified" = "true" ]; then
    echo -e "  ${GREEN}✅ ${detail}${NC}"
    VERIFY_PASS=$((VERIFY_PASS + 1))
  else
    echo -e "  ${YELLOW}⚠️  ${detail}${NC}"
    VERIFY_FAIL=$((VERIFY_FAIL + 1))
  fi
done

# ═══════════════════════════════════════════════════════════
# Step 7: Finalize audit trail
# ═══════════════════════════════════════════════════════════
finalize_apply_session "$SUCCEEDED" "$FAILED"

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Apply Session Complete${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Results:${NC}"
echo "  ├── Executed:  ${SUCCEEDED} succeeded, ${FAILED} failed"
echo "  ├── Verified:  ${VERIFY_PASS} confirmed, ${VERIFY_FAIL} unconfirmed"
echo "  └── Skipped:   $((ACTION_COUNT - VALID_COUNT)) (validation errors)"
echo ""
echo -e "  ${BOLD}Audit Trail:${NC}"
echo "  ├── Session:   ${_SESSION_FILE}"
echo "  ├── Registry:  ${REGISTRY_FILE}"
echo "  └── Master:    workspace/ads/audit-trail/_log.md"
echo ""

# Show reversal IDs for this session
FIRST_REV=$(jq -r '[.reversals[] | select(.status == "active")] | sort_by(.id) | last(.[].id) // empty' "$REGISTRY_FILE" 2>/dev/null)
if [ -n "$FIRST_REV" ]; then
  echo -e "  ${BOLD}Undo:${NC}"
  echo "  ├── Single:    gads-undo.sh <rev-ID>"
  echo "  ├── All:       gads-undo.sh --draft $(basename "$DRAFT_FILE")"
  echo "  └── List:      gads-undo.sh --list"
  echo ""
fi

if [ "$SUCCEEDED" -gt 0 ] && [ "$FAILED" -eq 0 ] && [ "$VERIFY_FAIL" -eq 0 ]; then
  echo -e "${GREEN}✅ All actions applied and verified successfully.${NC}"
  echo ""
  echo -e "  ${DIM}What to watch for in the next 7 days:${NC}"
  echo -e "  ${DIM}  • Check search term reports for blocked queries${NC}"
  echo -e "  ${DIM}  • Monitor that waste queries stop appearing${NC}"
  echo -e "  ${DIM}  • Run /google-ads daily for a quick health check${NC}"
elif [ "$FAILED" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Some actions failed. Check the session log for details.${NC}"
  echo "Re-run with the same draft to retry failed actions."
elif [ "$VERIFY_FAIL" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Some verifications didn't confirm. This may be propagation delay.${NC}"
  echo "Re-check in 5 minutes. Changes usually propagate within 60 seconds."
fi
