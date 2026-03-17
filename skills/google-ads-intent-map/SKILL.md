---
name: google-ads-intent-map
description: >
  Build or update a Google Ads Intent Map from search terms, campaign data, and account context.
  Pulls live data via MCP or works with manual exports. Produces structure drafts when
  intent classes need separation.
---

# Google Ads Intent Map

Read first:
- `google-ads/references/operator-thesis.md`
- `google-ads/references/intent-map.md`
- `google-ads/references/query-patterns.md`
- `google-ads/references/deliverable-templates.md`

Read workspace if available:
- `workspace/ads/account.md`
- `workspace/ads/goals.md`
- `workspace/ads/intent-map.md`
- `workspace/ads/queries.md`
- `workspace/ads/winners.md`
- `workspace/ads/learnings.md`

---

## Data Acquisition

### Connected Mode (MCP available)

Pull via the `search` tool on `google-ads-mcp`:

**Primary: All search terms for clustering — last 30 days:**
```sql
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

**Supplementary: Campaign and ad group structure (for routing analysis):**
```sql
SELECT
  campaign.name,
  campaign.advertising_channel_type,
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
ORDER BY campaign.name, ad_group.name
```

See `data/gaql-recipes.md` for additional queries.

### Date Range Fallback

If `LAST_30_DAYS` returns too few terms for meaningful clustering (<20 terms), fall back to `LAST_90_DAYS`, then all-time. Intent mapping benefits from volume — more search terms means better clustering. Always state the date range used.

### Export Mode (no MCP)

Ask the user for:
- Search Terms report: last 30 days, all terms (not just top spenders)
- Include: Search term, Campaign, Ad group, Impressions, Clicks, Cost, Conversions, Conv. value
- Campaign names are essential for routing analysis

See `data/export-formats.md` for recommended format.

---

## Process
1. **Announce mode** (connected/export).
2. Determine what data is available.
3. Load existing Intent Map from `workspace/ads/intent-map.md` if it exists.
4. Identify recurring query clusters and modifiers across all terms.
5. Classify clusters into intent classes:
   - **Buyer** — high commercial intent, ready to convert
   - **Comparison** — evaluating options, not yet committed
   - **Informational** — learning, researching, no purchase signal
   - **Navigational** — looking for a specific brand/page
   - **Branded** — searching for your brand specifically
   - **Junk** — no plausible path to conversion
6. For each class: note representative queries, performance profile, and current routing (which campaign/ad group they land in).
7. Separate high-confidence signals from ambiguous ones.
8. Infer structural implications — which classes are incorrectly sharing optimization buckets?
9. Build or update `workspace/ads/intent-map.md`.
10. Use the operator summary template when presenting results.

## Always Answer
- What query patterns signal a likely buyer?
- What patterns signal weak or misleading intent?
- What traffic types should never be optimized together?
- What language repeats among likely winners?
- What should be cut, isolated, or tested next?
- **Where is intent mixing causing structural problems?**

## Draft Output

### Structure Draft
**Trigger:** Two or more distinct intent classes are sharing a single campaign or ad group, AND the performance gap between them is significant (e.g., 2x+ CPA difference, or one class converts and the other doesn't).

Create a draft using `drafts/templates/structure-draft.md`:
- Write to `workspace/ads/drafts/YYYY-MM-DD-[account-slug]-structure.md`
- Specify exactly which intent classes to separate, which campaigns/ad groups to split
- Include keyword lists or patterns that should route to each new bucket
- Update `workspace/ads/drafts/_index.md`

### Negative Draft (secondary)
**Trigger:** Intent Map reveals a clear junk class that should be excluded account-wide.

Create using `drafts/templates/negative-draft.md` if the junk class is better solved by exclusion than by structure.

### Always update workspace memory:
- `workspace/ads/intent-map.md` — the primary deliverable. Rebuild or update the map.
- `workspace/ads/queries.md` — notable clusters
- `workspace/ads/findings.md` — strategic observations about intent routing

## Output Shape
1. **Account Status block** — account name, CID, status, date range used, tracking confidence, mode
2. Data summary (terms analyzed, date range)
3. Intent Map (classes with representative queries, performance, current routing)
4. Routing problems (intent classes sharing wrong buckets)
5. Structural implications (what should be separated)
6. Emerging patterns (new intent classes forming)
7. Confidence assessment per class
8. Drafts created (with paths and summaries)
9. Memory updates

## Rules
- Do not confuse underperformance with irrelevance.
- Do not recommend negatives where isolation is the better move.
- Prefer pattern interpretation over checklist regurgitation.
- **The Intent Map is the most strategic artifact in the workspace. Treat updates seriously — it compounds across every other skill.**
- **When in doubt between "exclude" and "isolate," prefer isolation. You can always exclude later. You can't un-exclude query data you never saw.**
