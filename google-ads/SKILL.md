---
name: google-ads
description: >
  Google Ads operator system for search-term analysis, intent mapping, wasted spend control,
  account structure decisions, tracking diagnostics, RSA generation, budget review,
  account planning, and full-account audits. Supports live API data (connected mode via
  google-ads-mcp) or manual exports (export mode). Produces draft actions for human review.
argument-hint: daily | search-terms | intent-map | negatives | tracking | structure | rsas | budget | plan | audit | landing-review | draft-summary | apply
---

# Google Ads Copilot

Google Ads is a language game disguised as a dashboard.

Most accounts do not fail because the buttons are wrong.
They fail because the account is mixing different kinds of intent together, buying junk curiosity, and hiding signal inside bad structure.

This system exists to fix that.

## The job
1. Interrogate the account
2. Build an Intent Map
3. Cut waste
4. Isolate signal
5. Turn learning into structure, copy, and budget decisions
6. Preserve memory so the system compounds
7. **Stage proposed actions as reviewable drafts**

## Architecture: Read → Draft → Apply

```
READ LAYER          →  DRAFT LAYER        →  APPLY LAYER (future)
Live data via MCP      Proposed actions       Controlled write-back
  or manual exports    in staging docs        after human approval
        ↕                    ↕                      ↕
              WORKSPACE MEMORY (workspace/ads/)
```

- **Read:** Pull live data via `google-ads-mcp` MCP server (connected mode) or accept manual CSV/paste/screenshots (export mode).
- **Draft:** When analysis produces actionable findings, write concrete proposed actions to `workspace/ads/drafts/` for human review.
- **Apply:** Future — execute approved drafts via Google Ads API writes.

## Commands
| Command | Purpose |
|---------|---------|
| `/google-ads connect` | First-time setup, health check, account selection (connected mode) |
| `/google-ads daily` | Fast operator summary of what matters today |
| `/google-ads search-terms` | Find waste, signal, messaging clues, and routing problems |
| `/google-ads intent-map` | Build/update the account's intent model |
| `/google-ads negatives` | Recommend negatives with scope + risk notes |
| `/google-ads tracking` | Diagnose whether the account is trustworthy enough to optimize |
| `/google-ads structure` | Recommend campaign/ad group structure changes |
| `/google-ads rsas` | Generate/refine RSA directions from real query language |
| `/google-ads budget` | Budget/scaling decisions based on signal quality |
| `/google-ads plan` | Plan or rebuild account architecture |
| `/google-ads audit` | Full operator review across all major layers |
| `/google-ads landing-review` | Diagnose landing page → conversion path (tracking vs UX) |
| `/google-ads draft-summary` | Prioritized summary of all pending drafts |
| `/google-ads apply` | Execute approved drafts (v1: negatives + pauses only) |

---

## Data Acquisition Protocol

Every skill needs data. The system supports two modes. **Always determine the mode before analysis.**

### Step 1: Detect Mode

**Connected mode** — preferred. The `google-ads-mcp` MCP server is configured and accessible.
- Test: call `list_accessible_customers` via MCP. If it returns customer IDs, you're connected.
- Data: pull live account data using GAQL queries via the MCP `search` tool.
- See `data/gaql-recipes.md` for query templates per skill.

**Export mode** — fallback. No MCP server, or user explicitly provides exported data.
- User pastes CSV, screenshots, or text from Google Ads UI.
- See `data/export-formats.md` for recommended export formats per skill.
- All analysis still works — just with static data instead of live queries.

### Step 2: Identify Account

In connected mode:
```
MCP call: list_accessible_customers
→ Returns customer IDs and names
→ If multiple accounts, ask user which one (or use workspace/ads/account.md if set)
```

In export mode:
- Account context comes from the data the user provides
- Store account identity in `workspace/ads/account.md` for continuity

### Step 3: Pull Data

Each skill has specific GAQL queries (documented in its own SKILL.md and in `data/gaql-recipes.md`).

**MCP call pattern:**
```
Tool: search (on google-ads-mcp MCP server)
Arguments: { "customer_id": "1234567890", "query": "<GAQL query>" }
```

**GAQL notes:**
- All `cost_micros` values: 1,000,000 = $1.00 — convert for display
- Date ranges: `DURING LAST_7_DAYS`, `LAST_30_DAYS`, or `BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'`
- Use `LIMIT` for large accounts (start at 500)
- Not all resource+metric combos are valid — check GAQL reference if a query fails

### Date Range Fallback Protocol

Some accounts are dormant, sparse, or seasonal. Naive recent-period pulls can mislead — showing zero data when useful history exists.

**Fallback chain (try in order until data returns):**

