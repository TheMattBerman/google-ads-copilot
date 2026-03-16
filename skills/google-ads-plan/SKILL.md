---
name: google-ads-plan
description: >
  Plan or rebuild a Google Ads account using business goals, offer structure, intent strategy,
  and traffic segmentation logic. Pulls live data via MCP (for rebuilds) or works from scratch
  (for new accounts).
---

# Google Ads Plan

This skill is for building from scratch or cleaning up a messy account before the mess compounds.

Read first:
- `google-ads/references/operator-thesis.md`
- `google-ads/references/intent-map.md`
- `google-ads/references/query-patterns.md`
- `google-ads/references/structure-playbook.md`
- `google-ads/references/rsa-playbook.md`
- `google-ads/references/budget-playbook.md`
- `google-ads/references/deliverable-templates.md`
- `google-ads/references/benchmarks.md`

Read workspace if available:
- `workspace/ads/account.md`
- `workspace/ads/goals.md`
- `workspace/ads/intent-map.md`
- `workspace/ads/learnings.md`

---

## Data Acquisition

### Connected Mode (for rebuilds)
If the account already exists and has data, pull audit-level queries to understand current state before planning the rebuild. Use the same queries as the audit skill.

### Export Mode / New Account
If building from scratch:
- No account data needed
- Gather: business model, offer, target audience, budget, geographic targets, existing keyword research
- Optionally: competitor URLs, existing landing pages, previous performance data

### Planning Mode (no existing account)
For brand-new accounts, this skill runs without MCP at all. The intelligence comes from:
- Business context gathered from the user
- Intent Map framework (hypothesized, validated later)
- Reference playbooks for structure, copy, and budget

---

## Process
1. **Announce mode** (connected rebuild / new account planning).
2. Clarify business model, offer, KPI, and budget reality.
3. Identify the most important intent buckets.
4. Design campaign architecture around commercial meaning, not cosmetic neatness.
5. Define what should be split, merged, or excluded from the start.
6. Recommend:
   - Campaign structure
   - Ad group logic
   - Negative logic (day-one exclusions)
   - RSA/message direction
   - Budget posture
7. Write planning notes to workspace memory.

## Core Planning Questions
- What search intents matter enough to deserve their own buckets?
- Which intents should never share one bid/copy/LP bucket?
- What should be excluded from day one?
- What does the budget realistically support?
- Where should simplicity beat ideal segmentation?

## Draft Output
Plans are **standalone deliverables**, not draft actions. They are saved directly to workspace:
- Write to `workspace/ads/plan.md` (or `workspace/ads/plan-YYYY-MM-DD.md` for rebuilds)
- This is a reference document, not an approval-gated draft

However, if the plan identifies **specific implementation steps** for an existing account, create appropriate drafts:
- Structure drafts for campaign/ad group creation
- Negative drafts for day-one exclusions
- Budget drafts for initial allocation

### Always update workspace memory:
- `workspace/ads/account.md` — account identity and business context
- `workspace/ads/goals.md` — KPIs and targets
- `workspace/ads/intent-map.md` — hypothesized intent model

## Output Format
Use the operator summary template, then add:
- Proposed campaign structure (table)
- Proposed ad group logic per campaign
- Exclusion/routing logic (day-one negatives)
- Message strategy by intent bucket
- Budget posture (allocation rationale)
- Risks and tradeoffs
- Phase plan (what to launch first, what to add later)

## Rules
- Do not over-segment low-volume plans.
- Build around intent separation and LP fit.
- Make tradeoffs explicit when budget is too small for ideal structure.
- A simple plan that respects meaning beats a perfect plan no budget can support.
- Use benchmarks only as orientation, not as the boss.
