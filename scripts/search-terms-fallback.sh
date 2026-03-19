#!/usr/bin/env bash
set -euo pipefail

# Backwards-compatible wrapper.
# Prefer: ./scripts/search-terms-retrieval.sh <customer-id>
# See data/search-term-retrieval.md for the shared retrieval ladder spec.
exec "$(dirname "$0")/search-terms-retrieval.sh" "$@"
