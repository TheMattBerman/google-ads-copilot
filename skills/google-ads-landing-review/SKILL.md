---
name: google-ads-landing-review
description: >
  Diagnose landing page → conversion path problems for Google Ads traffic.
  Separates tracking failures from UX/path failures — the two most commonly
  confused sources of "low conversion rate." Pulls ad and campaign data via MCP,
  then reviews landing pages via browser or URL fetch to assess message match,
  load issues, form friction, and conversion path completeness. Produces a
  landing-review draft when problems are found.
argument-hint: "[campaign name or URL]"
---

# Google Ads Landing Review

## Why this skill exists

"The landing page isn't converting" is the most common complaint in Google Ads.
But it hides two completely different root causes:

1. **Tracking problem** — conversions ARE happening but aren't being counted.
2. **Path problem** — the visitor arrives but the page fails them.

Most operators (and most clients) assume path failure when the numbers look bad.
Half the time, it's a tracking failure. Conflating the two wastes months.

This skill separates them.

Read first:
- `google-ads/references/operator-thesis.md`
- `google-ads/references/tracking-playbook.md`
- `google-ads/references/structure-playbook.md`

Read workspace if available:
- `workspace/ads/account.md`
- `workspace/ads/goals.md`
- `workspace/ads/findings.md`
- `workspace/ads/drafts/_index.md` — check for existing tracking drafts

---

## Diagnostic Model: Two Forks

```
"Landing page isn't converting"
         │
    ┌────┴────┐
    │         │
  FORK A    FORK B
  Tracking  Path/UX
    │         │
  Is the     Is the page
  signal     actually
  correct?   failing?
```

**Always run Fork A first.** If tracking is broken, Fork B conclusions are unreliable.

---

## Fork A: Tracking Diagnosis (Is the signal trustworthy?)

### What to check

**1. Does a conversion action exist for the goal on this page?**
- Is there a conversion action configured for the form/call/purchase that this landing page is supposed to produce?
- Is it set as primary (`include_in_conversions_metric = TRUE`)?
- Is the counting type correct?

**2. Does the tag actually fire?**
- Is the Google Ads conversion tag (or GA4 event imported to Google Ads) present on the confirmation/thank-you page?
- Does the tag fire when the user completes the action? (Google Tag Assistant, network tab, or manual test)
- Is the tag firing on the WRONG page? (e.g., firing on page load of the form page instead of the thank-you page)

**3. Is the conversion path end-to-end intact?**
- Click on ad → landing page → form/CTA → thank-you page → tag fires → conversion recorded
- Where does the chain break?

**4. Cross-domain / redirect issues?**
- Does the landing page redirect to a different domain for the form/checkout?
- If so, is cross-domain tracking configured?
- Are UTM parameters / GCLID surviving the redirect?

**5. Auto-tagging?**
- Is auto-tagging enabled?
- Are there URL parameters being stripped by the landing page CMS or CDN?

**6. Attribution window?**
- Conversion window too short (e.g., 1 day for a B2B lead that takes a week to decide)?
- Multiple touchpoints lost?

### Fork A Data Acquisition (Connected Mode)

**Conversion actions for this campaign:**
```sql
SELECT
  conversion_action.name,
  conversion_action.type,
  conversion_action.category,
  conversion_action.counting_type,
  conversion_action.include_in_conversions_metric,
  conversion_action.status,
  metrics.conversions,
  metrics.all_conversions
FROM conversion_action
WHERE segments.date DURING LAST_30_DAYS
  AND conversion_action.status = 'ENABLED'
ORDER BY metrics.conversions DESC
```

**Campaign-level conversion data:**
```sql
SELECT
  campaign.name,
  campaign.final_url_suffix,
  metrics.clicks,
  metrics.conversions,
  metrics.all_conversions,
  metrics.cost_micros,
  metrics.cost_per_conversion
FROM campaign
WHERE campaign.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
ORDER BY metrics.clicks DESC
```

