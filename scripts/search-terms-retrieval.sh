#!/usr/bin/env bash
set -euo pipefail

# Google Ads Copilot — Search Term Retrieval Ladder
#
# Shared retrieval subsystem for all search-term-dependent skills.
# Implements the ladder defined in data/search-term-retrieval.md.
#
# Usage:
#   source data/google-ads-mcp.test.env.sh
#   ./scripts/search-terms-retrieval.sh <customer-id> [date-condition]
#
# Examples:
#   ./scripts/search-terms-retrieval.sh 8468311086
#   ./scripts/search-terms-retrieval.sh 8468311086 "segments.date BETWEEN '2026-01-19' AND '2026-03-19'"
#
# Output: structured diagnostics + raw probe results per step.
# See data/search-term-retrieval.md for the full spec.

CID="${1:-}"
DATE_CONDITION="${2:-segments.date DURING LAST_30_DAYS}"

if [[ -z "$CID" ]]; then
  echo "Usage: $0 <customer-id> [date-condition]" >&2
  exit 1
fi

# --- helpers ---

call() {
  mcporter call "$1"
}

extract_field_values() {
  local key="$1"
  python3 -c 'import re, sys; key=sys.argv[1]; text=sys.stdin.read(); [print(m.group(2) if m.group(2) is not None else m.group(3)) for m in re.finditer(r"\"%s\":\\s*(\"([^\"]*)\"|([0-9]+))" % re.escape(key), text)]' "$key"
}

count_rows() {
  # Count occurrences of a key in MCP JSON output as a proxy for row count
  local key="$1"
  python3 -c 'import re, sys; key=sys.argv[1]; text=sys.stdin.read(); print(len(re.findall(r"\"%s\":" % re.escape(key), text)))' "$key"
}

has_field() {
  grep -q "\"$1\""
}

# --- query builders ---

query_account_wide() {
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"search_term_view\",fields:[\"search_term_view.search_term\",\"search_term_view.status\",\"campaign.name\",\"ad_group.name\",\"metrics.impressions\",\"metrics.clicks\",\"metrics.cost_micros\",\"metrics.conversions\",\"metrics.conversions_value\",\"metrics.cost_per_conversion\"],conditions:[\"$DATE_CONDITION\"],orderings:[\"metrics.cost_micros DESC\"],limit:500)"
}

query_search_only() {
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"search_term_view\",fields:[\"search_term_view.search_term\",\"search_term_view.status\",\"campaign.name\",\"ad_group.name\",\"metrics.impressions\",\"metrics.clicks\",\"metrics.cost_micros\",\"metrics.conversions\",\"metrics.conversions_value\",\"metrics.cost_per_conversion\"],conditions:[\"$DATE_CONDITION\",\"campaign.advertising_channel_type = 'SEARCH'\"],orderings:[\"metrics.cost_micros DESC\"],limit:500)"
}

query_campaigns() {
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign\",fields:[\"campaign.id\",\"campaign.name\",\"campaign.advertising_channel_type\",\"campaign.status\",\"metrics.cost_micros\",\"metrics.clicks\",\"metrics.conversions\"],conditions:[\"$DATE_CONDITION\"],orderings:[\"metrics.cost_micros DESC\"],limit:25)"
}

query_campaign_scoped_classic() {
  local campaign_name="$1"
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"search_term_view\",fields:[\"search_term_view.search_term\",\"campaign.name\",\"ad_group.name\",\"metrics.impressions\",\"metrics.clicks\",\"metrics.cost_micros\",\"metrics.conversions\"],conditions:[\"$DATE_CONDITION\",\"campaign.name = '$campaign_name'\"],orderings:[\"metrics.cost_micros DESC\"],limit:200)"
}

query_pmax_search_term_view() {
  local campaign_resource="$1"
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign_search_term_view\",fields:[\"campaign_search_term_view.search_term\",\"campaign_search_term_view.campaign\"],conditions:[\"campaign_search_term_view.campaign = '$campaign_resource'\",\"$DATE_CONDITION\"],limit:100)"
}

query_pmax_insight() {
  local campaign_id="$1"
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign_search_term_insight\",fields:[\"campaign_search_term_insight.category_label\",\"campaign_search_term_insight.id\",\"campaign_search_term_insight.campaign_id\"],conditions:[\"campaign_search_term_insight.campaign_id = $campaign_id\",\"$DATE_CONDITION\"],limit:100)"
}

# --- diagnostics state ---

RETRIEVAL_MODE="limited"
TOTAL_ROWS=0
CAMPAIGNS_TOTAL=0
CAMPAIGNS_SEARCH=0
CAMPAIGNS_PMAX=0
CAMPAIGNS_OTHER=0
SEARCH_WITH_ROWS=""
PMAX_WITH_ROWS=""
PMAX_WITHOUT_ROWS=""
VISIBILITY_NOTES=""

