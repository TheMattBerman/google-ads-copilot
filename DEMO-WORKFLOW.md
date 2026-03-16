# Demo Workflow — Google Ads Copilot

This is the full end-to-end walkthrough: connect an account, see what the agent finds, review its draft proposals, apply a change, and undo it. About 25 minutes with a live account.

The "aha moment" usually hits at Step 4 — when the Intent Map shows you how many different realities a single campaign is buying at once.

---

## Prerequisites

1. **Google Ads account** with at least 30 days of search campaign data
2. **Developer token** (basic access is fine — [get one here](https://developers.google.com/google-ads/api/docs/get-started/dev-token))
3. **OAuth credentials** configured per `data/mcp-config.md`
4. **Package installed:** `./install.sh auto`
5. **MCP server working:** `./scripts/test-mcp.sh` returns green

No API access? Skip to [Export Mode Demo](#export-mode-demo-no-api-needed) — the analysis is the same, you just paste a CSV.

---

## Connected Mode Demo (~25 minutes)

### Step 1: Connect and Select Account

```
/google-ads connect setup
```

**What happens:** The agent verifies MCP connectivity, lists all accessible accounts, and lets you pick one. An account fingerprint is written to `workspace/ads/account.md`.

**What to look for:**
- ✅ MCP server responding
- ✅ OAuth token valid
- ✅ Account list populated
- Account fingerprint saved

### Step 2: Run the Daily Check

```
/google-ads daily
```

**What happens:** A fast operator briefing — the agent pulls live metrics, checks for bleeding campaigns, identifies waste patterns, and tells you what needs attention today.

**What to look for:**
- Account status and health flags
- Waste patterns flagged (if any)
- Tracking confidence assessment
- Clear "do next" actions

### Step 3: Run a Search Terms Analysis

```
/google-ads search-terms
```

**What happens:** The agent pulls search term and keyword data, clusters queries by intent, identifies waste, finds messaging clues, and generates a negative keyword draft.

**What to look for:**
- Intent clusters (buyer vs research vs junk)
- Waste quantification (spend on non-converting queries)
- Draft created in `workspace/ads/drafts/`
- Cross-referencing: which *keywords* are generating waste

### Step 4: Build the Intent Map

```
/google-ads intent-map
```

**What happens:** The agent classifies every search query into intent buckets — Buyer, Branded, Competitor, Mixed, Junk, Informational — and builds a durable model that persists across sessions. This is the core artifact.

**What to look for:**
- Clear intent classes with representative queries
- Performance gaps between classes (buyer vs junk cost-per-conversion can differ 10-50x)
- Structural implications: are intent classes properly separated in the campaign structure, or is everything mixed?
- **The "aha" moment:** seeing how mixed intent distorts every metric the account reports

### Step 5: Diagnose Tracking

```
/google-ads tracking
```

**What happens:** A tracking confidence rubric is applied. Conversion actions are inventoried, primary vs secondary is audited, store visit pollution is detected, and a confidence level is assigned.

**What to look for:**
- Conversion action inventory (what's counted as "primary")
- Conv:all_conv ratio (healthy is < 2x)
- Store visit or page view pollution
- Tracking confidence: HIGH / MEDIUM / LOW / BROKEN

### Step 6: Review the Draft Queue

```
/google-ads draft-summary
```

**What happens:** All pending drafts are read, classified by priority, and presented in recommended apply order with dependencies mapped.

**What to look for:**
- Priority ranking (P0 critical → P3 monitor)
- Quick wins you could apply right now
- Blocked actions (e.g., budget decisions blocked by tracking problems)
- Dependency chains between drafts

### Step 7: Apply a Draft (the payoff)

```
/google-ads apply workspace/ads/drafts/<your-negative-draft>.md
```

**What happens:**
1. Draft is parsed into structured actions
2. Dry run shows exactly what will change
3. You confirm (or cancel)
4. Changes are applied one at a time
5. Each change is verified via GAQL re-query
6. Full audit trail is written with reversal records

**What to look for:**
- Clean dry-run table
- Explicit confirmation prompt
- Per-action success/failure reporting
- Verification step confirms changes took effect
- Reversal IDs assigned to every action

### Step 8: Verify and Undo (safety net)

```
# See what was applied
/google-ads apply log

# Undo a single action if needed
/google-ads undo rev-001
```

**What to look for:**
- Full audit trail accessible
- Single-action undo works cleanly
- Verification confirms the undo took effect

---

## Export Mode Demo (no API needed)

If you don't have API access, the analytical engine works identically with pasted data.

### Step 1: Install
```bash
./install.sh auto
```

### Step 2: Export Data from Google Ads UI
1. Go to Google Ads → Keywords → Search Terms
2. Set date range to "Last 30 days"
3. Download as CSV

### Step 3: Run Search Terms Analysis
```
/google-ads search-terms
```
When prompted, paste the CSV data or provide the file path.

### Step 4: Review Intent Map
```
/google-ads intent-map
```
The agent builds the intent model from the exported data — same classification, same structural insights.

### Step 5: Review Drafts
Check `workspace/ads/drafts/` for generated proposals.

---

## What Makes a Great Demo Account

The messier the account, the more dramatic the results. The best candidates:

- **Broad match keywords** — more intent mixing = more interesting analysis
- **No negatives (or few)** — the agent finds waste that hasn't been cleaned
- **Multiple intent types in one campaign** — buyer + researcher + competitor in a single ad group
- **Questionable tracking** — store visits or page views counted as primary conversions
- **At least $500/month spend** — enough data for patterns to emerge

The worst accounts for demo: brand-only campaigns with exact match keywords and clean tracking. The agent will correctly report "not much to fix" — accurate, but not exciting.

---

## Timing

| Phase | Time | Notes |
|-------|------|-------|
| Connect + select | 2 min | Assumes setup is done |
| Daily check | 3 min | Quick scan |
| Search terms | 5 min | Core analysis |
| Intent map | 5 min | The signature artifact |
| Tracking diagnosis | 3 min | Reveals measurement truth |
| Draft summary | 2 min | Prioritized view |
| Apply + verify | 5 min | The payoff moment |
| **Total** | **~25 min** | End-to-end connected demo |

---

## Things That Land During a Demo

1. **"The account thinks it has a $5 CPA. The real CPA is $700."** — Tracking pollution is the most common revelation. The agent catches store visits, page views, and direction requests inflating primary conversions.

2. **"Look at how many different things this one ad group is buying."** — The Intent Map shows the problem visually. Buyer intent, job seekers, and comparison shoppers all in one bucket, all optimized as if they're the same.

3. **"Every recommendation is a draft you can read, approve, or reject."** — Not vague advice. Specific negatives with match types, scope, evidence, and collateral risk notes.

4. **"Watch: apply, verify, undo — 30 seconds."** — The safety model isn't theoretical. Show the full cycle live.

5. **"Run it again next week and it remembers everything."** — Intent Map, findings, learnings — the agent compounds. It doesn't start from scratch each session.