**Ad-level landing page URLs and performance:**
```sql
SELECT
  campaign.name,
  ad_group.name,
  ad_group_ad.ad.final_urls,
  ad_group_ad.ad.type,
  metrics.clicks,
  metrics.impressions,
  metrics.conversions,
  metrics.cost_micros
FROM ad_group_ad
WHERE campaign.status = 'ENABLED'
  AND ad_group_ad.status = 'ENABLED'
  AND segments.date DURING LAST_30_DAYS
ORDER BY metrics.clicks DESC
LIMIT 50
```

**Landing page experience (quality score indicators):**
```sql
SELECT
  campaign.name,
  ad_group.name,
  ad_group_criterion.keyword.text,
  ad_group_criterion.quality_info.quality_score,
  ad_group_criterion.quality_info.post_click_quality_score,
  ad_group_criterion.quality_info.creative_quality_score,
  ad_group_criterion.quality_info.search_predicted_ctr
FROM keyword_view
WHERE campaign.status = 'ENABLED'
  AND ad_group.status = 'ENABLED'
  AND ad_group_criterion.status = 'ENABLED'
ORDER BY ad_group_criterion.quality_info.post_click_quality_score ASC
LIMIT 50
```

### Fork A Verdict

| Tracking Status | Meaning | Next Step |
|----------------|---------|-----------|
| **Clean** | Tag fires correctly, conversion action configured right, GCLID passes | Proceed to Fork B |
| **Suspicious** | Tag exists but volume seems too low or too high vs. reality | Investigate specific break, then Fork B |
| **Broken** | No tag, wrong tag, or GCLID stripped | Fix tracking FIRST. Fork B is premature. |
| **Unknown** | Can't verify from API alone — needs manual tag inspection | Recommend Tag Assistant audit, then Fork B |

---

## Fork B: Path/UX Diagnosis (Is the page actually failing?)

Only meaningful if Fork A shows tracking is Clean or Suspicious.

### The Message Match Test

**1. Search intent → Ad promise → Landing page delivery**

The #1 conversion killer in Google Ads is message mismatch:
- User searches "roll-off dumpster rental near me" (specific, purchase-intent)
- Ad says "Container Solutions for Your Business" (vague)
- Landing page is a generic homepage with 12 menu items

Each handoff is a potential drop:

| Handoff | Question | Failure Mode |
|---------|----------|-------------|
| Search → Ad | Does the ad answer the specific search? | Generic ad for specific intent |
| Ad → Landing | Does the LP deliver what the ad promised? | "Request a Quote" ad → page with no form |
| Landing → CTA | Is the CTA visible, clear, and low-friction? | Form buried below fold, 15 fields |
| CTA → Completion | Can the user actually complete the action? | Broken form, redirect fails, captcha blocks |

**2. Specific checks (via browser or URL fetch):**

- **Above-the-fold message:** Does the H1/hero text match the ad's promise? Does it match the search intent?
- **CTA visibility:** Can the user see what to do within 3 seconds? Is the CTA above the fold?
- **Form friction:** How many fields? Required fields? Captcha? Multi-step?
- **Mobile experience:** Does it work on mobile? (Most Google Ads clicks are mobile)
- **Page speed:** Does it load in <3 seconds? (Slow = bounced)
- **Trust signals:** Phone number, reviews, certifications, real photos?
- **Specificity:** Does the page serve ONE intent, or is it a homepage trying to serve all intents?

### The Intent Routing Test

**3. Are different intent classes landing on different pages?**

| Intent Class | Should Land On | Common Failure |
|-------------|----------------|---------------|
| Buyer ("buy X now") | Product/service page with CTA | Homepage |
| Comparison ("X vs Y") | Comparison content | Product page with no comparison |
| Research ("how does X work") | Educational content | Sales page |
| Local ("X near me") | Location/service area page | National homepage |
| Brand ("company name") | Homepage or brand page | Generic product page |

If multiple intent classes all route to the same generic page, that's a structure problem (→ recommend in structure draft), not a landing page problem.

### The Conversion Path Walk

**4. Walk the actual path the user takes:**

