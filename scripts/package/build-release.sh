#!/usr/bin/env bash
# build-release.sh — Build a public-safe, versioned release bundle.
#
# Usage:
#   ./scripts/package/build-release.sh 0.2.0
#
# Output:
#   dist/google-ads-copilot-<version>.tar.gz
#   dist/SHA256SUMS

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${1:-$(date +%Y-%m-%d)}"

OUT_DIR="${ROOT_DIR}/dist"
STAGE_ROOT="${OUT_DIR}/stage"
STAGE_DIR="${STAGE_ROOT}/google-ads-copilot-${VERSION}"
TARBALL="${OUT_DIR}/google-ads-copilot-${VERSION}.tar.gz"
SUMS_FILE="${OUT_DIR}/SHA256SUMS"

copy_tree() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  cp -R "$src" "$dest"
}

copy_file() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
}

echo "Building release bundle: google-ads-copilot-${VERSION}"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

copy_file "${ROOT_DIR}/README.md" "${STAGE_DIR}/README.md"
copy_file "${ROOT_DIR}/ARCHITECTURE.md" "${STAGE_DIR}/ARCHITECTURE.md"
copy_file "${ROOT_DIR}/APPLY-LAYER.md" "${STAGE_DIR}/APPLY-LAYER.md"
copy_file "${ROOT_DIR}/OPERATOR-PLAYBOOK.md" "${STAGE_DIR}/OPERATOR-PLAYBOOK.md"
copy_file "${ROOT_DIR}/DEMO-WORKFLOW.md" "${STAGE_DIR}/DEMO-WORKFLOW.md"
copy_file "${ROOT_DIR}/CHANGELOG.md" "${STAGE_DIR}/CHANGELOG.md"
copy_file "${ROOT_DIR}/PUBLISH-CHECKLIST.md" "${STAGE_DIR}/PUBLISH-CHECKLIST.md"
copy_file "${ROOT_DIR}/LICENSE" "${STAGE_DIR}/LICENSE"
copy_file "${ROOT_DIR}/install.sh" "${STAGE_DIR}/install.sh"
copy_file "${ROOT_DIR}/uninstall.sh" "${STAGE_DIR}/uninstall.sh"

copy_tree "${ROOT_DIR}/google-ads" "${STAGE_DIR}/google-ads"
copy_tree "${ROOT_DIR}/skills" "${STAGE_DIR}/skills"
copy_tree "${ROOT_DIR}/scripts" "${STAGE_DIR}/scripts"
copy_tree "${ROOT_DIR}/drafts" "${STAGE_DIR}/drafts"
copy_tree "${ROOT_DIR}/evals" "${STAGE_DIR}/evals"
copy_tree "${ROOT_DIR}/workspace-template" "${STAGE_DIR}/workspace-template"

mkdir -p "${STAGE_DIR}/data"
for f in "${ROOT_DIR}"/data/*.md; do
  [ -f "$f" ] && copy_file "$f" "${STAGE_DIR}/data/$(basename "$f")"
done

mkdir -p "${STAGE_DIR}/examples"
for f in "${ROOT_DIR}"/examples/*.md; do
  [ -f "$f" ] && copy_file "$f" "${STAGE_DIR}/examples/$(basename "$f")"
done

rm -rf "${STAGE_DIR}/workspace" "${STAGE_DIR}/examples/internal" "${STAGE_DIR}/reports" || true
rm -f "${STAGE_DIR}/data/google-ads-adc-authorized-user.json" || true
rm -f "${STAGE_DIR}/data/google-ads-mcp.test.env.sh" || true

echo "Running secret/client-data scans on staged content..."

if grep -rn "GOCSPX-\\|refresh_token.*1//\\|client_secret.*GOCSPX-" \
  --include="*.md" --include="*.sh" --include="*.json" \
  --exclude="build-release.sh" \
  --exclude="build-dist.sh" \
  --exclude-dir=.git "$STAGE_DIR" \
  | grep -v "PUBLISH-CHECKLIST" >/dev/null; then
  echo "ERROR: Credential-like pattern found in staged files."
  exit 1
fi

if grep -rn "East Coast Container\\|Cooper Recyc\\|Cooper Tank\\|Allocco\\|8468311086\\|9035206178\\|coopertank\\.com\\|eastcoastcontainer" \
  --include="*.md" --include="*.sh" \
  --exclude="build-release.sh" \
  --exclude="build-dist.sh" \
  --exclude-dir=.git "$STAGE_DIR" \
  | grep -v "PUBLISH-CHECKLIST" >/dev/null; then
  echo "ERROR: Known real-client identifier found in staged files."
  exit 1
fi

echo "Packaging tarball..."
mkdir -p "$OUT_DIR"
tar -czf "$TARBALL" -C "$STAGE_ROOT" "google-ads-copilot-${VERSION}"

echo "Writing checksums..."
rm -f "$SUMS_FILE"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$OUT_DIR" && sha256sum "$(basename "$TARBALL")" > "$(basename "$SUMS_FILE")")
else
  (cd "$OUT_DIR" && shasum -a 256 "$(basename "$TARBALL")" > "$(basename "$SUMS_FILE")")
fi

echo "OK:"
echo "  ${TARBALL}"
echo "  ${SUMS_FILE}"
