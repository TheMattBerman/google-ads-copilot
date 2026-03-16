# Google Ads Copilot — Architecture

## The Big Picture

Google Ads Copilot is an AI agent that compounds learning over time. It reads search behavior, maps intent, surfaces waste, and proposes precise corrective actions — all grounded in real account data.

Not a dashboard replacement. Not a bid optimizer. A strategist with memory.

### Architecture: Read → Draft → Apply

```
┌─────────────────────────────────────────────────────────────┐
│                    Google Ads Copilot                        │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  READ LAYER  │→ │  DRAFT LAYER │→ │  APPLY LAYER │      │
│  │              │  │              │  │              │      │
│  │ Live account │  │ Proposed     │  │ Controlled   │      │
│  │ data via MCP │  │ actions in   │  │ write-back   │      │
│  │ (read-only)  │  │ staging docs │  │ (future)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         ↕                  ↕                ↕               │
│  ┌──────────────────────────────────────────────────┐      │
│  │              WORKSPACE MEMORY                     │      │
│  │     workspace/ads/ — persistent learning          │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer 1: READ (Live Today)

### What it is
The read layer pulls live account data using the **official `googleads/google-ads-mcp` MCP server** — Google's own read-only MCP implementation.

### What it provides
| Tool | Purpose |
|------|---------|
| `search` | Execute GAQL queries — campaigns, ad groups, search terms, conversions, budgets, assets, anything queryable |
| `list_accessible_customers` | Discover which accounts/customer IDs the authenticated user can access |

The `search` tool accepts any valid [GAQL query](https://developers.google.com/google-ads/api/docs/query/overview), which means the copilot can pull:
- Campaign and ad group performance
- Search terms reports (the core of intent analysis)
- Conversion action configuration
- Budget and bid strategy details
- RSA asset performance
- Audience segments
- Change history
- Account-level settings

### Connected Mode vs Export Mode

**Connected Mode** (recommended)
- MCP server is configured with OAuth credentials + developer token
- Skills pull live data directly via GAQL queries
- Search terms, conversions, performance — all live
- Intent Map updates from real-time query data
- This is the primary mode

**Export Mode** (fallback)
- User pastes or uploads CSV/screenshots from Google Ads UI
- All analysis skills still work, just with static data
- Useful when: no API access yet, one-time audits, client accounts you can't connect
- Workspace memory still compounds across sessions

Both modes use the same analytical engine. Connected mode just feeds it live data instead of manual exports.

### How it connects

The `google-ads-mcp` server runs locally via `pipx`:

```json
{
  "mcpServers": {
    "google-ads-mcp": {
      "command": "pipx",
      "args": [
        "run", "--spec",
        "git+https://github.com/googleads/google-ads-mcp.git",
        "google-ads-mcp"
      ],
      "env": {
        "GOOGLE_APPLICATION_CREDENTIALS": "/path/to/credentials.json",
        "GOOGLE_CLOUD_PROJECT": "YOUR_PROJECT_ID",
        "GOOGLE_ADS_DEVELOPER_TOKEN": "YOUR_DEVELOPER_TOKEN"
      }
    }
  }
}
```

Requirements:
- Google Ads developer token (basic access is fine for read-only)
- OAuth 2.0 credentials (desktop or service account)
- `pipx` installed
- Google Ads API enabled in Google Cloud project

### Why read-only is strategically strong

1. **Zero risk to live campaigns.** No accidental bid changes, no paused campaigns, no broken tracking. The copilot reads. That's it.

2. **Faster to deploy.** Basic developer token access is sufficient. No need for standard access approval, no write-permission reviews, no billing setup for mutate calls.

3. **Trust is earned.** The agent proves its analytical value before it touches anything. You (or a client) see the quality of recommendations before granting write access. This is how you build trust with real money on the line.

4. **The hard part is the thinking, not the clicking.** The bottleneck in Google Ads management is never "I couldn't click the button." It's "I didn't know what to do." A system that tells you exactly what to change — with evidence — is 90% of the value even if the human clicks the buttons.

5. **Regulatory and client safety.** For agency use, read-only access to client accounts is a much easier conversation than write access. Clients who'd never grant API write access will happily share read access.

6. **Data compounds, actions are one-time.** The Intent Map, the query patterns, the learnings — these persist and get smarter. A negative keyword, once added, is done. The analytical layer is where compound value lives.

---

## Layer 2: DRAFT (Live Today)

### What it is
The draft layer turns audit findings and analysis into **concrete, staged proposed actions** written to the workspace as reviewable documents. These are not vague recommendations — they are specific, executable proposals with all the details needed to implement them.

### How it works

Every skill that produces actionable findings writes to the drafts system:

```
workspace/ads/drafts/
├── 2026-03-14-negatives.md        # Specific negatives to add
├── 2026-03-14-structure.md        # Structure changes to make
├── 2026-03-12-rsa-refresh.md      # RSA copy changes
├── 2026-03-10-budget-realloc.md   # Budget reallocation proposal
└── _index.md                      # Draft queue with status
```

### Draft document format

Every draft follows a standard shape:

```markdown
# Draft: [Action Type] — [Date]
Status: proposed | approved | applied | rejected | superseded

