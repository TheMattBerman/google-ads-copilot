# tracking-playbook.md

## Core principle
If conversion tracking is wrong, optimization is theater.

## Tracking trust hierarchy
1. Conversion definition
2. Conversion counting integrity
3. Tag firing / implementation health
4. Attribution setup
5. Value quality
6. Enhanced signal quality

## Common failure modes
- Duplicate conversion counting
- Micro-conversion pollution
- Premature firing
- Missing or broken values
- Consent / implementation gaps

---

## Tracking Confidence Rubric — Explicit Thresholds

### HIGH Confidence
**Meaning:** Conversion data is trustworthy enough to optimize, scale, and make budget decisions on.

**All of these must be true:**
- [ ] One clear primary conversion action that represents the real business goal (purchase, qualified lead, phone call >60s)
- [ ] Counting type is correct: "One" for leads, "Every" only for e-commerce transactions
- [ ] No duplicate tracking: same event is NOT counted by both Google Ads tag AND GA4 import
- [ ] `include_in_conversions_metric = TRUE` only for primary conversion actions (not micro-conversions)
- [ ] Auto-tagging is enabled
- [ ] `conversions` and `all_conversions` are within 2x of each other (if all_conversions is >2x, view-throughs or micro-conversions are polluting)
- [ ] At least 15 conversions in the last 30 days (enough volume for statistical reliability)
- [ ] Conversion values are set and reflect actual business value (not all $1.00 defaults)

**Operator behavior at HIGH:** Optimize freely. Trust CPA/ROAS numbers. Scale based on data.

---

### MEDIUM Confidence
**Meaning:** Directionally useful but not precise enough for aggressive optimization. Fix the issues before scaling.

**One or more of these are true:**
- [ ] Micro-conversions are included in primary (`include_in_conversions_metric = TRUE` for page views, scroll, etc.) — inflates conversion count
- [ ] Counting type may be wrong (e.g., "Every" on lead forms — counts repeat submissions)
- [ ] `all_conversions` is 2-5x `conversions` — some phantom signal present
- [ ] Auto-tagging is disabled but UTM tracking is in place — attribution is approximate
- [ ] Conversion volume is 5-14 in last 30 days — enough to see directional patterns, not enough for statistical confidence
- [ ] Values are present but inconsistent or defaulted for some actions
- [ ] Small suspected duplicate (e.g., GA4 import that might partially overlap with native tag)

**Operator behavior at MEDIUM:**
- Optimize cautiously — don't trust CPA numbers to the dollar
- Budget scaling: proceed if fundamentals are strong, but note the uncertainty
- Fix tracking issues in parallel with optimization
- Negatives and structure changes: proceed freely (waste is waste regardless)

---

### LOW Confidence
**Meaning:** Conversion data is significantly misleading. Fix tracking before making budget decisions.

**One or more of these are true:**
- [ ] Clear duplicate tracking: same conversion counted by two sources (Google Ads tag + GA4 import for same event)
- [ ] Micro-conversions dominate: page views or time-on-site represent >50% of reported "conversions"
- [ ] `all_conversions` is >5x `conversions` — massive view-through or micro-conversion pollution (often from Display Network)
- [ ] No clear primary conversion action — everything is weighted equally
- [ ] Conversion volume <5 in last 30 days — insufficient for any inference
- [ ] Smart bidding is active but learning from polluted signal
- [ ] Known broken implementation (tags not firing, wrong pages, etc.)

**Operator behavior at LOW:**
- **Block budget scaling** — do not increase spend on unreliable signal
- **Block bid strategy changes** — don't switch to tCPA/tROAS on bad data
- Structure changes: proceed with caution (intent analysis is still valid)
- Negatives: proceed freely
- RSA changes: proceed freely (copy quality is independent of tracking)
- **Create a tracking fix draft immediately** — this is P0

---

### BROKEN Confidence
**Meaning:** No meaningful conversion signal exists. The account is flying blind.

**One or more of these are true:**
- [ ] Zero conversion actions configured
- [ ] All conversion actions are disabled
- [ ] No conversions recorded in any time period
- [ ] Conversion actions exist but are clearly wrong (e.g., only tracking "page load" as a conversion)
- [ ] Tag is present but never fires (zero all_conversions)
- [ ] Account is optimizing spend with no feedback loop

**Operator behavior at BROKEN:**
- **STOP all optimization activity** except tracking fix
- Create a tracking fix draft as the ONLY deliverable
- Note: "This account has no conversion signal. All reported CPA/ROAS numbers are meaningless."
- Do not create budget, structure, or RSA drafts — they would be based on nothing

---

## Quick Decision Matrix

| Tracking Level | Negatives | Structure | RSAs | Budget Changes | Bid Strategy | Smart Bidding |
|---------------|-----------|-----------|------|---------------|-------------|---------------|
| HIGH | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ Trust it |
| MEDIUM | ✅ | ✅ | ✅ | ⚠️ Cautious | ⚠️ Cautious | ⚠️ Monitor |
| LOW | ✅ | ⚠️ | ✅ | ❌ Blocked | ❌ Blocked | ❌ Fix first |
| BROKEN | ✅* | ❌ | ❌ | ❌ | ❌ | ❌ |

*Negatives at BROKEN: only obvious junk can be excluded based on query text alone, without performance data.

## Operator rule
If tracking is unreliable, say it early and clearly.
Never bury a tracking problem under optimization suggestions.
The tracking diagnosis is a gate — everything else flows through it.

## Red flags to call out explicitly

1. **The "too good to be true" CPA:** If CPA looks unrealistically low (e.g., $2 for a B2B lead), check for micro-conversion pollution or duplicate counting.
2. **The conversions ≠ reality gap:** Ask the operator: "How many real leads/sales did you get last month?" If the answer doesn't match Google Ads' reported conversions, tracking is lying.
3. **Display Network + view-through conversions:** When `all_conversions` is massively higher than `conversions`, and the account has Display Network enabled on Search campaigns, view-through conversions are almost certainly inflating numbers.
4. **Smart campaign auto-conversions:** Smart campaigns may use Google's auto-detected conversions (store visits, calls of any duration) — these are directionally useful but not precise.
