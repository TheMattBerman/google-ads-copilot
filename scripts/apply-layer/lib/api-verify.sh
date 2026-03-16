#!/usr/bin/env bash
# api-verify.sh — Verify mutations took effect via GAQL queries
#
# Usage:
#   source lib/api-verify.sh
#   verify_negative_exists "$customer_id" "$campaign_name" "$keyword_text" "$match_type"
#   verify_keyword_paused "$customer_id" "$campaign_name" "$keyword_text"
#   verify_adgroup_paused "$customer_id" "$campaign_name" "$adgroup_name"
#
# All functions return JSON: {"verified": true/false, "detail": "..."}
# Uses GAQL via the REST searchStream endpoint (no MCP dependency).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# API version and base URL come from config.sh (sourced by token-refresh.sh)
# GADS_API_VERSION and GADS_API_BASE are already set

# Run a GAQL query via searchStream
_gaql_query() {
  local customer_id="$1"
  local query="$2"
  local access_token
  access_token=$(get_access_token)

  local payload
  payload=$(jq -n --arg q "$query" '{"query": $q}')

  local url="${GADS_API_BASE}/customers/${customer_id}/googleAds:searchStream"

  curl -s -X POST "$url" \
    -H "Authorization: Bearer ${access_token}" \
    -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" \
    -H "Content-Type: application/json" \
    ${GOOGLE_ADS_LOGIN_CUSTOMER_ID:+-H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}"} \
    -d "$payload"
}

# ═══════════════════════════════════════════════════════════
# VERIFY: Negative keyword exists at campaign level
# ═══════════════════════════════════════════════════════════
verify_negative_exists() {
  local customer_id="$1"
  local campaign_name="$2"
  local keyword_text="$3"
  local match_type="$4"

  match_type=$(echo "$match_type" | tr '[:lower:]' '[:upper:]')

  # Escape single quotes for GAQL safety
  local safe_campaign safe_keyword
  safe_campaign=$(_gaql_escape "$campaign_name")
  safe_keyword=$(_gaql_escape "$keyword_text")

  local query="SELECT
    campaign.name,
    campaign_criterion.keyword.text,
    campaign_criterion.keyword.match_type,
    campaign_criterion.negative
  FROM campaign_criterion
  WHERE campaign_criterion.negative = TRUE
    AND campaign_criterion.type = 'KEYWORD'
    AND campaign.name = '${safe_campaign}'
    AND campaign_criterion.keyword.text = '${safe_keyword}'
    AND campaign_criterion.keyword.match_type = '${match_type}'"

  local result
  result=$(_gaql_query "$customer_id" "$query")

  # searchStream returns an array; check if we got results
  local row_count
  row_count=$(echo "$result" | jq '[.[].results // [] | length] | add // 0' 2>/dev/null)

  if [ "$row_count" -gt 0 ]; then
    jq -n \
      --arg kw "$keyword_text" \
      --arg mt "$match_type" \
      --arg campaign "$campaign_name" \
      '{verified: true, detail: ("Negative keyword \"\($kw)\" [\($mt)] confirmed in campaign \"\($campaign)\"")}'
  else
    jq -n \
      --arg kw "$keyword_text" \
      --arg mt "$match_type" \
      --arg campaign "$campaign_name" \
      '{verified: false, detail: ("Negative keyword \"\($kw)\" [\($mt)] NOT FOUND in campaign \"\($campaign)\"")}'
  fi
}

