#!/usr/bin/env bash
# token-refresh.sh — OAuth2 token refresh for Google Ads API
#
# Usage:
#   source lib/token-refresh.sh
#   ACCESS_TOKEN=$(get_access_token)
#
# Reads credentials from GOOGLE_APPLICATION_CREDENTIALS (authorized_user JSON).
# Caches token in /tmp/gads-copilot-token.json with expiry tracking.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared config (provides GADS_TOKEN_CACHE)
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh"

TOKEN_CACHE="${GADS_TOKEN_CACHE}"
TOKEN_ENDPOINT="https://oauth2.googleapis.com/token"

# Extract OAuth2 credentials from the authorized_user JSON
_read_creds() {
  local creds_file="${GOOGLE_APPLICATION_CREDENTIALS:-}"
  if [ -z "$creds_file" ] || [ ! -f "$creds_file" ]; then
    echo "ERROR: GOOGLE_APPLICATION_CREDENTIALS not set or file missing" >&2
    return 1
  fi

  local cred_type
  cred_type=$(jq -r '.type // empty' "$creds_file")
  if [ "$cred_type" != "authorized_user" ]; then
    echo "ERROR: Credentials file type is '$cred_type', expected 'authorized_user'" >&2
    echo "       The apply layer requires OAuth2 user credentials (not service account)" >&2
    return 1
  fi

  CLIENT_ID=$(jq -r '.client_id' "$creds_file")
  CLIENT_SECRET=$(jq -r '.client_secret' "$creds_file")
  REFRESH_TOKEN=$(jq -r '.refresh_token' "$creds_file")
}

# Check if cached token is still valid (with 60s margin)
_token_valid() {
  if [ ! -f "$TOKEN_CACHE" ]; then
    return 1
  fi

  local expires_at
  expires_at=$(jq -r '.expires_at // 0' "$TOKEN_CACHE" 2>/dev/null)
  local now
  now=$(date +%s)

  if [ "$((expires_at - 60))" -gt "$now" ]; then
    return 0
  fi
  return 1
}

# Refresh the access token
_refresh_token() {
  _read_creds

  local response
  response=$(curl -s -X POST "$TOKEN_ENDPOINT" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_secret=${CLIENT_SECRET}" \
    -d "refresh_token=${REFRESH_TOKEN}" \
    -d "grant_type=refresh_token")

  local access_token
  access_token=$(echo "$response" | jq -r '.access_token // empty')

  if [ -z "$access_token" ]; then
    echo "ERROR: Token refresh failed:" >&2
    echo "$response" | jq '.' >&2
    return 1
  fi

  local expires_in
  expires_in=$(echo "$response" | jq -r '.expires_in // 3600')
  local now
  now=$(date +%s)
  local expires_at=$((now + expires_in))

  # Cache the token
  jq -n \
    --arg token "$access_token" \
    --argjson expires_at "$expires_at" \
    --arg refreshed_at "$(date -Iseconds)" \
    '{access_token: $token, expires_at: $expires_at, refreshed_at: $refreshed_at}' \
    > "$TOKEN_CACHE"

  chmod 600 "$TOKEN_CACHE"
}

# Main entry: get a valid access token (refresh if needed)
get_access_token() {
  if ! _token_valid; then
    _refresh_token
  fi
  jq -r '.access_token' "$TOKEN_CACHE"
}
