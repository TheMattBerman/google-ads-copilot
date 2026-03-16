#!/usr/bin/env bash
# parse-draft.sh — Extract structured actions from draft markdown files
#
# Usage:
#   source lib/parse-draft.sh
#   actions_json=$(parse_draft "/path/to/draft.md")
#
# Parses Section A (negatives to add) and Section D (keyword pauses)
# from draft markdown files into a JSON array of action objects.
#
# Output format:
# [
#   {
#     "index": 1,
#     "type": "ADD_NEGATIVE",
#     "keyword": "near me",
#     "match_type": "PHRASE",
#     "scope": "CAMPAIGN",
#     "campaign": "Website traffic-Search",
#     "adgroup": null,
#     "reason": "..."
#   },
#   {
#     "index": 14,
#     "type": "PAUSE_KEYWORD",
#     "keyword": "waste management",
#     "match_type": "EXACT",
#     "scope": "AD_GROUP",
#     "campaign": "Website traffic-Search",
#     "adgroup": "High-Intent Buyers",
#     "reason": "..."
#   }
# ]

set -euo pipefail

_first_quoted_value() {
  printf '%s\n' "$1" | sed -nE 's/^[^"]*"([^"]+)".*/\1/p' | head -1
}

# Parse the draft header to extract account info
parse_draft_header() {
  local draft_file="$1"

  local customer_id customer_name status
  # Account line: "Account: Acme Equipment Co. (1234567890)"
  customer_id=$(sed -nE 's/.*\(([0-9]{10})\).*/\1/p' "$draft_file" | head -1)
  customer_name=$(grep '^Account:' "$draft_file" | head -1 | sed 's/Account: //' | sed 's/ (.*//')
  status=$(grep '^Status:' "$draft_file" | head -1 | sed 's/Status: //')

  jq -n \
    --arg cid "$customer_id" \
    --arg name "$customer_name" \
    --arg status "$status" \
    '{customer_id: $cid, customer_name: $name, status: $status}'
}

# Parse Section A: Negatives to ADD
_parse_section_a() {
  local draft_file="$1"

  # Extract the Section A block
  local section_a
  section_a=$(sed -n '/^## Section A: Negatives to ADD/,/^## Section [B-Z]/p' "$draft_file" | sed '$d')

  if [ -z "$section_a" ]; then
    echo "[]"
    return
  fi

  # Parse each "### Negative N:" block
  local actions="[]"
  local current_index=""
  local current_keyword=""
  local current_match_type=""
  local current_scope=""
  local current_campaign=""
  local current_adgroup=""
  local current_reason=""

  while IFS= read -r line; do
    # Start of a new negative block
    if [[ "$line" =~ ^###\ Negative\ [0-9]+: ]]; then
      # Save previous block if we have one
      if [ -n "$current_index" ]; then
        actions=$(echo "$actions" | jq \
          --argjson idx "$current_index" \
          --arg kw "$current_keyword" \
          --arg mt "$current_match_type" \
          --arg scope "$current_scope" \
          --arg campaign "$current_campaign" \
          --arg adgroup "$current_adgroup" \
          --arg reason "$current_reason" \
          '. + [{
            index: $idx,
            type: "ADD_NEGATIVE",
            keyword: $kw,
            match_type: ($mt | ascii_upcase),
            scope: $scope,
            campaign: $campaign,
            adgroup: (if $adgroup == "" then null else $adgroup end),
            reason: $reason
          }]')
      fi

      # Parse new block header: ### Negative 1: "near me"
      current_index=$(printf '%s\n' "$line" | sed -nE 's/^### Negative ([0-9]+):.*/\1/p')
      current_keyword=$(_first_quoted_value "$line")
      current_match_type=""
      current_scope=""
      current_campaign=""
      current_adgroup=""
      current_reason=""
    fi

    # Parse fields within a block
    if [[ "$line" == '- **Match type:**'* ]]; then
      current_match_type=$(echo "$line" | sed 's/.*\*\*Match type:\*\* *//' | tr '[:lower:]' '[:upper:]')
    fi

    if [[ "$line" == '- **Scope:**'* ]]; then
      local scope_line
      scope_line=$(echo "$line" | sed 's/.*\*\*Scope:\*\* *//')
      if [[ "$scope_line" == *"Ad Group"* ]]; then
        current_scope="AD_GROUP"
        current_adgroup=$(_first_quoted_value "$scope_line")
        # Also extract campaign if both are listed
        if [[ "$scope_line" == *'Campaign "'* ]]; then
          current_campaign=$(printf '%s\n' "$scope_line" | sed -nE 's/.*Campaign "([^"]+)".*/\1/p')
        fi
      elif [[ "$scope_line" == *"Campaign"* ]]; then
        current_scope="CAMPAIGN"
        current_campaign=$(_first_quoted_value "$scope_line")
      fi
    fi

    if [[ "$line" == '- **Reason:**'* ]]; then
      current_reason=$(echo "$line" | sed 's/.*\*\*Reason:\*\* *//' | head -c 200)
    fi

  done <<< "$section_a"

  # Don't forget the last block
  if [ -n "$current_index" ]; then
    actions=$(echo "$actions" | jq \
      --argjson idx "$current_index" \
      --arg kw "$current_keyword" \
      --arg mt "$current_match_type" \
      --arg scope "$current_scope" \
      --arg campaign "$current_campaign" \
      --arg adgroup "$current_adgroup" \
      --arg reason "$current_reason" \
      '. + [{
        index: $idx,
        type: "ADD_NEGATIVE",
        keyword: $kw,
        match_type: ($mt | ascii_upcase),
        scope: $scope,
        campaign: $campaign,
        adgroup: (if $adgroup == "" then null else $adgroup end),
        reason: $reason
      }]')
  fi

  echo "$actions"
}

