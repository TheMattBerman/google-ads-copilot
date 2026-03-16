# Google Ads Copilot

> **Public Alpha — Builder Preview**
> I built an OpenClaw agent that manages Google Ads accounts through intent analysis instead of bid automation. All three layers — Read → Draft → Apply — are live and tested on real accounts. This is an early release for builders and agencies who want to try the intent-first approach.

Most Google Ads problems are not bid problems.
They are **intent-mixing problems**.

Your account is buying different kinds of searches — buyers, comparison shoppers, researchers, job seekers, freebie hunters — and mixing them together. When that happens, bids optimize against noise, RSAs get generic, good traffic subsidizes bad traffic, and every budget decision is distorted.

Google Ads Copilot is an AI agent that reads search behavior, builds a durable Intent Map, finds waste, isolates signal, and turns what the account is learning into structure, copy, and scale decisions. Every recommendation is staged as a reviewable draft. Nothing changes without your approval.

Not a dashboard. Not a bid optimizer. Not a generic audit checklist.

**A strategist with memory.**

---

## How It Works

```
READ  →  DRAFT  →  APPLY
```

| Layer | What happens |
|-------|-------------|
| **Read** | Pull live account data via Google's official `google-ads-mcp` MCP server (read-only). Or work with manual CSV exports — same analytical engine either way. |
| **Draft** | Every actionable finding becomes a concrete proposal — specific negatives, structure changes, budget moves, RSA directions — staged for human review. |
| **Apply** | Controlled write-back for approved drafts. v1 scope: **add negative keywords** and **pause keywords/ad groups**. Dry run, explicit confirmation, per-action verification, full audit trail, instant undo. |

**See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design, safety model, and roadmap.**

---

## Two Ways to Run It

### Connected Mode (recommended)
Hook up the MCP server with OAuth + developer token and the agent pulls live data automatically — search terms, keywords, conversions, budgets, everything via GAQL.

You get: live account data, automatic account discovery, date-range fallback for sparse accounts, cross-referencing search terms against targeted keywords, and health detection out of the box.

**Setup:** `./install.sh auto` → `/google-ads connect setup` → you're live. See `data/mcp-config.md` for details.

### Export Mode (zero setup)
Paste a CSV from Google Ads. The analytical engine is the same — you just feed it manually. Good for one-off audits or accounts where you don't have API access yet.

Both modes produce the same quality of analysis and drafts.

---

## What It Can Do

15 skills across three layers. The full operator workflow is in [OPERATOR-PLAYBOOK.md](OPERATOR-PLAYBOOK.md).

### Run the Account
| Command | What happens |
|---------|-------------|
| `/google-ads connect` | Set up, health check, pick an account |
| `/google-ads daily` | What matters today — bleeding campaigns, waste, opportunities |
| `/google-ads audit` | Full strategic review across all layers |
| `/google-ads draft-summary` | See what's queued, prioritized, with dependencies mapped |

### Analyze
| Command | What happens |
|---------|-------------|
| `/google-ads search-terms` | Find waste, signal, messaging clues, routing problems |
| `/google-ads intent-map` | Build the account's durable intent model |
| `/google-ads negatives` | Specific negatives with scope, risk, and collateral notes |
| `/google-ads tracking` | Is the account trustworthy enough to optimize? |
| `/google-ads structure` | Campaign/ad group restructuring recommendations |
| `/google-ads rsas` | RSA directions from actual buyer language |
| `/google-ads budget` | Budget/scaling decisions grounded in signal quality |
| `/google-ads plan` | Plan or rebuild account architecture from scratch |
| `/google-ads pmax` | PMax analysis through the intent contamination lens |
| `/google-ads landing-review` | Landing page diagnosis — tracking vs UX vs both |

### Act
| Command | What happens |
|---------|-------------|
| `/google-ads apply [draft]` | Execute an approved draft — dry run, confirm, verify, log |
| `/google-ads undo [rev-id]` | Reverse any applied action instantly |
| `/google-ads apply log` | Full audit trail of everything applied |

---

## Why This Exists

Most Google Ads tools report metrics, enforce generic best practices, or automate bids. None of them think about what the account is *actually buying*.

Google Ads Copilot starts from search intent — what people typed, what they meant, and whether the account structure reflects that reality.

| | What it means |
|---|---|
| **Intent-first** | Reads search behavior, not just metrics |
| **Memory** | Compounds learning across sessions — never starts from scratch |
| **Decision-oriented** | Every output ends in "what to do," not "what happened" |
| **Draft-staged** | Concrete proposals you can read, approve, or reject |
| **Human-in-the-loop** | Nothing changes without your explicit confirmation |
| **Safe writes** | Smallest blast radius first, full audit trail, instant undo |
| **Works anywhere** | Live API or manual exports — same engine |

