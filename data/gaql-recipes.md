# GAQL Recipes — Google Ads Copilot

Standard queries for each skill's data needs. All queries go through the `search` tool on the `google-ads-mcp` MCP server.

**Reference:** https://developers.google.com/google-ads/api/docs/query/overview

**Note:** Replace `{customer_id}` with the actual customer ID (no dashes). Date ranges use `YYYY-MM-DD` format.

---

## Account Discovery

```sql
-- List all campaigns with status and type
SELECT
  campaign.id,
  campaign.name,
  campaign.status,
  campaign.advertising_channel_type,
  campaign.bidding_strategy_type,
  campaign_budget.amount_micros
FROM campaign
WHERE campaign.status != 'REMOVED'
ORDER BY campaign.name
```

```sql
-- Account-level settings
SELECT
  customer.id,
  customer.descriptive_name,
  customer.currency_code,
  customer.time_zone,
  customer.auto_tagging_enabled
FROM customer
```

---

## Daily Operator (`/google-ads daily`)

```sql
-- Campaign performance: last 7 days vs prior 7 days
SELECT
  campaign.name,
  campaign.status,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.conversions_value,
  metrics.cost_per_conversion,
  segments.date
FROM campaign
WHERE segments.date DURING LAST_7_DAYS
  AND campaign.status = 'ENABLED'
ORDER BY metrics.cost_micros DESC
```

```sql
-- Same query for prior period comparison
SELECT
  campaign.name,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.cost_per_conversion,
  segments.date
FROM campaign
WHERE segments.date BETWEEN '2026-03-01' AND '2026-03-07'
  AND campaign.status = 'ENABLED'
ORDER BY metrics.cost_micros DESC
```

---

## Search Terms (`/google-ads search-terms`)

```sql
-- Search terms report: last 30 days, sorted by spend
SELECT
  search_term_view.search_term,
  search_term_view.status,
  campaign.name,
  ad_group.name,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.conversions_value,
  metrics.cost_per_conversion
FROM search_term_view
WHERE segments.date DURING LAST_30_DAYS
ORDER BY metrics.cost_micros DESC
LIMIT 500
```

```sql
-- Search terms with zero conversions and spend > $10
SELECT
  search_term_view.search_term,
  campaign.name,
  ad_group.name,
  metrics.cost_micros,
  metrics.clicks,
  metrics.impressions
FROM search_term_view
WHERE segments.date DURING LAST_30_DAYS
  AND metrics.conversions = 0
  AND metrics.cost_micros > 10000000
ORDER BY metrics.cost_micros DESC
```

---

## Intent Map (`/google-ads intent-map`)

```sql
-- All search terms with performance data for clustering
SELECT
  search_term_view.search_term,
  campaign.name,
  campaign.advertising_channel_type,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.conversions_value,
  metrics.all_conversions
FROM search_term_view
WHERE segments.date DURING LAST_30_DAYS
ORDER BY metrics.impressions DESC
LIMIT 1000
```

---

## Negatives (`/google-ads negatives`)

```sql
-- Existing campaign-level negatives
SELECT
  campaign.name,
  campaign_criterion.keyword.text,
  campaign_criterion.keyword.match_type,
  campaign_criterion.negative
FROM campaign_criterion
WHERE campaign_criterion.negative = TRUE
  AND campaign_criterion.type = 'KEYWORD'
```

```sql
-- Existing shared negative keyword lists
SELECT
  shared_set.name,
  shared_set.type,
  shared_set.member_count,
  shared_set.status
FROM shared_set
WHERE shared_set.type = 'NEGATIVE_KEYWORDS'
  AND shared_set.status = 'ENABLED'
```

---

## Tracking (`/google-ads tracking`)

```sql
-- Conversion actions and their configuration
SELECT
  conversion_action.id,
  conversion_action.name,
  conversion_action.type,
  conversion_action.category,
  conversion_action.status,
  conversion_action.counting_type,
  conversion_action.include_in_conversions_metric,
  conversion_action.value_settings.default_value
FROM conversion_action
WHERE conversion_action.status = 'ENABLED'
```

```sql
-- Conversion performance by action (detect duplicates/pollution)
SELECT
  conversion_action.name,
  conversion_action.type,
  conversion_action.category,
  metrics.conversions,
  metrics.conversions_value,
  metrics.all_conversions
FROM conversion_action
WHERE segments.date DURING LAST_30_DAYS
  AND conversion_action.status = 'ENABLED'
ORDER BY metrics.conversions DESC
```

---

## Structure (`/google-ads structure`)

