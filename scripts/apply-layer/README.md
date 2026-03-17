# Apply Layer — CLI Scripts

## Status: LIVE — Write Access Confirmed
API v20 confirmed working 2026-03-15 (v18 sunset/404, v19 unstable/500).
Full write cycle proven on a live account.

## Architecture

These scripts implement the Google Ads Copilot apply layer: the safe-write path
from approved drafts to real Google Ads API mutations.

**v1 scope (default):** Add negative keywords + pause keywords/ad groups.

**v2 scope (budget):** Set campaign daily budgets with hard guardrails (max % change, cooldowns, tracking gate, budget-neutral default).
Budget actions require an `## Apply Manifest` JSON block (see `drafts/ACTION-MANIFEST.md`).

### Flow

```
┌──────────────┐     ┌──────────┐     ┌─────────┐     ┌─────────┐     ┌────────┐     ┌───────┐
│ parse-draft  │ ──► │ dry-run  │ ──► │ approve │ ──► │ execute │ ──► │ verify │ ──► │ audit │
│ (read .md)   │     │ (show)   │     │ (human) │     │ (API)   │     │ (GAQL) │     │ (log) │
└──────────────┘     └──────────┘     └─────────┘     └─────────┘     └────────┘     └───────┘
```

### Scripts

| Script | Purpose |
|--------|---------|
| `gads-apply.sh` | Main entry point — orchestrates the full apply flow |
| `gads-undo.sh` | Reverse a single action or full draft |
| `gads-review.sh` | Review a draft without applying — action breakdown + risk |
| `gads-status.sh` | Operator state overview — connection, drafts, reversals |
| `gads-auth.sh` | Get/refresh OAuth2 access token, test API connectivity |
| `gads-smoke-test.sh` | End-to-end write cycle test (`negative` or `budget` mode) |
| `lib/config.sh` | Shared config: API version, base URL, GAQL escaping helpers |
| `lib/parse-draft.sh` | Extract structured actions from draft markdown (negatives + pauses) |
| `lib/api-mutate.sh` | Execute a single Google Ads API mutation |
| `lib/api-verify.sh` | Verify a mutation took effect via GAQL query + ID lookups |
| `lib/audit-write.sh` | Write audit trail entries |
| `lib/token-refresh.sh` | OAuth2 token refresh helper |

### Prerequisites

- `jq` — JSON processing
- `curl` — API calls
- OAuth2 credentials saved to a local file based on `data/google-ads-adc-authorized-user.template.json`
- Developer token in env: `GOOGLE_ADS_DEVELOPER_TOKEN`
- Account configured in `workspace/ads/account.md`

### Quick Start

```bash
# Create local credential/env files from the public templates
cp data/google-ads-adc-authorized-user.template.json data/google-ads-adc-authorized-user.json
cp data/google-ads-mcp.test.env.example.sh data/google-ads-mcp.test.env.sh

# Fill in your real values, then source the local env file
source data/google-ads-mcp.test.env.sh

# Check operator status (what's connected, pending, applied)
./scripts/apply-layer/gads-status.sh

# Run smoke test (proves write cycle works)
./scripts/apply-layer/gads-smoke-test.sh negative <YOUR_CID>
./scripts/apply-layer/gads-smoke-test.sh budget <YOUR_CID> [campaign_id]

# Check auth
./scripts/apply-layer/gads-auth.sh

# Review a draft without applying (no API calls)
./scripts/apply-layer/gads-review.sh workspace/ads/drafts/<your-draft>.md

# Review all pending drafts
./scripts/apply-layer/gads-review.sh --all

# Dry run only (resolves IDs via API but doesn't mutate)
./scripts/apply-layer/gads-apply.sh --dry-run workspace/ads/drafts/<your-draft>.md

# Apply a draft (full flow: parse → validate → dry-run → confirm → execute → verify → audit)
./scripts/apply-layer/gads-apply.sh workspace/ads/drafts/<your-draft>.md

# List active reversals
./scripts/apply-layer/gads-undo.sh --list

# Undo a specific action
./scripts/apply-layer/gads-undo.sh rev-001

# Undo an entire draft
./scripts/apply-layer/gads-undo.sh --draft workspace/ads/drafts/<your-draft>.md
```

### API Version History

| Version | Status | Notes |
|---------|--------|-------|
| v18 | ❌ 404 | Sunset — no longer accessible |
| v19 | ❌ 500 | Unstable — server errors |
| **v20** | ✅ 200 | **Current** — confirmed working 2026-03-15 |

The API version is centralized in `lib/config.sh`. To upgrade, change it once there.

### Design Constraints

1. **bash + curl + jq only** — no Python/Node runtime dependency
2. **No MCP dependency for writes** — direct REST API (MCP is read-only today)
3. **Idempotent** — re-running on an already-applied draft skips applied actions
4. **Atomic logging** — audit trail written per-action, not batched
5. **Fail-forward** — one failed action doesn't block the rest
6. **GAQL-safe** — all query string values escaped via `_gaql_escape()`
7. **Manifest-first for new writes** — budget writes come from `## Apply Manifest`, with legacy markdown parsing kept for v1 draft types

### Public Repo Note

The repo intentionally excludes any real credential or test files. Only safe templates are committed:

- `data/google-ads-adc-authorized-user.template.json`
- `data/google-ads-mcp.test.env.example.sh`

Create your own local copies before running live tests.

### Supported Endpoints (v20)

| Endpoint | Operation | Status |
|----------|-----------|--------|
| `customers/{cid}/campaignCriteria:mutate` | CREATE (add campaign negative) | ✅ Tested |
| `customers/{cid}/campaignCriteria:mutate` | REMOVE (undo campaign negative) | ✅ Tested |
| `customers/{cid}/adGroupCriteria:mutate` | CREATE (add ad group negative) | ✅ Scaffolded |
| `customers/{cid}/adGroupCriteria:mutate` | UPDATE status→PAUSED (pause keyword) | ✅ Scaffolded |
| `customers/{cid}/adGroupCriteria:mutate` | UPDATE status→ENABLED (undo keyword pause) | ✅ Scaffolded |
| `customers/{cid}/adGroupCriteria:mutate` | REMOVE (undo ad group negative) | ✅ Scaffolded |
| `customers/{cid}/adGroups:mutate` | UPDATE status→PAUSED (pause ad group) | ✅ Scaffolded |
| `customers/{cid}/adGroups:mutate` | UPDATE status→ENABLED (undo ad group pause) | ✅ Scaffolded |
| `customers/{cid}/googleAds:searchStream` | GAQL queries (verify, lookup) | ✅ Tested |
| `customers:listAccessibleCustomers` | Account discovery | ✅ Tested |
