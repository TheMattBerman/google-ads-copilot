#!/usr/bin/env bash
# gads-review.sh — Operator review: parse a draft and show what's in it
#
# Sits between "read the draft markdown" and "run gads-apply.sh".
# Shows a clean, operator-facing summary with action counts, risk levels,
# and a recommendation on whether to proceed.
#
# Usage:
#   ./gads-review.sh <draft-file>          # Review a single draft
#   ./gads-review.sh --all                 # Review all pending drafts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/config.sh"
source "$LIB_DIR/parse-draft.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

DRAFTS_DIR="${PROJECT_ROOT}/workspace/ads/drafts"

# ═══════════════════════════════════════════════════════════
# Parse arguments
# ═══════════════════════════════════════════════════════════
REVIEW_ALL=false
DRAFT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)     REVIEW_ALL=true; shift ;;
    -h|--help)
      echo "Usage: gads-review.sh <draft-file> | --all"
      echo ""
      echo "Review a draft or all pending drafts without applying anything."
      echo "Shows action counts, risk levels, and a proceed/defer recommendation."
      exit 0
      ;;
    *)
      DRAFT_FILE="$1"; shift ;;
  esac
done

# ═══════════════════════════════════════════════════════════
# Review a single draft
# ═══════════════════════════════════════════════════════════
review_draft() {
  local draft_file="$1"

  # Resolve relative paths
  if [[ "$draft_file" != /* ]]; then
    draft_file="${PROJECT_ROOT}/${draft_file}"
  fi

  if [ ! -f "$draft_file" ]; then
    echo -e "${RED}Draft not found: ${draft_file}${NC}"
    return 1
  fi

  local draft_name
  draft_name=$(basename "$draft_file")

  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD} Draft Review: ${draft_name}${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo ""

  # Parse the draft
  local parsed
  parsed=$(parse_draft "$draft_file" 2>/dev/null)

  if [ -z "$parsed" ]; then
    echo -e "${RED}Could not parse draft.${NC}"
    return 1
  fi

  local customer_id customer_name status action_count
  customer_id=$(echo "$parsed" | jq -r '.customer_id')
  customer_name=$(echo "$parsed" | jq -r '.customer_name')
  status=$(echo "$parsed" | jq -r '.status')
  action_count=$(echo "$parsed" | jq -r '.action_count')

  echo -e "  ${BOLD}Account:${NC}  ${customer_name} (${customer_id})"
  echo -e "  ${BOLD}Status:${NC}   ${status}"
  echo -e "  ${BOLD}Actions:${NC}  ${action_count}"
  echo ""

  # Count by type
  local neg_count pause_kw_count pause_ag_count
  neg_count=$(echo "$parsed" | jq '[.actions[] | select(.type == "ADD_NEGATIVE")] | length')
  pause_kw_count=$(echo "$parsed" | jq '[.actions[] | select(.type == "PAUSE_KEYWORD")] | length')
  pause_ag_count=$(echo "$parsed" | jq '[.actions[] | select(.type == "PAUSE_ADGROUP")] | length')

  echo -e "  ${CYAN}Action Breakdown:${NC}"
  [ "$neg_count" -gt 0 ] && echo -e "    📎 ${neg_count} negative keyword addition(s)  ${DIM}— Risk: Low${NC}"
  [ "$pause_kw_count" -gt 0 ] && echo -e "    ⏸️  ${pause_kw_count} keyword pause(s)              ${DIM}— Risk: Low${NC}"
  [ "$pause_ag_count" -gt 0 ] && echo -e "    ⏸️  ${pause_ag_count} ad group pause(s)             ${DIM}— Risk: Medium${NC}"
  echo ""

  # Show each action
  echo -e "  ${CYAN}Actions:${NC}"
  for i in $(seq 0 $((action_count - 1))); do
    local action action_type keyword match_type campaign adgroup reason
    action=$(echo "$parsed" | jq ".actions[$i]")
    action_type=$(echo "$action" | jq -r '.type')
    keyword=$(echo "$action" | jq -r '.keyword')
    match_type=$(echo "$action" | jq -r '.match_type')
    campaign=$(echo "$action" | jq -r '.campaign')
    adgroup=$(echo "$action" | jq -r '.adgroup // "-"')
    reason=$(echo "$action" | jq -r '.reason // ""')

    local icon=""
    case "$action_type" in
      ADD_NEGATIVE)    icon="📎" ;;
      PAUSE_KEYWORD)   icon="⏸️ " ;;
      PAUSE_ADGROUP)   icon="⏸️ " ;;
    esac

    printf "    %s %-3d %-16s \"%-25s [%s]\n" "$icon" "$((i + 1))" "$action_type" "${keyword}\"" "$match_type"
    if [ -n "$reason" ] && [ "$reason" != "null" ]; then
      echo -e "          ${DIM}${reason:0:80}${NC}"
    fi
  done
  echo ""

  # Extract confidence from the draft file
  local confidence
  confidence=$(grep -oP '^## Confidence\n\K.*' "$draft_file" 2>/dev/null || echo "")
  if [ -z "$confidence" ]; then
    confidence=$(sed -n '/^## Confidence/{n;p;}' "$draft_file" 2>/dev/null | head -c 80)
  fi

  if [ -n "$confidence" ]; then
    echo -e "  ${CYAN}Confidence:${NC} ${confidence}"
    echo ""
  fi

  # Extract dependencies
  local deps
  deps=$(sed -n '/^## Dependencies/{n;p;}' "$draft_file" 2>/dev/null | head -c 120)
  if [ -n "$deps" ]; then
    echo -e "  ${CYAN}Dependencies:${NC} ${deps}"
    echo ""
  fi

  # Recommendation
  echo -e "  ${CYAN}Assessment:${NC}"

  local risk_level="LOW"
  [ "$pause_ag_count" -gt 0 ] && risk_level="MEDIUM"

  case "$risk_level" in
    LOW)
      echo -e "    ${GREEN}✅ Low risk — all actions are easily reversible${NC}"
      echo -e "    ${GREEN}   Recommendation: safe to apply${NC}"
      ;;
    MEDIUM)
      echo -e "    ${YELLOW}⚠️  Medium risk — ad group pauses affect multiple keywords${NC}"
      echo -e "    ${YELLOW}   Recommendation: review each ad group pause carefully${NC}"
      ;;
  esac

  echo ""
  echo -e "  ${DIM}To apply:    gads-apply.sh ${draft_file}${NC}"
  echo -e "  ${DIM}To dry-run:  gads-apply.sh --dry-run ${draft_file}${NC}"
  echo ""
}

# ═══════════════════════════════════════════════════════════
# Review all pending drafts
# ═══════════════════════════════════════════════════════════
review_all() {
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD} Review All Pending Drafts${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo ""

  local found=0

  while IFS= read -r -d '' draft_file; do
    local draft_name
    draft_name=$(basename "$draft_file")
    [[ "$draft_name" == _* ]] && continue

    local status
    status=$(grep -oP '^Status: \K.*' "$draft_file" 2>/dev/null || echo "unknown")
    if [ "$status" = "proposed" ] || [ "$status" = "approved" ]; then
      found=$((found + 1))
      review_draft "$draft_file"
    fi
  done < <(find "$DRAFTS_DIR" -name "*.md" -print0 2>/dev/null | sort -z)

  if [ "$found" -eq 0 ]; then
    echo -e "  ${DIM}No pending drafts found.${NC}"
    echo ""
  else
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD} Total: ${found} pending draft(s)${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
  fi
}

# ═══════════════════════════════════════════════════════════
# Dispatch
# ═══════════════════════════════════════════════════════════
if $REVIEW_ALL; then
  review_all
elif [ -n "$DRAFT_FILE" ]; then
  review_draft "$DRAFT_FILE"
else
  echo "Usage: gads-review.sh <draft-file> | --all"
  exit 1
fi
