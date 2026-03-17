# Apply Manifest — Draft-to-Apply Contract

This document defines the machine-readable “Apply Manifest” format embedded in draft markdown files.

Goals:
- Provide a stable, evaluable contract between the Draft layer and Apply layer.
- Avoid brittle markdown parsing for new action types (budgets, RSA updates, etc.).
- Keep the apply layer implementation compatible with existing constraints (bash + curl + jq).
- Keep budget writes fail-closed unless the manifest explicitly opts into the allowed policy.

## Where It Lives In a Draft

Drafts MAY include an `## Apply Manifest` section with a fenced JSON block:

```markdown
## Apply Manifest

~~~json
{ ... }
~~~
```

Apply-layer parsing rules:
- If a valid manifest is present, it is authoritative (manifest-first).
- If no manifest is present, apply falls back to legacy v1 markdown parsing (negatives + pauses).
- If a manifest is present but invalid, apply MUST fail closed.

## Schema (v0.2)

Top-level object:
- `draft_version` (required): `"0.2"`
- `customer_id` (required): 10-digit string
- `customer_name` (optional): string
- `meta` (optional): object for draft-level policy
- `actions` (required): array of action objects (must be non-empty)

Draft-level `meta.budget_policy` fields used by v2 budget apply:
- `allow_net_increase` (boolean, default `false`): permit a draft-level net budget increase
- `max_net_increase_pct` (integer, default `10`): maximum aggregate increase vs current total budget
- If `allow_net_increase` is omitted or false, the draft must be budget-neutral.

Action object (common fields):
- `id` (required): stable identifier, `^[a-z][a-z0-9_-]{1,31}$`
- `type` (required): action type enum (see below)
- `risk` (required): `"low" | "medium" | "high"`
- `reason` (required): short string (<= 240 chars)
- `depends_on` (optional): array of action ids
- `targets` (required): object; type-specific fields
- `guardrails` (optional): object; required for money-moving actions

## Action Types

### v1 Apply Types (existing)
- `ADD_NEGATIVE_CAMPAIGN`
  - `targets`: `{ "campaign_name": string, "keyword_text": string, "match_type": "PHRASE"|"EXACT"|"BROAD" }`
- `ADD_NEGATIVE_ADGROUP`
  - `targets`: `{ "campaign_name": string, "adgroup_name": string, "keyword_text": string, "match_type": "PHRASE"|"EXACT"|"BROAD" }`
- `PAUSE_KEYWORD`
  - `targets`: `{ "campaign_name": string, "adgroup_name": string, "keyword_text": string, "match_type": "PHRASE"|"EXACT"|"BROAD" }`
- `PAUSE_ADGROUP`
  - `targets`: `{ "campaign_name": string, "adgroup_name": string }`

### v2 Apply Types (budgets)
- `SET_CAMPAIGN_DAILY_BUDGET`
  - `targets`: `{ "campaign_name": string, "proposed_daily_budget_micros": integer }`
  - `guardrails` (required by v2 apply implementation):
    - `max_pct_change` (integer, default 30)
    - `cooldown_days` (integer, default 7)
    - `require_budget_neutral` (boolean, default true)
    - `tracking_min_confidence` (`"medium"` default)

## Example (Budget Reallocation)

```json
{
  "draft_version": "0.2",
  "customer_id": "1234567890",
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
      "reason": "Budget-limited buyer intent campaign; scale cautiously within cap.",
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

Budget drafts MUST use the Apply Manifest. Legacy markdown parsing remains available for v1 negative and pause drafts only.