# --- ladder execution ---

echo "## Search Term Retrieval Ladder"
echo "- Customer ID: $CID"
echo "- Date condition: $DATE_CONDITION"
echo

# Step 1: Account-wide search_term_view
echo "### Step 1 — Account-wide search_term_view"
STEP1_OUT=$(call "$(query_account_wide)" 2>&1 || true)
STEP1_ROWS=$(printf '%s\n' "$STEP1_OUT" | count_rows "search_term_view.search_term")
echo "Rows: $STEP1_ROWS"

if [[ "$STEP1_ROWS" -gt 0 ]]; then
  RETRIEVAL_MODE="classic"
  TOTAL_ROWS=$STEP1_ROWS
  echo "Result: classic mode succeeded at account scope."
  echo
  echo "$STEP1_OUT"
  echo
else
  echo "Result: no rows. Proceeding to Step 2."
  echo
fi

# Step 2: Search-only search_term_view
if [[ "$RETRIEVAL_MODE" == "limited" ]]; then
  echo "### Step 2 — Search-only search_term_view"
  STEP2_OUT=$(call "$(query_search_only)" 2>&1 || true)
  STEP2_ROWS=$(printf '%s\n' "$STEP2_OUT" | count_rows "search_term_view.search_term")
  echo "Rows: $STEP2_ROWS"

  if [[ "$STEP2_ROWS" -gt 0 ]]; then
    RETRIEVAL_MODE="classic-search-only"
    TOTAL_ROWS=$STEP2_ROWS
    echo "Result: classic-search-only mode succeeded."
    echo
    echo "$STEP2_OUT"
    echo
  else
    echo "Result: no rows. Proceeding to Step 3."
    echo
  fi
fi

# Step 3: Campaign enumeration
if [[ "$RETRIEVAL_MODE" == "limited" ]]; then
  echo "### Step 3 — Campaign enumeration"
  CAMPAIGNS_OUT=$(call "$(query_campaigns)" 2>&1 || true)

  mapfile -t IDS < <(printf '%s\n' "$CAMPAIGNS_OUT" | extract_field_values "campaign.id")
  mapfile -t NAMES < <(printf '%s\n' "$CAMPAIGNS_OUT" | extract_field_values "campaign.name")
  mapfile -t TYPES < <(printf '%s\n' "$CAMPAIGNS_OUT" | extract_field_values "campaign.advertising_channel_type")

  CAMPAIGNS_TOTAL=${#IDS[@]}

  for i in "${!IDS[@]}"; do
    type="${TYPES[$i]:-}"
    case "$type" in
      2)  ((CAMPAIGNS_SEARCH++)) || true ;;
      10) ((CAMPAIGNS_PMAX++)) || true ;;
      *)  ((CAMPAIGNS_OTHER++)) || true ;;
    esac
  done

  echo "- Total: $CAMPAIGNS_TOTAL"
  echo "- Search: $CAMPAIGNS_SEARCH"
  echo "- PMax: $CAMPAIGNS_PMAX"
  echo "- Other: $CAMPAIGNS_OTHER"
  echo

  if [[ "$CAMPAIGNS_TOTAL" -eq 0 ]]; then
    RETRIEVAL_MODE="limited"
    VISIBILITY_NOTES="No campaigns surfaced for the period."
    echo "Result: no campaigns found. Limited visibility."
    echo
  fi
fi

# Step 4: Campaign-scoped classic retrieval (Search campaigns)
if [[ "$RETRIEVAL_MODE" == "limited" && "$CAMPAIGNS_SEARCH" -gt 0 ]]; then
  echo "### Step 4 — Campaign-scoped classic retrieval (Search campaigns)"
  STEP4_FOUND=0

  for i in "${!IDS[@]}"; do
    type="${TYPES[$i]:-}"
    name="${NAMES[$i]:-}"
    [[ "$type" == "2" ]] || continue

    echo "#### $name (Search)"
    OUT=$(call "$(query_campaign_scoped_classic "$name")" 2>&1 || true)
    ROWS=$(printf '%s\n' "$OUT" | count_rows "search_term_view.search_term")
    echo "Rows: $ROWS"

    if [[ "$ROWS" -gt 0 ]]; then
      STEP4_FOUND=1
      TOTAL_ROWS=$((TOTAL_ROWS + ROWS))
      SEARCH_WITH_ROWS="${SEARCH_WITH_ROWS:+$SEARCH_WITH_ROWS, }$name"
      echo "$OUT"
    else
      echo "No rows for this campaign."
    fi
    echo
  done

  if [[ "$STEP4_FOUND" -eq 1 ]]; then
    RETRIEVAL_MODE="classic-campaign-scoped"
  fi