# ═══════════════════════════════════════════════════════════
# VERIFY: Negative keyword exists at ad group level
# ═══════════════════════════════════════════════════════════
verify_negative_adgroup_exists() {
  local customer_id="$1"
  local adgroup_name="$2"
  local keyword_text="$3"
  local match_type="$4"

  match_type=$(echo "$match_type" | tr '[:lower:]' '[:upper:]')

  local safe_adgroup safe_keyword
  safe_adgroup=$(_gaql_escape "$adgroup_name")
  safe_keyword=$(_gaql_escape "$keyword_text")

  local query="SELECT
    ad_group.name,
    ad_group_criterion.keyword.text,
    ad_group_criterion.keyword.match_type,
    ad_group_criterion.negative
  FROM ad_group_criterion
  WHERE ad_group_criterion.negative = TRUE
    AND ad_group_criterion.type = 'KEYWORD'
    AND ad_group.name = '${safe_adgroup}'
    AND ad_group_criterion.keyword.text = '${safe_keyword}'
    AND ad_group_criterion.keyword.match_type = '${match_type}'"

  local result
  result=$(_gaql_query "$customer_id" "$query")

  local row_count
  row_count=$(echo "$result" | jq '[.[].results // [] | length] | add // 0' 2>/dev/null)

  if [ "$row_count" -gt 0 ]; then
    jq -n \
      --arg kw "$keyword_text" \
      --arg mt "$match_type" \
      --arg ag "$adgroup_name" \
      '{verified: true, detail: ("Negative keyword \"\($kw)\" [\($mt)] confirmed in ad group \"\($ag)\"")}'
  else
    jq -n \
      --arg kw "$keyword_text" \
      --arg mt "$match_type" \
      --arg ag "$adgroup_name" \
      '{verified: false, detail: ("Negative keyword \"\($kw)\" [\($mt)] NOT FOUND in ad group \"\($ag)\"")}'
  fi
}

# ═══════════════════════════════════════════════════════════
# VERIFY: Keyword is paused
# ═══════════════════════════════════════════════════════════
verify_keyword_paused() {
  local customer_id="$1"
  local campaign_name="$2"
  local adgroup_name="$3"
  local keyword_text="$4"

  local safe_campaign safe_adgroup safe_keyword
  safe_campaign=$(_gaql_escape "$campaign_name")
  safe_adgroup=$(_gaql_escape "$adgroup_name")
  safe_keyword=$(_gaql_escape "$keyword_text")

  local query="SELECT
    campaign.name,
    ad_group.name,
    ad_group_criterion.keyword.text,
    ad_group_criterion.keyword.match_type,
    ad_group_criterion.status
  FROM keyword_view
  WHERE ad_group_criterion.keyword.text = '${safe_keyword}'
    AND campaign.name = '${safe_campaign}'
    AND ad_group.name = '${safe_adgroup}'"

  local result
  result=$(_gaql_query "$customer_id" "$query")

  local status
  status=$(echo "$result" | jq -r '[.[].results[]?.adGroupCriterion.status] | first // "UNKNOWN"' 2>/dev/null)

  if [ "$status" = "PAUSED" ]; then
    jq -n \
      --arg kw "$keyword_text" \
      --arg status "$status" \
      '{verified: true, detail: ("Keyword \"\($kw)\" status is \($status)")}'
  else
    jq -n \
      --arg kw "$keyword_text" \
      --arg status "$status" \
      '{verified: false, detail: ("Keyword \"\($kw)\" status is \($status), expected PAUSED")}'
  fi
}

# ═══════════════════════════════════════════════════════════
# VERIFY: Ad group is paused
# ═══════════════════════════════════════════════════════════
verify_adgroup_paused() {
  local customer_id="$1"
  local campaign_name="$2"
  local adgroup_name="$3"

  local safe_campaign safe_adgroup
  safe_campaign=$(_gaql_escape "$campaign_name")
  safe_adgroup=$(_gaql_escape "$adgroup_name")

  local query="SELECT
    campaign.name,
    ad_group.name,
    ad_group.status
  FROM ad_group
  WHERE ad_group.name = '${safe_adgroup}'
    AND campaign.name = '${safe_campaign}'"

  local result
  result=$(_gaql_query "$customer_id" "$query")

  local status
  status=$(echo "$result" | jq -r '[.[].results[]?.adGroup.status] | first // "UNKNOWN"' 2>/dev/null)

  if [ "$status" = "PAUSED" ]; then
    jq -n \
      --arg ag "$adgroup_name" \
      --arg status "$status" \
      '{verified: true, detail: ("Ad group \"\($ag)\" status is \($status)")}'
  else
    jq -n \
      --arg ag "$adgroup_name" \
      --arg status "$status" \
      '{verified: false, detail: ("Ad group \"\($ag)\" status is \($status), expected PAUSED")}'
  fi
}