## Summary
One paragraph: what this proposes and why.

## Evidence
What data/analysis led to this recommendation.
Link to findings, search terms, intent map entries.

## Proposed Actions
### Action 1: [Specific thing]
- **Type:** add_negative | pause_campaign | adjust_budget | update_rsa | restructure | ...
- **Target:** Campaign / Ad Group / Account level
- **Detail:** Exact keyword, exact match type, exact scope
- **Risk:** What could go wrong
- **Reversibility:** Easy / Moderate / Hard

### Action 2: ...

## Dependencies
Actions that should happen before or after this one.

## Confidence
High / Medium / Low — with reasoning.

## Approval
- [ ] Reviewed by operator
- [ ] Approved for implementation
- Applied on: ____
```

### Draft types

| Draft Type | Triggered By | Contains |
|------------|-------------|----------|
| `negatives` | search-terms, intent-map, audit | Exact negative keywords, match types, scopes, risk notes |
| `structure` | structure, audit, plan | Campaign/ad group splits, merges, routing changes |
| `rsa-refresh` | rsas, search-terms | New headlines, descriptions, pin recommendations |
| `budget-realloc` | budget, daily, audit | Specific $/% shifts between campaigns |
| `tracking-fix` | tracking, audit | Conversion action changes, tag fixes |
| `pmax-containment` | pmax, audit | Exclusion lists, asset group changes |

### Why drafts matter

- **Audit trail.** Every change recommendation is dated, evidenced, and trackable.
- **Review before action.** The human (or a future approval workflow) signs off before anything moves.
- **Batch operations.** Accumulate a week's worth of recommendations, review them together, apply the best ones.
- **Learning feedback.** After applying a draft, the agent can check whether the change actually helped — feeding back into the workspace memory.

---

## Layer 3: APPLY (Live — v1)

### What it is
The apply layer executes approved draft actions against the Google Ads API using controlled, audited write operations. v1 scope is deliberately narrow: negative keywords and pauses only. The safest mutations first, with full audit trail and instant undo.

### Safety model

```
Draft (proposed) → Human Review → Approved → Apply Queue → Confirmation → Applied
                       ↓
                   Rejected (with reason → feeds back into learnings)