fi

# Step 5: PMax campaign-scoped retrieval
if [[ "$CAMPAIGNS_PMAX" -gt 0 ]]; then
  # Run PMax probes regardless — they add rows even if classic already succeeded
  PMAX_LABEL="Step 5"
  [[ "$RETRIEVAL_MODE" != "limited" ]] && PMAX_LABEL="Step 5 (supplementary)"

  echo "### $PMAX_LABEL — PMax campaign-scoped retrieval"
  STEP5_FOUND=0

  for i in "${!IDS[@]}"; do
    type="${TYPES[$i]:-}"
    id="${IDS[$i]}"
    name="${NAMES[$i]:-}"
    [[ "$type" == "10" ]] || continue

    RESOURCE="customers/$CID/campaigns/$id"

    echo "#### $name (PMax)"

    # 5a: campaign_search_term_view
    echo "##### campaign_search_term_view"
    OUT=$(call "$(query_pmax_search_term_view "$RESOURCE")" 2>&1 || true)
    ROWS=$(printf '%s\n' "$OUT" | count_rows "campaign_search_term_view.search_term")
    echo "Rows: $ROWS"

    if [[ "$ROWS" -gt 0 ]]; then
      STEP5_FOUND=1
      TOTAL_ROWS=$((TOTAL_ROWS + ROWS))
      PMAX_WITH_ROWS="${PMAX_WITH_ROWS:+$PMAX_WITH_ROWS, }$name"
      echo "$OUT"
    else
      PMAX_WITHOUT_ROWS="${PMAX_WITHOUT_ROWS:+$PMAX_WITHOUT_ROWS, }$name"
      echo "No rows."
    fi

    # 5b: campaign_search_term_insight
    echo "##### campaign_search_term_insight"
    INSIGHT=$(call "$(query_pmax_insight "$id")" 2>&1 || true)
    INSIGHT_ROWS=$(printf '%s\n' "$INSIGHT" | count_rows "campaign_search_term_insight.category_label")
    echo "Insight rows: $INSIGHT_ROWS"
    if [[ "$INSIGHT_ROWS" -gt 0 ]]; then
      echo "$INSIGHT"
    else
      echo "No insight rows (common for newer PMax campaigns)."
    fi
    echo
  done

  # If classic modes didn't succeed but PMax did, set pmax-fallback
  if [[ "$RETRIEVAL_MODE" == "limited" && "$STEP5_FOUND" -eq 1 ]]; then
    RETRIEVAL_MODE="pmax-fallback"
    VISIBILITY_NOTES="PMax rows are query text only — no per-term cost/CPA/conversion metrics."
  fi
fi

# --- diagnostic summary ---

echo "---"
echo
echo "## Search Term Retrieval Diagnostics"
echo "- Customer ID: $CID"
echo "- Date range: $DATE_CONDITION"
echo "- Retrieval mode: $RETRIEVAL_MODE"
echo "- Rows returned: $TOTAL_ROWS"
echo "- Campaigns probed: $CAMPAIGNS_TOTAL total, $CAMPAIGNS_SEARCH Search, $CAMPAIGNS_PMAX PMax, $CAMPAIGNS_OTHER other"
echo "- Search campaigns with rows: ${SEARCH_WITH_ROWS:-none}"
echo "- PMax campaigns with rows: ${PMAX_WITH_ROWS:-none}"
echo "- PMax campaigns without rows: ${PMAX_WITHOUT_ROWS:-none}"
echo "- Visibility notes: ${VISIBILITY_NOTES:-none}"
echo

case "$RETRIEVAL_MODE" in
  classic|classic-search-only)
    echo "## Operator Guidance"
    echo "Full per-term metrics available. All search-term-dependent skills can run at full confidence."
    ;;
  classic-campaign-scoped)
    echo "## Operator Guidance"
    echo "Per-term metrics available at campaign scope. Cross-campaign patterns may be incomplete."
    ;;
  pmax-fallback)
    echo "## Operator Guidance"
    echo "PMax query rows available as language signal. Per-term cost/CPA/conversion metrics are NOT available."
    echo "- Negatives: only recommend for extremely obvious junk terms."
    echo "- Intent map: use rows for clustering, but performance profiling is unavailable."
    echo "- RSAs: use rows for buyer-language extraction only."
    echo "- Audit: mark search-term sections as 'PMax visibility-limited'."
    ;;
  limited)
    echo "## Operator Guidance"
    echo "Insufficient search-term visibility for the period."
    echo "- Shift to campaign / asset-group / tracking analysis."
    echo "- Request a UI export from the Google Ads interface for exact waste attribution."
    echo "- Do not fabricate search-term conclusions from absent data."
    ;;
esac
