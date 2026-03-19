# Search Term Retrieval Ladder

Shared retrieval spec for all search-term-dependent skills. Every skill that needs search query data follows this ladder instead of implementing its own fallback logic.

**Consumers:** `/google-ads search-terms`, `/google-ads negatives`, `/google-ads intent-map`, `/google-ads rsas`, `/google-ads audit`, `/google-ads pmax`

---

## The Ladder

Execute steps in order. For classic `search_term_view` surfaces, "usable rows" means rows plus at least `$5` of spend (`metrics.cost_micros >= 5000000`) in the current probe window. Stop at the first step that produces usable rows.

### Step 1 — Account-wide `search_term_view`

```sql
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

**Success →** `retrieval_mode: classic`, full per-term metrics available. If rows exist but spend is below `$5`, continue down the ladder and widen the date window.

### Step 2 — Search-only `search_term_view`

Same query with `AND campaign.advertising_channel_type = 'SEARCH'`.

Isolates Search campaigns from the query. Useful when account-wide returns errors due to incompatible campaign types.

**Success →** `retrieval_mode: classic-search-only`. Full per-term metrics, but only for Search campaigns. If rows exist but spend is below `$5`, continue down the ladder and widen the date window.

### Step 3 — Campaign enumeration

Pull all campaigns with spend in the period:

```sql
SELECT
  campaign.id,
  campaign.name,
  campaign.advertising_channel_type,
  campaign.status,
  metrics.cost_micros,
  metrics.clicks,
  metrics.conversions
FROM campaign
WHERE segments.date DURING LAST_30_DAYS
ORDER BY metrics.cost_micros DESC
LIMIT 25
```

Classify each campaign:
- Type `SEARCH` (channel type 2) → eligible for campaign-scoped classic retrieval
- Type `PERFORMANCE_MAX` (channel type 10) → eligible for PMax fallback
- Other types → skip for search-term retrieval

### Step 4 — Campaign-scoped classic retrieval (Search campaigns)

For each Search campaign from Step 3:

```sql
SELECT
  search_term_view.search_term,
  campaign.name,
  ad_group.name,
  metrics.impressions,
  metrics.clicks,
  metrics.cost_micros,
  metrics.conversions
FROM search_term_view
WHERE segments.date DURING LAST_30_DAYS
  AND campaign.resource_name = 'customers/<cid>/campaigns/<campaign_id>'
LIMIT 200
```

Aggregate rows and spend across all Search campaigns in the current window.

**Success →** `retrieval_mode: classic-campaign-scoped`. Per-term metrics available, scoped to individual Search campaigns, with combined spend of at least `$5`.

### Step 5 — PMax campaign-scoped `campaign_search_term_view`

For each PMax campaign from Step 3, resolve the resource string `customers/<cid>/campaigns/<campaign_id>`:

```sql
SELECT
  campaign_search_term_view.search_term,
  campaign_search_term_view.campaign
FROM campaign_search_term_view
WHERE campaign_search_term_view.campaign = 'customers/<cid>/campaigns/<campaign_id>'
  AND segments.date DURING LAST_30_DAYS
LIMIT 100
```

**Success →** `retrieval_mode: pmax-fallback`. Query rows available, but **no per-term cost/CPA/conversion metrics**. Language signal only. The `$5` spend threshold does **not** apply here because `campaign_search_term_view` does not expose per-term spend.

### Step 5b — PMax `campaign_search_term_insight` probe

For each PMax campaign, also probe category-level insight:

```sql
SELECT
  campaign_search_term_insight.category_label,
  campaign_search_term_insight.id,
  campaign_search_term_insight.campaign_id
FROM campaign_search_term_insight
WHERE campaign_search_term_insight.campaign_id = <campaign_id>
  AND segments.date DURING LAST_30_DAYS
