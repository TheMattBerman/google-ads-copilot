#!/usr/bin/env bash
# gads-status.sh — Show current operator state at a glance
#
# Answers: What's connected? What's been applied? What's pending? What can be undone?
#
# Usage:
#   ./gads-status.sh                    # Full status overview
#   ./gads-status.sh --applied          # Show only applied actions
#   ./gads-status.sh --pending          # Show only pending drafts
#   ./gads-status.sh --reversals        # Show only active reversals

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/config.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

AUDIT_DIR="${PROJECT_ROOT}/workspace/ads/audit-trail"
DRAFTS_DIR="${PROJECT_ROOT}/workspace/ads/drafts"
REGISTRY_FILE="${AUDIT_DIR}/reversal-registry.json"
ACCOUNT_FILE="${PROJECT_ROOT}/workspace/ads/account.md"
LOG_FILE="${AUDIT_DIR}/_log.md"

# ═══════════════════════════════════════════════════════════
# Parse arguments
# ═══════════════════════════════════════════════════════════
SHOW_ALL=true
SHOW_APPLIED=false
SHOW_PENDING=false
SHOW_REVERSALS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --applied)    SHOW_ALL=false; SHOW_APPLIED=true; shift ;;
    --pending)    SHOW_ALL=false; SHOW_PENDING=true; shift ;;
    --reversals)  SHOW_ALL=false; SHOW_REVERSALS=true; shift ;;
    -h|--help)
      echo "Usage: gads-status.sh [--applied|--pending|--reversals]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ═══════════════════════════════════════════════════════════
# Header
# ═══════════════════════════════════════════════════════════
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD} Google Ads Copilot — Operator Status${NC}"
echo -e "${BOLD} $(date '+%Y-%m-%d %H:%M %Z')${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# Section 1: Connection & Account
# ═══════════════════════════════════════════════════════════
if $SHOW_ALL; then
  echo -e "${CYAN}┌─ CONNECTION ────────────────────────────────────────────┐${NC}"

  # Check account file
  if [ -f "$ACCOUNT_FILE" ]; then
    account_name=$(gads_markdown_field "$ACCOUNT_FILE" "Descriptive Name")
    [ -z "$account_name" ] && account_name=$(gads_markdown_field "$ACCOUNT_FILE" "Name")
    [ -z "$account_name" ] && account_name="Unknown"
    account_id=$(gads_markdown_field "$ACCOUNT_FILE" "Customer ID")
    [ -z "$account_id" ] && account_id="Unknown"
    last_verified=$(gads_markdown_field "$ACCOUNT_FILE" "Last verified")
    [ -z "$last_verified" ] && last_verified="Unknown"
    echo -e "│  Account:   ${GREEN}${account_name}${NC} (${account_id})"
    echo -e "│  Verified:  ${last_verified}"
  else
    echo -e "│  Account:   ${RED}Not connected${NC}"
    echo -e "│  Run:       /google-ads connect setup"
  fi

  # Check API config
  if [ -n "${GOOGLE_ADS_DEVELOPER_TOKEN:-}" ]; then
    echo -e "│  Dev Token: ${GREEN}Set${NC}"
  else
    echo -e "│  Dev Token: ${RED}Missing${NC}"
  fi

  if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    echo -e "│  OAuth:     ${GREEN}Configured${NC}"
  else
    echo -e "│  OAuth:     ${RED}Missing${NC}"
  fi

  echo -e "│  API:       v${GADS_API_VERSION}"
  echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
  echo ""
fi

# ═══════════════════════════════════════════════════════════
# Section 2: Pending Drafts
# ═══════════════════════════════════════════════════════════
if $SHOW_ALL || $SHOW_PENDING; then
  echo -e "${CYAN}┌─ PENDING DRAFTS ───────────────────────────────────────┐${NC}"

  if [ -d "$DRAFTS_DIR" ]; then
    pending_count=0
    while IFS= read -r -d '' draft_file; do
      draft_name=$(basename "$draft_file")
      # Skip index/summary files
      [[ "$draft_name" == _* ]] && continue

      status=$(awk 'index($0, "Status: ") == 1 { print substr($0, 9); exit }' "$draft_file")
      [ -z "$status" ] && status="unknown"
      if [ "$status" = "proposed" ] || [ "$status" = "approved" ]; then
        pending_count=$((pending_count + 1))

        # Extract summary line
        summary=$(gads_heading_body_line "$draft_file" "## Summary" | head -c 80)

        status_icon="📋"
        [ "$status" = "approved" ] && status_icon="✅"

        echo -e "│  ${status_icon} ${BOLD}${draft_name}${NC}"
        echo -e "│     Status: ${status}"
        if [ -n "$summary" ]; then
          echo -e "│     ${DIM}${summary:0:70}${NC}"
        fi
      fi
    done < <(find "$DRAFTS_DIR" -name "*.md" -print0 2>/dev/null)

    if [ "$pending_count" -eq 0 ]; then
      echo -e "│  ${DIM}No pending drafts${NC}"
    else
      echo -e "│"
      echo -e "│  ${BOLD}Total pending: ${pending_count}${NC}"
    fi
  else
    echo -e "│  ${DIM}No drafts directory${NC}"
  fi

  echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
  echo ""
fi

