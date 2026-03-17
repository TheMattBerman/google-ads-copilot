# Example: Budget Reallocation Apply, Monitor, Undo

> Budget writes use the manifest-backed v2 path: dry run, `confirm budgets`, verify, monitor, and undo if needed.

## Input Mode
- Connected mode against fictional account `Acme Equipment Co. (1234567890)`
- Draft source: `/google-ads budget`

## Drafts Created
- `workspace/ads/drafts/2026-03-17-acme-budget.md`
- `workspace/ads/drafts/_batch-2026-03-17-acme.md`

## Dry-Run Excerpt

```text
DRY RUN: 2026-03-17-acme-budget.md

Account: Acme Equipment Co. (CID: 1234567890)
Actions: 2 valid / 2 total

#    Action           Target                              Detail                         Risk
1    BUDGET           Campaign: Search - Buyers          50000000->55000000 (10%)      Medium
2    BUDGET           Campaign: Search - Mixed Intent    65000000->60000000 (-8%)      Medium

Summary:
  • 2 budget change(s)
  • Reversibility: All actions reversible
  • Net budget delta (micros): 0
  • Budget policy: budget-neutral only

Type 'confirm budgets' to proceed, or 'cancel' to abort:
```

## Audit-Trail Excerpt

```text
## 2026-03-17 11:42 — Apply Session

Draft: 2026-03-17-acme-budget.md
Account: Acme Equipment Co. (1234567890)
Result: 2/2 succeeded
Verification: 2/2 confirmed

| # | Action | Target | Status | Reversal ID |
|---|--------|--------|--------|-------------|
| 1 | SET_CAMPAIGN_DAILY_BUDGET | Search - Buyers | Applied | rev-201 |
| 2 | SET_CAMPAIGN_DAILY_BUDGET | Search - Mixed Intent | Applied | rev-202 |
```

## Monitor Window
- Check impression share lost to budget on the scaled campaign.
- Confirm spend reallocated away from mixed-intent traffic, not just delayed.
- Watch conversion quality for 7 days before any additional budget move.

## Undo Behavior

```text
/google-ads undo rev-201

Undo: rev-201
  Original action: SET_CAMPAIGN_DAILY_BUDGET
  Campaign:        Search - Buyers
  Budget (micros): 55000000 -> 50000000
  Reversal:        RESTORE_CAMPAIGN_DAILY_BUDGET

Type 'confirm' to proceed:
  ✅ Reversed
  ✅ Verified — budget restored to prior amount_micros
```