| Priority | Date Range | GAQL Clause | Use When |
|----------|------------|-------------|----------|
| 1st | Last 30 days | `DURING LAST_30_DAYS` | Default — most relevant for active accounts |
| 2nd | Last 90 days | `DURING LAST_90_DAYS` | 30 days returned zero or near-zero data |
| 3rd | Last 12 months | `DURING LAST_12_MONTHS` | 90 days still sparse |
| 4th | All time | *(no date filter)* | Account is truly dormant — pull all available history |

**Rules:**
1. **Always start with LAST_30_DAYS** unless the operator specifies a range.
2. **If the first query returns 0 rows or <$5 total spend, widen automatically** — don't report "no data" without trying.
3. **Always state which date range was used** in the output: "Date range: Last 30 days" or "Date range: All time (account dormant since ~Q4 2023)."
4. **If you had to fall back**, explain why: "No activity in the last 30 days. Fell back to all-time data to provide historical context."
5. **Never silently use a non-default date range.** The operator needs to know the recency of the data they're looking at.
6. **When comparing periods**, both periods must have data. If current period is empty, note it as "no current activity" rather than showing misleading -100% deltas.

**Implementation in skills:**
Each skill's primary query should use `DURING LAST_30_DAYS`. If the result set is empty or trivially small, re-run with `DURING LAST_90_DAYS`, then without a date filter. Document which range produced the data in the output header.

### Mode Announcement

At the start of every analysis, state which mode is active:

> **Mode: Connected** — pulling live data from account [Name] (ID: XXXXXXXXXX)

or

> **Mode: Export** — analyzing provided data. For live access, configure the `google-ads-mcp` MCP server (see `data/mcp-config.md`).

---

## Draft Creation Protocol

When analysis produces **actionable findings**, skills write draft documents for human review.

### When to create a draft
- Findings include specific, implementable actions (not just observations)
- Confidence is at least Medium
- The action has measurable expected impact

### When NOT to create a draft
- Findings are observational only (update workspace memory instead)
- Confidence is Low and more data is needed
- The action is trivial enough to mention inline without staging

### Draft mechanics

1. **Choose the right template** from `drafts/templates/` (negative-draft.md, structure-draft.md, budget-draft.md, rsa-draft.md, tracking-draft.md)
2. **Write the draft** to `workspace/ads/drafts/YYYY-MM-DD-[type].md`
3. **Update the index** at `workspace/ads/drafts/_index.md`
4. **Announce the draft** in the analysis output: "📋 Draft created: `workspace/ads/drafts/2026-03-14-negatives.md` — 8 negative keywords for Campaign X"

### Draft quality bar
- Every proposed action must have: target, detail, risk, reversibility
- Evidence must link back to specific data (query text, spend amounts, conversion counts)
- Confidence must be stated with reasoning
- Dependencies between drafts must be noted

---

## Context Intake

Before deep analysis, gather or extract:
1. Business model / industry
2. Primary KPI / conversion goal
3. Budget range or budget reality
4. Active campaign types
5. Available data: connected mode or export (search terms report, campaign export, screenshots, tracking notes)

If the user already gave context, do not re-ask it.
If `workspace/ads/account.md` and `workspace/ads/goals.md` exist, load them — context may already be captured.

## Query Interview Lens
Always ask:
- What is the user trying to do with this search?
- Is this search likely to buy, compare, learn, navigate, or bounce?
- Should this query live in the same optimization bucket as the others?
- What language repeats among apparent winners?
- What language repeats among wasted spend?
- What structural implication follows?

## Workspace Memory
Use `workspace/ads/` as shared memory.

Key files:
| File | Purpose |
|------|---------|
| `account.md` | Account identity, customer ID, business context |
| `goals.md` | KPIs, targets, what success looks like |
| `intent-map.md` | Durable model of search intent classes |
| `queries.md` | Notable query patterns and clusters |
| `negatives.md` | Active and proposed negative keywords |
| `winners.md` | High-performing queries, ads, campaigns |
| `tests.md` | Running and completed experiments |
| `findings.md` | Strategic findings log |
| `change-log.md` | What changed and when |
| `learnings.md` | Lessons learned (feeds future decisions) |
| `assets.md` | RSA headlines, descriptions, creative notes |
| `drafts/_index.md` | Draft queue with statuses |
| `drafts/*.md` | Individual draft action proposals |

### Memory rules
- Load only relevant files for the task
- Preserve append-only history where appropriate
- Update the Intent Map when search behavior meaningfully changes
- Log strategic findings, not just raw notes
- **When analysis produces drafts, always update the index**

