#!/usr/bin/env bash
set -euo pipefail

# Google Ads Copilot — Negative Keyword Inventory
#
# Verifies whether negatives are running at campaign, ad-group, or shared-list level.
# Uses a minimal shared-set discovery pass first, then upgrades to verified negative-list
# reporting only when shared_set.type is available.
#
# Usage:
#   source data/google-ads-mcp.test.env.sh
#   ./scripts/negative-inventory.sh <customer-id>

CID="${1:-}"
if [[ -z "$CID" ]]; then
  echo "Usage: $0 <customer-id>" >&2
  exit 1
fi

call() {
  mcporter call "$1"
}

count_rows() {
  local key="$1"
  python3 -c 'import re, sys; key=sys.argv[1]; text=sys.stdin.read(); print(len(re.findall(r"\"%s\":" % re.escape(key), text)))' "$key"
}

extract_field_values() {
  local key="$1"
  python3 -c 'import re, sys; key=sys.argv[1]; text=sys.stdin.read(); [print(m.group(2) if m.group(2) is not None else m.group(3)) for m in re.finditer(r"\"%s\":\s*(\"([^\"]*)\"|([0-9]+))" % re.escape(key), text)]' "$key"
}

echo "## Negative Inventory"
echo "- Customer ID: $CID"
echo

# 1. Campaign-level negatives
CAMPAIGN_NEG=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign_criterion\",fields:[\"campaign.name\",\"campaign_criterion.keyword.text\",\"campaign_criterion.keyword.match_type\",\"campaign_criterion.negative\"],conditions:[\"campaign_criterion.negative = TRUE\",\"campaign_criterion.type = 'KEYWORD'\"],limit:200)" 2>&1 || true)
CAMPAIGN_NEG_ROWS=$(printf '%s\n' "$CAMPAIGN_NEG" | count_rows "campaign_criterion.keyword.text")

echo "### Campaign-level negatives"
echo "Rows: $CAMPAIGN_NEG_ROWS"
if [[ "$CAMPAIGN_NEG_ROWS" -gt 0 ]]; then
  echo "$CAMPAIGN_NEG"
else
  echo "None found."
fi
echo

# 2. Ad-group-level negatives
ADGROUP_NEG=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"ad_group_criterion\",fields:[\"campaign.name\",\"ad_group.name\",\"ad_group_criterion.keyword.text\",\"ad_group_criterion.keyword.match_type\",\"ad_group_criterion.negative\"],conditions:[\"ad_group_criterion.negative = TRUE\",\"ad_group_criterion.type = 'KEYWORD'\"],limit:200)" 2>&1 || true)
ADGROUP_NEG_ROWS=$(printf '%s\n' "$ADGROUP_NEG" | count_rows "ad_group_criterion.keyword.text")

echo "### Ad-group-level negatives"
echo "Rows: $ADGROUP_NEG_ROWS"
if [[ "$ADGROUP_NEG_ROWS" -gt 0 ]]; then
  echo "$ADGROUP_NEG"
else
  echo "None found."
fi
echo

# 3. Shared sets (minimal discovery first)
SHARED_SET_MIN=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"shared_set\",fields:[\"shared_set.id\",\"shared_set.name\"],limit:100)" 2>&1 || true)
SHARED_SET_DISCOVERED_ROWS=$(printf '%s\n' "$SHARED_SET_MIN" | count_rows "shared_set.id")

echo "### Shared sets (minimal discovery)"
echo "Rows: $SHARED_SET_DISCOVERED_ROWS"
if [[ "$SHARED_SET_DISCOVERED_ROWS" -gt 0 ]]; then
  echo "$SHARED_SET_MIN"
else
  echo "None found."
fi
echo

# 4. Shared set type verification
SHARED_SET_TYPED=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"shared_set\",fields:[\"shared_set.resource_name\",\"shared_set.name\",\"shared_set.type\"],limit:100)" 2>&1 || true)
SHARED_SET_TYPE_VERIFIED=1
SHARED_SET_TYPE_NOTE="none"
SHARED_NEG_LIST_ROWS=0
CAMPAIGN_SHARED_ROWS=0
SHARED_CRIT_ROWS=0
declare -a NEG_SHARED_SET_RESOURCES=()
declare -a NEG_SHARED_SET_NAMES=()

