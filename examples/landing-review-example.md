# Example: Landing Page Review

> When conversions are low, is it the page or the tracking? The agent runs a differential diagnosis.

## Account Status
- **Account:** Acme Equipment Co. (CID: 555-123-4567)
- **Status:** Active
- **Date range used:** Last 30 days
- **Tracking confidence:** 🔴 LOW
- **Mode:** Connected

## Diagnostic Classification
**Primary issue:** Both — Tracking Problem + Path/UX Problem

---

## Fork A: Tracking Status

### Conversion Action: "Request quote (Page load thank-you)"
- **Status:** Enabled, primary, counting "One"
- **30-day volume:** 1 conversion across $729 spend (857 clicks)
- **Tag status:** ⚠️ Suspicious — tag exists but has fired only once in 30 days
- **GCLID passing:** Yes (auto-tagging enabled)

### Tracking Verdict: **Suspicious**

Either:
1. The tag is intermittently broken (most likely — 1 fire in 857 clicks is abnormally low)
2. The form is genuinely getting almost zero submissions (possible but needs verification)
3. The thank-you page URL has changed and the tag is on the old URL

**Recommendation:** Manually test the form submission path and check Tag Assistant before diagnosing conversion rate issues.

### Other Tracking Problems (from existing diagnosis)
- Store visits counting as primary conversions (59% of total)
- Directions goal inconsistency between campaigns
- See existing draft for tracking fixes

---

## Fork B: Path/UX Assessment

> ⚠️ **Caveat:** Conversion rate conclusions are unreliable because tracking is Suspicious.
> These UX observations are still valid but can't be tied to conversion impact until tracking is fixed.

### Page: acme-equipment.example.com

**Campaigns pointing here:** Website traffic-Search, Performance Max
**Clicks (30d):** 857
**Conversions (30d):** 1 (but tracking is suspicious)

#### Scores
| Dimension | Score | Detail |
|-----------|-------|--------|
| Message match | **Weak** | Users searching "roll-off containers for sale" land on a general company homepage. No product-specific landing pages. |
| CTA clarity | **Buried** | "Request a Quote" link exists but is in the navigation bar, not prominently placed above the fold with a visible form or button. |
| Form friction | **Medium** | Quote form has 7 fields, but is on a separate page (not inline). Extra click = extra friction. |
| Mobile experience | **Adequate** | Responsive but quote CTA is hard to find on mobile. Phone number is present but not click-to-call formatted. |
| Page speed | **Slow** | ~4.2 seconds on mobile. Heavy images not optimized. |
| Trust signals | **Some** | Years in business mentioned, but no customer reviews, no certifications visible, stock-photo feel. |
| Intent specificity | **Generic** | Homepage serves as landing for all intent classes — buyers, researchers, brand searches. |
| Path completeness | **Suspicious** | Can't verify — form → thank-you page path needs manual testing. |

---

## Differential Diagnosis

**This is Scenario 3: Both Problems.**

1. **Tracking is suspicious** — the request quote tag may not be firing correctly. Must investigate first.
2. **Landing page has real UX issues** — even if tracking is fixed, the page will underperform because:
   - Generic homepage serving as landing for specific buyer-intent queries
   - CTA is buried in navigation instead of prominent above-the-fold
   - No product-specific landing pages for different intent classes
   - Page speed is slow

**Fix order:**
1. P0: Verify request quote tag fires correctly (tracking investigation)
2. P0: Apply tracking fixes from existing draft (remove store visit pollution)
3. P1: Add prominent CTA / inline form above the fold
4. P1: Create product-specific landing pages for key intent classes
5. P2: Page speed optimization
6. P2: Add real customer reviews and trust signals

---

## Proposed Changes

### Change 1: Investigate and Fix Request Quote Tag
- **Current state:** 1 fire in 30 days across 857 clicks — almost certainly broken
- **Proposed state:** Verify tag fires on form submission, fix if broken
- **Expected impact:** Unknown until verified — could reveal 10-50x more conversions
- **Risk:** None (investigation only)
- **Priority:** P0

### Change 2: Add Prominent CTA Above the Fold
- **Current state:** "Request a Quote" is a navigation link, not a visible CTA
- **Proposed state:** Large CTA button above the fold on every landing page, or inline form
- **Expected impact:** Significant — users need to see the action within 3 seconds
- **Risk:** Low
- **Priority:** P1

### Change 3: Create Intent-Specific Landing Pages
- **Current state:** All traffic lands on homepage regardless of search intent
- **Proposed state:** Dedicated pages for each major product/service line
- **Expected impact:** Better message match → higher quality score → lower CPCs + higher conversion rate
- **Risk:** Requires landing page creation effort
- **Priority:** P1

---

## Key Insight

> The client thinks "our landing page isn't converting." The real story is that we don't know
> if it's converting because tracking is broken, AND the page has genuine issues that will
> suppress conversion rate even when tracking is fixed. Two separate problems, two separate
> fix tracks, and tracking comes first.
