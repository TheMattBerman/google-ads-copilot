#!/usr/bin/env bash
# config.sh — Shared configuration for the apply layer
#
# Source this file from all apply-layer scripts.
# Single source of truth for API version, base URL, and common settings.

# Google Ads REST API version
# Updated 2026-03-15: v18 sunset (404), v19 unstable (500), v20 confirmed working
GADS_API_VERSION="v20"
GADS_API_BASE="https://googleads.googleapis.com/${GADS_API_VERSION}"

# Rate limiting
GADS_MUTATION_DELAY_MS=500    # Delay between mutations (milliseconds)
GADS_MAX_ACTIONS_PER_SESSION=50

# Token cache location
GADS_TOKEN_CACHE="/tmp/gads-copilot-token.json"

# Escape a string for safe use in GAQL WHERE clauses
# Handles single quotes by doubling them (GAQL escaping)
_gaql_escape() {
  local input="$1"
  echo "${input//\'/\'\'}"
}
