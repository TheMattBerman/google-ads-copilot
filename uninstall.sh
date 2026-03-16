#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_TARGET="${CLAUDE_TARGET:-${HOME}/.claude/skills}"
MODE="${1:-auto}"

resolve_openclaw_target() {
  if [ -n "${OPENCLAW_TARGET:-}" ]; then
    echo "$OPENCLAW_TARGET"
  elif [ -d "${HOME}/clawd/skills/local" ]; then
    echo "${HOME}/clawd/skills/local/google-ads-copilot"
  elif [ -d "${HOME}/openclaw/skills/local" ]; then
    echo "${HOME}/openclaw/skills/local/google-ads-copilot"
  else
    echo "${HOME}/openclaw/skills/local/google-ads-copilot"
  fi
}

OPENCLAW_TARGET="$(resolve_openclaw_target)"

remove_claude_style() {
  echo "Removing Claude/OpenClaw-compatible skill dirs from $CLAUDE_TARGET"
  rm -rf "$CLAUDE_TARGET/google-ads"
  for skill_dir in "$ROOT_DIR"/skills/*; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
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
    echo "Override targets with CLAUDE_TARGET=... or OPENCLAW_TARGET=..."
    exit 1
    ;;
esac

echo "Done."
