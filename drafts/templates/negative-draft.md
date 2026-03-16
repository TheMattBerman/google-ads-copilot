# Draft: Negative Keywords — [DATE]
Status: proposed
Skill: /google-ads negatives
Account: [Customer ID / Name]

## Summary
[One paragraph: how many negatives to add, how many to remove/narrow, which campaigns, why these were selected.]

## Evidence
- Source: [search-terms analysis / intent-map review / audit]
- Date range analyzed: [e.g., last 30 days]
- Total waste identified: $[amount] on [N] non-converting terms
- Keyword view cross-reference: [Yes/No — note which targeted keywords triggered waste]
- Related workspace files: findings.md, queries.md

---

## Section A: Negatives to ADD

### Negative 1: "[keyword]"
- **Match type:** phrase | exact | broad
- **Scope:** Campaign "[name]" | Ad Group "[name]" | Shared list "[name]"
- **Reason:** [Why this is bad traffic — intent class, zero conversions, etc.]
- **Triggering keyword:** [Which targeted keyword(s) caused this match, if known from keyword_view]
- **Spend wasted:** $[amount] over [period]
- **Collateral risk:** [What good traffic could be blocked — or "none identified"]
- **Reversibility:** Easy (remove negative)

### Negative 2: "[keyword]"
- **Match type:**
- **Scope:**
- **Reason:**
- **Triggering keyword:**
- **Spend wasted:**
- **Collateral risk:**
- **Reversibility:** Easy

[... repeat for each negative to add]

---

## Section B: Negatives to REMOVE

Existing negatives that may be blocking valuable traffic. These should be reviewed and removed or narrowed.

### Remove 1: "[keyword]"
- **Current match type:** [phrase | exact | broad]
- **Current scope:** Campaign "[name]" | Ad Group "[name]" | Shared list "[name]"
- **Reason to remove:** [Why this negative is harmful — blocking valuable traffic, overly broad, outdated]
- **Evidence:** [What traffic is being blocked? Estimated opportunity cost? Did keyword_view show low impressions on terms this negative might suppress?]
- **Risk of removal:** [What bad traffic might return if removed]
- **Alternative:** [If not full removal — narrow to exact match? Move to different scope? Replace with more specific negative?]

### Remove 2: "[keyword]"
- **Current match type:**
- **Current scope:**
- **Reason to remove:**
- **Evidence:**
- **Risk of removal:**
- **Alternative:**

[... repeat for each negative to remove]

---

## Section C: Negatives to NARROW or MOVE

Existing negatives that aren't wrong, but are scoped too broadly or placed at the wrong level.

### Narrow 1: "[keyword]"
- **Current state:** [match type] at [scope]
- **Proposed change:** [new match type] at [new scope]
- **Reason:** [Why the current scope is too aggressive]
- **Example of blocked good traffic:** [Specific queries being suppressed]

[... repeat for each]

---

## Dependencies
- [e.g., "Apply structure changes from 2026-03-14-structure.md first" or "None"]

## Confidence
[High / Medium / Low] — [reasoning]

## Review
- [ ] Reviewed by operator
- [ ] Approved for implementation
- Reviewed on: ____
- Applied on: ____
- Notes: ____
