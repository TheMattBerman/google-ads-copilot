# Draft: Budget Reallocation — [DATE]
Status: proposed
Skill: /google-ads budget
Account: [Customer ID / Name]

## Summary
[One paragraph: what budget shifts are proposed, total $ impact, and why.]

## Evidence
- Source: [budget analysis / daily review / audit]
- Period analyzed: [last 30 days]
- Current total daily budget: $[total]
- Key metrics driving this: [CPA differences, impression share gaps, signal quality]
- Related workspace files: findings.md, goals.md

## Proposed Actions

### Reallocation 1: [Campaign Name]
- **Current daily budget:** $[amount]
- **Proposed daily budget:** $[amount]
- **Change:** [+$X / -$X / +Y%]
- **Reason:** [e.g., "Strong buyer intent, 40% IS lost to budget, CPA $22 vs account avg $45"]
- **Expected impact:** [More conversions at current CPA / Reduced waste / etc.]
- **Risk:** [What if we're wrong — bounded by daily cap]
- **Reversibility:** Easy (change budget back)

### Reallocation 2: [Campaign Name]
- **Current daily budget:** $[amount]
- **Proposed daily budget:** $[amount]
- **Change:** [-$X]
- **Reason:** [e.g., "Mixed intent, 60% of spend on non-converting research queries"]
- **Dependency:** [e.g., "Better after negatives from draft X are applied"]
- **Reversibility:** Easy

## Net Budget Change
- Total before: $[X]/day
- Total after: $[Y]/day
- Net change: $[+/-Z]/day
- [Or: "Budget-neutral reallocation — same total, different distribution"]

---

## Apply Manifest

```json
{
  "draft_version": "0.2",
  "customer_id": "[10-digit CID]",
  "meta": {
    "budget_policy": {
      "allow_net_increase": false,
      "max_net_increase_pct": 10
    }
  },
  "actions": [
    {
      "id": "b1",
      "type": "SET_CAMPAIGN_DAILY_BUDGET",
      "risk": "medium",
      "reason": "[short reason <= 240 chars]",
      "targets": {
        "campaign_name": "[Campaign Name]",
        "proposed_daily_budget_micros": 0
      },
      "guardrails": {
        "max_pct_change": 30,
        "cooldown_days": 7,
        "require_budget_neutral": true,
        "tracking_min_confidence": "medium"
      }
    }
  ]
}
```

- Set `meta.budget_policy.allow_net_increase` to `true` only when the draft intentionally raises total budget.
- Any allowed net increase is capped at `max_net_increase_pct` (default `10`).

## Dependencies
- [e.g., "Tracking fixes should be applied first" or "None"]

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
