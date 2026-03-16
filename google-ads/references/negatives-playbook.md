# negatives-playbook.md

## Core principle
Negative keywords are a scalpel, not a shotgun.

The job is to add the **right negatives at the right scope with the right match type** — and also to **remove or narrow negatives that are blocking good traffic**.

## Three-dimensional negative management

### 1. Negatives to ADD
Traffic that has no plausible path to conversion. Cut it.

**Priorities:**
1. Obvious junk (competitor brands, wrong geography, wrong service)
2. Repeated irrelevant intent (informational, job-seeker, DIY)
3. Structural negatives (routing traffic between campaigns/ad groups)
4. Defensive negatives (proactive exclusion of emerging waste patterns)

### 2. Negatives to REMOVE
Existing negatives that are blocking valuable traffic. Common in:
- Smart campaign auto-generated negatives (often overly aggressive)
- Inherited negatives from previous account managers
- Negatives that made sense historically but don't now (business services changed)
- Overly broad negatives that suppress good queries

**Red flags for harmful negatives:**
- A negative that matches the business's own services (e.g., "brick" negative on a brick recycling company)
- Low impression counts on ad groups where you'd expect volume — check if negatives are suppressing queries
- Keywords in keyword_view with low impressions relative to search volume — a negative may be interfering
- Converting queries that are semantically close to an existing negative — the negative may be blocking similar valuable traffic

### 3. Negatives to NARROW or MOVE
Existing negatives that aren't wrong, just poorly calibrated:
- Broad match negative → narrow to phrase or exact
- Campaign-level negative → move to ad-group-level (or vice versa)
- Individual campaign negatives → consolidate into a shared negative list

## Match type guidance
- **Exact:** Safest default for specific junk terms. Use when the exact query is bad but related queries might be good.
- **Phrase:** Good for recurring unwanted patterns. Use when any query containing that phrase is bad.
- **Broad match negative:** HIGH RISK. Blocks any query containing all words in any order. Avoid unless clearly justified and collateral risk is documented.

## Scope guidance
- **Shared list / account level:** For globally bad intent (job seekers, wrong geography, competitor brands)
- **Campaign level:** When bad in one campaign but valuable elsewhere
- **Ad group level:** For routing control — directing queries to the right ad group

## Output expectation
Every negative recommendation must include:
- keyword/cluster
- why it is a problem
- suggested match type
- suggested scope
- confidence level
- collateral-risk note
- whether exclusion, isolation, or keyword fix is better
- **triggering keyword** (from keyword_view, when available) — which targeted keyword caused this match

Every removal/narrowing recommendation must include:
- current state (keyword, match type, scope)
- why it should change
- evidence of blocked good traffic
- risk of the change (what bad traffic might return)
- proposed new state
