---
name: google-ads-budget
description: >
  Review Google Ads budget allocation and scaling decisions based on signal quality,
  intent clarity, tracking confidence, and structural health. Pulls live data via MCP
  or works with manual exports. Produces budget reallocation drafts.
---

# Google Ads Budget

Read first:
- `google-ads/references/operator-thesis.md`
- `google-ads/references/intent-map.md`
- `google-ads/references/tracking-playbook.md`
- `google-ads/references/structure-playbook.md`
- `google-ads/references/budget-playbook.md`
- `google-ads/references/deliverable-templates.md`

Read workspace if available:
- `workspace/ads/account.md`
- `workspace/ads/goals.md`
- `workspace/ads/intent-map.md`
- `workspace/ads/winners.md`
- `workspace/ads/findings.md`
- `workspace/ads/change-log.md`
- `workspace/ads/learnings.md`
- `workspace/ads/drafts/_index.md` — check if tracking fixes are pending (gates scaling)

---

## Data Acquisition

### Connected Mode (MCP available)

Pull via the `search` tool on `google-ads-mcp`:

**Primary: Campaign budgets and spend:**
```sql
SELECT
  campaign.name,
  campaign.status,
  campaign_budget.amount_micros,
  campaign_budget.delivery_method,
  campaign.bidding_strategy_type,
  metrics.cost_micros,
  metrics.conversions,
  metrics.cost_per_conversion,
  metrics.impressions,
  metrics.search_impression_share
FROM campaign
WHERE campaign.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
```

**Primary: Impression share and budget-limited detection:**
```sql
SELECT
  campaign.name,
  metrics.search_impression_share,
  metrics.search_budget_lost_impression_share,
  metrics.search_rank_lost_impression_share,
  metrics.cost_micros,
  metrics.conversions
FROM campaign
WHERE campaign.status = 'ENABLED'
  AND campaign.advertising_channel_type = 'SEARCH'
  AND segments.date DURING LAST_7_DAYS
```

**Supplementary: Tracking confidence check:**
```sql
SELECT
  conversion_action.name,
  conversion_action.type,
  conversion_action.counting_type,
  conversion_action.include_in_conversions_metric,
  metrics.conversions
FROM conversion_action
WHERE conversion_action.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
ORDER BY metrics.conversions DESC
```

See `data/gaql-recipes.md` for additional queries.

### Date Range Fallback

If `LAST_30_DAYS` returns 0 rows, fall back to `LAST_90_DAYS`. For budget analysis, older data is less useful — if 90 days is also empty, note "Account dormant: no activity to base budget decisions on" and recommend a plan or audit instead. Always state the date range used.

### Export Mode (no MCP)

Ask the user for:
- Campaign budget report: Budget, Spend, Conversions, Search IS%, Budget Lost IS%
- Last 30 days preferred

---

## Process
1. **Announce mode** (connected/export).
2. **Check tracking confidence first** — from workspace findings or quick tracking check.
   - If tracking confidence is Low/Broken, flag that budget decisions are provisional.
   - Check `workspace/ads/drafts/_index.md` for pending tracking fix drafts.
3. Identify which buckets are buying clean signal vs. noisy traffic.
4. Assess impression share — where is budget the constraint vs. where is it quality?
5. Distinguish between budget constraints and structural/intent problems.
6. Recommend:
   - **Scale** — clean signal, budget-limited, good CPA
   - **Protect** — working well, don't starve it
   - **Reduce** — noisy traffic, poor signal, overfunded
   - **Hold** — needs more data or structural fix before budget decision
   - **Fix-before-scaling** — blocked by tracking, structure, or intent problems

## Draft Output

### Budget Reallocation Draft
**Trigger:** Analysis identifies campaigns where budget is clearly misallocated (strong campaign starved while weak campaign overfunded), AND tracking confidence is at least Medium.

Create using `drafts/templates/budget-draft.md`:
- Write to `workspace/ads/drafts/YYYY-MM-DD-budget-realloc.md`
- Include: current daily budget, proposed daily budget, change amount, reason, expected impact
- Show net budget change (budget-neutral reallocation vs. total spend change)
- Note tracking confidence gate
- Update `workspace/ads/drafts/_index.md`

### Blocking conditions
Do **not** produce a budget draft if:
- Tracking confidence is Low or Broken (recommend tracking fix instead)
- A pending tracking fix draft exists that hasn't been applied

Instead, note: "Budget decisions are blocked until tracking fix draft [X] is resolved."

### Always update workspace memory:
- `workspace/ads/findings.md` — budget observations
- `workspace/ads/learnings.md` — what we learned about spend efficiency

## Rules
- Do not scale ambiguous traffic just because volume is available.
- Do not mistake structure problems for budget problems.
- If tracking confidence is low, say that budget decisions are provisional.
- **Budget scaling is the highest-risk action in the system. Gate it behind tracking trust.**