---

## Getting Started

### Try It in 5 Minutes (export mode)
1. `./install.sh auto`
2. Export search terms from Google Ads (last 30 days, CSV)
3. `/google-ads search-terms` → paste your data
4. Check `workspace/ads/drafts/` for what it found

### Full Setup (connected mode)
1. Configure the MCP server: [data/mcp-config.md](data/mcp-config.md)
2. `./install.sh auto`
3. `./scripts/test-mcp.sh` to verify connectivity
4. `/google-ads connect setup` → discovers your accounts, picks one, writes workspace
5. `/google-ads daily` or `/google-ads audit` → live data flows automatically
6. Review drafts → approve → apply → verify

**See [DEMO-WORKFLOW.md](DEMO-WORKFLOW.md) for a guided walkthrough of the full cycle.**

**Environment variables:**
| Variable | Required | Notes |
|----------|----------|-------|
| `GOOGLE_APPLICATION_CREDENTIALS` | Yes | Path to OAuth/ADC credentials JSON |
| `GOOGLE_CLOUD_PROJECT` | Yes | Google Cloud project ID |
| `GOOGLE_ADS_DEVELOPER_TOKEN` | Yes | Google Ads developer token |
| `GOOGLE_ADS_LOGIN_CUSTOMER_ID` | If MCC | Manager account ID (no dashes) |

---

## Workspace Memory

Every session compounds. The agent writes to `workspace/ads/` — a persistent knowledge base that survives between runs:

| File | Purpose |
|------|---------|
| `account.md` | Account profile and setup |
| `goals.md` | Business objectives and KPIs |
| `intent-map.md` | Durable model of search behavior |
| `queries.md` | Query patterns and clusters |
| `negatives.md` | Exclusion history |
| `winners.md` | What's working and why |
| `tests.md` | Active tests and hypotheses |
| `findings.md` | Analytical notes |
| `change-log.md` | What was changed and when |
| `learnings.md` | What the account has taught us |
| `drafts/` | Staged action proposals |
| `audit-trail/` | Apply session logs + reversal registry |

---

## Package Structure

```text
google-ads-copilot/
├── README.md                    # This file
├── ARCHITECTURE.md              # Three-layer design doc
├── APPLY-LAYER.md               # Apply layer design (safety, reversibility, audit)
├── OPERATOR-PLAYBOOK.md         # Full operator workflow loop
├── CHANGELOG.md                 # Release history
├── LICENSE
├── install.sh
│
├── google-ads/                  # Orchestrator skill
│   ├── SKILL.md
│   └── references/              # Strategic playbooks
│
├── scripts/                     # Helper scripts + apply layer CLI
│   ├── apply-layer/             # Write-path CLI (bash + curl + jq)
│   └── list-customers.sh        # Account discovery
│
├── skills/                      # Analytical skills (15 skills)
│   ├── google-ads-apply/
│   ├── google-ads-audit/
│   ├── google-ads-budget/
│   ├── google-ads-connect/
│   ├── google-ads-daily/
│   ├── google-ads-draft-summary/
│   ├── google-ads-intent-map/
│   ├── google-ads-landing-review/
│   ├── google-ads-negatives/
│   ├── google-ads-plan/
│   ├── google-ads-pmax/
│   ├── google-ads-rsas/
│   ├── google-ads-search-terms/
│   ├── google-ads-structure/
│   └── google-ads-tracking/
│
├── data/                        # Data layer (MCP config, GAQL recipes)
├── drafts/                      # Draft templates per action type
├── examples/                    # Sanitized example outputs
├── evals/                       # Eval suite
└── workspace-template/          # Blank workspace for new accounts
```

---

## v1 Apply Scope

| Action | Status | Risk | Undo |
|--------|--------|------|------|
| Add campaign-level negative keyword | ✅ Live | Low | Remove the negative |
| Add ad-group-level negative keyword | ✅ Ready | Low | Remove the negative |
| Pause keyword | ✅ Ready | Low | Re-enable keyword |
| Pause ad group | ✅ Ready | Medium | Re-enable ad group |

**Explicitly excluded from v1:** budget changes, bid strategy changes, campaign creation, RSA edits, enabling paused entities, deletions.

---

## What's Next

This is a public alpha. The analytical engine and apply layer are solid — tested on real accounts with real money. What's coming:

- **v2 apply scope** — budget changes with safety bounds
- Expanded write actions as confidence accumulates
- More example walkthroughs from real (anonymized) accounts
- Eval coverage for decision quality
- Packaging for broader distribution

If you're running Google Ads for clients or your own business, try it. Break it. Tell me what's missing.

---

## License

See [LICENSE](LICENSE).