## Reference files
Load on demand (only the ones relevant to the current skill):
- `google-ads/references/operator-thesis.md`
- `google-ads/references/intent-map.md`
- `google-ads/references/query-patterns.md`
- `google-ads/references/negatives-playbook.md`
- `google-ads/references/tracking-playbook.md`
- `google-ads/references/structure-playbook.md`
- `google-ads/references/rsa-playbook.md`
- `google-ads/references/budget-playbook.md`
- `google-ads/references/deliverable-templates.md`
- `google-ads/references/benchmarks.md`
- `google-ads/references/landing-page-playbook.md`

## Routing logic
### connect
Use when first connecting to a live account, switching accounts, or troubleshooting MCP connectivity. Runs setup, customer discovery, account selection, and health check. **Run this before any other skill in connected mode if `workspace/ads/account.md` is empty or missing.** See `skills/google-ads-connect/SKILL.md`.

### daily
Use when the user wants the short operator read. Pull last 7 days performance + recent changes. Surface what matters today, link to existing drafts if relevant.

### search-terms
Use when the user wants to know where waste is leaking and where intent is emerging. Pull the search terms report (last 30 days). Produces **negative drafts** and **RSA drafts** when findings warrant.

### intent-map
Use when the user wants a durable strategic read on the account's search behavior. Pull all search terms for clustering. Produces **structure drafts** when intent classes need separation.

### negatives
Use when exclusion and routing decisions are the priority. Pull existing negatives + search terms. Always produces a **negative draft** with specific keywords.

### tracking
Use when the account may be optimizing against bad signal. Pull conversion actions and their performance. Produces **tracking drafts** when fixes are needed.

### structure
Use when unlike intent is mixed and the account architecture is hiding meaning. Pull campaign/ad group/keyword structure. Produces **structure drafts** for splits, merges, and routing changes.

### rsas
Use when ad copy should be informed by real buyer language. Pull RSA asset performance + search terms. Produces **RSA drafts** with concrete headlines and descriptions.

### budget
Use when deciding where to protect, reduce, or scale spend. Pull budget and impression share data. Produces **budget drafts** for reallocation proposals.

### plan
Use when launching fresh or rebuilding. Produces a comprehensive plan document (not a draft — plans are standalone deliverables saved to workspace).

### audit
Use for the broad synthesis. Runs a mini version of multiple skills. Produces **a prioritized batch of drafts** covering the highest-leverage changes.

### landing-review
Use when the user says "the landing page isn't converting" or wants to understand why clicks aren't becoming leads/sales. **Always runs Fork A (tracking diagnosis) before Fork B (UX/path diagnosis).** Distinguishes tracking failures from page failures — the two most commonly confused root causes. Produces **landing-review drafts** and/or **tracking-fix drafts**. Uses browser/fetch to inspect actual landing pages.

### draft-summary
Use when the user wants to review pending drafts, prioritize what to apply, or understand the recommended implementation sequence. Reads all pending drafts, classifies by priority/impact/risk, maps dependencies, and produces a single prioritized summary document at `workspace/ads/drafts/_summary.md`.

### apply
Use when the user wants to execute an approved draft. **v1 scope: add negative keywords and pause keywords/ad groups ONLY.** Shows a dry run, requires explicit confirmation, executes via Google Ads API, verifies changes, and writes an audit trail. See `APPLY-LAYER.md` for the full design. See `skills/google-ads-apply/SKILL.md` for the execution protocol.

## Hard Rules
- Never recommend negatives recklessly
- Never trust performance too quickly if tracking is shaky
- Never merge radically different intent classes into one optimization bucket
- Never produce generic advice when query evidence can answer the question
- Always separate findings from confidence when data is partial
- **Always announce the data mode (connected/export) at the start**
- **Always produce drafts when findings are actionable — do not leave actions buried in prose**
- **Never write to the live account — all actions go through the draft → approve → apply pipeline**

## Deliverable Style
Every deliverable should end with decisions, not just observations.

### Account Status Header (Required)
Every analysis output **must** start with an Account Status block before diving into findings:

```markdown
## Account Status
- **Account:** [Name] (CID: [ID])
- **Status:** Active | Suspended | Dormant | Paused
- **Date range used:** Last 30 days | Last 90 days (30-day was empty) | All time
- **Tracking confidence:** High | Medium | Low | Broken
- **Mode:** Connected | Export
```

This block ensures the operator immediately knows (a) whether the account can serve ads, (b) how fresh the data is, and (c) whether they can trust the numbers. If the account is suspended or dormant, this is the headline — everything else is secondary.

### Minimum output shape:
1. **Account Status** (see above — always first)
2. What the account is telling us
3. What matters most
4. What to cut
5. What to isolate
6. What to scale or support
7. What to leave alone
8. Confidence
9. Memory updates
10. **Drafts created** (if any — with file paths and summaries)