# ═══════════════════════════════════════════════════════════
# Section 3: Applied Actions (Active Reversals)
# ═══════════════════════════════════════════════════════════
if $SHOW_ALL || $SHOW_APPLIED || $SHOW_REVERSALS; then
  echo -e "${CYAN}┌─ APPLIED ACTIONS (REVERSIBLE) ─────────────────────────┐${NC}"

  if [ -f "$REGISTRY_FILE" ]; then
    active_count=$(jq '[.reversals[] | select(.status == "active")] | length' "$REGISTRY_FILE" 2>/dev/null || echo 0)
    undone_count=$(jq '[.reversals[] | select(.status == "undone")] | length' "$REGISTRY_FILE" 2>/dev/null || echo 0)
    total_count=$(jq '.reversals | length' "$REGISTRY_FILE" 2>/dev/null || echo 0)

    if [ "$active_count" -gt 0 ]; then
      echo -e "│  ${GREEN}Active: ${active_count}${NC}  │  ${DIM}Undone: ${undone_count}${NC}  │  Total: ${total_count}"
      echo -e "│"

      # Show active reversals grouped by draft
      jq -r '[.reversals[] | select(.status == "active")] | group_by(.draftSource) | .[] | .[0].draftSource + "|" + (length | tostring)' "$REGISTRY_FILE" 2>/dev/null | while IFS='|' read -r draft count; do
        echo -e "│  📎 ${BOLD}${draft}${NC} — ${count} active action(s)"

        # Show first few actions from this draft
        jq -r --arg d "$draft" '[.reversals[] | select(.status == "active" and .draftSource == $d)] | .[:5][] | "│     " + .id + "  " + .action + " \"" + .keyword + "\" [" + .matchType + "]"' "$REGISTRY_FILE" 2>/dev/null

        remaining=$(jq --arg d "$draft" '[.reversals[] | select(.status == "active" and .draftSource == $d)] | length - 5' "$REGISTRY_FILE" 2>/dev/null || echo 0)
        if [ "$remaining" -gt 0 ]; then
          echo -e "│     ${DIM}... and ${remaining} more${NC}"
        fi
      done

      echo -e "│"
      echo -e "│  Undo one:  ${DIM}gads-undo.sh <rev-ID>${NC}"
      echo -e "│  Undo all:  ${DIM}gads-undo.sh --draft <file>${NC}"
      echo -e "│  List all:  ${DIM}gads-undo.sh --list${NC}"
    else
      echo -e "│  ${DIM}No active reversals (${undone_count} undone, ${total_count} total)${NC}"
    fi
  else
    echo -e "│  ${DIM}No apply sessions yet${NC}"
  fi

  echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
  echo ""
fi

# ═══════════════════════════════════════════════════════════
# Section 4: Recent Apply Sessions
# ═══════════════════════════════════════════════════════════
if $SHOW_ALL || $SHOW_APPLIED; then
  echo -e "${CYAN}┌─ RECENT APPLY SESSIONS ───────────────────────────────┐${NC}"

  if [ -f "$LOG_FILE" ]; then
    # Count session headers
    session_count=$(grep -c '^## .* — Apply Session' "$LOG_FILE" 2>/dev/null || echo 0)

    if [ "$session_count" -gt 0 ]; then
      echo -e "│  Total sessions: ${session_count}"
      echo -e "│"

      # Show last 5 sessions (headers only)
      grep '^## .* — Apply Session' "$LOG_FILE" | tail -5 | while read -r line; do
        echo -e "│  📝 ${line#\#\# }"
      done

      echo -e "│"
      echo -e "│  Full log: ${DIM}workspace/ads/audit-trail/_log.md${NC}"
    else
      echo -e "│  ${DIM}No apply sessions recorded${NC}"
    fi
  else
    echo -e "│  ${DIM}No audit trail yet${NC}"
  fi

  echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
  echo ""
fi

# ═══════════════════════════════════════════════════════════
# Section 5: What to Do Next
# ═══════════════════════════════════════════════════════════
if $SHOW_ALL; then
  echo -e "${CYAN}┌─ SUGGESTED NEXT STEP ─────────────────────────────────┐${NC}"

  # Determine next action based on state
  if [ ! -f "$ACCOUNT_FILE" ]; then
    echo -e "│  → Run ${BOLD}/google-ads connect setup${NC} to connect an account"
  elif [ -f "$DRAFTS_DIR/_summary.md" ]; then
    # Check for quick-apply candidates
    quick_count=$(grep -c 'Quick-apply candidate' "$DRAFTS_DIR/_summary.md" 2>/dev/null || echo 0)
    if [ "$quick_count" -gt 0 ]; then
      echo -e "│  → ${GREEN}Quick-apply candidates available!${NC}"
      echo -e "│    Review: ${DIM}/google-ads draft-summary${NC}"
      echo -e "│    Apply:  ${DIM}/google-ads apply <draft-file>${NC}"
    else
      echo -e "│  → Review pending drafts: ${DIM}/google-ads draft-summary${NC}"
    fi
  elif [ -d "$DRAFTS_DIR" ] && [ "$(find "$DRAFTS_DIR" -name "*.md" ! -name "_*" 2>/dev/null | wc -l)" -gt 0 ]; then
    echo -e "│  → Generate summary: ${DIM}/google-ads draft-summary${NC}"
  else
    echo -e "│  → Run an audit: ${DIM}/google-ads audit${NC} or ${DIM}/google-ads daily${NC}"
  fi

  echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
fi
