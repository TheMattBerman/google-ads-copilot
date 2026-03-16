#!/usr/bin/env bash
# api-mutate.sh — Execute a single Google Ads API mutation
#
# Usage:
#   source lib/api-mutate.sh
#   result=$(mutate_add_negative "$customer_id" "$campaign_id" "$keyword" "$match_type")
#   result=$(mutate_add_negative_adgroup "$customer_id" "$adgroup_id" "$keyword" "$match_type")
#   result=$(mutate_pause_keyword "$customer_id" "$adgroup_criterion_id")
#   result=$(mutate_pause_adgroup "$customer_id" "$adgroup_id")
#
# All functions return JSON: {"success": true/false, "resource_name": "...", "error": "..."}
# Requires: get_access_token from lib/token-refresh.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# API version and base URL come from config.sh (sourced by token-refresh.sh)
# GADS_API_VERSION and GADS_API_BASE are already set

# Common headers for Google Ads API
_gads_headers() {
  local access_token="$1"
  echo -H "Authorization: Bearer ${access_token}"
  echo -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}"
  echo -H "Content-Type: application/json"
  if [ -n "${GOOGLE_ADS_LOGIN_CUSTOMER_ID:-}" ]; then
    echo -H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}"
  fi
}

# Wrapper: make an API call and return structured result
_gads_call() {
  local method="$1"
  local url="$2"
  local body="$3"
  local access_token
  access_token=$(get_access_token)

  local response http_code
  response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
    -H "Authorization: Bearer ${access_token}" \
    -H "developer-token: ${GOOGLE_ADS_DEVELOPER_TOKEN}" \
    -H "Content-Type: application/json" \
    ${GOOGLE_ADS_LOGIN_CUSTOMER_ID:+-H "login-customer-id: ${GOOGLE_ADS_LOGIN_CUSTOMER_ID}"} \
    -d "$body")

  http_code=$(echo "$response" | tail -1)
  local body_response
  body_response=$(echo "$response" | sed '$d')

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo "$body_response"
    return 0
  else
    echo "$body_response" >&2
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════
# MUTATION: Add campaign-level negative keyword
# ═══════════════════════════════════════════════════════════
mutate_add_negative_campaign() {
  local customer_id="$1"      # e.g., 1234567890
  local campaign_id="$2"      # numeric campaign ID
  local keyword_text="$3"     # e.g., "near me"
  local match_type="$4"       # PHRASE, EXACT, or BROAD

  # Normalize match type to uppercase
  match_type=$(echo "$match_type" | tr '[:lower:]' '[:upper:]')

  local payload
  payload=$(jq -n \
    --arg campaign "customers/${customer_id}/campaigns/${campaign_id}" \
    --arg text "$keyword_text" \
    --arg match "$match_type" \
    '{
      "operations": [{
        "create": {
          "campaign": $campaign,
          "negative": true,
          "keyword": {
            "text": $text,
            "matchType": $match
          }
        }
      }]
    }')

  local url="${GADS_API_BASE}/customers/${customer_id}/campaignCriteria:mutate"

  local result
  if result=$(_gads_call "POST" "$url" "$payload"); then
    # Extract the resource name from the response
    local resource_name
    resource_name=$(echo "$result" | jq -r '.results[0].resourceName // empty')
    local criterion_id
    criterion_id="${resource_name##*~}"

    jq -n \
      --arg resource_name "$resource_name" \
      --arg criterion_id "$criterion_id" \
      '{success: true, resource_name: $resource_name, criterion_id: $criterion_id}'
  else
    local error_msg
    error_msg=$(echo "$result" 2>&1 | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "API call failed")

    # Check for duplicate keyword (not really an error)
    if echo "$error_msg" | grep -qi "duplicate"; then
      jq -n --arg msg "$error_msg" '{success: true, already_exists: true, message: $msg}'
    else
      jq -n --arg msg "$error_msg" '{success: false, error: $msg}'
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# MUTATION: Add ad-group-level negative keyword
# ═══════════════════════════════════════════════════════════
mutate_add_negative_adgroup() {
  local customer_id="$1"
  local adgroup_id="$2"
  local keyword_text="$3"
  local match_type="$4"

  match_type=$(echo "$match_type" | tr '[:lower:]' '[:upper:]')

  local payload
  payload=$(jq -n \
    --arg adgroup "customers/${customer_id}/adGroups/${adgroup_id}" \
    --arg text "$keyword_text" \
    --arg match "$match_type" \
    '{
      "operations": [{
        "create": {
          "adGroup": $adgroup,
          "negative": true,
          "keyword": {
            "text": $text,
            "matchType": $match
          }
        }
      }]
    }')

  local url="${GADS_API_BASE}/customers/${customer_id}/adGroupCriteria:mutate"

  local result
  if result=$(_gads_call "POST" "$url" "$payload"); then
    local resource_name
    resource_name=$(echo "$result" | jq -r '.results[0].resourceName // empty')
    local criterion_id
    criterion_id="${resource_name##*~}"

    jq -n \
      --arg resource_name "$resource_name" \
      --arg criterion_id "$criterion_id" \
      '{success: true, resource_name: $resource_name, criterion_id: $criterion_id}'
  else
    local error_msg
    error_msg=$(echo "$result" 2>&1 | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "API call failed")
    if echo "$error_msg" | grep -qi "duplicate"; then
      jq -n --arg msg "$error_msg" '{success: true, already_exists: true, message: $msg}'
    else
      jq -n --arg msg "$error_msg" '{success: false, error: $msg}'
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# MUTATION: Pause a keyword (ad group criterion)
# ═══════════════════════════════════════════════════════════
mutate_pause_keyword() {
  local customer_id="$1"
  local adgroup_id="$2"
  local criterion_id="$3"

  local resource_name="customers/${customer_id}/adGroupCriteria/${adgroup_id}~${criterion_id}"

  local payload
  payload=$(jq -n \
    --arg rn "$resource_name" \
    '{
      "operations": [{
        "updateMask": "status",
        "update": {
          "resourceName": $rn,
          "status": "PAUSED"
        }
      }]
    }')

  local url="${GADS_API_BASE}/customers/${customer_id}/adGroupCriteria:mutate"

  local result
  if result=$(_gads_call "POST" "$url" "$payload"); then
    jq -n --arg rn "$resource_name" '{success: true, resource_name: $rn, new_status: "PAUSED"}'
  else
    local error_msg
    error_msg=$(echo "$result" 2>&1 | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "API call failed")
    jq -n --arg msg "$error_msg" '{success: false, error: $msg}'
  fi
}

# ═══════════════════════════════════════════════════════════
# MUTATION: Pause an ad group
# ═══════════════════════════════════════════════════════════
mutate_pause_adgroup() {
  local customer_id="$1"
  local adgroup_id="$2"

  local resource_name="customers/${customer_id}/adGroups/${adgroup_id}"

  local payload
  payload=$(jq -n \
    --arg rn "$resource_name" \
    '{
      "operations": [{
        "updateMask": "status",
        "update": {
          "resourceName": $rn,
          "status": "PAUSED"
        }
      }]
    }')

  local url="${GADS_API_BASE}/customers/${customer_id}/adGroups:mutate"

  local result
  if result=$(_gads_call "POST" "$url" "$payload"); then
    jq -n --arg rn "$resource_name" '{success: true, resource_name: $rn, new_status: "PAUSED"}'
  else
    local error_msg
    error_msg=$(echo "$result" 2>&1 | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "API call failed")
    jq -n --arg msg "$error_msg" '{success: false, error: $msg}'
  fi
}

# ═══════════════════════════════════════════════════════════
# REVERSAL: Remove a campaign criterion (undo negative keyword)
# ═══════════════════════════════════════════════════════════
mutate_remove_campaign_criterion() {
  local customer_id="$1"
  local resource_name="$2"  # e.g., customers/123/campaignCriteria/campaignId~criterionId

  local payload
  payload=$(jq -n \
    --arg rn "$resource_name" \
    '{
      "operations": [{
        "remove": $rn
      }]
    }')

  local url="${GADS_API_BASE}/customers/${customer_id}/campaignCriteria:mutate"

  local result
  if result=$(_gads_call "POST" "$url" "$payload"); then
    jq -n --arg rn "$resource_name" '{success: true, removed: $rn}'
  else
    local error_msg
    error_msg=$(echo "$result" 2>&1 | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "API call failed")
    jq -n --arg msg "$error_msg" '{success: false, error: $msg}'
  fi
}

# ═══════════════════════════════════════════════════════════
# REVERSAL: Remove an ad group criterion (undo negative keyword)
# ═══════════════════════════════════════════════════════════
mutate_remove_adgroup_criterion() {
  local customer_id="$1"
  local resource_name="$2"  # e.g., customers/123/adGroupCriteria/456~789

  local payload
  payload=$(jq -n \
    --arg rn "$resource_name" \
    '{
      "operations": [{
        "remove": $rn
      }]
    }')

  local url="${GADS_API_BASE}/customers/${customer_id}/adGroupCriteria:mutate"

  local result
  if result=$(_gads_call "POST" "$url" "$payload"); then
    jq -n --arg rn "$resource_name" '{success: true, removed: $rn}'
  else
    local error_msg
    error_msg=$(echo "$result" 2>&1 | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "API call failed")
    jq -n --arg msg "$error_msg" '{success: false, error: $msg}'
  fi
}

# ═══════════════════════════════════════════════════════════
# REVERSAL: Re-enable a keyword (undo pause)
# ═══════════════════════════════════════════════════════════
mutate_enable_keyword() {
  local customer_id="$1"
  local adgroup_id="$2"
  local criterion_id="$3"

  local resource_name="customers/${customer_id}/adGroupCriteria/${adgroup_id}~${criterion_id}"

  local payload
  payload=$(jq -n \
    --arg rn "$resource_name" \
    '{
      "operations": [{
        "updateMask": "status",
        "update": {
          "resourceName": $rn,
          "status": "ENABLED"
        }
      }]
    }')

  local url="${GADS_API_BASE}/customers/${customer_id}/adGroupCriteria:mutate"

  local result
  if result=$(_gads_call "POST" "$url" "$payload"); then
    jq -n --arg rn "$resource_name" '{success: true, resource_name: $rn, new_status: "ENABLED"}'
  else
    local error_msg
    error_msg=$(echo "$result" 2>&1 | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "API call failed")
    jq -n --arg msg "$error_msg" '{success: false, error: $msg}'
  fi
}

# ═══════════════════════════════════════════════════════════
# REVERSAL: Re-enable an ad group (undo pause)
# ═══════════════════════════════════════════════════════════
mutate_enable_adgroup() {
  local customer_id="$1"
  local adgroup_id="$2"

  local resource_name="customers/${customer_id}/adGroups/${adgroup_id}"

  local payload
  payload=$(jq -n \
    --arg rn "$resource_name" \
    '{
      "operations": [{
        "updateMask": "status",
        "update": {
          "resourceName": $rn,
          "status": "ENABLED"
        }
      }]
    }')

  local url="${GADS_API_BASE}/customers/${customer_id}/adGroups:mutate"

  local result
  if result=$(_gads_call "POST" "$url" "$payload"); then
    jq -n --arg rn "$resource_name" '{success: true, resource_name: $rn, new_status: "ENABLED"}'
  else
    local error_msg
    error_msg=$(echo "$result" 2>&1 | jq -r '.error.message // "Unknown error"' 2>/dev/null || echo "API call failed")
    jq -n --arg msg "$error_msg" '{success: false, error: $msg}'
  fi
}