# Parse Section D: Keyword-level recommendations (pauses)
_parse_section_d() {
  local draft_file="$1"

  # Look for Section D or "PAUSE" / "Pause" recommendations
  local section_d
  section_d=$(sed -n '/^## Section D:/,/^## Section [^D]/p' "$draft_file" | sed '$d')

  # Also check for CRITICAL KEYWORD-LEVEL RECOMMENDATION section (used in some drafts)
  if [ -z "$section_d" ]; then
    section_d=$(sed -n '/^## .*CRITICAL.*KEYWORD.*RECOMMENDATION/,/^## /p' "$draft_file" | sed '$d')
  fi

  if [ -z "$section_d" ]; then
    echo "[]"
    return
  fi

  local actions="[]"

  # Parse "Pause or Narrow" blocks
  # These have a different format — look for keyword, match type, campaign, ad group
  local keyword match_type campaign adgroup
  keyword=""
  match_type=""
  campaign=""
  adgroup=""

  while IFS= read -r line; do
    # Header: ### ⚠️ Pause or Narrow: "waste management" [EXACT MATCH]
    if [[ "$line" == *'"'*'"'* ]] && [[ "${line,,}" == *pause* ]]; then
      keyword=$(_first_quoted_value "$line")
      match_type=$(printf '%s\n' "$line" | sed -nE 's/.*\[(EXACT|PHRASE|BROAD).*/\1/ip' | head -1 | tr '[:lower:]' '[:upper:]')
      [ -z "$match_type" ] && match_type="EXACT"
    fi

    # Current state line: - **Current state:** EXACT match, ENABLED, in "High-Intent Buyers" ad group
    if [[ "$line" == '- **Current state:**'* ]]; then
      adgroup=$(printf '%s\n' "$line" | sed -nE 's/.*in "([^"]+)".*/\1/p')
    fi

    # Ad group field: - **Ad group:** "High-Intent Buyers"
    if [[ "$line" == '- **Ad group:**'* ]]; then
      adgroup=$(_first_quoted_value "$line")
    fi

    # Campaign field: - **Campaign:** "Website traffic-Search"
    if [[ "$line" == '- **Campaign:**'* ]]; then
      campaign=$(_first_quoted_value "$line")
    fi

    # Look for campaign mentions in the section (multiple patterns)
    if [[ "$line" == *'Campaign "'* ]]; then
      campaign=$(printf '%s\n' "$line" | sed -nE 's/.*Campaign.*"([^"]+)".*/\1/p' | head -1)
    elif [[ "$line" == *'campaign "'* ]]; then
      local maybe_campaign
      maybe_campaign=$(_first_quoted_value "$line")
      [ -n "$maybe_campaign" ] && campaign="$maybe_campaign"
    fi

    # Recommendation line confirms it's a pause
    if [[ "$line" == '- **Recommendation:**'* ]] && [[ "${line^^}" == *PAUSE* ]]; then
      # Fallback: if campaign not found in Section D, try to find it in the full draft
      if [ -z "$campaign" ]; then
        campaign=$(sed -nE 's/.*Campaign "([^"]+)".*/\1/p' "$draft_file" | head -1)
      fi
      # Last resort: use the first campaign from Section A
      if [ -z "$campaign" ]; then
        campaign=$(awk '
          index($0, "- **Scope:**") == 1 && index($0, "Campaign") {
            if (match($0, /"[^"]+"/)) {
              print substr($0, RSTART + 1, RLENGTH - 2)
              exit
            }
          }
        ' "$draft_file")
      fi

      if [ -n "$keyword" ]; then
        actions=$(echo "$actions" | jq \
          --arg kw "$keyword" \
          --arg mt "$match_type" \
          --arg campaign "$campaign" \
          --arg adgroup "$adgroup" \
          '. + [{
            index: (length + 100),
            type: "PAUSE_KEYWORD",
            keyword: $kw,
            match_type: $mt,
            scope: "AD_GROUP",
            campaign: $campaign,
            adgroup: $adgroup,
            reason: "Recommended for pause in draft Section D"
          }]')
      fi
    fi
  done <<< "$section_d"

  echo "$actions"
}

