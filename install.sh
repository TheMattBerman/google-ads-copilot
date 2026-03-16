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

copy_tree() {
  local src="$1"
  local dest="$2"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
}

install_claude_style() {
  echo "Installing Claude/OpenClaw-compatible skill directories into $CLAUDE_TARGET"
  mkdir -p "$CLAUDE_TARGET"
  copy_tree "$ROOT_DIR/google-ads" "$CLAUDE_TARGET/google-ads"
  for skill_dir in "$ROOT_DIR"/skills/*; do
    name="$(basename "$skill_dir")"
    copy_tree "$skill_dir" "$CLAUDE_TARGET/$name"
  done
}

install_openclaw_local_bundle() {
  echo "Installing bundled package into $OPENCLAW_TARGET"
  mkdir -p "$OPENCLAW_TARGET"
  copy_tree "$ROOT_DIR/google-ads" "$OPENCLAW_TARGET/google-ads"
  copy_tree "$ROOT_DIR/skills" "$OPENCLAW_TARGET/skills"
  copy_tree "$ROOT_DIR/drafts" "$OPENCLAW_TARGET/drafts"
  copy_tree "$ROOT_DIR/evals" "$OPENCLAW_TARGET/evals"
  copy_tree "$ROOT_DIR/workspace-template" "$OPENCLAW_TARGET/workspace-template"
  copy_tree "$ROOT_DIR/scripts" "$OPENCLAW_TARGET/scripts"

  # Data layer — copy docs but exclude credentials
  mkdir -p "$OPENCLAW_TARGET/data"
  for f in "$ROOT_DIR"/data/*.md; do
    [ -f "$f" ] && cp "$f" "$OPENCLAW_TARGET/data/"
  done

  # Examples — public only (exclude internal/)
  mkdir -p "$OPENCLAW_TARGET/examples"
  for f in "$ROOT_DIR"/examples/*.md; do
    [ -f "$f" ] && cp "$f" "$OPENCLAW_TARGET/examples/"
  done

  # Top-level docs
  cp "$ROOT_DIR"/README.md "$OPENCLAW_TARGET"/README.md
  cp "$ROOT_DIR"/ARCHITECTURE.md "$OPENCLAW_TARGET"/ARCHITECTURE.md
  cp "$ROOT_DIR"/APPLY-LAYER.md "$OPENCLAW_TARGET"/APPLY-LAYER.md 2>/dev/null || true
  cp "$ROOT_DIR"/OPERATOR-PLAYBOOK.md "$OPENCLAW_TARGET"/OPERATOR-PLAYBOOK.md
  cp "$ROOT_DIR"/DEMO-WORKFLOW.md "$OPENCLAW_TARGET"/DEMO-WORKFLOW.md
  cp "$ROOT_DIR"/CHANGELOG.md "$OPENCLAW_TARGET"/CHANGELOG.md
  cp "$ROOT_DIR"/LICENSE "$OPENCLAW_TARGET"/LICENSE
}

case "$MODE" in
  claude)
    install_claude_style
    ;;
  openclaw)
    install_openclaw_local_bundle
    ;;
  auto)
    install_claude_style
    install_openclaw_local_bundle
    ;;
  *)
    echo "Usage: $0 [auto|claude|openclaw]"
    echo "Override targets with CLAUDE_TARGET=... or OPENCLAW_TARGET=..."
    exit 1
    ;;
esac

echo "Done."