LIMIT 100
```

**Important:** This resource requires a single-campaign `campaign_id` filter. Account-wide queries will error.

### Step 6 — Limited visibility mode

If no step above produced rows, the account has insufficient search-term visibility for the period.

**→** `retrieval_mode: limited`. Shift to campaign/asset-group/tracking analysis. Request a UI export for exact waste attribution.

---

## Date Range Fallback

Applied by retrying the ladder across progressively broader windows. If the classic search-term steps return 0 rows or less than `$5` of spend:

1. `DURING LAST_30_DAYS` (default)
2. `DURING LAST_14_DAYS`
3. `BETWEEN <90-days-ago> AND <today>`
4. `BETWEEN <365-days-ago> AND <today>`

Always report which date range produced the final result.

---

## Diagnostic Output Shape

Every retrieval run produces a diagnostic header for the consuming skill:

```
## Search Term Retrieval Diagnostics
- Customer ID: <cid>
- Date range: <range used>
- Retrieval mode: <classic | classic-search-only | classic-campaign-scoped | pmax-fallback | limited>
- Rows returned: <count>
- Campaigns probed: <N total, N Search, N PMax, N other>
- Search campaigns with rows: <list or "none">
- PMax campaigns with rows: <list or "none">
- PMax campaigns without rows: <list or "none">
- Visibility notes: <any caveats>
```

When classic rows exist but stay below the spend threshold, note that explicitly before moving to the next step or date window.

### Retrieval modes and what they mean for consumers

| Mode | Per-term metrics | Negative recommendations | Intent clustering | Buyer language extraction |
|------|-----------------|-------------------------|-------------------|--------------------------|
| `classic` | Full | Full confidence | Full | Full |
| `classic-search-only` | Full (Search only) | Full confidence (Search only) | Full (Search only) | Full (Search only) |
| `classic-campaign-scoped` | Full (per-campaign) | Full confidence (per-campaign) | Partial — may miss cross-campaign patterns | Full (per-campaign) |
| `pmax-fallback` | **None** — rows only | Downgrade: only obvious/low-risk | Rows usable for clustering | Rows usable for language signal |
| `limited` | **None** | **Blocked** — request UI export | **Blocked** — insufficient data | **Blocked** — insufficient data |

### Consumer-specific guidance

- **search-terms:** Report retrieval mode in output header. In `pmax-fallback`, present query rows but do not fabricate cost/CPA analysis.
- **negatives:** In `pmax-fallback`, only recommend negatives for extremely obvious junk terms. In `limited`, do not recommend negatives — ask for UI export.
- **intent-map:** In `pmax-fallback`, use rows for clustering but note that performance metrics are unavailable for intent-class profiling.
- **rsas:** In `pmax-fallback`, use rows for buyer-language extraction only. In `limited`, rely on existing asset performance data.
- **audit:** Report retrieval mode. Mark audit sections as "PMax visibility-limited" where classic metrics are unavailable.
- **pmax:** Use Steps 5/5b directly since PMax campaigns are the primary subject.

---

## Visibility Limits (honest)

Google's search-term visibility is intentionally constrained:

1. **Privacy thresholds:** Low-volume terms are suppressed from `search_term_view`. This affects 20-40% of spend in many accounts.
2. **PMax opacity:** Performance Max does not expose per-term cost/conversion data through any API surface. `campaign_search_term_view` returns query text only.
3. **campaign_search_term_insight** returns category labels, not individual queries. It is often sparse or empty for newer campaigns.
4. **Match type evolution:** Broad match changes which terms are visible over time. Historical retrieval may show different terms than current behavior.

The kit does not pretend these limits don't exist. It surfaces what Google exposes, labels the source, and tells the operator what cannot be concluded.

---

## Script Reference

`scripts/search-terms-retrieval.sh` implements this ladder as a standalone diagnostic tool.

Usage:
```bash
./scripts/search-terms-retrieval.sh <customer-id> [date-condition]
```

The script produces the diagnostic output shape above plus raw probe results for each step.
