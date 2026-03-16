# Draft: Pause Actions — [DATE]
Status: proposed
Skill: /google-ads search-terms | /google-ads audit | /google-ads structure
Account: [Customer ID / Name]

## Summary
[One paragraph: how many keywords and ad groups to pause, why, estimated waste stopped.]

## Evidence
- Source: [search-terms analysis / structure review / audit]
- Date range analyzed: [e.g., last 30 days]
- Total waste identified: $[amount] on paused entities
- Tracking confidence: [HIGH / MEDIUM / LOW / BROKEN]
- Related workspace files: findings.md, intent-map.md

---

## Section A: Keywords to PAUSE

### Keyword Pause 1: "[keyword]" [MATCH TYPE]
- **Campaign:** "[campaign name]"
- **Ad group:** "[ad group name]"
- **Current status:** ENABLED
- **Match type:** [EXACT / PHRASE / BROAD]
- **Spend (period):** $[amount] over [period]
- **Conversions:** [count] at $[CPA] CPA
- **Problem:** [Why this keyword should be paused — wrong intent, competitor brand navigation, inflated conversions, etc.]
- **Why pause vs. negative:** [Explain: "This is the keyword itself, not a search term matching it. A negative won't help — the keyword IS the problem."]
- **Collateral risk:** [What might be lost — usually low if the keyword is clearly wrong]
- **Reversibility:** Easy (set status back to ENABLED)
- **Reversal action:** `ENABLE_KEYWORD`

### Keyword Pause 2: "[keyword]" [MATCH TYPE]
- **Campaign:** "[campaign name]"
- **Ad group:** "[ad group name]"
- **Current status:** ENABLED
- **Match type:** [EXACT / PHRASE / BROAD]
- **Spend (period):** $[amount]
- **Conversions:** [count]
- **Problem:** [reason]
- **Why pause vs. negative:** [reason]
- **Collateral risk:** [risk]
- **Reversibility:** Easy
- **Reversal action:** `ENABLE_KEYWORD`

[... repeat for each keyword to pause]

---

## Section B: Ad Groups to PAUSE

### Ad Group Pause 1: "[ad group name]"
- **Campaign:** "[campaign name]"
- **Current status:** ENABLED
- **Keywords in group:** [count]
- **Spend (period):** $[amount] over [period]
- **Conversions:** [count] at $[CPA] CPA
- **Problem:** [Why this ad group should be paused — intent mismatch at group level, all keywords are waste, test that failed, etc.]
- **Impact scope:** [List key keywords that will stop serving]
- **Why pause vs. restructure:** [Explain: "Pausing is the right first move because X. Restructuring can happen later."]
- **Collateral risk:** [What good traffic might be lost]
- **Reversibility:** Easy (set status back to ENABLED)
- **Reversal action:** `ENABLE_ADGROUP`
- **Pre-pause verification:** [Confirm current status is ENABLED, confirm metrics match draft]

### Ad Group Pause 2: "[ad group name]"
- **Campaign:** "[campaign name]"
- **Current status:** ENABLED
- **Keywords in group:** [count]
- **Spend (period):** $[amount]
- **Conversions:** [count]
- **Problem:** [reason]
- **Impact scope:** [keywords affected]
- **Why pause vs. restructure:** [reason]
- **Collateral risk:** [risk]
- **Reversibility:** Easy
- **Reversal action:** `ENABLE_ADGROUP`
- **Pre-pause verification:** [verification steps]

[... repeat for each ad group to pause]

---

## Section C: Pause Impact Summary

| Entity | Type | Spend Stopped | Conv. Lost | Net Impact |
|--------|------|---------------|------------|------------|
| "[keyword1]" | Keyword | $[amt]/mo | [N] (inflated?) | Positive — waste removal |
| "[keyword2]" | Keyword | $[amt]/mo | [N] | Positive |
| "[adgroup1]" | Ad Group | $[amt]/mo | [N] | Positive |
| **Total** | | **$[amt]/mo** | **[N]** | **$[amt]/mo saved** |

---

## Dependencies
- [e.g., "Apply negatives from 2026-03-15-negatives.md first — clean up search term waste before pausing structural entities"]
- [Or: "None — these pauses are independent"]

## Confidence
[High / Medium / Low] — [reasoning]

## Review
- [ ] Reviewed by operator
- [ ] Approved for implementation
- Reviewed on: ____
- Applied on: ____
- Reversal IDs: ____
- Notes: ____
