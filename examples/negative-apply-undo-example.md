# Example: Negatives Apply, Verify, Undo

> Public-safe walkthrough of the smallest write path: review a negatives draft, apply it, verify it, and reverse it.

## Input Mode
- Connected mode against fictional account `Acme Equipment Co. (1234567890)`
- Draft source: `/google-ads negatives`

## Drafts Created
- `workspace/ads/drafts/2026-03-17-acme-negatives.md`

## Dry-Run Excerpt

```text
DRY RUN: 2026-03-17-acme-negatives.md

Account: Acme Equipment Co. (CID: 1234567890)
Actions: 3 valid / 3 total

#    Action           Target                              Detail                         Risk
1    ADD NEG          Campaign: Search - Core            "jobs" [PHRASE]               Low
2    ADD NEG          Campaign: Search - Core            "support" [PHRASE]            Low
3    PAUSE KW         AG: Mixed Intent                   "waste management" [EXACT]    Low

Summary:
  • 2 negative keyword addition(s)
  • 1 keyword pause(s)
  • Reversibility: All actions reversible
```

## Audit-Trail Excerpt

```text
## 2026-03-17 10:14 — Apply Session

Draft: 2026-03-17-acme-negatives.md
Account: Acme Equipment Co. (1234567890)
Result: 3/3 succeeded
Verification: 3/3 confirmed

| # | Action | Target | Status | Reversal ID |
|---|--------|--------|--------|-------------|
| 1 | ADD_NEGATIVE | Campaign: Search - Core | Applied | rev-101 |
| 2 | ADD_NEGATIVE | Campaign: Search - Core | Applied | rev-102 |
| 3 | PAUSE_KEYWORD | AG: Mixed Intent | Applied | rev-103 |
```

## Undo Behavior

```text
/google-ads undo rev-101

Undo: rev-101
  Original action: ADD_NEGATIVE
  Campaign:        Search - Core
  Reversal:        REMOVE_NEGATIVE_CAMPAIGN

Type 'confirm' to proceed:
  ✅ Reversed
  ✅ Verified — negative no longer exists
```
