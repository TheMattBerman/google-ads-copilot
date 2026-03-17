---
name: google-ads-draft-summary
description: >
  Summarize all pending drafts across accounts. Produces a single prioritized view of
  what needs review, sorted by impact, risk, and apply order. Surfaces dependency chains,
  blocked actions, and the optimal implementation sequence. Use before review sessions
  or when returning to an account after time away.
argument-hint: "[account-slug] | all"
---

# Google Ads Draft Summary

## Why this skill exists

After an audit, search-term review, or tracking diagnosis, the copilot produces individual draft files.
But individual files don't answer the operator's real question:

> "I have 20 minutes. What should I review and apply first?"

This skill answers that.

Read first:
- `drafts/DRAFTS.md` — draft system documentation

Read workspace:
- `workspace/ads/drafts/_index.md` — current queue
- All `workspace/ads/drafts/*.md` — individual draft files
- `workspace/ads/account.md` — account context
- `workspace/ads/findings.md` — for tracking confidence context

---

## What This Produces

A **Draft Summary** — a single document that:

1. Lists every pending draft (status: `proposed` or `approved`)
2. Classifies each by **priority**, **impact**, **risk**, and **reversibility**
3. Shows **dependency chains** (what must be applied before what)
4. Produces a **recommended apply order** (the sequence an operator should follow)
5. Flags **blocked actions** (e.g., budget scaling blocked by tracking problems)
6. Estimates **total impact** of applying all pending changes

This is the current backlog snapshot, not the audit-run packet. `_summary.md` should always reflect the latest pending queue. Durable audit packets belong in `_batch-*.md`.

---

## Priority Classification

Each draft gets a priority level based on these criteria:

### P0 — Fix First (Blocking)
- Tracking problems that gate all other decisions
- Actively harmful configurations (e.g., paying for store visits as conversions)
- Budget bleeding on clearly wrong traffic
- **Apply these before anything else**

### P1 — Quick Wins (High Confidence, Easy, High Impact)
- Clear negative keyword additions with significant waste (>$100/month)
- Keyword pauses with obvious waste
- Simple tracking cleanup (remove micro-conversion from primary)
- **Apply these in the same session as P0**

### P2 — Strategic Moves (Requires Thought)
- Structure changes (campaign splits, ad group reorganization)
- Budget reallocation between campaigns
- Landing page changes
- **Schedule a focused review session for these**

### P3 — Refinement (Low Risk, Incremental)
- RSA headline/description refreshes
- Minor negative additions (<$50/month waste)
- Value setting updates
- **Apply when convenient, batch with other changes**

---

## Impact Assessment

Each draft gets an impact estimate:

| Impact Level | Description | Signal |
|-------------|-------------|--------|
| **Critical** | Stopping active harm or fixing broken measurement | Tracking broken, massive waste |
| **High** | Significant waste reduction or conversion improvement | >$200/month waste, or >20% of spend affected |
| **Medium** | Meaningful improvement in efficiency or clarity | $50-200/month impact, structure improvement |
| **Low** | Minor optimization, incremental improvement | <$50/month, cosmetic structure |

---

## Risk Assessment

| Risk Level | Description | Reversibility |
|-----------|-------------|---------------|
| **High** | Could disrupt Smart Bidding learning, reduce impression share, or block good traffic | Moderate — takes 2-3 weeks to recover |
| **Medium** | Temporary performance dip possible, but recoverable | Easy — undo within a day |
| **Low** | No meaningful risk of regression | Easy — instant undo |

---

## Dependency Chain Logic

Drafts can depend on each other. Common dependency patterns:

```
Tracking Fix (P0)
  ├── blocks → Budget Scaling (P2)
  ├── blocks → Bid Strategy Changes (P2)
  └── informs → Structure Changes (P2)

Negative Keywords (P1)
  └── before → Structure Changes (P2)
      └── before → RSA Refresh (P3)
          └── before → Budget Scaling (P2)
```