# Parse Section A or B from pause-draft.md templates
# Handles:
#   Section A: Keywords to PAUSE
#   Section B: Ad Groups to PAUSE
_parse_pause_sections() {
  local draft_file="$1"

  local actions="[]"

  # ─── Parse keyword pauses from pause-draft template (Section A) ───
  local section_kw_pause
  section_kw_pause=$(sed -n '/^## Section A: Keywords to PAUSE/,/^## Section [B-Z]/p' "$draft_file" | sed '$d')

  if [ -n "$section_kw_pause" ]; then
    local kw_keyword="" kw_match_type="" kw_campaign="" kw_adgroup="" kw_reason="" kw_status=""

    while IFS= read -r line; do
      # Header: ### Keyword Pause 1: "waste management" [EXACT]
      if [[ "$line" =~ ^###\ Keyword\ Pause\ [0-9]+: ]]; then
        # Save previous block
        if [ -n "$kw_keyword" ] && [ "$kw_status" = "ENABLED" ]; then
          actions=$(echo "$actions" | jq \
            --arg kw "$kw_keyword" \
            --arg mt "${kw_match_type:-EXACT}" \
            --arg campaign "$kw_campaign" \
            --arg adgroup "$kw_adgroup" \
            --arg reason "$kw_reason" \
            '. + [{
              index: (length + 200),
              type: "PAUSE_KEYWORD",
              keyword: $kw,
              match_type: ($mt | ascii_upcase),
              scope: "AD_GROUP",
              campaign: $campaign,
              adgroup: $adgroup,
              reason: $reason
            }]')
        fi

        kw_keyword=$(_first_quoted_value "$line")
        kw_match_type=$(printf '%s\n' "$line" | sed -nE 's/.*\[(EXACT|PHRASE|BROAD).*/\1/ip' | head -1 | tr '[:lower:]' '[:upper:]')
        kw_campaign=""
        kw_adgroup=""
        kw_reason=""
        kw_status=""
      fi

      # Field parsing
      if [[ "$line" == '- **Campaign:**'* ]]; then
        kw_campaign=$(_first_quoted_value "$line")
      fi
      if [[ "$line" == '- **Ad group:**'* ]]; then
        kw_adgroup=$(_first_quoted_value "$line")
      fi
      if [[ "$line" == '- **Match type:**'* ]]; then
        kw_match_type=$(echo "$line" | sed 's/.*\*\*Match type:\*\* *//' | tr '[:lower:]' '[:upper:]')
      fi
      if [[ "$line" == '- **Current status:**'* ]]; then
        kw_status=$(echo "$line" | sed 's/.*\*\*Current status:\*\* *//' | tr '[:lower:]' '[:upper:]')
      fi
      if [[ "$line" == '- **Problem:**'* ]]; then
        kw_reason=$(echo "$line" | sed 's/.*\*\*Problem:\*\* *//' | head -c 200)
      fi
    done <<< "$section_kw_pause"

    # Don't forget the last block
    if [ -n "$kw_keyword" ] && [ "$kw_status" = "ENABLED" ]; then
      actions=$(echo "$actions" | jq \
        --arg kw "$kw_keyword" \
        --arg mt "${kw_match_type:-EXACT}" \
        --arg campaign "$kw_campaign" \
        --arg adgroup "$kw_adgroup" \
        --arg reason "$kw_reason" \
        '. + [{
          index: (length + 200),
          type: "PAUSE_KEYWORD",
          keyword: $kw,
          match_type: ($mt | ascii_upcase),
          scope: "AD_GROUP",
          campaign: $campaign,
          adgroup: $adgroup,
          reason: $reason
        }]')
    fi
  fi

  # ─── Parse ad group pauses from pause-draft template (Section B) ───
  local section_ag_pause
  section_ag_pause=$(sed -n '/^## Section B: Ad Groups to PAUSE/,/^## Section [C-Z]/p' "$draft_file" | sed '$d')

  if [ -n "$section_ag_pause" ]; then
    local ag_name="" ag_campaign="" ag_reason="" ag_status=""

    while IFS= read -r line; do
      # Header: ### Ad Group Pause 1: "High-Intent Buyers"
      if [[ "$line" =~ ^###\ Ad\ Group\ Pause\ [0-9]+: ]]; then
        # Save previous block
        if [ -n "$ag_name" ] && [ "$ag_status" = "ENABLED" ]; then
          actions=$(echo "$actions" | jq \
            --arg ag "$ag_name" \
            --arg campaign "$ag_campaign" \
            --arg reason "$ag_reason" \
            '. + [{
              index: (length + 300),
              type: "PAUSE_ADGROUP",
              keyword: $ag,
              match_type: "N/A",
              scope: "AD_GROUP",
              campaign: $campaign,
              adgroup: $ag,
              reason: $reason
            }]')
        fi

        ag_name=$(_first_quoted_value "$line")
        ag_campaign=""
        ag_reason=""
        ag_status=""
      fi

      # Field parsing
      if [[ "$line" == '- **Campaign:**'* ]]; then
        ag_campaign=$(_first_quoted_value "$line")
      fi
      if [[ "$line" == '- **Current status:**'* ]]; then
        ag_status=$(echo "$line" | sed 's/.*\*\*Current status:\*\* *//' | tr '[:lower:]' '[:upper:]')
      fi
      if [[ "$line" == '- **Problem:**'* ]]; then
        ag_reason=$(echo "$line" | sed 's/.*\*\*Problem:\*\* *//' | head -c 200)
      fi
    done <<< "$section_ag_pause"

    # Don't forget the last block
    if [ -n "$ag_name" ] && [ "$ag_status" = "ENABLED" ]; then
      actions=$(echo "$actions" | jq \
        --arg ag "$ag_name" \
        --arg campaign "$ag_campaign" \
        --arg reason "$ag_reason" \
        '. + [{
          index: (length + 300),
          type: "PAUSE_ADGROUP",
          keyword: $ag,
          match_type: "N/A",
          scope: "AD_GROUP",
          campaign: $campaign,
          adgroup: $ag,
          reason: $reason
        }]')
    fi
  fi

  echo "$actions"
}

