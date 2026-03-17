# Draft: Tracking Fixes — [DATE]
Status: proposed
Skill: /google-ads tracking
Account: [Customer ID / Name]

## Summary
[One paragraph: what tracking problems were found and what fixes are proposed.]

## Evidence
- Source: [tracking diagnosis / audit]
- Current tracking confidence: [High / Medium / Low]
- Primary issue: [duplicate counting / micro-conversion pollution / missing conversions / etc.]
- Related workspace files: findings.md, account.md

## Proposed Actions

### Fix 1: [Specific tracking change]
- **Current state:** [e.g., "GA4 import + native tag both counting same lead form as primary"]
- **Proposed state:** [e.g., "Remove GA4 import, keep native tag as sole primary conversion"]
- **Impact on reported conversions:** [e.g., "Conversions will drop ~40% but accuracy improves"]
- **Impact on bidding:** [e.g., "Smart bidding will recalibrate over 2-3 weeks"]
- **Risk:** [Learning period, possible CPA spike during recalibration]
- **Reversibility:** Easy (re-add conversion action)

### Fix 2: [e.g., "Remove 'page scroll' from primary conversions"]
- **Current state:** [Micro-conversion set as primary, inflating conversion count]
- **Proposed state:** [Move to secondary/observation-only]
- **Impact:** [Lower reported conversions, cleaner optimization signal]
- **Risk:** [Bid strategy may temporarily reduce spend]
- **Reversibility:** Easy

## Decisions That Should Wait Until Tracking Is Fixed
- [e.g., "Budget scaling — current CPA is artificially low due to double counting"]
- [e.g., "Campaign structure changes — can't tell what's actually converting"]

## Confidence
[High / Medium / Low] — [reasoning]

## Review
- [ ] Evidence checked
- [ ] Collateral risk checked
- [ ] Dependencies checked
- **Decision:** approve | defer | reject
- **Decision reason:** ____
- **Reviewed by:** ____
- **Reviewed on:** ____
- **Applied on:** ____
- **Notes:** ____