```

**Hard rules for apply layer:**
1. **No action without explicit approval.** Every write goes through the draft → approve → apply pipeline.
2. **Dry-run first.** Before any mutate call, show exactly what will change and what it looked like before.
3. **Reversibility check.** Every action must document how to undo it. Some actions (like pausing a campaign) are trivially reversible. Others (like restructuring) are not.
4. **Rate limiting.** Maximum N changes per day per account, configurable. No "apply all 47 recommendations at once."
5. **Change log.** Every applied action is logged to `workspace/ads/change-log.md` with timestamp, what changed, why, and the draft that proposed it.
6. **Kill switch.** One command to halt all pending applies.

### First 5 Write Actions Worth Building

These are ordered by value-to-risk ratio — the actions where automation saves the most time with the least danger:

#### 1. Add Negative Keywords
- **Risk:** Low (easily reversible — just remove the negative)
- **Value:** High (the #1 most common recommendation from search terms analysis)
- **Complexity:** Simple API call — `KeywordPlanNegativeKeyword` or campaign/ad group level negatives
- **Why first:** This is what operators do most often after reviewing search terms. The copilot already identifies them precisely. Automating the "add these 12 negatives at phrase match to campaign X" step saves real time.

#### 2. Pause / Enable Campaigns or Ad Groups
- **Risk:** Low-medium (easily reversible — just re-enable)
- **Value:** Medium (useful for seasonal, budget, or performance-based decisions)
- **Complexity:** Simple status toggle
- **Why second:** Straightforward, reversible, and the draft layer already identifies when things should be paused.

#### 3. Adjust Campaign Budgets
- **Risk:** Medium (money moves, but bounded by daily budget caps)
- **Value:** High (budget reallocation is a core operator action)
- **Complexity:** Single field update per campaign
- **Why third:** The budget skill already recommends specific dollar shifts. Automating "move $50/day from campaign A to campaign B" is precise and auditable.

#### 4. Update RSA Assets (Add/Remove Headlines & Descriptions)
- **Risk:** Medium (affects ad serving, but old assets remain until removed)
- **Value:** High (RSA refresh from buyer language is a signature copilot strength)
- **Complexity:** Moderate — requires asset creation and ad association
- **Why fourth:** The copilot generates RSA copy from real query language. The gap between "here are 5 headlines worth testing" and "they're live in ad group X" is pure friction.

#### 5. Create/Update Shared Negative Keyword Lists
- **Risk:** Low (reversible, and shared lists are cleaner than campaign-level negatives)
- **Value:** High (scales negative management across campaigns)
- **Complexity:** Moderate — list CRUD + campaign association
- **Why fifth:** This extends action #1 from tactical (add 12 negatives to one campaign) to structural (maintain organized negative lists across the account).

### Actions deliberately NOT in the first batch

| Action | Why Not Yet |
|--------|-------------|
| Create new campaigns | Too structural, too many parameters, too much risk of getting it wrong |
| Change bid strategies | Affects smart bidding learning, hard to reverse cleanly |
| Modify audience targeting | Complex interactions, hard to predict downstream effects |
| Create/modify extensions | Lower leverage, rarely the bottleneck |
| Asset group changes (PMax) | PMax is too opaque for confident automated changes |

---

## Product Framing

### The Pitch
**"I built an OpenClaw agent that manages Google Ads through intent analysis instead of bid automation."**

It's a skill package — not a SaaS product. Install it into Claude or OpenClaw and your AI gets the strategic framework + persistent workspace memory to manage Google Ads accounts like a senior strategist.

### For Agencies
Connect client accounts (read-only) → instant strategic visibility. Every audit finding becomes a concrete draft. The weekly draft review replaces "what should we do" meetings. The Intent Map builds institutional knowledge that survives team turnover.

### Positioning
Most Google Ads tools are dashboard replacers, bid optimizers, or rule engines. This is none of those:

- **Intent-first** — reads search behavior, not just metrics
- **Memory** — compounds learning across sessions, never starts over
- **Decision-oriented** — every output ends in "what to do," not "what happened"
- **Human-in-the-loop** — nothing changes without review and approval
- **Works anywhere** — live API or manual exports, same engine

---

## File Structure (Updated)

```
google-ads-copilot/
├── README.md                       # Package overview
├── ARCHITECTURE.md                 # This document
├── CLAUDE.md                       # Project notes
├── data/mcp-config.md              # Public MCP/OpenClaw integration notes
├── CHANGELOG.md
├── LICENSE
├── install.sh
│
├── google-ads/                     # Orchestrator skill
│   ├── SKILL.md                    # Router + framework
│   └── references/                 # Strategic playbooks
│       ├── operator-thesis.md
│       ├── intent-map.md
│       ├── query-patterns.md
│       ├── negatives-playbook.md
│       ├── tracking-playbook.md
│       ├── structure-playbook.md
│       ├── rsa-playbook.md
│       ├── budget-playbook.md
│       ├── benchmarks.md
│       └── deliverable-templates.md
│
├── scripts/                        # Helper scripts
│   ├── test-mcp.sh                 # MCP connectivity health check
│   └── list-customers.sh           # Discover accessible accounts
│
├── skills/                         # Layer 1+2 analytical skills
│   ├── google-ads-connect/         # Connected-mode onboarding + account selection
│   ├── google-ads-daily/
│   ├── google-ads-search-terms/
│   ├── google-ads-intent-map/
│   ├── google-ads-negatives/
│   ├── google-ads-tracking/
│   ├── google-ads-structure/
│   ├── google-ads-rsas/
│   ├── google-ads-budget/
│   ├── google-ads-pmax/
│   ├── google-ads-plan/
│   └── google-ads-audit/
│
├── agents/                         # Specialist sub-agents
│   ├── audit-intent.md
│   ├── audit-tracking.md
│   └── audit-structure.md
│
├── data/                           # NEW: Data layer config
│   ├── mcp-config.md               # MCP setup instructions
│   ├── gaql-recipes.md             # Common GAQL queries for each skill
│   └── export-formats.md           # How to format manual exports
│
├── drafts/                         # NEW: Draft layer templates
│   ├── DRAFTS.md                   # How the draft system works
│   └── templates/
│       ├── negative-draft.md
│       ├── structure-draft.md
│       ├── budget-draft.md
│       ├── rsa-draft.md
│       └── tracking-draft.md
│
├── workspace-template/             # Template for new accounts
│   └── ads/
│       ├── account.md
│       ├── goals.md
│       ├── intent-map.md
│       ├── queries.md
│       ├── negatives.md
│       ├── winners.md
│       ├── tests.md
│       ├── findings.md
│       ├── change-log.md
│       ├── learnings.md
│       ├── assets.md
│       └── drafts/                 # NEW: per-account draft queue
│           └── _index.md
│
├── examples/
│   ├── plan-example.md
│   ├── search-terms-example.md
│   ├── tracking-diagnosis-example.md
│   ├── daily-operator-example.md
│   └── intent-map-example.md
│
├── evals/
│   ├── cases.json
│   ├── run.py
│   └── fixtures/
│
└── .claude-plugin/
    └── plugin.json