# Main: parse a draft file into a complete action list
parse_draft() {
  local draft_file="$1"

  if [ ! -f "$draft_file" ]; then
    echo "ERROR: Draft file not found: $draft_file" >&2
    return 1
  fi

  local header negatives pauses pause_sections

  header=$(parse_draft_header "$draft_file")
  negatives=$(_parse_section_a "$draft_file")
  pauses=$(_parse_section_d "$draft_file")
  pause_sections=$(_parse_pause_sections "$draft_file")

  # Merge all action sources and re-index
  # Dedup by type+keyword+campaign to avoid double-counting across sections
  local all_actions
  all_actions=$(echo "$negatives" "$pauses" "$pause_sections" | jq -s '
    add
    | unique_by(.type + "|" + .keyword + "|" + .match_type + "|" + .scope + "|" + .campaign + "|" + (.adgroup // ""))
    | to_entries
    | map(.value + {index: (.key + 1)})
  ')

  # Return full parsed draft
  jq -n \
    --argjson header "$header" \
    --argjson actions "$all_actions" \
    --arg draft_file "$draft_file" \
    '{
      draft_file: $draft_file,
      customer_id: $header.customer_id,
      customer_name: $header.customer_name,
      status: $header.status,
      action_count: ($actions | length),
      actions: $actions
    }'
}
