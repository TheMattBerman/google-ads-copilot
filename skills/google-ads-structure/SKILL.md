---
name: google-ads-structure
description: >
  Recommend Google Ads campaign and ad group structure based on intent separation,
  routing problems, brand/non-brand boundaries, competitor isolation, and landing-page fit.
  Pulls live data via MCP or works with manual exports. Produces structure drafts.
---

# Google Ads Structure

Read first:
- `google-ads/references/operator-thesis.md`
- `google-ads/references/intent-map.md`
- `google-ads/references/query-patterns.md`
- `google-ads/references/structure-playbook.md`
- `google-ads/references/deliverable-templates.md`

Read workspace if available:
- `workspace/ads/account.md`
- `workspace/ads/goals.md`
- `workspace/ads/intent-map.md`
- `workspace/ads/queries.md`
- `workspace/ads/winners.md`
- `workspace/ads/change-log.md`
- `workspace/ads/learnings.md`

---

## Data Acquisition

### Connected Mode (MCP available)

Pull via the `search` tool on `google-ads-mcp`:

**Primary: Ad group structure with performance:**
```sql
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

**Primary: Keywords per ad group (intent mixing check):**
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
ORDER BY campaign.name, ad_group.name
```

**Supplementary: Search terms (to verify routing):**
```sql
SELECT
  search_term_view.search_term,
  campaign.name,
  ad_group.name,
  metrics.cost_micros,
  metrics.conversions
FROM search_term_view
WHERE segments.date DURING LAST_30_DAYS
ORDER BY metrics.cost_micros DESC
LIMIT 300
```

See `data/gaql-recipes.md` for additional queries.

### Export Mode (no MCP)

Ask the user for:
- Campaign list with types, budgets, bid strategies
- Ad group list with campaign parent
- Keywords per ad group (at least the main ones)
- Search terms report helps but is not strictly required

---

## Process
1. **Announce mode** (connected/export).
2. Identify where unlike intent is currently mixed.
3. Determine whether the problem is better solved by split, merge, or routing.
4. Evaluate whether current campaign and ad group boundaries reflect real commercial meaning.
5. Recommend actions: keep / clean up / split / merge / route / rebuild.
6. Update workspace memory.

## Core Questions
- What traffic types are wrongly sharing one optimization bucket?
- Where is generic structure hiding high-intent signal?
- Where are negatives doing patchwork for a deeper structure problem?
- What structure would make bidding, copy, LPs, and reporting cleaner?

## Draft Output

### Structure Draft
**Trigger:** Analysis identifies intent mixing with measurable performance impact.

Create using `drafts/templates/structure-draft.md`:
- Write to `workspace/ads/drafts/YYYY-MM-DD-[account-slug]-structure.md`
- Specify: current state, proposed state, keywords to move, budget impact, risk, reversibility
- Note dependencies on other drafts (e.g., "Add negatives first to prevent traffic bleed during restructure")
- Update `workspace/ads/drafts/_index.md`

### Always update workspace memory:
- `workspace/ads/findings.md` — structural observations
- `workspace/ads/change-log.md` — if recommending changes
- `workspace/ads/intent-map.md` — if routing analysis reveals new intent classes

## Rules
- Do not split just because the account feels messy.
- Do not over-segment thin volume.
- Recommend routing when negatives can solve the problem more cleanly than new structure.
- Distinguish between cleanup and full rebuild.
