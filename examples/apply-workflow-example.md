# Example: Apply Workflow — End to End

> The full cycle: review a draft, see exactly what will change, confirm, execute, verify, undo if needed. This is what "human-in-the-loop" looks like in practice.

---

## The Setup

A B2B equipment company's account — typical of what the agent finds on first audit:
- **Zero negative keywords** — completely unprotected
- **Broad-match keywords** attracting service-seekers instead of equipment buyers
- **A high-spend exact-match keyword** capturing competitor brand navigation traffic
- **Tracking pollution** — store visits inflating CPA by ~140x

The search terms analysis produced a draft: 13 negative keywords + 1 keyword pause.

---

## Step 1: Review the Draft

```
/google-ads apply review workspace/ads/drafts/2026-03-15-acme-negatives.md
```

Output:
```
═══════════════════════════════════════════════════════
 DRAFT REVIEW (no API calls)
═══════════════════════════════════════════════════════

 Draft:   2026-03-15-acme-negatives.md
 Status:  proposed
 Actions: 14 total

 #   Type         Target                    Detail                        Risk
 --- ------------ ------------------------- ----------------------------- ------
 1   ADD NEG      Campaign: Search          "near me" [PHRASE]            Low
 2   ADD NEG      Campaign: Search          "debris chute" [PHRASE]       Low
 3   ADD NEG      Campaign: Search          "competitor-a" [PHRASE]       Low
 4   ADD NEG      Campaign: Search          "competitor-b" [PHRASE]       Low
 5   ADD NEG      Campaign: Search          "competitor-c" [PHRASE]       Low
 6   ADD NEG      Campaign: Search          "competitor-d" [PHRASE]       Low
 7   ADD NEG      Campaign: Search          "competitor-e" [PHRASE]       Low
 8   ADD NEG      Campaign: Search          "garbage truck" [PHRASE]      Low
 9   ADD NEG      Campaign: Search          "municipal" [PHRASE]          Low
 10  ADD NEG      Campaign: Search          "sanitation dept" [PHRASE]    Low
 11  ADD NEG      Campaign: Search          "basura" [PHRASE]             Low
 12  ADD NEG      Campaign: Search          "dump truck" [PHRASE]         Low
 13  ADD NEG      Campaign: Search          "smash truck" [PHRASE]        Low
 14  PAUSE KW     AG: High-Intent Buyers    "waste management" [EXACT]    Low

 Estimated waste: $40+/month on visible terms (51% waste rate)
 Plus $1,500+ all-time on competitor navigation keyword (#14)
```

---

## Step 2: Apply the Draft

```
/google-ads apply workspace/ads/drafts/2026-03-15-acme-negatives.md
```

### Dry Run Output
```
═══════════════════════════════════════════════════════
 Google Ads Copilot — Apply Layer (API v20)
═══════════════════════════════════════════════════════

 Step 1: Parsing draft...
   Account:  Acme Equipment Co. (1234567890)
   Actions:  14
   Status:   proposed

 Step 2: Validating and resolving resource IDs...
   Campaign "Search" → customers/1234567890/campaigns/12345678
   Ad Group "High-Intent Buyers" → customers/1234567890/adGroups/87654321
   All 14 actions validated.

 Step 3: Dry run display

 #   Action        Target              Detail                     Risk
 --- ------------- ------------------- -------------------------- ------
 1   ADD NEG       Campaign: Search    "near me" [PHRASE]         Low
 2   ADD NEG       Campaign: Search    "debris chute" [PHRASE]    Low
 ...
 14  PAUSE KW      AG: High-Intent     "waste management" [EXACT] Low

 ⚠️  This will make REAL changes to account 1234567890.
 Type 'confirm' to proceed, or 'cancel' to abort:
```

### After Confirmation
```
 Step 4: Executing...

 [1/14] ADD NEG "near me" [PHRASE] → Campaign: Search
        ✅ Applied (resource: customers/1234567890/campaignCriteria/12345678~98765)
        ✅ Verified via GAQL

 [2/14] ADD NEG "debris chute" [PHRASE] → Campaign: Search
        ✅ Applied
        ✅ Verified via GAQL

 ...

 [14/14] PAUSE KW "waste management" [EXACT] → AG: High-Intent Buyers
         ✅ Applied (status → PAUSED)
         ✅ Verified via GAQL

═══════════════════════════════════════════════════════
 Apply Session Complete
═══════════════════════════════════════════════════════

  Executed:  14 succeeded, 0 failed
  Verified:  14 confirmed, 0 unconfirmed
  Audit:     workspace/ads/audit-trail/apply-session.md
  Registry:  14 reversal records created (rev-001 through rev-014)
```

---

## Step 3: Verify in the Audit Trail

The audit trail records every action with timestamps, resource IDs, and reversal instructions:

```markdown
## Apply Session — 2026-03-15 16:09

**Draft:** 2026-03-15-acme-negatives.md
**Account:** Acme Equipment Co. (1234567890)
**Actions planned:** 14
**Started:** 2026-03-15T16:09:51-05:00

### Action Results

| # | Action | Target | Detail | Status | Reversal ID |
|---|--------|--------|--------|--------|-------------|
| 1 | ADD_NEGATIVE | Campaign: Search | "near me" [PHRASE] | ✅ Applied | rev-001 |
| 2 | ADD_NEGATIVE | Campaign: Search | "debris chute" [PHRASE] | ✅ Applied | rev-002 |
| ... | ... | ... | ... | ... | ... |
| 14 | PAUSE_KW | AG: High-Intent | "waste management" [EXACT] | ✅ Applied | rev-014 |

### Summary
- **Succeeded:** 14/14
- **Failed:** 0/14
```

---

## Step 4: Undo (if needed)

```
# Undo a single action
/google-ads undo rev-001

# Output:
  Reversing rev-001: REMOVE negative "near me" [PHRASE] from Campaign: Search
  ✅ Removed
  ✅ Verified — negative no longer exists
  Reversal logged to audit trail.
```

---

## Key Takeaways

1. **You always see what will happen before it happens.** The dry run is mandatory.
2. **You must explicitly confirm.** No auto-approve, no timeout.
3. **Every action is verified.** GAQL re-query confirms the change took effect.
4. **Every action is reversible.** Reversal records are created automatically.
5. **The audit trail is append-only.** Full history of everything applied and undone.