# ═══════════════════════════════════════════════════════════
# LOOKUP: Resolve campaign name → campaign ID
# ═══════════════════════════════════════════════════════════
lookup_campaign_id() {
  local customer_id="$1"
  local campaign_name="$2"

  local safe_name
  safe_name=$(_gaql_escape "$campaign_name")

  local query="SELECT campaign.id, campaign.name FROM campaign WHERE campaign.name = '${safe_name}' AND campaign.status != 'REMOVED'"

  local result
  result=$(_gaql_query "$customer_id" "$query")

  echo "$result" | jq -r '[.[].results[]?.campaign.id] | first // empty' 2>/dev/null
}

# ═══════════════════════════════════════════════════════════
# LOOKUP: Resolve ad group name → ad group ID (within campaign)
# ═══════════════════════════════════════════════════════════
lookup_adgroup_id() {
  local customer_id="$1"
  local campaign_name="$2"
  local adgroup_name="$3"

  local safe_campaign safe_adgroup
  safe_campaign=$(_gaql_escape "$campaign_name")
  safe_adgroup=$(_gaql_escape "$adgroup_name")

  local query="SELECT ad_group.id, ad_group.name, campaign.name FROM ad_group WHERE campaign.name = '${safe_campaign}' AND ad_group.name = '${safe_adgroup}' AND ad_group.status != 'REMOVED'"

  local result
  result=$(_gaql_query "$customer_id" "$query")

  echo "$result" | jq -r '[.[].results[]?.adGroup.id] | first // empty' 2>/dev/null
}

# ═══════════════════════════════════════════════════════════
# LOOKUP: Resolve keyword text → criterion ID (within ad group)
# ═══════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════
# LOOKUP: Resolve ad group name → ad group ID (without campaign name)
# Useful when only the ad group name is known
# ═══════════════════════════════════════════════════════════
lookup_adgroup_id_by_name() {
  local customer_id="$1"
  local adgroup_name="$2"

  local safe_adgroup
  safe_adgroup=$(_gaql_escape "$adgroup_name")

  local query="SELECT ad_group.id, ad_group.name FROM ad_group WHERE ad_group.name = '${safe_adgroup}' AND ad_group.status != 'REMOVED'"

  local result
  result=$(_gaql_query "$customer_id" "$query")

  echo "$result" | jq -r '[.[].results[]?.adGroup.id] | first // empty' 2>/dev/null
}

lookup_keyword_criterion_id() {
  local customer_id="$1"
  local campaign_name="$2"
  local adgroup_name="$3"
  local keyword_text="$4"
  local match_type="$5"

  match_type=$(echo "$match_type" | tr '[:lower:]' '[:upper:]')

  local safe_campaign safe_adgroup safe_keyword
  safe_campaign=$(_gaql_escape "$campaign_name")
  safe_adgroup=$(_gaql_escape "$adgroup_name")
  safe_keyword=$(_gaql_escape "$keyword_text")

  local query="SELECT
    ad_group_criterion.criterion_id,
    ad_group_criterion.keyword.text,
    ad_group_criterion.keyword.match_type,
    ad_group.name,
    campaign.name
  FROM keyword_view
  WHERE ad_group_criterion.keyword.text = '${safe_keyword}'
    AND ad_group_criterion.keyword.match_type = '${match_type}'
    AND ad_group.name = '${safe_adgroup}'
    AND campaign.name = '${safe_campaign}'"

  local result
  result=$(_gaql_query "$customer_id" "$query")

  echo "$result" | jq -r '[.[].results[]?.adGroupCriterion.criterionId] | first // empty' 2>/dev/null
}
