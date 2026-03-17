# Live Test Checklist — Google Ads Copilot

Use this checklist before running a live connected-mode analysis on a new account.

## Pre-Flight

### 1. MCP Connectivity
- [ ] Run `./scripts/test-mcp.sh` — all green
- [ ] Run `./scripts/list-customers.sh` — target account visible
- [ ] Verify the correct customer ID matches the business name you expect

### 2. Account Selection
- [ ] Run `/google-ads connect setup`
- [ ] Confirm account name matches the business (avoid wrong-account audits)
- [ ] Check account status: ENABLED, SUSPENDED, CLOSED?
- [ ] Note if account is dormant (no recent activity)
- [ ] `workspace/ads/account.md` updated with fingerprint

### 3. Data Availability Check
- [ ] Test a campaign query with `DURING LAST_30_DAYS`
- [ ] If empty, test with `DURING LAST_90_DAYS`
- [ ] Note which date range produces data
- [ ] Check if any campaigns are ENABLED (vs all paused)

### 4. Workspace Prep
- [ ] `workspace/ads/account.md` — populated
- [ ] `workspace/ads/goals.md` — fill in if known (business model, KPIs)
- [ ] `workspace/ads/drafts/_index.md` — clean or carry forward prior drafts
- [ ] Clear or archive old findings if switching accounts

---

## During Analysis

### Per-Skill Checks
- [ ] Mode announced (Connected / Export)
- [ ] Account Status block present at top of output
- [ ] Date range stated
- [ ] Tracking confidence assessed before budget/bid recommendations

### Data Quality
- [ ] Search terms pulled and reviewed (check row count)
- [ ] keyword_view cross-referenced with search terms
- [ ] Existing negatives loaded (check for harmful ones)
- [ ] Conversion actions inventoried

### Draft Quality
- [ ] Every actionable finding has a corresponding draft
- [ ] Drafts use account-slug naming
- [ ] Multi-draft audits create `_batch-YYYY-MM-DD-[account-slug].md`
- [ ] Negative drafts include Add/Remove/Narrow sections as appropriate
- [ ] Dependencies between drafts noted
- [ ] `workspace/ads/drafts/_index.md` updated
- [ ] Review checklist fields are present and readable

---

## Post-Analysis

- [ ] Workspace memory files updated: findings.md, intent-map.md, queries.md, negatives.md
- [ ] Account.md updated with tracking confidence and campaign summary
- [ ] All drafts listed in _index.md with correct statuses
- [ ] `_summary.md` reflects the current backlog rather than the audit packet
- [ ] Learnings captured in learnings.md

---

## Known Gotchas (from live testing)

1. **Wrong account:** Always verify descriptive name matches the business you want. We audited a different account on the first attempt when CIDs were similar.

2. **`GOOGLE_CLOUD_PROJECT` not `GOOGLE_PROJECT_ID`:** The MCP server uses `GOOGLE_CLOUD_PROJECT`. Older docs may reference the wrong env var.

3. **Suspended accounts:** Some accounts are suspended but still return data for historical queries. Note suspension prominently — it's always P0.

4. **Smart campaign limitations:** Smart campaigns don't support all GAQL queries (limited date segmentation, no keyword control). Expect incomplete data from Smart campaigns.

5. **mcporter output truncation:** Default mcporter output shows only the first result. Use `--output raw` to see all results.

6. **Empty date ranges on dormant accounts:** If LAST_30_DAYS returns nothing, don't give up. Use the fallback chain. Historical data is still valuable for intent mapping and negative recommendations.

7. **Display Network on Search campaigns:** Check `target_content_network` on Search campaigns. If enabled, `all_conversions` will be inflated by view-throughs. The gap between `conversions` and `all_conversions` is the tell.
