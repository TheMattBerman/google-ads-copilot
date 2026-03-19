---
name: google-ads-negatives
description: >
  Recommend negative keywords for Google Ads with the right match type, scope, and caution.
  Pulls live data via MCP or works with manual exports. Always produces a negative keyword
  draft for human review.
---

# Google Ads Negatives

Read first:
- `google-ads/references/operator-thesis.md`
- `google-ads/references/query-patterns.md`
- `google-ads/references/negatives-playbook.md`
- `google-ads/references/intent-map.md`
- `google-ads/references/deliverable-templates.md`
- `data/negative-inventory.md`

Read workspace if available:
- `workspace/ads/account.md`
- `workspace/ads/goals.md`
- `workspace/ads/intent-map.md`
- `workspace/ads/queries.md`
- `workspace/ads/negatives.md`
- `workspace/ads/learnings.md`

---

## Data Acquisition

### Connected Mode (MCP available)

Pull via the `search` tool on `google-ads-mcp`:

**Primary: Search terms with waste signals — last 30 days:**
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

**Retrieval ladder** — if the primary query returns no rows, follow the shared retrieval ladder in `data/search-term-retrieval.md`. In `pmax-fallback` mode, only recommend negatives for extremely obvious junk terms — do not recommend exact negatives without per-term metrics. In `limited` mode, do not recommend negatives at all — ask for a UI export.

**Required: Existing campaign-level negatives:**
```sql
SELECT
  campaign.name,
  campaign_criterion.keyword.text,
  campaign_criterion.keyword.match_type,
  campaign_criterion.negative
FROM campaign_criterion
WHERE campaign_criterion.negative = TRUE
  AND campaign_criterion.type = 'KEYWORD'
```

**Required: Negative inventory verification (all locations):**
Use the shared verification path in `data/negative-inventory.md` / `scripts/negative-inventory.sh` to check:
- campaign-level negatives
- ad-group-level negatives
- shared negative lists
- campaign/shared-list attachments
- shared-list keyword members

