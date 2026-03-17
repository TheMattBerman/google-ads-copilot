#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_TARGET="${CLAUDE_TARGET:-${HOME}/.claude/skills}"
MODE="${1:-auto}"
SOURCE_ROOT="$ROOT_DIR"
TEMP_SOURCE_DIR=""

cleanup() {
  if [ -n "$TEMP_SOURCE_DIR" ] && [ -d "$TEMP_SOURCE_DIR" ]; then
    rm -rf "$TEMP_SOURCE_DIR"
  fi
}
trap cleanup EXIT

resolve_source_root() {
  local candidate="$1"

  if [ -d "$candidate" ]; then
    echo "$(cd "$candidate" && pwd)"
    return 0
  fi

  if [ -f "$candidate" ]; then
    TEMP_SOURCE_DIR="$(mktemp -d)"
    tar -xzf "$candidate" -C "$TEMP_SOURCE_DIR"
    local extracted_root
    extracted_root=$(find "$TEMP_SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -z "$extracted_root" ]; then
      echo "Failed to locate extracted bundle root in $candidate" >&2
      exit 1
    fi
    echo "$extracted_root"
    return 0
  fi

  echo "Bundle path not found: $candidate" >&2
  exit 1
}

if [ $# -gt 0 ] && [ -e "$1" ]; then
  SOURCE_ROOT="$(resolve_source_root "$1")"
  MODE="${2:-auto}"
fi

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
  copy_tree "$SOURCE_ROOT/google-ads" "$CLAUDE_TARGET/google-ads"
  for skill_dir in "$SOURCE_ROOT"/skills/*; do
    name="$(basename "$skill_dir")"
    copy_tree "$skill_dir" "$CLAUDE_TARGET/$name"
  done
}

install_openclaw_local_bundle() {
  echo "Installing bundled package into $OPENCLAW_TARGET"
  mkdir -p "$OPENCLAW_TARGET"
  copy_tree "$SOURCE_ROOT/google-ads" "$OPENCLAW_TARGET/google-ads"
  copy_tree "$SOURCE_ROOT/skills" "$OPENCLAW_TARGET/skills"
  copy_tree "$SOURCE_ROOT/drafts" "$OPENCLAW_TARGET/drafts"
  copy_tree "$SOURCE_ROOT/evals" "$OPENCLAW_TARGET/evals"
  copy_tree "$SOURCE_ROOT/workspace-template" "$OPENCLAW_TARGET/workspace-template"
  copy_tree "$SOURCE_ROOT/scripts" "$OPENCLAW_TARGET/scripts"

  # Data layer — copy docs but exclude credentials
  mkdir -p "$OPENCLAW_TARGET/data"
  for f in "$SOURCE_ROOT"/data/*.md; do
    [ -f "$f" ] && cp "$f" "$OPENCLAW_TARGET/data/"
  done

  # Examples — public only (exclude internal/)
  mkdir -p "$OPENCLAW_TARGET/examples"
  for f in "$SOURCE_ROOT"/examples/*.md; do
    [ -f "$f" ] && cp "$f" "$OPENCLAW_TARGET/examples/"
  done

  # Top-level docs
  cp "$SOURCE_ROOT"/README.md "$OPENCLAW_TARGET"/README.md
  cp "$SOURCE_ROOT"/ARCHITECTURE.md "$OPENCLAW_TARGET"/ARCHITECTURE.md
  cp "$SOURCE_ROOT"/APPLY-LAYER.md "$OPENCLAW_TARGET"/APPLY-LAYER.md 2>/dev/null || true
  cp "$SOURCE_ROOT"/OPERATOR-PLAYBOOK.md "$OPENCLAW_TARGET"/OPERATOR-PLAYBOOK.md
  cp "$SOURCE_ROOT"/DEMO-WORKFLOW.md "$OPENCLAW_TARGET"/DEMO-WORKFLOW.md
  cp "$SOURCE_ROOT"/CHANGELOG.md "$OPENCLAW_TARGET"/CHANGELOG.md
  cp "$SOURCE_ROOT"/LICENSE "$OPENCLAW_TARGET"/LICENSE
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
    echo "       $0 <bundle-path> [auto|claude|openclaw]"
    echo "Override targets with CLAUDE_TARGET=... or OPENCLAW_TARGET=..."
    exit 1
    ;;
esac

echo "Done."
