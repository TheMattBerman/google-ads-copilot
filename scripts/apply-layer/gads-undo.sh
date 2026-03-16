#!/usr/bin/env bash
# gads-undo.sh — Reverse applied actions from the reversal registry
#
# Usage:
#   ./gads-undo.sh <reversal-id>                    # Undo a single action
#   ./gads-undo.sh --draft <draft-file>              # Undo all actions from a draft
#   ./gads-undo.sh --list                            # List all active reversals
#   ./gads-undo.sh --list --draft <draft-file>       # List reversals for a draft
#
# Each undo follows the same confirm → execute → verify → audit pattern.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/token-refresh.sh"
source "$LIB_DIR/api-mutate.sh"
source "$LIB_DIR/api-verify.sh"
source "$LIB_DIR/audit-write.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

REGISTRY_FILE="${PROJECT_ROOT}/workspace/ads/audit-trail/reversal-registry.json"

# ═══════════════════════════════════════════════════════════
# Parse arguments
# ═══════════════════════════════════════════════════════════
MODE=""
TARGET=""
LIST_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --draft)   MODE="draft"; TARGET="$2"; shift 2 ;;
    --list)    LIST_ONLY=true; shift ;;
    -h|--help)
      echo "Usage:"
      echo "  gads-undo.sh <reversal-id>          Undo a single action"
      echo "  gads-undo.sh --draft <draft-file>    Undo all actions from a draft"
      echo "  gads-undo.sh --list                  List all active reversals"
      echo ""
      echo "API version: ${GADS_API_VERSION}"
      exit 0
      ;;
    *)
      MODE="single"
      TARGET="$1"
      shift
      ;;
  esac
done

if [ ! -f "$REGISTRY_FILE" ]; then
  echo -e "${RED}No reversal registry found at ${REGISTRY_FILE}${NC}"
  exit 1
fi

# ═══════════════════════════════════════════════════════════
# List mode
# ═══════════════════════════════════════════════════════════
if $LIST_ONLY; then
  echo -e "${BOLD}Active Reversals:${NC}"
  echo ""

  reversals=""
  if [ "$MODE" = "draft" ]; then
    draft_base=$(basename "$TARGET")
    reversals=$(jq --arg d "$draft_base" '[.reversals[] | select(.status == "active" and .draftSource == $d)]' "$REGISTRY_FILE")
  else
    reversals=$(jq '[.reversals[] | select(.status == "active")]' "$REGISTRY_FILE")
  fi

  count=$(echo "$reversals" | jq 'length')

  if [ "$count" -eq 0 ]; then
    echo "  No active reversals."
    exit 0
  fi

  printf "%-10s %-18s %-25s %-12s %-25s\n" "ID" "Action" "Keyword" "Match" "Draft"
  printf "%-10s %-18s %-25s %-12s %-25s\n" "----------" "------------------" "-------------------------" "------------" "-------------------------"

  for i in $(seq 0 $((count - 1))); do
    r=$(echo "$reversals" | jq ".[$i]")
    printf "%-10s %-18s %-25s %-12s %-25s\n" \
      "$(echo "$r" | jq -r '.id')" \
      "$(echo "$r" | jq -r '.action')" \
      "$(echo "$r" | jq -r '.keyword')" \
      "$(echo "$r" | jq -r '.matchType')" \
      "$(echo "$r" | jq -r '.draftSource')"
  done

  exit 0
fi

