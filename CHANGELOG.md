# Changelog

## 0.4.0 — Public Alpha (Builder Preview) — 2026-03-15

### Highlights
- **All three layers are live.** Read → Draft → Apply — the full architecture is operational with real write-back to Google Ads API v20.
- **Publish-prep polish pass.** Public-facing materials sanitized, demo workflow defined, examples curated.

### Apply Layer (v1)
- CLI scripts for safe write-back: `gads-apply.sh`, `gads-undo.sh`, `gads-review.sh`, `gads-status.sh`, `gads-smoke-test.sh`
- v1 scope: add negative keywords (campaign + ad group), pause keywords, pause ad groups
- Full safety model: dry run → human confirm → execute → GAQL verify → audit trail → reversal registry
- Bash + curl + jq only — no Python/Node runtime dependency
- API v20 (v18 sunset, v19 unstable)
- End-to-end write cycle proven on live accounts

### New Skills
- `google-ads-apply` — safe write execution with draft parsing
- `google-ads-draft-summary` — prioritized summary of all pending drafts with apply order
- `google-ads-landing-review` — landing page → conversion path diagnosis (Two-Fork model: tracking vs UX)

### New Documents
- `OPERATOR-PLAYBOOK.md` — full operator workflow loop (connect → apply → undo)
- `DEMO-WORKFLOW.md` — blessed happy-path walkthrough for demos and onboarding
- `PUBLISH-CHECKLIST.md` — sanitization and release checklist

### Infrastructure
- `.gitignore` — covers credentials, live workspace data, internal-only files
- `examples/internal/` — real-account test examples separated from public-facing examples
- Sanitized all public-facing docs (README, OPERATOR-PLAYBOOK, ARCHITECTURE, examples)

### Pause Support
- Keyword pause + ad group pause fully scaffolded (parser, template, validation, verification)
- Pause draft template: `drafts/templates/pause-draft.md`

---

## 0.3.0 — Connected Mode Live Testing — 2026-03-14

### Highlights
- First live connected-mode tests against real Google Ads accounts
- Intent Map validated on real data — confirmed as most valuable artifact
- Connected-mode onboarding via `google-ads-connect` skill

### Connected Mode
- `google-ads-connect` skill: first-time setup, health check, account selection
- Customer discovery via `list_accessible_customers`
- Account fingerprint written to `workspace/ads/account.md`
- Date range fallback chain: LAST_30_DAYS → LAST_90_DAYS → LAST_12_MONTHS → all time
- `keyword_view` supplementation alongside `search_term_view`

### Intent Map Validation
- Tested against real accounts in connected mode
- Framework transfers well across industries (SaaS, local services, B2B equipment)
- Structural implications section is the key differentiator
- Documented as the most valuable analytical artifact in the package

### Tracking Confidence
- Explicit threshold rubric with decision matrix
- Tracking confidence gates budget/bid decisions (LOW/BROKEN blocks scaling)
- Conv:all_conv ratio threshold (2x = healthy)
- Store visit pollution detection

### Negative Lifecycle
- Three-section template: Add, Remove, Narrow/Move
- Catches harmful existing negatives
- Keyword cross-referencing: identifies which keywords generate waste

### Landing Page Diagnosis
- Two-Fork model: Fork A (tracking broken?) → Fork B (UX broken?)
- Scenario classification: tracking-only, UX-only, both, traffic quality
- Conversion path walking: traces click → landing → CTA → form → conversion

---

## 0.2.0 — Three-Layer Wiring

### Highlights
- Defined Read → Draft → Apply three-layer architecture
- All skills wired with connected + export mode
- Draft system with templates, lifecycle, and queue

### Architecture
- `ARCHITECTURE.md` — full design document
- Connected mode: GAQL queries via `googleads/google-ads-mcp` MCP server
- Export mode: graceful fallback to CSV/paste data
- Draft system: templates, lifecycle, index, dependency tracking

### Skills
- All 11 original skills updated with data acquisition + draft output
- Orchestrator updated with data + draft protocols
- Tracking confidence flows through to gate budget decisions

### Data Layer
- `data/mcp-config.md` — MCP server setup instructions
- `data/gaql-recipes.md` — GAQL query library per skill
- `data/export-formats.md` — manual export specifications

---

## 0.1.0 — Initial Package

- Package skeleton with orchestrator and core skills
- Reference playbooks: operator thesis, intent map, query patterns, negatives, tracking, structure, RSA, budget
- Workspace memory templates
- Eval scaffold
- Specialist agents
