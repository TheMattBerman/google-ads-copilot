# landing-page-playbook.md

## Core principle
The landing page is not where optimization starts.
Tracking trust is where optimization starts.
The landing page is where it either converts or doesn't — but only if you can measure it.

## The Two-Fork Rule
Never diagnose a "low converting landing page" without first verifying:
1. Is the conversion action configured correctly?
2. Is the tag actually firing?

If tracking is broken, conversion rate is meaningless.
If tracking is fine, the page is fair game for diagnosis.

---

## Tracking vs Path — The Differential Diagnosis

### How to tell the difference

| Signal | Tracking Problem | Path/UX Problem | Traffic Quality Problem |
|--------|-----------------|-----------------|----------------------|
| Conversion rate | 0% or near-zero | Low but non-zero (0.5-2%) | Low despite good page |
| Bounce rate | Normal (40-60%) | High (70%+) | Very high (80%+) |
| Form submissions visible in CRM | Yes (just not in Google Ads) | No (users aren't submitting) | No (wrong people visiting) |
| Tag Assistant | Tag missing or not firing | Tag fires correctly | Tag fires correctly |
| Phone calls happening | Yes (just not tracked) | No | No |
| Time on page | Normal | Normal or high | Very low (<10s) |

### The Killer Question
Ask the client: **"How many real leads/sales did you get from your website last month?"**

- If they say "20" but Google Ads shows 2 → tracking problem
- If they say "2" and Google Ads shows 2 → path problem (or traffic quality problem)
- If they say "0" and Google Ads shows 0 → could be either or both

---

## Message Match Framework

### The Three Handoffs

```
Search Query → Ad Copy → Landing Page
```

Each handoff must preserve specificity.

**Good:**
- Search: "roll-off dumpster rental 30 yard"
- Ad: "30-Yard Roll-Off Dumpsters — Same Day Delivery"
- Page: H1 says "30-Yard Roll-Off Dumpster Rental" with pricing and order form

**Bad (common):**
- Search: "roll-off dumpster rental 30 yard"
- Ad: "Container Solutions for Business"
- Page: Homepage with 8 menu items, no mention of dumpsters

**Message match score:**
- **Strong:** Page H1 contains the core intent from the search query. CTA directly follows.
- **Weak:** Page is related but generic. User has to figure out where to go.
- **Missing:** Page has nothing to do with the search intent. Complete disconnect.

---

## Landing Page CRO Scorecard

### Priority 1: Above the Fold (First 3 Seconds)
- [ ] H1 matches the search intent
- [ ] Value proposition is clear in one sentence
- [ ] Primary CTA is visible without scrolling
- [ ] No confusing navigation competing with the CTA
- [ ] Trust indicator visible (phone number, rating, badge)

### Priority 2: Form/CTA Quality
- [ ] Form has ≤5 fields for lead gen (name, email, phone, zip, message is the max)
- [ ] CTA button text is specific ("Get My Free Quote" not "Submit")
- [ ] Form is above the fold on mobile
- [ ] No captcha (or invisible captcha only)
- [ ] Confirmation page loads after submission
- [ ] Phone number is click-to-call on mobile

### Priority 3: Trust and Proof
- [ ] Real customer reviews or testimonials
- [ ] Real photos (not stock)
- [ ] Specific numbers (years in business, customers served, rating)
- [ ] Industry certifications or awards
- [ ] Physical address or service area shown

### Priority 4: Technical
- [ ] Page loads in <3 seconds
- [ ] Mobile rendering is clean (no horizontal scroll, readable text)
- [ ] No interstitials or pop-ups blocking content
- [ ] HTTPS (no security warnings)
- [ ] No broken images or layout issues

---

## Intent-Specific Landing Page Requirements

### Buyer Intent ("buy X", "X near me", "hire X")
- **Needs:** Direct path to purchase/quote/booking
- **CTA:** Action-oriented (Get Quote, Book Now, Order Today)
- **Content:** Pricing info, availability, process steps
- **Don't do:** Long educational content before the CTA

### Comparison Intent ("X vs Y", "best X for Y")
- **Needs:** Comparison content that positions you favorably
- **CTA:** "See How We Compare" or "Get a Comparison Quote"
- **Content:** Feature comparison, pricing transparency, differentiators
- **Don't do:** Ignore the comparison entirely (user will bounce to find one)

### Research Intent ("how does X work", "what is X")
- **Needs:** Educational content with a soft conversion path
- **CTA:** "Download Guide" or "Get a Consultation"
- **Content:** Thorough explanation, FAQ, process overview
- **Don't do:** Hard sell on a research page (kills trust)

### Local Intent ("X near me", "X in [city]")
- **Needs:** Service area confirmation, local proof
- **CTA:** "Call Now" or "Get a Local Quote"
- **Content:** Service area map, local reviews, local phone number
- **Don't do:** Generic national page with no local relevance

### Brand Intent ("[company name]")
- **Needs:** Brand homepage is usually fine
- **CTA:** Whatever the primary business goal is
- **Content:** Brand story, overview, navigation to deeper pages
- **Don't do:** Send brand traffic to a generic product page

---

## Common Conversion Path Breaks

### 1. Redirect Chain Losing GCLID
**Symptom:** Clicks > 0, conversions = 0, page seems fine
**Cause:** ad click → domain1.com/?gclid=abc → redirect to domain2.com/page (GCLID stripped)
**Fix:** Ensure GCLID passes through all redirects, or use cross-domain tracking

### 2. Form Submits but Thank-You Page Doesn't Load
**Symptom:** CRM shows leads, Google Ads shows 0 conversions
**Cause:** Form submits via AJAX, no page navigation, tag fires on page load of thank-you page
**Fix:** Switch to event-based conversion tracking (fire on form submit event, not page load)

### 3. Homepage as Landing Page for Specific Intent
**Symptom:** High bounce rate, low conversion rate, quality score "Below Average" for LP experience
**Cause:** Specific search queries landing on generic homepage
**Fix:** Create intent-specific landing pages, or use ad group-level final URLs

### 4. Mobile Form Disaster
**Symptom:** Desktop converts okay, mobile doesn't
**Cause:** Form doesn't render on mobile, fields too small, captcha impossible on phone
**Fix:** Mobile-first form design, reduce field count, click-to-call as alternative

### 5. Speed Kill
**Symptom:** High bounce rate across all segments
**Cause:** Page takes >5 seconds to load (common with heavy WordPress sites, unoptimized images)
**Fix:** Page speed optimization, lighter landing page builder, CDN

---

## Quality Score Connection

Google's quality score includes **landing page experience** as one of three factors.
A "Below Average" LP experience score means Google is already penalizing you:
- Higher CPCs
- Lower ad rank
- Less impression share

Fixing landing page issues can lower costs AND increase conversions simultaneously.

**Quality score → LP experience levels:**
- Above Average → No issues from Google's perspective
- Average → Minor concerns, still competitive
- Below Average → Google sees problems (speed, mobile, content relevance)

Use the `post_click_quality_score` from keyword_view to identify which keywords have LP issues.

---

## Operator Checklist

When reviewing a landing page for a Google Ads account:

1. ☐ Check Fork A (tracking) FIRST — is the tag firing?
2. ☐ Check conversion action configuration
3. ☐ Walk the full conversion path (click → page → form → confirm → tag)
4. ☐ Check message match (search → ad → page H1)
5. ☐ Check CTA visibility and form friction
6. ☐ Check mobile rendering
7. ☐ Check page speed
8. ☐ Check intent routing (is the right page serving the right intent?)
9. ☐ Compare to quality score data (if available)
10. ☐ Classify the problem (tracking / path / traffic / both)
11. ☐ Create the right draft type for the diagnosis
