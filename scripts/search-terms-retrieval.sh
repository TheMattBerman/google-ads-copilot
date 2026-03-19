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
# Output: structured diagnostics + raw probe results per step.
# See data/search-term-retrieval.md for the full spec.

CID="${1:-}"
DATE_CONDITION="${2:-}"
MIN_SPEND_MICROS=5000000

if [[ -z "$CID" ]]; then
  echo "Usage: $0 <customer-id> [date-condition]" >&2
  exit 1
fi

# --- date fallback chain ---
# If no explicit date condition, try progressively wider windows.
DATE_FALLBACK_CHAIN=(
  "segments.date DURING LAST_30_DAYS"
  "segments.date DURING LAST_14_DAYS"
)
# Note: LAST_90_DAYS and LAST_12_MONTHS are NOT valid GAQL DURING literals.
# We use explicit BETWEEN ranges instead.
TODAY=$(date +%Y-%m-%d)
D90=$(date -d "90 days ago" +%Y-%m-%d 2>/dev/null || date -v-90d +%Y-%m-%d 2>/dev/null || echo "")
D365=$(date -d "365 days ago" +%Y-%m-%d 2>/dev/null || date -v-365d +%Y-%m-%d 2>/dev/null || echo "")
[[ -n "$D90" ]] && DATE_FALLBACK_CHAIN+=("segments.date BETWEEN '$D90' AND '$TODAY'")
[[ -n "$D365" ]] && DATE_FALLBACK_CHAIN+=("segments.date BETWEEN '$D365' AND '$TODAY'")

# If user provided an explicit date condition, use only that (no fallback).
if [[ -n "$DATE_CONDITION" ]]; then
  DATE_FALLBACK_CHAIN=("$DATE_CONDITION")
fi

# --- helpers ---

call() {
  mcporter call "$1"
}

extract_field_values() {
  local key="$1"
  python3 -c 'import re, sys; key=sys.argv[1]; text=sys.stdin.read(); [print(m.group(2) if m.group(2) is not None else m.group(3)) for m in re.finditer(r"\"%s\":\s*(\"([^\"]*)\"|([0-9]+))" % re.escape(key), text)]' "$key"
}

count_rows() {
  local key="$1"
  python3 -c 'import re, sys; key=sys.argv[1]; text=sys.stdin.read(); print(len(re.findall(r"\"%s\":" % re.escape(key), text)))' "$key"
}

sum_numeric_field() {
  local key="$1"
  python3 -c 'import re, sys; key=sys.argv[1]; text=sys.stdin.read(); print(sum(int(m.group(1)) for m in re.finditer(r"\"%s\":\s*([0-9]+)" % re.escape(key), text)))' "$key"
}

format_micros_as_dollars() {
  local micros="${1:-0}"
  python3 -c 'import sys; micros=int(sys.argv[1]); print(f"${micros / 1_000_000:.2f}")' "$micros"
}

classify_campaign_type() {
  # Handle both numeric (2, 10) and string (SEARCH, PERFORMANCE_MAX) enum values
  local t="$1"
  case "$t" in
    2|SEARCH)           echo "search" ;;
    10|PERFORMANCE_MAX) echo "pmax" ;;
    *)                  echo "other" ;;
  esac
}

# --- query builders ---

query_account_wide() {
  local dc="$1"
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"search_term_view\",fields:[\"search_term_view.search_term\",\"search_term_view.status\",\"campaign.name\",\"ad_group.name\",\"metrics.impressions\",\"metrics.clicks\",\"metrics.cost_micros\",\"metrics.conversions\",\"metrics.conversions_value\",\"metrics.cost_per_conversion\"],conditions:[\"$dc\"],orderings:[\"metrics.cost_micros DESC\"],limit:500)"
}

query_search_only() {
  local dc="$1"
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"search_term_view\",fields:[\"search_term_view.search_term\",\"search_term_view.status\",\"campaign.name\",\"ad_group.name\",\"metrics.impressions\",\"metrics.clicks\",\"metrics.cost_micros\",\"metrics.conversions\",\"metrics.conversions_value\",\"metrics.cost_per_conversion\"],conditions:[\"$dc\",\"campaign.advertising_channel_type = 'SEARCH'\"],orderings:[\"metrics.cost_micros DESC\"],limit:500)"
}