if printf '%s\n' "$SHARED_SET_TYPED" | grep -qi "error"; then
  SHARED_SET_TYPE_VERIFIED=0
  SHARED_SET_TYPE_NOTE="Negative-list type could not be verified from shared_set."
fi

echo "### Shared-set type verification"
if [[ "$SHARED_SET_TYPE_VERIFIED" -eq 1 ]]; then
  SHARED_SET_RESOURCES=()
  while IFS= read -r value; do
    [[ -n "$value" ]] && SHARED_SET_RESOURCES+=("$value")
  done < <(printf '%s\n' "$SHARED_SET_TYPED" | extract_field_values "shared_set.resource_name")

  SHARED_SET_NAMES=()
  while IFS= read -r value; do
    [[ -n "$value" ]] && SHARED_SET_NAMES+=("$value")
  done < <(printf '%s\n' "$SHARED_SET_TYPED" | extract_field_values "shared_set.name")

  SHARED_SET_TYPES=()
  while IFS= read -r value; do
    [[ -n "$value" ]] && SHARED_SET_TYPES+=("$value")
  done < <(printf '%s\n' "$SHARED_SET_TYPED" | extract_field_values "shared_set.type")

  for i in "${!SHARED_SET_RESOURCES[@]}"; do
    [[ "${SHARED_SET_TYPES[$i]:-}" == "NEGATIVE_KEYWORDS" ]] || continue
    NEG_SHARED_SET_RESOURCES+=("${SHARED_SET_RESOURCES[$i]}")
    NEG_SHARED_SET_NAMES+=("${SHARED_SET_NAMES[$i]:-}")
  done

  SHARED_NEG_LIST_ROWS=${#NEG_SHARED_SET_RESOURCES[@]}
  echo "Verified negative keyword shared sets: $SHARED_NEG_LIST_ROWS"
  if [[ "$SHARED_NEG_LIST_ROWS" -gt 0 ]]; then
    for i in "${!NEG_SHARED_SET_RESOURCES[@]}"; do
      echo "- ${NEG_SHARED_SET_NAMES[$i]:-unnamed} (${NEG_SHARED_SET_RESOURCES[$i]})"
    done
  else
    echo "No verified negative keyword shared sets found."
  fi
else
  echo "$SHARED_SET_TYPE_NOTE"
  echo "$SHARED_SET_TYPED"
fi
echo

# 5. Campaign-to-shared-set links
if [[ "$SHARED_SET_TYPE_VERIFIED" -eq 1 ]]; then
  echo "### Campaign -> shared negative-list attachments"
  if [[ "$SHARED_NEG_LIST_ROWS" -gt 0 ]]; then
    for resource in "${NEG_SHARED_SET_RESOURCES[@]}"; do
      CAMPAIGN_SHARED=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign_shared_set\",fields:[\"campaign.name\",\"campaign_shared_set.shared_set\"],conditions:[\"campaign_shared_set.shared_set = '$resource'\"],limit:100)" 2>&1 || true)
      ROWS=$(printf '%s\n' "$CAMPAIGN_SHARED" | count_rows "campaign_shared_set.shared_set")
      CAMPAIGN_SHARED_ROWS=$((CAMPAIGN_SHARED_ROWS + ROWS))
      if [[ "$ROWS" -gt 0 ]]; then
        echo "$CAMPAIGN_SHARED"
      fi
    done
  fi

  echo "Rows: $CAMPAIGN_SHARED_ROWS"
  if [[ "$CAMPAIGN_SHARED_ROWS" -eq 0 ]]; then
    echo "None found."
  fi
  echo

  # 6. Shared criteria / actual keywords in verified negative shared lists
  echo "### Shared negative-list keyword members"
  if [[ "$SHARED_NEG_LIST_ROWS" -gt 0 ]]; then
    for resource in "${NEG_SHARED_SET_RESOURCES[@]}"; do
      SHARED_CRIT=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"shared_criterion\",fields:[\"shared_criterion.shared_set\",\"shared_criterion.keyword.text\",\"shared_criterion.keyword.match_type\"],conditions:[\"shared_criterion.shared_set = '$resource'\",\"shared_criterion.type = 'KEYWORD'\"],limit:200)" 2>&1 || true)
      # If the type filter errors, fall back to an unfiltered per-set query.
      if printf '%s\n' "$SHARED_CRIT" | grep -qi "error"; then
        SHARED_CRIT=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"shared_criterion\",fields:[\"shared_criterion.shared_set\",\"shared_criterion.keyword.text\"],conditions:[\"shared_criterion.shared_set = '$resource'\"],limit:200)" 2>&1 || true)
      fi
      ROWS=$(printf '%s\n' "$SHARED_CRIT" | count_rows "shared_criterion.keyword.text")
      SHARED_CRIT_ROWS=$((SHARED_CRIT_ROWS + ROWS))
      if [[ "$ROWS" -gt 0 ]]; then
        echo "$SHARED_CRIT"
      fi
    done
  fi

  echo "Rows: $SHARED_CRIT_ROWS"
  if [[ "$SHARED_CRIT_ROWS" -eq 0 ]]; then
    echo "None found."
  fi