**Rules:**
- Tracking fixes always come first (they change the data everything else is based on)
- Negatives before structure (clean the traffic before reorganizing it)
- Structure before RSAs (know the buckets before writing the copy)
- Everything before budget scaling (scale only what's working)

---

## Draft Summary Document Format

```markdown
# Draft Summary — [Date]
Account: [Name] (CID: [ID])
Tracking confidence: [HIGH / MEDIUM / LOW / BROKEN]
Pending drafts: [N]
Total estimated waste addressable: $[amount]/month

## Recommended Apply Order

### Step 1: [Draft name] — P0
- **File:** `workspace/ads/drafts/[filename]`
- **Type:** [tracking-fix / negatives / structure / budget / rsa / landing-review]
- **Summary:** [one sentence]
- **Impact:** [Critical / High / Medium / Low]
- **Risk:** [High / Medium / Low]
- **Reversibility:** [Easy / Moderate / Hard]
- **Estimated waste stopped:** $[amount]/month
- **Blocked by:** [nothing / other draft]
- **Blocks:** [list of drafts that depend on this one]

### Step 2: [Draft name] — P1
[same format]

### Step 3: [Draft name] — P2
[same format]

[... repeat for all pending drafts]

## Dependency Map

```text
[visual or text representation of dependencies]
```

## Blocked Actions
- [action] — blocked by [reason]. Unblocks after [draft] is applied.

## Quick-Apply Candidates
Drafts that are low-risk, high-confidence, and have no dependencies:
- [draft name] — [one-line summary]

## Deferred / Needs More Data
Drafts that shouldn't be applied yet:
- [draft name] — [reason: needs more data / confidence too low / depends on client input]

## Total Impact Estimate
If all pending drafts are applied in the recommended order:
- **Waste reduction:** ~$[amount]/month
- **Tracking improvement:** [description]
- **Structure improvement:** [description]
- **Time to full effect:** [estimate]
```

---

## How to Generate the Summary

### Step 1: Read the Index
Load `workspace/ads/drafts/_index.md` to get the list of all drafts and their current status.

### Step 2: Read Each Pending Draft
For each draft with status `proposed` or `approved`, read the full file to extract:
- Action type(s)
- Confidence level
- Risk and reversibility
- Dependencies
- Estimated impact (waste $ if quantified)

### Step 3: Check Tracking Confidence
Load the most recent tracking diagnosis from `workspace/ads/findings.md`.
Tracking confidence determines which drafts are blocked.

### Step 4: Build the Dependency Chain
Map out which drafts depend on which. Apply the standard ordering:
1. Tracking fixes
2. Keyword pauses (stop active bleeding)
3. Negative keyword additions
4. Structure changes
5. RSA refreshes
6. Landing page improvements
7. Budget reallocation

### Step 5: Assign Priority and Impact
Using the P0-P3 framework and impact/risk tables above.

### Step 6: Write the Summary
Output the Draft Summary document to `workspace/ads/drafts/_summary.md`

---

## Output Locations

- **Summary document:** `workspace/ads/drafts/_summary.md` (overwritten each time)
- **Audit packets:** `workspace/ads/drafts/_batch-YYYY-MM-DD-[account-slug].md` (created by `/google-ads audit` when one run emits 2+ drafts)
- **Index update:** Update `workspace/ads/drafts/_index.md` if any status changes are warranted
- **Console output:** Also display the summary inline for immediate review

---

## Multi-Account Support

When `workspace/ads/drafts/_index.md` contains drafts for multiple accounts (identified by account slug in the filename):

- Group the summary by account
- Show per-account tracking confidence
- Show per-account total impact
- Cross-account dependencies are rare but possible (shared negative lists, MCC-level changes)

---

## Rules

- **Read every pending draft.** Don't summarize from the index alone — the index is a title list, not a summary.
- **Always check tracking confidence.** It gates everything.
- **Be honest about confidence.** If a draft says "Medium confidence," don't promote it to P1.
- **Surface the 20-minute review.** The operator should be able to read the summary, pick the top 2-3 actions, and apply them in one session.
- **Don't create new drafts.** This skill summarizes existing drafts — it doesn't generate new recommendations.
- **Flag stale drafts.** If a draft is >30 days old, note it. The data it was based on may no longer be current.
- **Flag conflicting drafts.** If two drafts recommend contradictory actions, call it out explicitly.
