# Publish Checklist — Google Ads Copilot

Use this checklist before every public release or share. The goal is to ensure no real client data, credentials, or internal-only artifacts leak into public-facing materials.

---

## 1. Credential & Secret Scan

- [ ] `data/google-ads-adc-authorized-user.json` — **MUST NOT be committed to any public repo.** Contains OAuth client_id, client_secret, and refresh_token.
- [ ] `data/google-ads-mcp.test.env.sh` — **MUST NOT be committed.** Contains developer token, project ID.
- [ ] `.env` files — check for any stray environment files with secrets.
- [ ] `scripts/` — no hardcoded customer IDs, tokens, or API keys in shell scripts.
- [ ] Verify `.gitignore` covers all credential files (see below).

### Quick scan command
```bash
# Run from project root
grep -rn "client_secret\|refresh_token\|DEVELOPER_TOKEN\|GOCSPX-\|emerald-digital" \
  --include="*.md" --include="*.sh" --include="*.json" \
  --exclude-dir=.git --exclude-dir=examples/internal . \
  | grep -v PUBLISH-CHECKLIST | grep -v .gitignore
```

---

## 2. Client Data Sanitization

### Real names / identifiers that MUST NOT appear in public files:
- Client business names (any real company name from actual accounts)
- Customer IDs (CIDs) from real accounts
- Real campaign names tied to identifiable businesses
- Real website URLs of client properties
- Dollar amounts from real accounts (generalize or anonymize)
- Employee / contact names from client organizations

### Where to check:
- [ ] `README.md` — no real client names or CIDs
- [ ] `ARCHITECTURE.md` — no real client names
- [ ] `OPERATOR-PLAYBOOK.md` — example outputs use fictional accounts
- [ ] `APPLY-LAYER.md` — example outputs use fictional accounts
- [ ] `scripts/apply-layer/README.md` — no real CIDs in examples
- [ ] `examples/*.md` (public examples) — all use fictional businesses
- [ ] `examples/internal/` — this directory is excluded from public distribution

### Fictional names safe for public use:
- **Acme Equipment Co.** (CID: 1234567890) — industrial equipment seller
- **Metro Recycling LLC** (CID: 9876543210) — local recycling facility
- **Precision CRM** — SaaS CRM for law firms (used in original synthetic examples)
- Use `example.com` domains, never real URLs

### Quick scan command
```bash
# Scan for known real-client patterns (update as needed)
grep -rn "East Coast Container\|Cooper Recyc\|Cooper Tank\|Allocco\|8468311086\|9035206178\|emerald-digital-main\|coopertank\.com\|eastcoastcontainer" \
  --include="*.md" --include="*.sh" \
  --exclude-dir=.git --exclude-dir=examples/internal --exclude-dir=workspace --exclude-dir=reports . \
  | grep -v PUBLISH-CHECKLIST
```

---

## 3. Directory Structure for Distribution

### Include in public distribution:
```
README.md
ARCHITECTURE.md
APPLY-LAYER.md
OPERATOR-PLAYBOOK.md
DEMO-WORKFLOW.md
CHANGELOG.md
LICENSE
install.sh
google-ads/              # Orchestrator skill
skills/                  # All 15 analytical skills
scripts/apply-layer/     # CLI scripts (no embedded secrets)
scripts/list-customers.sh
scripts/test-mcp.sh
data/mcp-config.md       # Setup instructions (no credentials)
data/gaql-recipes.md
data/export-formats.md
data/LIVE-TEST-CHECKLIST.md
drafts/                  # Draft templates
examples/*.md            # Public sanitized examples only
evals/
workspace-template/
```

### EXCLUDE from public distribution:
```
workspace/               # Live account data
examples/internal/       # Real-client live examples
reports/                 # Internal audit reports
data/google-ads-adc-authorized-user.json    # OAuth credentials
data/google-ads-mcp.test.env.sh             # Developer token + project
data/google-ads-mcp.openclaw.patch-example.json  # May contain project refs
data/mcporter.google-ads-mcp.patch.json     # May contain project refs
CLAUDE.md                # Internal project notes
MILESTONES.md            # Internal milestones
NEXT-IMPROVEMENTS.md     # Internal roadmap
README-OPENCLAW.md       # Internal integration notes
APPLY-IMPLEMENTATION.md  # Internal implementation notes
.claude-plugin/          # Internal plugin config
```

---

## 4. Content Quality Pass

- [ ] README.md reads as a polished project introduction, not an internal dev log
- [ ] No TODO/FIXME comments in public-facing files
- [ ] No "we tested on X's account" language — use "tested on real accounts"
- [ ] Examples feel realistic but are clearly not real companies
- [ ] OPERATOR-PLAYBOOK.md walkthrough uses fictional account names
- [ ] CHANGELOG.md is current with the latest release

---

## 5. Functional Checks

- [ ] `install.sh` runs cleanly on a fresh system
- [ ] `./install.sh auto` doesn't reference excluded files
- [ ] Skills load correctly (each SKILL.md is self-contained)
- [ ] `workspace-template/` is clean (no leftover data from real accounts)
- [ ] `evals/` runs or at least doesn't error on missing fixtures

---

## 6. Pre-Commit Automation (Recommended)

Add to `.git/hooks/pre-commit` or CI:
```bash
#!/bin/bash
# Block commits containing likely credential patterns
if git diff --cached --name-only | xargs grep -l "GOCSPX-\|refresh_token.*1//\|client_secret.*GOCSPX" 2>/dev/null; then
  echo "❌ BLOCKED: Credential-like pattern found in staged files."
  exit 1
fi

# Block commits with known real CIDs in public-facing files
if git diff --cached -- '*.md' ':!examples/internal/*' ':!workspace/*' ':!reports/*' ':!CLAUDE.md' ':!MILESTONES.md' ':!NEXT-IMPROVEMENTS.md' | grep -E '8468311086|9035206178'; then
  echo "❌ BLOCKED: Real client CID found in public-facing file."
  exit 1
fi
```

---

## Checklist Version

Last updated: 2026-03-15
Author: Publish-prep automation
