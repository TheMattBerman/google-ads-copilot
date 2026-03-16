---
name: google-ads-audit
description: >
  Full Google Ads review that synthesizes tracking, search terms, intent mapping, negatives,
  structure, RSAs, budget decisions, and PMax context into a single operator read.
  Pulls live data via MCP or works with manual exports. Produces a prioritized batch of
  action drafts.
---

# Google Ads Audit

This is the broad review.
Not just a checklist.
A synthesis of what the account is learning, where it is leaking, and what should change.

Read first:
- `google-ads/references/operator-thesis.md`
- `google-ads/references/intent-map.md`
- `google-ads/references/query-patterns.md`
- `google-ads/references/negatives-playbook.md`
- `google-ads/references/tracking-playbook.md`
- `google-ads/references/structure-playbook.md`
- `google-ads/references/rsa-playbook.md`
- `google-ads/references/budget-playbook.md`
- `google-ads/references/benchmarks.md`
- `google-ads/references/deliverable-templates.md`

Read workspace if available:
- All `workspace/ads/` files except `assets.md` (unless creative output is needed)
- Including `workspace/ads/drafts/_index.md` — check for existing pending drafts

---

## Data Acquisition

### Connected Mode (MCP available)

The audit pulls data across all skill areas. Run queries in this order (each feeds into the next):

**1. Account overview:**
```sql
SELECT
  customer.id,
  customer.descriptive_name,
  customer.currency_code,
  customer.time_zone,
  customer.auto_tagging_enabled
FROM customer
```

**2. Tracking health (check trust first):**
```sql
SELECT
  conversion_action.name,
  conversion_action.type,
  conversion_action.category,
  conversion_action.counting_type,
  conversion_action.include_in_conversions_metric,
  metrics.conversions,
  metrics.all_conversions
FROM conversion_action
WHERE segments.date DURING LAST_30_DAYS
  AND conversion_action.status = 'ENABLED'
ORDER BY metrics.conversions DESC
```

**3. Campaign performance and structure:**
```sql
SELECT
  campaign.name,
  campaign.status,
  campaign.advertising_channel_type,
  campaign.bidding_strategy_type,
  campaign_budget.amount_micros,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.conversions_value,
  metrics.cost_per_conversion,
  metrics.search_impression_share,
  metrics.search_budget_lost_impression_share
FROM campaign
WHERE campaign.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
ORDER BY metrics.cost_micros DESC
```

**4. Search terms (top 500 by spend):**
```sql
SELECT
  search_term_view.search_term,
  campaign.name,
  ad_group.name,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.conversions_value
FROM search_term_view
WHERE segments.date DURING LAST_30_DAYS
ORDER BY metrics.cost_micros DESC
LIMIT 500
```

**5. Ad group structure:**
```sql
SELECT
  campaign.name,
  ad_group.name,
  ad_group.status,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions
FROM ad_group
WHERE campaign.status = 'ENABLED'
  AND ad_group.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
ORDER BY campaign.name
```

**6. Keyword view (targeted keywords — cross-reference with search terms):**
```sql
SELECT
  campaign.name,
  ad_group.name,
  ad_group_criterion.keyword.text,
  ad_group_criterion.keyword.match_type,
  ad_group_criterion.status,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions
FROM keyword_view
WHERE campaign.status = 'ENABLED'
  AND ad_group.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
ORDER BY metrics.cost_micros DESC
LIMIT 200
```

**7. Existing negatives:**
```sql
SELECT
  campaign.name,
  campaign_criterion.keyword.text,
  campaign_criterion.keyword.match_type
FROM campaign_criterion
WHERE campaign_criterion.negative = TRUE
  AND campaign_criterion.type = 'KEYWORD'
```

**8. RSA assets (if time permits):**
```sql
SELECT
  asset.text_asset.text,
  asset.type,
  ad_group_ad_asset_view.performance_label,
  ad_group_ad_asset_view.field_type,
  campaign.name,
  metrics.impressions,
  metrics.clicks,
  metrics.conversions
FROM ad_group_ad_asset_view
WHERE segments.date DURING LAST_30_DAYS
  AND campaign.status = 'ENABLED'
ORDER BY metrics.impressions DESC
```

See `data/gaql-recipes.md` for additional/variant queries.

### Date Range Fallback

All date-ranged queries above default to `LAST_30_DAYS`. If results are empty or near-zero (<$5 total spend):

1. Re-run with `DURING LAST_90_DAYS`
2. If still empty, re-run without a date filter (all-time)
3. **Always state the date range used** in the output header
4. **If fallback was needed**, note: "Account dormant — using [range] for historical context"

This prevents reporting "no data" on paused or seasonal accounts that have useful history.

### Export Mode (no MCP)

Ask the user for as much as they can provide:
- Campaign overview (last 30 days)
- Search Terms report (last 30 days, top 200+)
- Conversion actions list
- Current negative keyword list
- RSA asset report (optional)
- Any notes on tracking, recent changes, or known issues

