---
name: google-ads-rsas
description: >
  Generate or refine Google Ads RSA recommendations using real buyer language from search terms,
  intent clusters, and winning modifiers. Pulls live data via MCP or works with manual exports.
  Produces RSA refresh drafts.
---

# Google Ads RSAs

Read first:
- `google-ads/references/operator-thesis.md`
- `google-ads/references/query-patterns.md`
- `google-ads/references/intent-map.md`
- `google-ads/references/rsa-playbook.md`
- `google-ads/references/deliverable-templates.md`

Read workspace if available:
- `workspace/ads/account.md`
- `workspace/ads/goals.md`
- `workspace/ads/intent-map.md`
- `workspace/ads/queries.md`
- `workspace/ads/winners.md`
- `workspace/ads/assets.md`
- `workspace/ads/learnings.md`

---

## Data Acquisition

### Connected Mode (MCP available)

Pull via the `search` tool on `google-ads-mcp`:

**Primary: RSA asset performance:**
```sql
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

**Supplementary: Search terms (for buyer language extraction):**
```sql
SELECT
  search_term_view.search_term,
  campaign.name,
  metrics.conversions,
  metrics.clicks,
  metrics.cost_micros
FROM search_term_view
WHERE segments.date DURING LAST_30_DAYS
  AND metrics.conversions > 0
ORDER BY metrics.conversions DESC
LIMIT 200
```

**Supplementary: RSA ad-level data:**
```sql
SELECT
  campaign.name,
  ad_group.name,
  ad_group_ad.ad.responsive_search_ad.headlines,
  ad_group_ad.ad.responsive_search_ad.descriptions,
  ad_group_ad.ad.final_urls,
  metrics.impressions,
  metrics.clicks,
  metrics.conversions
FROM ad_group_ad
WHERE ad_group_ad.ad.type = 'RESPONSIVE_SEARCH_AD'
  AND campaign.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
```

See `data/gaql-recipes.md` for additional queries.

### Export Mode (no MCP)

Ask the user for:
- RSA asset report (headlines, descriptions, performance labels)
- Or RSA preview from the ads tab
- Search terms report (for buyer language extraction)

---

## Process
1. **Announce mode** (connected/export).
2. Identify the target query cluster or intent bucket.
3. Extract buyer language and repeated modifiers from converting search terms.
4. Review current RSA assets: what's BEST, GOOD, LOW, UNRATED?
5. Determine the core promise and LP fit.
6. Recommend RSA components: headline themes, description angles, message hierarchy.
7. Save outputs to workspace memory.

## Draft Output

### RSA Refresh Draft
**Trigger:** Analysis shows (a) LOW-performing assets that could be replaced, or (b) buyer language patterns not represented in current ads.

Create using `drafts/templates/rsa-draft.md`:
- Write to `workspace/ads/drafts/YYYY-MM-DD-rsa-refresh.md`
- Include specific headlines (≤30 chars) and descriptions (≤90 chars)
- Note pin recommendations (use sparingly)
- Note which assets to consider removing and why
- Source each new asset to the buyer language it came from
- Update `workspace/ads/drafts/_index.md`

### Always update workspace memory:
- `workspace/ads/assets.md` — current asset inventory and new recommendations
- `workspace/ads/winners.md` — high-performing query language
- `workspace/ads/queries.md` — buyer language patterns

## Rules
- Do not write generic ads for mixed intent.
- Use real query language where possible.
- Keep LP alignment explicit.
- If the intent bucket is weak or noisy, say so before generating ads.
