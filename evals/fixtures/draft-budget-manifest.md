# Draft: Budget Reallocation — 2026-03-17
Status: proposed
Skill: /google-ads budget
Account: Acme Equipment Co. (1234567890)

## Summary
Budget-neutral shift from mixed-intent to high-intent.

## Apply Manifest

```json
{
  "draft_version": "0.2",
  "customer_id": "1234567890",
  "customer_name": "Acme Equipment Co.",
  "actions": [
    {
      "id": "b1",
      "type": "SET_CAMPAIGN_DAILY_BUDGET",
      "risk": "medium",
      "reason": "Scale high-intent cautiously within cap.",
      "targets": {
        "campaign_name": "High Intent - Search",
        "proposed_daily_budget_micros": 75000000
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