The audit works with partial data — it will note confidence limitations.

---

## Audit Order

### 1. Can we trust the account?
If tracking is weak, say so immediately. Assign tracking confidence level (High/Medium/Low/Broken).
Note which downstream conclusions are conditional on tracking trust.

### 2. What is the account learning about buyer intent?
Summarize the query and intent reality. Build or update the Intent Map.
Note where intent classes are well-routed vs. poorly routed.

### 3. Where is waste leaking spend?
Identify junk, ambiguity, and routing failures. Quantify the waste.
Separate "waste from bad queries" from "waste from bad structure."

### 4. What should be negative vs. isolated vs. already wrongly negated?
Distinguish exclusion from structure problems.
Default to isolation when in doubt.
**Also review existing negatives for harm:** Check if any current negatives are blocking traffic that matches the business's services. Smart campaign auto-negatives and inherited negatives are common culprits. If harmful negatives are found, include a "Negatives to Remove" section in the negative draft.

### 5. What structure changes matter most?
Focus on where meaning is being mixed.
Prioritize by spend impact, not by cosmetic neatness.

### 6. Are RSAs aligned with buyer language?
Check whether ads reflect real intent and LP promise.
Note specific gaps between search language and ad copy.

### 7. What deserves more budget, less budget, or no touch yet?
Make support/protect/reduce/hold decisions.
**Gate budget scaling behind tracking confidence.**

### 8. Are landing pages converting (or do they look like they should be)?
When conversion rates look suspiciously low, run a quick Fork A check (tracking) before blaming the landing page. If clicks are high but conversions are near-zero, the tag may not be firing — not the page's fault. For full landing page → conversion path diagnosis, delegate to `/google-ads landing-review`. See `skills/google-ads-landing-review/SKILL.md` and `google-ads/references/landing-page-playbook.md`.

### 9. Is PMax helping or contaminating signal?
Be explicit about inference vs. direct evidence.
Check for branded/high-intent cannibalization.

## Draft Output

### Prioritized Draft Batch
The audit produces **multiple drafts** organized by priority. Not everything needs fixing at once.

**Priority tiers:**
1. **Fix first** — tracking problems that gate everything else
2. **Quick wins** — clear negatives that stop obvious waste
3. **Strategic moves** — structure changes, budget reallocation
4. **Refinement** — RSA refreshes, minor optimizations

For each tier with actionable findings, create a draft:
- Tracking fixes → `drafts/templates/tracking-draft.md` → `workspace/ads/drafts/YYYY-MM-DD-tracking-fix.md`
- Negatives → `drafts/templates/negative-draft.md` → `workspace/ads/drafts/YYYY-MM-DD-negatives.md`
- Structure → `drafts/templates/structure-draft.md` → `workspace/ads/drafts/YYYY-MM-DD-structure.md`
- Budget → `drafts/templates/budget-draft.md` → `workspace/ads/drafts/YYYY-MM-DD-budget-realloc.md`
- RSAs → `drafts/templates/rsa-draft.md` → `workspace/ads/drafts/YYYY-MM-DD-rsa-refresh.md`
- Landing page → `drafts/templates/landing-review-draft.md` → `workspace/ads/drafts/YYYY-MM-DD-landing-review.md`

**Cross-reference dependencies between drafts.** E.g., "Apply tracking fix before budget scaling."

Update `workspace/ads/drafts/_index.md` with all new drafts.

### Always update workspace memory:
- `workspace/ads/intent-map.md` — build or update from search terms
- `workspace/ads/findings.md` — audit findings log
- `workspace/ads/negatives.md` — recommended negatives
- `workspace/ads/learnings.md` — what we learned
- `workspace/ads/account.md` — account context if this is first audit

## Output Shape
1. **Account Status block** — account name, CID, status (active/suspended/dormant), date range used, tracking confidence, mode
2. **Executive summary** — 3-5 sentences: biggest issues, tracking trust, top priority
3. Tracking confidence detail (High/Medium/Low/Broken)
4. Intent landscape (brief Intent Map)
5. Waste analysis (quantified)
6. Structure assessment
7. RSA alignment check
8. Budget posture
9. PMax assessment
10. **Prioritized action plan** — organized by tier
11. Drafts created (list with paths, summaries, and dependencies)
12. Confidence assessment
13. Memory updates

## Rules
- Tracking trust comes first. Everything else is conditional.
- Search behavior beats generic advice.
- Distinguish symptoms from root causes.
- Do not bury the highest-leverage decision.
- Use benchmarks as context, not as authority.
- **The audit is the highest-value skill in the system. It should produce the clearest, most actionable output. Every finding should either become a draft or be explicitly marked as "no action needed."**
- **Prioritize ruthlessly. An audit that recommends 30 equally-weighted changes is useless. An audit that identifies the 3 things that matter most is gold.**
