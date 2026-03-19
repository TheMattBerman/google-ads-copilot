#!/usr/bin/env bash
set -euo pipefail

# Google Ads Copilot — Negative Keyword Inventory
#
# Verifies whether negatives are running at campaign, ad-group, or shared-list level.
# Uses a retrieval ladder similar to search-term diagnostics and favors minimal field sets first.
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

# 3. Shared sets (minimal first)
SHARED_SET=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"shared_set\",fields:[\"shared_set.id\",\"shared_set.name\"],limit:100)" 2>&1 || true)
SHARED_SET_ROWS=$(printf '%s\n' "$SHARED_SET" | count_rows "shared_set.id")

echo "### Shared negative lists"
echo "Rows: $SHARED_SET_ROWS"
if [[ "$SHARED_SET_ROWS" -gt 0 ]]; then
  echo "$SHARED_SET"
else
  echo "None found."
fi
echo

# 4. Campaign-to-shared-set links
CAMPAIGN_SHARED=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign_shared_set\",fields:[\"campaign.name\",\"campaign_shared_set.shared_set\"],limit:100)" 2>&1 || true)
CAMPAIGN_SHARED_ROWS=$(printf '%s\n' "$CAMPAIGN_SHARED" | count_rows "campaign_shared_set.shared_set")

echo "### Campaign → shared-list attachments"
echo "Rows: $CAMPAIGN_SHARED_ROWS"
if [[ "$CAMPAIGN_SHARED_ROWS" -gt 0 ]]; then
  echo "$CAMPAIGN_SHARED"
else
  echo "None found."
fi
echo

# 5. Shared criteria / actual keywords in shared lists
SHARED_CRIT=$(call "google-ads-mcp.search(customer_id:\"$CID\",resource:\"shared_criterion\",fields:[\"shared_criterion.shared_set\",\"shared_criterion.keyword.text\"],limit:200)" 2>&1 || true)
SHARED_CRIT_ROWS=$(printf '%s\n' "$SHARED_CRIT" | count_rows "shared_criterion.keyword.text")

echo "### Shared-list keyword members"
echo "Rows: $SHARED_CRIT_ROWS"
if [[ "$SHARED_CRIT_ROWS" -gt 0 ]]; then
  echo "$SHARED_CRIT"
else
  echo "None found."
fi
echo

# Summary
echo "---"
echo
echo "## Negative Inventory Diagnostics"
echo "- Campaign negatives: $CAMPAIGN_NEG_ROWS"
echo "- Ad-group negatives: $ADGROUP_NEG_ROWS"
echo "- Shared negative lists: $SHARED_SET_ROWS"
echo "- Shared-list attachments: $CAMPAIGN_SHARED_ROWS"
echo "- Shared-list keyword members: $SHARED_CRIT_ROWS"

if [[ "$CAMPAIGN_NEG_ROWS" -eq 0 && "$ADGROUP_NEG_ROWS" -eq 0 && "$SHARED_CRIT_ROWS" -eq 0 ]]; then
  echo "- Verification result: No negatives found anywhere"
else
  echo "- Verification result: Negatives are active in the account"
fi
