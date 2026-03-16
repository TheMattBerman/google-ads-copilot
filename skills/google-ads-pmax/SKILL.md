---
name: google-ads-pmax
description: >
  Analyze Performance Max through the lens of intent contamination, cannibalization,
  weak control surfaces, and what can still be learned despite PMax opacity.
  Pulls live data via MCP or works with manual exports.
---

# Google Ads PMax

Read first:
- `google-ads/references/operator-thesis.md`
- `google-ads/references/intent-map.md`
- `google-ads/references/query-patterns.md`
- `google-ads/references/structure-playbook.md`
- `google-ads/references/benchmarks.md`
- `google-ads/references/deliverable-templates.md`

Read workspace if available:
- `workspace/ads/account.md`
- `workspace/ads/goals.md`
- `workspace/ads/intent-map.md`
- `workspace/ads/findings.md`
- `workspace/ads/change-log.md`
- `workspace/ads/learnings.md`

---

## Data Acquisition

### Connected Mode (MCP available)

Pull via the `search` tool on `google-ads-mcp`:

**Primary: PMax campaign performance:**
```sql
SELECT
  campaign.name,
  campaign.status,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.conversions_value,
  metrics.cost_per_conversion
FROM campaign
WHERE campaign.advertising_channel_type = 'PERFORMANCE_MAX'
  AND campaign.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
```

**Primary: Asset group performance:**
```sql
SELECT
  campaign.name,
  asset_group.name,
  asset_group.status,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions
FROM asset_group
WHERE campaign.advertising_channel_type = 'PERFORMANCE_MAX'
  AND segments.date DURING LAST_30_DAYS
```

**Supplementary: Compare with Search campaign performance (cannibalization check):**
```sql
SELECT
  campaign.name,
  campaign.advertising_channel_type,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.cost_per_conversion
FROM campaign
WHERE campaign.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
ORDER BY metrics.cost_micros DESC
```

See `data/gaql-recipes.md` for additional queries.

### Export Mode (no MCP)

Ask the user for:
- PMax campaign metrics
- Asset group list with performance
- Search campaign performance (for comparison)
- Any listing group or audience signal notes

---

## Core Questions
- Is PMax cannibalizing branded or clean high-intent traffic?
- Is it helping discover net-new signal, or just absorbing existing demand?
- What can we infer about intent quality despite limited visibility?
- What should be protected outside PMax?
- What should be fixed in feeds, exclusions, or surrounding structure?

## Process
1. **Announce mode** (connected/export).
2. Pull PMax and Search campaign data.
3. Compare PMax vs. Search on shared conversion actions.
4. Look for branded cannibalization signals.
5. Assess asset group quality.
6. Identify what should be protected in dedicated Search campaigns.

## Draft Output
PMax analysis **typically does not produce its own draft type** — its findings feed into:
- **Structure drafts** (if PMax is cannibalizing, recommend brand exclusions or campaign restructure)
- **Negative drafts** (if account-level negatives can help contain PMax)
- **Budget drafts** (if PMax is absorbing budget that should go to proven Search campaigns)

When PMax-specific actions are needed, use the structure draft template and note the PMax context.

### Always update workspace memory:
- `workspace/ads/findings.md` — PMax observations (inference vs. direct evidence)
- `workspace/ads/learnings.md` — what we learned about PMax behavior in this account

## Output Format
Use operator summary, then add:
- Cannibalization risks (with evidence level)
- Useful signal PMax may still be surfacing
- What should be protected in Search or other buckets
- What is direct evidence vs inference

## Rules
- Treat PMax as useful but not self-explanatory.
- Look for contamination before celebrating efficiency.
- Protect clean branded and high-intent buckets when needed.
- Be explicit about what is inference versus direct evidence.
- If visibility is weak, say that clearly instead of pretending certainty.
