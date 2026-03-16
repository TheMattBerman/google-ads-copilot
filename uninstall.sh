#!/usr/bin/env bash
set -euo pipefail

CLAUDE_TARGET="${HOME}/.claude/skills"
OPENCLAW_TARGET="${HOME}/clawd/skills/local/google-ads-copilot"
MODE="${1:-auto}"

remove_claude_style() {
  echo "Removing Claude/OpenClaw-compatible skill dirs from $CLAUDE_TARGET"
  rm -rf "$CLAUDE_TARGET/google-ads"
  for name in \
    google-ads-daily \
    google-ads-search-terms \
    google-ads-intent-map \
    google-ads-negatives \
    google-ads-tracking \
    google-ads-structure \
    google-ads-rsas \
    google-ads-budget \
    google-ads-plan \
    google-ads-audit \
    google-ads-pmax
  do
    rm -rf "$CLAUDE_TARGET/$name"
  done
}

remove_openclaw_bundle() {
  echo "Removing OpenClaw local bundle from $OPENCLAW_TARGET"
  rm -rf "$OPENCLAW_TARGET"
}

case "$MODE" in
  claude)
    remove_claude_style
    ;;
  openclaw)
    remove_openclaw_bundle
    ;;
  auto)
    remove_claude_style
    remove_openclaw_bundle
    ;;
  *)
    echo "Usage: $0 [auto|claude|openclaw]"
    exit 1
    ;;
esac

echo "Done."