```

### What changed from v0.1
1. **Added `data/`** — MCP configuration docs, GAQL query recipes, export format specs
2. **Added `drafts/`** — Draft system documentation and templates for each action type
3. **Added `workspace-template/ads/drafts/`** — Per-account draft queue
4. **Architecture doc** — This file, explaining the three-layer model
5. **Updated skills** — Each skill now documents its data source (MCP query or export) and draft output

---

## Implementation Sequence

### Phase 1: Read Layer (Now)
- [x] Analytical skills exist and work with export data
- [x] Document MCP server setup for connected mode
- [x] Write GAQL recipe library for each skill's data needs
- [x] Add connected-mode data fetching instructions to each skill
- [x] Test with real accounts via `google-ads-mcp` (multiple live accounts validated)
- [x] Connected-mode onboarding skill (`google-ads-connect`)
- [x] Customer discovery and selection flow
- [x] Health check scripts (`scripts/test-mcp.sh`, `scripts/list-customers.sh`)
- [x] Date range fallback protocol for dormant/sparse accounts
- [x] keyword_view supplementation for search-terms and negatives analysis
- [x] Fix env var docs (`GOOGLE_CLOUD_PROJECT`, not `GOOGLE_PROJECT_ID`)

### Phase 2: Draft Layer (Now)
- [x] Define draft document format
- [x] Create draft templates for each action type
- [x] Update each skill to output drafts when actionable findings exist
- [x] Build draft index/queue system in workspace
- [x] Add draft review workflow to daily operator
- [x] Add "negatives to remove/narrow/move" sections to negative draft template
- [x] Tighten tracking confidence rubric with explicit thresholds
- [ ] Account-slug naming for drafts (e.g., `2026-03-14-east-coast-negatives.md`)
- [ ] Batch summary file for multi-draft audit runs
- [ ] Draft review checklist UX improvements

### Phase 3: Apply Layer (Live — v1)
- [x] Build write-action implementations (v1: negatives + pauses)
- [x] Implement approval pipeline (dry-run → confirm → execute → verify)
- [x] Add dry-run mode
- [x] Add change log / audit trail automation
- [x] Add reversal registry and undo commands
- [ ] v2: Budget changes with safety bounds
- [ ] v2: Expanded write scope as confidence accumulates

---

## Decision Log

| Date | Decision | Reasoning |
|------|----------|-----------|
| 2026-03-14 | Use `googleads/google-ads-mcp` for read layer | Official Google implementation, read-only by design, actively maintained, uses standard GAQL |
| 2026-03-14 | Support both connected and export modes | Maximizes reach — some accounts can't do API, but the analysis is still valuable |
| 2026-03-14 | Draft layer uses markdown files in workspace | Keeps everything in the workspace memory system, human-readable, version-controllable |
| 2026-03-14 | Apply layer starts with smallest blast radius | Negatives + pauses first. Prove safety model before expanding write scope. |
| 2026-03-14 | Negative keywords are the first write action | Highest frequency recommendation, lowest risk, most easily reversible |