else
  CAMPAIGN_SHARED=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign_shared_set\",fields:[\"campaign.name\",\"campaign_shared_set.shared_set\"],limit:100)" 2>&1 || true)
  CAMPAIGN_SHARED_ROWS=$(printf '%s\n' "$CAMPAIGN_SHARED" | count_rows "campaign_shared_set.shared_set")

  echo "### Campaign -> shared-set attachments (type unverified)"
  echo "Rows: $CAMPAIGN_SHARED_ROWS"
  if [[ "$CAMPAIGN_SHARED_ROWS" -gt 0 ]]; then
    echo "$CAMPAIGN_SHARED"
  else
    echo "None found."
  fi
  echo

  SHARED_CRIT=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"shared_criterion\",fields:[\"shared_criterion.shared_set\",\"shared_criterion.keyword.text\",\"shared_criterion.keyword.match_type\"],conditions:[\"shared_criterion.type = 'KEYWORD'\"],limit:200)" 2>&1 || true)
  # If the type filter errors, fall back to unfiltered (some MCP surfaces do not support it).
  if printf '%s\n' "$SHARED_CRIT" | grep -qi "error"; then
    SHARED_CRIT=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"shared_criterion\",fields:[\"shared_criterion.shared_set\",\"shared_criterion.keyword.text\"],limit:200)" 2>&1 || true)
  fi
  SHARED_CRIT_ROWS=$(printf '%s\n' "$SHARED_CRIT" | count_rows "shared_criterion.keyword.text")

  echo "### Shared-set keyword members (type unverified)"
  echo "Rows: $SHARED_CRIT_ROWS"
  if [[ "$SHARED_CRIT_ROWS" -gt 0 ]]; then
    echo "$SHARED_CRIT"
  else
    echo "None found."
  fi
fi
echo

# Summary
echo "---"
echo
echo "## Negative Inventory Diagnostics"
echo "- Campaign negatives: $CAMPAIGN_NEG_ROWS"
echo "- Ad-group negatives: $ADGROUP_NEG_ROWS"
echo "- Shared sets discovered: $SHARED_SET_DISCOVERED_ROWS"
if [[ "$SHARED_SET_TYPE_VERIFIED" -eq 1 ]]; then
  echo "- Shared negative lists: $SHARED_NEG_LIST_ROWS"
  echo "- Shared negative-list attachments: $CAMPAIGN_SHARED_ROWS"
  echo "- Shared negative-list keyword members: $SHARED_CRIT_ROWS"
else
  echo "- Shared-set type verification: unavailable"
  echo "- Shared-set attachments (type unverified): $CAMPAIGN_SHARED_ROWS"
  echo "- Shared-set keyword members (type unverified): $SHARED_CRIT_ROWS"
  echo "- Diagnostic note: $SHARED_SET_TYPE_NOTE"
fi

if [[ "$CAMPAIGN_NEG_ROWS" -gt 0 || "$ADGROUP_NEG_ROWS" -gt 0 || ( "$SHARED_SET_TYPE_VERIFIED" -eq 1 && "$SHARED_CRIT_ROWS" -gt 0 ) ]]; then
  echo "- Verification result: Negatives are active in the account"
elif [[ "$SHARED_SET_TYPE_VERIFIED" -eq 1 ]]; then
  echo "- Verification result: No negatives found anywhere"
else
  echo "- Verification result: Shared-set negatives could not be verified"
fi