```
Click on ad
  → Landing page loads (check: speed, mobile rendering)
    → User reads headline (check: message match)
      → User finds CTA (check: visibility, clarity)
        → User clicks CTA (check: does it work?)
          → Form/checkout loads (check: friction, fields)
            → User submits (check: confirmation page loads)
              → Tag fires (check: conversion recorded)
```

Each step is a potential break. Document where the break is.

### Fork B Scoring

Rate each dimension:

| Dimension | Score | Notes |
|-----------|-------|-------|
| Message match (search→ad→page) | Strong / Weak / Missing | |
| CTA clarity | Clear / Buried / Missing | |
| Form friction | Low (≤4 fields) / Medium (5-8) / High (9+) | |
| Mobile experience | Good / Adequate / Broken | |
| Page speed | Fast (<3s) / Slow (3-6s) / Broken (>6s) | |
| Trust signals | Strong / Some / None | |
| Intent specificity | Focused / Mixed / Generic | |
| Conversion path completeness | Complete / Partially broken / Broken | |

---

## Data Acquisition — Landing Page Review

### Connected Mode (MCP + Browser/Fetch)

1. Pull ad final URLs and campaign data via GAQL (see queries above)
2. For each unique landing URL:
   - Fetch with `web_fetch` for content analysis (H1, CTA text, form fields, page structure)
   - Use `browser` for interactive checks if needed (JavaScript-rendered pages, form testing)
   - Check mobile rendering if concerns arise
3. Cross-reference landing pages against search term intent classes from `workspace/ads/intent-map.md`

### Export Mode