```sql
-- Ad group structure with performance
SELECT
  campaign.name,
  campaign.advertising_channel_type,
  ad_group.name,
  ad_group.status,
  ad_group.type,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.cost_per_conversion
FROM ad_group
WHERE campaign.status = 'ENABLED'
  AND ad_group.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
ORDER BY campaign.name, ad_group.name
```

```sql
-- Keywords per ad group (check for intent mixing)
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
ORDER BY campaign.name, ad_group.name
```

---

## Keyword View (supplementary for search-terms, negatives, audit)

```sql
-- Targeted keywords with performance (cross-reference with search terms)
SELECT
  campaign.name,
  ad_group.name,
  ad_group_criterion.keyword.text,
  ad_group_criterion.keyword.match_type,
  ad_group_criterion.status,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions,
  metrics.cost_per_conversion
FROM keyword_view
WHERE campaign.status = 'ENABLED'
  AND ad_group.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
ORDER BY metrics.cost_micros DESC
LIMIT 200
```

**Purpose:** Cross-reference with search_term_view to understand which targeted keywords are triggering wasteful search terms. If a single broad-match keyword generates most of the waste, keyword narrowing/pausing may be better than adding negatives.

---

## RSAs (`/google-ads rsas`)

```sql
-- RSA asset performance
SELECT
  campaign.name,
  ad_group.name,
  ad_group_ad.ad.responsive_search_ad.headlines,
  ad_group_ad.ad.responsive_search_ad.descriptions,
  ad_group_ad.ad.final_urls,
  ad_group_ad.policy_summary.approval_status,
  metrics.impressions,
  metrics.clicks,
  metrics.conversions,
  metrics.cost_micros
FROM ad_group_ad
WHERE ad_group_ad.ad.type = 'RESPONSIVE_SEARCH_AD'
  AND campaign.status = 'ENABLED'
  AND ad_group.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
```

```sql
-- Asset-level performance (headline/description level)
SELECT
  asset.text_asset.text,
  asset.type,
  ad_group_ad_asset_view.performance_label,
  ad_group_ad_asset_view.field_type,
  campaign.name,
  ad_group.name,
  metrics.impressions,
  metrics.clicks,
  metrics.conversions
FROM ad_group_ad_asset_view
WHERE segments.date DURING LAST_30_DAYS
  AND campaign.status = 'ENABLED'
ORDER BY metrics.impressions DESC
```

---

## Budget (`/google-ads budget`)

```sql
-- Campaign budgets and spend
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

```sql
-- Search impression share (budget-limited detection)
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

---

## PMax (`/google-ads pmax`)

```sql
-- PMax campaign performance
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

```sql
-- PMax asset group performance
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

---

## Change History (for audit and daily)

```sql
-- Recent changes to the account
SELECT
  change_event.change_date_time,
  change_event.change_resource_type,
  change_event.change_resource_name,
  change_event.client_type,
  change_event.user_email,
  change_event.old_resource,
  change_event.new_resource
FROM change_event
WHERE change_event.change_date_time DURING LAST_14_DAYS
ORDER BY change_event.change_date_time DESC
LIMIT 100
```

---

## Notes

- All `cost_micros` values are in micros (1,000,000 = $1.00)
- GAQL `DURING` clauses: `LAST_7_DAYS`, `LAST_14_DAYS`, `LAST_30_DAYS`, `LAST_90_DAYS`, `LAST_12_MONTHS`, `THIS_MONTH`, `LAST_MONTH`
- Custom date ranges: `WHERE segments.date BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'`
- `LIMIT` recommended for large accounts — start with 500, adjust as needed
- Not all resource+metric combinations are valid — check the GAQL reference if a query fails

### Date Range Fallback

If a query returns 0 rows or <$5 total spend, widen the date range:

1. `DURING LAST_30_DAYS` (default)
2. `DURING LAST_90_DAYS`
3. `DURING LAST_12_MONTHS`
4. No date filter (all time)

Always note which range was used in the output. See the main skill's Date Range Fallback Protocol.

### MCP Call Format

The `google-ads-mcp` MCP server uses structured parameters, not raw GAQL:

```json
{
  "customer_id": "YOUR_CUSTOMER_ID",
  "resource": "search_term_view",
  "fields": ["search_term_view.search_term", "metrics.cost_micros", "metrics.conversions"],
  "conditions": ["segments.date DURING LAST_30_DAYS", "metrics.cost_micros > 0"],
  "orderings": ["metrics.cost_micros DESC"],
  "limit": 500
}
```

Use `--output raw` with mcporter to see all results (default shows only the first).
