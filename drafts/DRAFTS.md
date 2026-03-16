# Draft System — Google Ads Copilot

## What are drafts?

Drafts are **concrete, staged proposed actions** that the copilot writes when analysis produces actionable findings. They are not vague suggestions — they are specific proposals with everything needed to implement them.

## Why drafts exist

1. **No action without review.** The copilot recommends; the human decides.
2. **Audit trail.** Every recommendation is dated, evidenced, and trackable.
3. **Batch review.** Accumulate recommendations over time, review and apply the best ones.
4. **Learning loop.** After implementation, check results → update workspace memory.

## Where drafts live

```
workspace/ads/drafts/
├── _index.md                         # Queue: all drafts with status
├── 2026-03-14-negatives.md          # Individual draft files
├── 2026-03-14-structure.md
├── 2026-03-12-rsa-refresh.md
└── ...
```

## Draft lifecycle

```
proposed → approved → applied → verified
              ↓
          rejected (reason logged → feeds into learnings)
              ↓
          superseded (newer draft replaces this one)
```

## Status definitions

| Status | Meaning |
|--------|---------|
| `proposed` | Copilot generated this draft. Awaiting human review. |
| `approved` | Human reviewed and approved for implementation. |
| `applied` | Action was taken (manually or via apply layer). |
| `verified` | Post-implementation check confirmed expected results. |
| `rejected` | Human reviewed and declined. Reason should be logged. |
| `superseded` | A newer draft covers the same ground. |

## Draft document format

Every draft follows this shape:

```markdown
# Draft: [Type] — [Date]
Status: proposed
Skill: /google-ads [skill-name]
Account: [Customer ID or name]

## Summary
One paragraph: what this proposes and why.

## Evidence
What data/analysis led here. Link to workspace findings if applicable.

## Proposed Actions

### Action 1: [Specific description]
- **Type:** add_negative | remove_negative | narrow_negative | move_negative | pause_entity | adjust_budget | update_rsa | restructure | fix_tracking
- **Target:** [Campaign / Ad Group / Account level + specific name]
- **Detail:** [Exact parameters — keyword text, match type, dollar amount, etc.]
- **Risk:** [What could go wrong]
- **Reversibility:** Easy / Moderate / Hard

### Action 2: ...
[repeat as needed]

## Dependencies
List any actions that should happen before or after this batch.

## Confidence
High / Medium / Low — with brief reasoning.

## Review
- [ ] Reviewed by operator
- [ ] Approved for implementation
- Reviewed on: ____
- Applied on: ____
- Notes: ____
```

## How skills produce drafts

Each analytical skill decides whether findings warrant a draft:

| Skill | Produces Drafts When |
|-------|---------------------|
| `search-terms` | Identifies clear waste terms, isolation opportunities, or harmful existing negatives |
| `intent-map` | Finds intent classes that need structural separation |
| `negatives` | Has specific negative keyword recommendations (adds, removes, or scope changes) |
| `tracking` | Identifies fixable tracking problems |
| `structure` | Recommends splits, merges, or routing changes |
| `rsas` | Has concrete headline/description improvements |
| `budget` | Recommends specific dollar reallocation |
| `daily` | Surfaces urgent fixes (usually links to existing drafts) |
| `audit` | Synthesizes findings into prioritized draft batch |
| `landing-review` | Finds tracking vs UX/path problems on landing pages — produces landing-review or tracking drafts |
| `plan` | Produces a launch/rebuild draft |

## Index file format

`workspace/ads/drafts/_index.md`:

```markdown
# Draft Queue

## Proposed
- [ ] 2026-03-14-negatives.md — 8 negative keywords for Campaign X
- [ ] 2026-03-14-structure.md — Split branded traffic from generic

## Approved
- [x] 2026-03-12-rsa-refresh.md — 5 new headlines for Ad Group Y

## Applied
- [x] 2026-03-08-negatives.md — Job-seeker exclusions (applied 2026-03-09)

## Rejected
- [x] 2026-03-05-budget-realloc.md — Premature: tracking not trusted yet
```

## Draft Naming Convention

Use account-slug naming when working with multiple accounts:

```
YYYY-MM-DD-[account-slug]-[type].md
```

Examples:
- `2026-03-14-east-coast-negatives.md`
- `2026-03-14-cooper-structure.md`
- `2026-03-14-east-coast-tracking-fix.md`

For single-account workspaces, the slug is optional:
- `2026-03-14-negatives.md`

The slug should be a short, recognizable identifier derived from the account's descriptive name — lowercase, hyphenated, 2-3 words max.

## Draft Summary

Use `/google-ads draft-summary` to generate a prioritized summary of all pending drafts.
The summary lives at `workspace/ads/drafts/_summary.md` and includes:
- Every pending draft classified by priority (P0-P3), impact, risk, and reversibility
- Dependency chains between drafts
- Recommended apply order
- Blocked actions (e.g., budget scaling blocked by tracking problems)
- Quick-apply candidates (low-risk, no dependencies)

## Apply Layer

Use `/google-ads apply [draft-file]` to execute approved drafts.
See `APPLY-LAYER.md` for the full design document.

**v1 scope (safe actions only):**
- Add negative keywords (campaign or ad group level)
- Pause keywords or ad groups

**Flow:** Dry run → Confirm → Execute → Verify → Audit trail

All applied actions are logged in `workspace/ads/audit-trail/` and fully reversible via `/google-ads undo`.

## Rules

1. **One draft per action batch.** Don't mix negatives and structure changes in one draft.
2. **Date-prefix all drafts.** Include account slug for multi-account clarity.
3. **Link evidence.** Every draft should reference the analysis that produced it.
4. **Log rejections.** If a draft is rejected, say why — it teaches the system.
5. **Update after apply.** Move to applied status, note the date, and update change-log.md.
6. **Regenerate summary after changes.** Run draft-summary after creating, applying, or rejecting drafts.