Ask the user for:
- Landing page URL(s)
- Which campaigns/ad groups point to which pages
- Conversion action name and how it fires (page load, event, etc.)
- Any known issues (form complaints, mobile problems)
- Recent conversion volume (or "we don't know" — that's data too)

---

## Differential Diagnosis Summary

After running both forks, produce a clear classification:

### Scenario 1: Tracking Problem Masquerading as UX Problem
**Symptoms:** Low/zero conversions, but page looks fine, form works, users seem to engage
**Diagnosis:** Tag not firing, wrong conversion action, GCLID stripped, cross-domain break
**Action:** Fix tracking → then reassess conversion rate with clean data
**Draft type:** Tracking fix (use `drafts/templates/tracking-draft.md`)

### Scenario 2: UX/Path Problem (Tracking Is Fine)
**Symptoms:** Tracking verified clean, but conversion rate is genuinely low
**Diagnosis:** Message mismatch, buried CTA, excessive form friction, wrong page for intent
**Action:** Landing page improvements or intent routing changes
**Draft type:** Landing review draft (use template below) and/or structure draft

### Scenario 3: Both Problems
**Symptoms:** Tracking has issues AND the page has UX problems
**Diagnosis:** Two independent failures compounding
**Action:** Fix tracking first (P0), then address UX (P1) — in that order
**Draft types:** Tracking fix draft + Landing review draft

### Scenario 4: Traffic Quality Problem (Page and Tracking Are Fine)
**Symptoms:** Tracking clean, page is good, but conversion rate still low
**Diagnosis:** The traffic is wrong — keywords matching wrong intent, broad match pulling junk, PMax sending Display/YouTube traffic to a Search landing page
**Action:** Search terms analysis, negative keywords, or structure changes
**Draft type:** Negative draft and/or structure draft (this is NOT a landing page problem)

---

## Draft Output

### Landing Review Draft
**Trigger:** Fork B finds meaningful path/UX issues (at least 2 dimensions scored Weak/Missing/Broken)

Create using the template below:
- Write to `workspace/ads/drafts/YYYY-MM-DD-[account-slug]-landing-review.md`
- Update `workspace/ads/drafts/_index.md`

If Fork A also finds issues, create a SEPARATE tracking fix draft — don't mix them.

### Landing Review Draft Template

```markdown
# Draft: Landing Page Review — [DATE]
Status: proposed
Skill: /google-ads landing-review
Account: [Customer ID / Name]

## Summary
[One paragraph: which pages were reviewed, the primary diagnosis (tracking vs path vs both),
and the highest-priority fix.]

## Diagnostic Classification
**Primary issue:** Tracking Problem | Path/UX Problem | Both | Traffic Quality Problem

## Fork A: Tracking Status
- **Conversion action:** [Name and status]
- **Tag status:** [Fires correctly / Suspicious / Broken / Unknown]
- **GCLID passing:** [Yes / No / Unknown]
- **Auto-tagging:** [Enabled / Disabled]
- **Verdict:** [Clean / Suspicious / Broken / Unknown]

## Fork B: Path/UX Assessment

### Page: [URL]
- **Campaigns pointing here:** [list]
- **Clicks (30d):** [N]
- **Conversions (30d):** [N]
- **Implied conversion rate:** [X%]

#### Scores
| Dimension | Score | Detail |
|-----------|-------|--------|
| Message match | [Strong/Weak/Missing] | [specific observation] |
| CTA clarity | [Clear/Buried/Missing] | [specific observation] |
| Form friction | [Low/Medium/High] | [field count, issues] |
| Mobile experience | [Good/Adequate/Broken] | [specific observation] |
| Page speed | [Fast/Slow/Broken] | [load time if available] |
| Trust signals | [Strong/Some/None] | [specific observation] |
| Intent specificity | [Focused/Mixed/Generic] | [specific observation] |
| Path completeness | [Complete/Partial/Broken] | [where it breaks] |

### Proposed Changes

#### Change 1: [Specific recommendation]
- **Current state:** [what's wrong]
- **Proposed state:** [what to do]
- **Expected impact:** [on conversion rate, quality score]
- **Risk:** [what could go wrong]
- **Priority:** P0 / P1 / P2

[repeat for each change]

## Intent Routing Assessment
- **Are different intent classes landing on the right pages?** [Yes / No — detail]
- **Should new landing pages be created?** [If so, for which intent classes]
- **Cross-reference with intent map:** [link to workspace/ads/intent-map.md findings]

## Dependencies
- [e.g., "Fix tracking (2026-03-15-acme-tracking-fix.md) before assessing conversion rate improvement"]

## Confidence
[High / Medium / Low] — [reasoning]

## Review
- [ ] Evidence checked
- [ ] Collateral risk checked
- [ ] Dependencies checked
- **Decision:** approve | defer | reject
- **Decision reason:** ____
- **Reviewed by:** ____
- **Reviewed on:** ____
- **Applied on:** ____
- **Notes:** ____
```

### Always update workspace memory:
- `workspace/ads/findings.md` — landing page diagnosis and classification
- `workspace/ads/learnings.md` — what we learned about this account's conversion path
- Update existing tracking drafts if Fork A reveals new tracking problems

---

## Output Shape

1. **Account Status block** — name, CID, mode, date range, tracking confidence
2. **Diagnostic classification** — tracking problem vs path problem vs both vs traffic quality
3. **Fork A summary** — tracking status for each page/campaign reviewed
4. **Fork B summary** — path/UX scores for each landing page reviewed
5. **Differential diagnosis** — which scenario applies (1, 2, 3, or 4)
6. **Prioritized recommendations** — fix order matters (always tracking before UX)
7. **Drafts created** — with file paths and summaries
8. **Memory updates**

---

## Rules

- **Always run Fork A first.** If tracking is broken, do NOT produce detailed UX recommendations — they will be based on phantom conversion data.
- **Distinguish clearly:** A page with a broken tag and 0% conversion rate is a tracking problem, not a UX problem. Say it explicitly.
- **Don't blame the landing page for traffic quality problems.** If the keywords are sending the wrong people, the page can be perfect and still not convert. Route to negatives/structure skills.
- **Walk the actual path.** Don't just look at the page — follow the entire click → conversion chain.
- **Be specific.** "The form has too many fields" is vague. "The form has 12 required fields including 'company size' and 'annual revenue' which are unnecessary for an initial quote request" is useful.
- **Mobile first.** Most Google Ads clicks are mobile. If you can only check one thing, check mobile.
- **One page at a time.** Don't try to review 10 pages at once. Start with the highest-spend page.
- **Message match is almost always the problem.** When in doubt, check whether the H1 matches the search intent. If there's a mismatch, that's usually the answer.