query_campaigns() {
  local dc="$1"
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign\",fields:[\"campaign.id\",\"campaign.name\",\"campaign.advertising_channel_type\",\"campaign.status\",\"metrics.cost_micros\",\"metrics.clicks\",\"metrics.conversions\"],conditions:[\"$dc\"],orderings:[\"metrics.cost_micros DESC\"],limit:25)"
}

query_campaign_scoped_classic() {
  local dc="$1"
  local campaign_id="$2"
  local campaign_resource="customers/$CID/campaigns/$campaign_id"
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"search_term_view\",fields:[\"search_term_view.search_term\",\"campaign.name\",\"ad_group.name\",\"metrics.impressions\",\"metrics.clicks\",\"metrics.cost_micros\",\"metrics.conversions\"],conditions:[\"$dc\",\"campaign.resource_name = '$campaign_resource'\"],orderings:[\"metrics.cost_micros DESC\"],limit:200)"
}

query_pmax_search_term_view() {
  local dc="$1"
  local campaign_resource="$2"
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign_search_term_view\",fields:[\"campaign_search_term_view.search_term\",\"campaign_search_term_view.campaign\"],conditions:[\"campaign_search_term_view.campaign = '$campaign_resource'\",\"$dc\"],limit:100)"
}

query_pmax_insight() {
  local dc="$1"
  local campaign_id="$2"
  echo "google-ads-mcp.search(customer_id:\"$CID\",resource:\"campaign_search_term_insight\",fields:[\"campaign_search_term_insight.category_label\",\"campaign_search_term_insight.id\",\"campaign_search_term_insight.campaign_id\"],conditions:[\"campaign_search_term_insight.campaign_id = $campaign_id\",\"$dc\"],limit:100)"
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
USED_DATE_CONDITION=""

echo "## Search Term Retrieval Ladder"
echo "- Customer ID: $CID"
echo "- Minimum spend threshold for classic search-term surfaces: $(format_micros_as_dollars "$MIN_SPEND_MICROS")"
echo

# --- iterate date fallback chain ---

for dc in "${DATE_FALLBACK_CHAIN[@]}"; do
  echo "### Trying date condition: $dc"
  echo
  USED_DATE_CONDITION="$dc"
  TOTAL_ROWS=0
  CAMPAIGNS_TOTAL=0
  CAMPAIGNS_SEARCH=0
  CAMPAIGNS_PMAX=0
  CAMPAIGNS_OTHER=0
  SEARCH_WITH_ROWS=""
  PMAX_WITH_ROWS=""
  PMAX_WITHOUT_ROWS=""
  VISIBILITY_NOTES=""

  # Campaign arrays (populated in Step 3, used in Steps 4+5)
  declare -a IDS=()
  declare -a NAMES=()
  declare -a CTYPES=()

  # Step 1: Account-wide search_term_view
  echo "#### Step 1 — Account-wide search_term_view"
  STEP1_OUT=$(call "$(query_account_wide "$dc")" 2>&1 || true)
  STEP1_ROWS=$(printf '%s\n' "$STEP1_OUT" | count_rows "search_term_view.search_term")
  STEP1_SPEND=$(printf '%s\n' "$STEP1_OUT" | sum_numeric_field "metrics.cost_micros")
  echo "Rows: $STEP1_ROWS"
  echo "Spend: $(format_micros_as_dollars "$STEP1_SPEND")"

  if [[ "$STEP1_ROWS" -gt 0 && "$STEP1_SPEND" -ge "$MIN_SPEND_MICROS" ]]; then
    RETRIEVAL_MODE="classic"
    TOTAL_ROWS=$STEP1_ROWS
    echo "Result: classic mode succeeded at account scope."
    echo
    echo "$STEP1_OUT"
    echo
    break
  fi
  if [[ "$STEP1_ROWS" -gt 0 ]]; then
    echo "Result: rows found, but spend is below the $(format_micros_as_dollars "$MIN_SPEND_MICROS") threshold. Trying Step 2."
  else
    echo "Result: no rows. Trying Step 2."
  fi
  echo

  # Step 2: Search-only search_term_view
  echo "#### Step 2 — Search-only search_term_view"
  STEP2_OUT=$(call "$(query_search_only "$dc")" 2>&1 || true)
  STEP2_ROWS=$(printf '%s\n' "$STEP2_OUT" | count_rows "search_term_view.search_term")
  STEP2_SPEND=$(printf '%s\n' "$STEP2_OUT" | sum_numeric_field "metrics.cost_micros")
  echo "Rows: $STEP2_ROWS"
  echo "Spend: $(format_micros_as_dollars "$STEP2_SPEND")"

  if [[ "$STEP2_ROWS" -gt 0 && "$STEP2_SPEND" -ge "$MIN_SPEND_MICROS" ]]; then
    RETRIEVAL_MODE="classic-search-only"
    TOTAL_ROWS=$STEP2_ROWS
    echo "Result: classic-search-only mode succeeded."
    echo
    echo "$STEP2_OUT"
    echo
    break
  fi
  if [[ "$STEP2_ROWS" -gt 0 ]]; then
    echo "Result: rows found, but spend is below the $(format_micros_as_dollars "$MIN_SPEND_MICROS") threshold. Trying Step 3."
  else
    echo "Result: no rows. Trying Step 3."
  fi
  echo

  # Step 3: Campaign enumeration
  echo "#### Step 3 — Campaign enumeration"
  CAMPAIGNS_OUT=$(call "$(query_campaigns "$dc")" 2>&1 || true)

  IDS=()
  while IFS= read -r value; do
    [[ -n "$value" ]] && IDS+=("$value")
  done < <(printf '%s\n' "$CAMPAIGNS_OUT" | extract_field_values "campaign.id")

  NAMES=()
  while IFS= read -r value; do
    [[ -n "$value" ]] && NAMES+=("$value")
  done < <(printf '%s\n' "$CAMPAIGNS_OUT" | extract_field_values "campaign.name")

  RAW_TYPES=()
  while IFS= read -r value; do
    [[ -n "$value" ]] && RAW_TYPES+=("$value")
  done < <(printf '%s\n' "$CAMPAIGNS_OUT" | extract_field_values "campaign.advertising_channel_type")

  CAMPAIGNS_TOTAL=${#IDS[@]}
  CAMPAIGNS_SEARCH=0
  CAMPAIGNS_PMAX=0
  CAMPAIGNS_OTHER=0
  CTYPES=()

  for i in "${!IDS[@]}"; do
    ct=$(classify_campaign_type "${RAW_TYPES[$i]:-}")
    CTYPES+=("$ct")
    case "$ct" in
      search) ((CAMPAIGNS_SEARCH++)) || true ;;
      pmax)   ((CAMPAIGNS_PMAX++)) || true ;;
      other)  ((CAMPAIGNS_OTHER++)) || true ;;
    esac
  done

  echo "- Total: $CAMPAIGNS_TOTAL"
  echo "- Search: $CAMPAIGNS_SEARCH"
  echo "- PMax: $CAMPAIGNS_PMAX"
  echo "- Other: $CAMPAIGNS_OTHER"
  echo

  if [[ "$CAMPAIGNS_TOTAL" -eq 0 ]]; then
    VISIBILITY_NOTES="No campaigns surfaced for date range: $dc."
    echo "No campaigns found for this date range. Trying next window."
    echo
    continue
  fi

  # Step 4: Campaign-scoped classic retrieval (Search campaigns)
  if [[ "$CAMPAIGNS_SEARCH" -gt 0 ]]; then
    echo "#### Step 4 — Campaign-scoped classic retrieval (Search campaigns)"
    STEP4_ROWS_TOTAL=0
    STEP4_SPEND_TOTAL=0

    for i in "${!IDS[@]}"; do
      [[ "${CTYPES[$i]}" == "search" ]] || continue
      id="${IDS[$i]}"
      name="${NAMES[$i]:-}"

      echo "##### $name (Search, ID: $id)"
      OUT=$(call "$(query_campaign_scoped_classic "$dc" "$id")" 2>&1 || true)
      ROWS=$(printf '%s\n' "$OUT" | count_rows "search_term_view.search_term")
      SPEND=$(printf '%s\n' "$OUT" | sum_numeric_field "metrics.cost_micros")
      echo "Rows: $ROWS"
      echo "Spend: $(format_micros_as_dollars "$SPEND")"

      if [[ "$ROWS" -gt 0 ]]; then
        STEP4_ROWS_TOTAL=$((STEP4_ROWS_TOTAL + ROWS))
        STEP4_SPEND_TOTAL=$((STEP4_SPEND_TOTAL + SPEND))
        SEARCH_WITH_ROWS="${SEARCH_WITH_ROWS:+$SEARCH_WITH_ROWS, }$name"
        echo "$OUT"
      else
        echo "No rows for this campaign."
      fi
      echo
    done

    if [[ "$STEP4_ROWS_TOTAL" -gt 0 && "$STEP4_SPEND_TOTAL" -ge "$MIN_SPEND_MICROS" ]]; then
      RETRIEVAL_MODE="classic-campaign-scoped"
      TOTAL_ROWS=$STEP4_ROWS_TOTAL
      echo "Result: campaign-scoped classic retrieval succeeded with combined spend $(format_micros_as_dollars "$STEP4_SPEND_TOTAL")."
      echo
      break
    fi

    if [[ "$STEP4_ROWS_TOTAL" -gt 0 ]]; then
      echo "Result: Search campaigns produced rows, but combined spend $(format_micros_as_dollars "$STEP4_SPEND_TOTAL") is below the $(format_micros_as_dollars "$MIN_SPEND_MICROS") threshold. Trying Step 5."
      echo
    fi
  fi

  # Step 5: PMax campaign-scoped retrieval
  if [[ "$CAMPAIGNS_PMAX" -gt 0 ]]; then
    echo "#### Step 5 — PMax campaign-scoped retrieval"
    STEP5_ROWS_TOTAL=0

    for i in "${!IDS[@]}"; do
      [[ "${CTYPES[$i]}" == "pmax" ]] || continue
      id="${IDS[$i]}"
      name="${NAMES[$i]:-}"
      RESOURCE="customers/$CID/campaigns/$id"

      echo "##### $name (PMax, ID: $id)"

      echo "###### campaign_search_term_view"
      OUT=$(call "$(query_pmax_search_term_view "$dc" "$RESOURCE")" 2>&1 || true)
      ROWS=$(printf '%s\n' "$OUT" | count_rows "campaign_search_term_view.search_term")
      echo "Rows: $ROWS"

      if [[ "$ROWS" -gt 0 ]]; then
        STEP5_ROWS_TOTAL=$((STEP5_ROWS_TOTAL + ROWS))
        PMAX_WITH_ROWS="${PMAX_WITH_ROWS:+$PMAX_WITH_ROWS, }$name"
        echo "$OUT"
      else
        PMAX_WITHOUT_ROWS="${PMAX_WITHOUT_ROWS:+$PMAX_WITHOUT_ROWS, }$name"
        echo "No rows."
      fi

      echo "###### campaign_search_term_insight"
      INSIGHT=$(call "$(query_pmax_insight "$dc" "$id")" 2>&1 || true)
      INSIGHT_ROWS=$(printf '%s\n' "$INSIGHT" | count_rows "campaign_search_term_insight.category_label")
      echo "Insight rows: $INSIGHT_ROWS"
      if [[ "$INSIGHT_ROWS" -gt 0 ]]; then
        echo "$INSIGHT"
      else
        echo "No insight rows (common for newer PMax campaigns)."
      fi
      echo
    done

    if [[ "$STEP5_ROWS_TOTAL" -gt 0 ]]; then
      RETRIEVAL_MODE="pmax-fallback"
      TOTAL_ROWS=$STEP5_ROWS_TOTAL
      VISIBILITY_NOTES="PMax rows are query text only — no per-term cost/CPA/conversion metrics. Spend thresholding applies only to classic search_term_view surfaces."
      break
    fi
  fi

  echo "No rows found for date range: $dc. Trying next window."
  echo
done

# --- diagnostic summary ---

echo "---"
echo
echo "## Search Term Retrieval Diagnostics"
echo "- Customer ID: $CID"
echo "- Date range: $USED_DATE_CONDITION"
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
    echo "- Spend thresholding only applies to classic search_term_view surfaces."
    echo "- Negatives: only recommend for extremely obvious junk terms."
    echo "- Intent map: use rows for clustering, but performance profiling is unavailable."
    echo "- RSAs: use rows for buyer-language extraction only."
    echo "- Audit: mark search-term sections as 'PMax visibility-limited'."
    ;;
  limited)
    echo "## Operator Guidance"
    echo "Insufficient search-term visibility across all date ranges tried."
    echo "- Shift to campaign / asset-group / tracking analysis."
    echo "- Request a UI export from the Google Ads interface for exact waste attribution."
    echo "- Do not fabricate search-term conclusions from absent data."
    ;;
esac
