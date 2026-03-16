#!/usr/bin/env bash
# audit-write.sh — Write audit trail entries for apply sessions
#
# Usage:
#   source lib/audit-write.sh
#   init_apply_session "$draft_file" "$customer_id" "$customer_name" "$action_count"
#   log_action_result "$index" "$action_type" "$target" "$detail" "$status" "$reversal_id" "$resource_name"
#   finalize_apply_session "$succeeded" "$failed"
#   add_reversal_record <json_record>
#
# Writes to:
#   workspace/ads/audit-trail/_log.md
#   workspace/ads/audit-trail/YYYY-MM-DD-apply-session.md
#   workspace/ads/audit-trail/reversal-registry.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../../.."
AUDIT_DIR="${PROJECT_ROOT}/workspace/ads/audit-trail"
LOG_FILE="${AUDIT_DIR}/_log.md"
REGISTRY_FILE="${AUDIT_DIR}/reversal-registry.json"

# Session state
_SESSION_DATE=""
_SESSION_FILE=""
_SESSION_TABLE_ROWS=""

# Initialize audit trail directories
_ensure_audit_dir() {
  mkdir -p "$AUDIT_DIR"

  if [ ! -f "$LOG_FILE" ]; then
    cat > "$LOG_FILE" << 'EOF'
# Apply Layer — Audit Trail

---

EOF
  fi

  if [ ! -f "$REGISTRY_FILE" ]; then
    cat > "$REGISTRY_FILE" << 'EOF'
{
  "version": "1.0",
  "description": "Registry of all applied actions and their reversal instructions.",
  "reversals": []
}
EOF
  fi
}

# Start a new apply session
init_apply_session() {
  local draft_file="$1"
  local customer_id="$2"
  local customer_name="$3"
  local action_count="$4"

  _ensure_audit_dir

  _SESSION_DATE=$(date +%Y-%m-%d)
  local session_time
  session_time=$(date +%H:%M)

  _SESSION_FILE="${AUDIT_DIR}/${_SESSION_DATE}-apply-session.md"
  _SESSION_TABLE_ROWS=""

  # Write session detail header
  cat >> "$_SESSION_FILE" << EOF

---

## Apply Session — ${_SESSION_DATE} ${session_time}

**Operator:** Matt
**Draft:** $(basename "$draft_file")
**Account:** ${customer_name} (${customer_id})
**Actions planned:** ${action_count}
**Started:** $(date -Iseconds)

### Dry Run Displayed
(Operator confirmed before execution)

### Action Results

| # | Action | Target | Detail | Status | Reversal ID |
|---|--------|--------|--------|--------|-------------|
EOF

  # Start the log entry (will be completed in finalize)
  echo "" >> "$LOG_FILE"
  echo "## ${_SESSION_DATE} ${session_time} — Apply Session" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  echo "**Operator:** Matt" >> "$LOG_FILE"
  echo "**Draft:** $(basename "$draft_file")" >> "$LOG_FILE"
  echo "**Account:** ${customer_name} (${customer_id})" >> "$LOG_FILE"
}

# Log a single action result
log_action_result() {
  local index="$1"
  local action_type="$2"
  local target="$3"
  local detail="$4"
  local status="$5"          # ✅ Applied / ❌ Failed / ⏭️ Skipped
  local reversal_id="$6"
  local resource_name="${7:-}"

  # Append to session detail file
  echo "| ${index} | ${action_type} | ${target} | ${detail} | ${status} | ${reversal_id} |" >> "$_SESSION_FILE"

  # Accumulate for master log
  _SESSION_TABLE_ROWS="${_SESSION_TABLE_ROWS}| ${index} | ${action_type} | ${target} | ${status} | ${reversal_id} |
"
}

# Finalize the apply session
finalize_apply_session() {
  local succeeded="$1"
  local failed="$2"

  local total=$((succeeded + failed))

  # Complete session detail file
  cat >> "$_SESSION_FILE" << EOF

### Summary
- **Succeeded:** ${succeeded}/${total}
- **Failed:** ${failed}/${total}
- **Completed:** $(date -Iseconds)

EOF

  # Complete master log entry
  echo "**Actions:** ${succeeded}/${total} succeeded, ${failed} failed" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  echo "| # | Action | Target | Status | Reversal ID |" >> "$LOG_FILE"
  echo "|---|--------|--------|--------|-------------|" >> "$LOG_FILE"
  echo -n "$_SESSION_TABLE_ROWS" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  echo "---" >> "$LOG_FILE"
}

# Add a reversal record to the registry
add_reversal_record() {
  local record_json="$1"

  # Read current registry, add the new record, write back
  local updated
  updated=$(jq --argjson new "$record_json" '.reversals += [$new]' "$REGISTRY_FILE")
  echo "$updated" > "$REGISTRY_FILE"
}

# Generate a reversal ID (rev-NNN based on current count)
next_reversal_id() {
  local current_count
  current_count=$(jq '.reversals | length' "$REGISTRY_FILE" 2>/dev/null || echo 0)
  printf "rev-%03d" $((current_count + 1))
}

# Look up a reversal record by ID
get_reversal() {
  local reversal_id="$1"
  jq --arg id "$reversal_id" '.reversals[] | select(.id == $id)' "$REGISTRY_FILE"
}

# Update reversal status (e.g., mark as undone)
update_reversal_status() {
  local reversal_id="$1"
  local new_status="$2"  # "undone"
  local undone_at
  undone_at=$(date -Iseconds)

  local updated
  updated=$(jq --arg id "$reversal_id" --arg status "$new_status" --arg at "$undone_at" \
    '(.reversals[] | select(.id == $id)) |= . + {status: $status, undoneAt: $at}' \
    "$REGISTRY_FILE")
  echo "$updated" > "$REGISTRY_FILE"
}

# Get all active reversals for a draft file
get_draft_reversals() {
  local draft_file="$1"
  local basename
  basename=$(basename "$draft_file")

  jq --arg draft "$basename" \
    '[.reversals[] | select(.draftSource == $draft and .status == "active")]' \
    "$REGISTRY_FILE"
}