**Required: Keyword view (understand what's triggering waste):**
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

**Why keyword_view matters for negatives:**
- A wasteful search term may be caused by a single over-broad keyword — pausing or narrowing that keyword is sometimes better than adding a negative
- Keyword match types reveal WHY certain search terms are matching — helps assess whether the negative or the keyword is the better fix
- Cross-referencing keywords with search terms reveals the "blast radius" of each keyword — how many waste terms it's generating

**Required: Existing shared negative keyword lists:**
```sql
SELECT
  shared_set.name,
  shared_set.type,
  shared_set.member_count,
  shared_set.status
FROM shared_set
WHERE shared_set.type = 'NEGATIVE_KEYWORDS'
  AND shared_set.status = 'ENABLED'
```

See `data/gaql-recipes.md` for additional queries.

### Date Range Fallback

If `LAST_30_DAYS` returns 0 rows or <$5 total spend, fall back to `LAST_90_DAYS`, then all-time (no date filter). Negative keyword analysis is LESS time-sensitive than budget analysis — historical waste patterns are still actionable even if the data is older. Always state the date range used.

### Export Mode (no MCP)

Ask the user for:
- Search Terms report: last 30 days (sorted by Cost descending)
- Current negative keyword list (campaign-level and shared lists)

See `data/export-formats.md` for recommended format.

---

## Process
1. **Announce mode** (connected/export).
2. Load existing negatives from MCP query or `workspace/ads/negatives.md`.
3. In connected mode, run the shared retrieval ladder (`data/search-term-retrieval.md`). Report `retrieval_mode` in the output header.
4. Run the shared negative-inventory verification (`data/negative-inventory.md` / `scripts/negative-inventory.sh`) so you know whether negatives already exist at campaign, ad-group, or shared-list level.
5. If retrieval mode is `pmax-fallback`, only recommend negatives for extremely obvious junk terms. If `limited`, do not recommend negatives — ask for a UI export.
6. Review query evidence and recurring waste clusters.
7. Cross-reference against existing negatives — **never recommend what's already excluded.**
7. **Cross-reference against keyword_view** when keyword rows are available — for each waste cluster, check which targeted keyword(s) triggered it. If a single broad-match keyword generates most of the waste, consider recommending keyword narrowing (change to phrase/exact, or pause) alongside or instead of negatives.
8. For each waste cluster, decide: **exclusion, isolation, or keyword fix?**
   - Exclusion: the traffic has no plausible path to value → negative it
   - Isolation: the traffic has potential but is in the wrong bucket → recommend structure change instead
   - Keyword fix: the triggering keyword is too broad → recommend match type change or pause
7. For each recommended negative:
   - Choose match type (exact → phrase → broad, in order of safety)
   - Choose scope (ad group → campaign → shared list, in order of precision)
   - Assess collateral risk (what good traffic could this block?)
   - Note spend evidence (how much was wasted on this pattern?)
7. Use the negative recommendation template from `deliverable-templates.md`.
8. Write/update workspace memory.

## Draft Output

### Negative Keyword Draft — ALWAYS PRODUCED
This skill's primary deliverable is a negative keyword draft. Every run that identifies exclusion-worthy terms produces one.

Create using `drafts/templates/negative-draft.md`:
- Write to `workspace/ads/drafts/YYYY-MM-DD-[account-slug]-negatives.md`
- Include every recommended negative with all fields: keyword, match type, scope, reason, spend wasted, collateral risk, reversibility
- Group negatives by theme (e.g., "Job-seeker exclusions," "Informational queries," "Competitor brand terms")
- Update `workspace/ads/drafts/_index.md`
- Announce: "Draft created: `workspace/ads/drafts/YYYY-MM-DD-[account-slug]-negatives.md` — N negatives for [scope description]"

### Negatives to REMOVE
The draft template now includes three sections: Add, Remove, and Narrow/Move.

**When to recommend removal:**
- An existing negative is blocking traffic that matches the business's actual services (e.g., "brick" negative on a brick recycling company)
- A broad-match negative is suppressing queries that more specific negatives would handle better
- Business services have changed since the negative was added (e.g., company now offers junk removal but had "junk" as a negative)
- A negative was auto-generated (common in Smart campaigns) and doesn't reflect operator intent

**When to recommend narrowing:**
- A phrase-match negative is correct in concept but too aggressive in scope (e.g., "free" as phrase match blocking "free estimate" queries)
- A campaign-level negative should be ad-group-level (or vice versa)
- A broad-match negative should be phrase or exact

**Always cross-reference existing negatives against:**
1. The business's actual services (from `workspace/ads/account.md`)
2. Converting search terms (from the search terms report)
3. The Intent Map (from `workspace/ads/intent-map.md`)

### If isolation is the better answer
When the analysis reveals that traffic doesn't need exclusion but rather better routing:
- Note this in the negative draft's Dependencies section
- Create a supplementary structure draft using `drafts/templates/structure-draft.md`
- Link the two drafts to each other

### Always update workspace memory:
- `workspace/ads/negatives.md` — updated negative list (proposed + existing)
- `workspace/ads/queries.md` — waste patterns identified
- `workspace/ads/findings.md` — strategic notes

## Output Shape
1. **Account Status block** — account name, CID, status, date range used, tracking confidence, mode
2. Existing negatives summary (what's already excluded, any harmful ones flagged)
3. Waste analysis (clusters, patterns, spend amounts)
4. Exclusion vs. isolation decisions (with reasoning)
5. Recommended negatives (summary table)
6. Draft created (path and summary)
7. Confidence assessment
8. Memory updates

## Rules
- Do not negative underperformance when the real issue is structure or copy.
- Do not recommend broad negatives casually.
- Always note collateral risk.
- Always say when confidence is low.
- **Exact match is safest. Phrase match is the default. Broad match negative is a last resort.**
- **Campaign-level negatives are fine for focused campaigns. Shared lists are better for account-wide exclusion themes.**
- **Every negative draft is a decision document, not a wish list. Each entry must be individually justified.**