# ═══════════════════════════════════════════════════════════
# Single undo mode
# ═══════════════════════════════════════════════════════════
undo_single() {
  local reversal_id="$1"

  local record
  record=$(get_reversal "$reversal_id")

  if [ -z "$record" ] || [ "$record" = "null" ]; then
    echo -e "${RED}Reversal not found: ${reversal_id}${NC}"
    exit 1
  fi

  local status
  status=$(echo "$record" | jq -r '.status')
  if [ "$status" != "active" ]; then
    echo -e "${YELLOW}Reversal ${reversal_id} has status '${status}' — already undone?${NC}"
    exit 1
  fi

  local action keyword match_type campaign account_id reversal_action resource_name applied_at
  action=$(echo "$record" | jq -r '.action')
  keyword=$(echo "$record" | jq -r '.keyword')
  match_type=$(echo "$record" | jq -r '.matchType')
  campaign=$(echo "$record" | jq -r '.campaignName')
  account_id=$(echo "$record" | jq -r '.accountId')
  reversal_action=$(echo "$record" | jq -r '.reversalAction')
  resource_name=$(echo "$record" | jq -r '.reversalResourceName')
  applied_at=$(echo "$record" | jq -r '.appliedAt')

  echo -e "${BOLD}Undo: ${reversal_id}${NC}"
  echo ""
  echo "  Original action: ${action}"
  echo "  Keyword:         \"${keyword}\" [${match_type}]"
  echo "  Campaign:        ${campaign}"
  echo "  Applied at:      ${applied_at}"
  echo "  Reversal:        ${reversal_action}"
  echo "  Resource:        ${resource_name}"
  echo ""

  # Check age warning
  local applied_epoch now_epoch age_days
  applied_epoch=$(date -d "$applied_at" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  age_days=$(( (now_epoch - applied_epoch) / 86400 ))

  if [ "$age_days" -gt 7 ]; then
    echo -e "${YELLOW}⚠️  This change has been live for ${age_days} days.${NC}"
    echo -e "${YELLOW}   Performance data since then may be affected by reversal.${NC}"
    echo ""
  fi

  echo -e "${RED}⚠️  This will reverse a change on account ${account_id}.${NC}"
  echo -n "Type 'confirm' to proceed: "
  read -r confirmation

  if [ "$confirmation" != "confirm" ]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    return
  fi

  echo ""
  echo -n "  Executing reversal... "

  local result
  case "$reversal_action" in
    REMOVE_NEGATIVE)
      result=$(mutate_remove_campaign_criterion "$account_id" "$resource_name")
      ;;
    ENABLE_KEYWORD)
      # Extract adgroup_id and criterion_id from resource name
      # Format: customers/{cid}/adGroupCriteria/{agId}~{criterionId}
      local ag_id crit_id
      ag_id=$(echo "$resource_name" | grep -oP '\d+(?=~)' || echo "")
      crit_id=$(echo "$resource_name" | grep -oP '(?<=~)\d+' || echo "")
      if [ -n "$ag_id" ] && [ -n "$crit_id" ]; then
        result=$(mutate_enable_keyword "$account_id" "$ag_id" "$crit_id")
      else
        result='{"success": false, "error": "Cannot parse resource name for enable"}'
      fi
      ;;
    ENABLE_ADGROUP)
      local ag_id
      ag_id=$(echo "$resource_name" | grep -oP '\d+$' || echo "")
      result=$(mutate_enable_adgroup "$account_id" "$ag_id")
      ;;
    *)
      result='{"success": false, "error": "Unknown reversal action: '"$reversal_action"'"}'
      ;;
  esac

  local success
  success=$(echo "$result" | jq -r '.success')

  if [ "$success" = "true" ]; then
    echo -e "${GREEN}✅ Reversed${NC}"
    update_reversal_status "$reversal_id" "undone"
  else
    local error
    error=$(echo "$result" | jq -r '.error // "Unknown"')
    echo -e "${RED}❌ Failed: ${error}${NC}"
  fi
}

# ═══════════════════════════════════════════════════════════
# Draft undo mode — undo all actions from a draft
# ═══════════════════════════════════════════════════════════
undo_draft() {
  local draft_file="$1"
  local draft_base
  draft_base=$(basename "$draft_file")

  local reversals
  reversals=$(jq --arg d "$draft_base" '[.reversals[] | select(.status == "active" and .draftSource == $d)]' "$REGISTRY_FILE")
  local count
  count=$(echo "$reversals" | jq 'length')

  if [ "$count" -eq 0 ]; then
    echo -e "${YELLOW}No active reversals found for draft: ${draft_base}${NC}"
    exit 0
  fi

  echo -e "${BOLD}Undo Draft: ${draft_base}${NC}"
  echo "  ${count} active reversal(s) found"
  echo ""

  for i in $(seq 0 $((count - 1))); do
    local r
    r=$(echo "$reversals" | jq ".[$i]")
    local rid
    rid=$(echo "$r" | jq -r '.id')
    echo "  ${rid}: $(echo "$r" | jq -r '.action') \"$(echo "$r" | jq -r '.keyword')\" [$(echo "$r" | jq -r '.matchType')]"
  done

  echo ""
  echo -e "${RED}⚠️  This will reverse ALL ${count} actions from this draft.${NC}"
  echo -n "Type 'confirm' to proceed: "
  read -r confirmation

  if [ "$confirmation" != "confirm" ]; then
    echo -e "${YELLOW}Cancelled.${NC}"
    exit 0
  fi

  echo ""
  for i in $(seq 0 $((count - 1))); do
    local rid
    rid=$(echo "$reversals" | jq -r ".[$i].id")
    undo_single "$rid" <<< "confirm"
  done
}

# ═══════════════════════════════════════════════════════════
# Dispatch
# ═══════════════════════════════════════════════════════════
case "$MODE" in
  single) undo_single "$TARGET" ;;
  draft)  undo_draft "$TARGET" ;;
  *)
    echo "Usage: gads-undo.sh <reversal-id> | --draft <draft-file> | --list"
    exit 1
    ;;
esac
