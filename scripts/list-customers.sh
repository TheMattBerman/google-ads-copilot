#!/usr/bin/env bash
# list-customers.sh — Discover and display all accessible Google Ads accounts
#
# Usage:
#   ./scripts/list-customers.sh
#
# Output: Table of customer IDs and names
# Prerequisites: mcporter configured with google-ads-mcp

set -euo pipefail

echo "Discovering accessible Google Ads accounts..."
echo ""

if ! command -v mcporter &>/dev/null; then
  echo "Error: mcporter not found. Install: npm install -g mcporter"
  exit 1
fi

RESULT=$(mcporter call google-ads-mcp list_accessible_customers '{}' --output raw 2>&1)

if [ $? -ne 0 ]; then
  echo "Error calling MCP server:"
  echo "$RESULT"
  echo ""
  echo "Check your MCP configuration — see data/mcp-config.md"
  exit 1
fi

echo "Accessible Accounts:"
echo "═══════════════════════════════════════════"
echo "$RESULT"
echo "═══════════════════════════════════════════"
echo ""
echo "To test a specific account:"
echo "  ./scripts/test-mcp.sh <customer_id>"
echo ""
echo "To start an audit:"
echo "  /google-ads connect select <customer_id>"
echo "  /google-ads audit"
