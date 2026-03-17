# Example: Tracking Issue Blocks Budget Scaling

> Budget writes fail closed when measurement is not trustworthy enough.

## Input Mode
- Connected mode against fictional account `Metro Recycling LLC (9876543210)`
- Audit source: `/google-ads audit`

## Drafts Created
- `workspace/ads/drafts/2026-03-17-metro-tracking.md`
- `workspace/ads/drafts/2026-03-17-metro-budget.md`
- `workspace/ads/drafts/_batch-2026-03-17-metro.md`

## What the Audit Found
- GA4 import and native Google Ads tag both counted the same lead form.
- Search quality was improving, but scaling conclusions were not yet trustworthy.
- The budget draft was intentionally staged but blocked from execution until tracking was fixed.

## Dry-Run Excerpt

```text
./scripts/apply-layer/gads-apply.sh --dry-run workspace/ads/drafts/2026-03-17-metro-budget.md

Step 1: Parsing draft...
  Account:  Metro Recycling LLC (9876543210)
  Actions:  2
  Status:   proposed

Step 2: Validating and resolving resource IDs...
  WARNING: Budget actions blocked: tracking confidence must be Medium/High in workspace/ads/account.md (dry-run continues)
  WARNING: Budget actions blocked: pending tracking draft(s) exist in workspace/ads/drafts/_index.md (dry-run continues)
```

## Audit-Trail Excerpt

```text
No apply session created.
Reason: budget write blocked before confirmation because tracking confidence was Low and a tracking-fix draft was still pending.
```

## Defer Behavior
- Review and apply the tracking-fix draft first.
- Regenerate `/google-ads budget` after tracking confidence returns to Medium or High.
- Re-run the budget draft only after the tracking draft leaves the Proposed/Approved queue.
