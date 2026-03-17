# Apply Layer — Design Document

## Status: LIVE — Write Access Confirmed
Last updated: 2026-03-15

> **API v20 confirmed working** (v18 sunset/404, v19 unstable/500).
> Live write paths: add campaign negative → GAQL verify → remove → verify removal, plus manifest-backed campaign budget update → verify → restore.
> Smoke test: `scripts/apply-layer/gads-smoke-test.sh negative <cid>` or `scripts/apply-layer/gads-smoke-test.sh budget <cid>`

---

## What This Is

The Apply Layer is the third layer of Google Ads Copilot's architecture:

```
READ  →  DRAFT  →  APPLY
(live)   (live)    (this document)
```

It defines how approved drafts get executed as real changes in Google Ads accounts — safely, reversibly, and with a complete audit trail.

**This document is the design + operating contract for the live implementation in `scripts/apply-layer/`.**

---

## Design Principles

### 1. Human-in-the-Loop (Always)
No mutation happens without explicit human approval. Period.

### 2. Reversibility First
The first apply actions are chosen specifically because they're easy to undo.
- Adding a negative keyword → remove it.
- Pausing a keyword → re-enable it.
These are the safest possible write operations in Google Ads.

### 3. Smallest Blast Radius
Start with actions that affect individual keywords, not campaigns or budgets.
Grow the blast radius slowly as confidence grows.

### 4. Audit Trail for Everything
Every mutation is logged: what changed, when, who approved it, what the state was before, and how to undo it.

### 5. Dry Run by Default
Every apply action first shows exactly what would happen, without doing it.
The operator confirms before the mutation executes.

---

## Scope: Live Safe Actions

The live apply layer supports three bounded write categories:

### Action 1: Add Negative Keywords
- **What:** Add negative keywords at campaign or ad group level
- **Why first:** Negative keywords can only REDUCE traffic. They cannot increase spend, break ads, or corrupt tracking. They are the safest possible mutation.
- **Undo:** Remove the negative keyword. Traffic resumes immediately.

### Action 2: Pause Keyword / Ad Group
- **What:** Set the status of a keyword or ad group to PAUSED
- **Why second:** Pausing stops traffic to a specific entity without deleting it. All history, quality scores, and configuration remain intact.
- **Undo:** Set status back to ENABLED. Entity resumes immediately.

### Action 3: Set Campaign Daily Budget
- **What:** Update `campaign_budget.amount_micros` for a campaign daily budget
- **How:** Only through an `## Apply Manifest` JSON block embedded in the draft
- **Why now:** Budget reallocation is a core operator action, but it is gated behind stronger guardrails than the v1 writes
- **Undo:** Restore the prior `amount_micros`

### Explicitly NOT in Live Scope
- ❌ Bid strategy changes
- ❌ Shared budgets / portfolio budgets
- ❌ Creating new campaigns or ad groups
- ❌ Modifying RSA assets
- ❌ Enabling paused entities
- ❌ Deleting anything
- ❌ Conversion action changes
- ❌ Account-level settings

---

## Approval Model

### Three-Step Flow

```
DRAFT (proposed)
    │
    ▼
DRY RUN → shows exactly what would change
    │
    ▼
APPROVE → human confirms ("apply this draft")
    │
    ▼
EXECUTE → mutation happens via Google Ads API
    │
    ▼
VERIFY → confirm the change took effect
    │
    ▼
LOG → write to audit trail
```

### Approval UX

When the operator says "apply this draft" or "/google-ads apply [draft-file]":

**Step 1: Dry Run Display**
```markdown
## Dry Run: 2026-03-15-east-coast-negatives.md

### Mutations (13 total):

1. ADD NEGATIVE keyword "near me" [PHRASE]
   → Campaign: "Website traffic-Search" (CID: 1234567890)
   
2. ADD NEGATIVE keyword "debris chute" [PHRASE]
   → Campaign: "Website traffic-Search" (CID: 1234567890)

3. ADD NEGATIVE keyword "cardella" [PHRASE]
   → Campaign: "Website traffic-Search" (CID: 1234567890)

[... all 13 listed ...]

### Separate Action (requires keyword-level mutation):

14. PAUSE keyword "waste management" [EXACT]
    → Campaign: "Website traffic-Search"
    → Ad Group: "High-Intent Buyers"
    → Current status: ENABLED → PAUSED

### Summary:
- 13 negative keyword additions (campaign level)
- 1 keyword pause
- Estimated waste stopped: ~$1,550/month
- Reversibility: Easy (all actions reversible)

⚠️ This will make real changes to the Google Ads account.
Type "confirm" to proceed, or "cancel" to abort.
```

**Step 2: Human Confirmation**
The operator must explicitly confirm. No implicit approvals, no timeouts that auto-approve.

**Step 3: Execution**
Mutations are applied one at a time, with error handling:
- If any single mutation fails, log the error and continue with the rest
- Report which succeeded and which failed
- Failed mutations remain in the draft as "not applied"

**Step 4: Verification**
After execution, re-query the account to verify changes took effect:
- Confirm negative keywords exist in the account
- Confirm keyword/ad group status changed to PAUSED

**Step 5: Audit Trail**
Log everything (see Audit Trail section below).

---

## Reversibility Model

### How Undo Works

Every applied action gets a **reversal record** stored alongside it:

```markdown
## Applied Action Log Entry

### Action: ADD NEGATIVE "near me" [PHRASE]
- **Applied at:** 2026-03-15T14:30:00Z
- **Applied by:** operator (Matt)
- **Draft source:** 2026-03-15-east-coast-negatives.md
- **Account:** Acme Equipment Co. (1234567890)
- **Target:** Campaign "Website traffic-Search"
- **Reversal:** REMOVE negative keyword "near me" [PHRASE] from Campaign "Website traffic-Search"
- **Reversal API call:**
  ```
  mutate: campaign_criterion REMOVE
  resource_name: customers/1234567890/campaignCriteria/{criterion_id}
  ```
- **Status:** active
```

### Undo Command

```
/google-ads undo [action-id]
```

Displays what will be reversed, requires confirmation (same dry-run flow as apply).

### Bulk Undo

```
/google-ads undo-draft [draft-file]
```

Reverses ALL actions from a specific draft. Useful if a batch of negatives turns out to be too aggressive.

### Time-Limited Safety Window
For the first 30 days of apply-layer usage:
- All applied changes get a 7-day "easy undo" window
- After 7 days, undo still works but triggers a warning: "This change has been live for X days. Performance data since then may be affected by reversal."

---

## Audit Trail

### Location
```
workspace/ads/audit-trail/
├── _log.md                          # Append-only master log
├── 2026-03-15-apply-session.md      # Per-session detailed log
└── reversal-registry.json           # Machine-readable reversal records
```

### Master Log Format (`_log.md`)

```markdown
# Apply Layer — Audit Trail

## 2026-03-15 14:30 — Apply Session

**Operator:** Matt
**Draft:** 2026-03-15-east-coast-negatives.md
**Account:** Acme Equipment Co. (1234567890)
**Actions:** 13 negative additions + 1 keyword pause
**Result:** 14/14 succeeded
**Verification:** All confirmed via re-query

| # | Action | Target | Status | Reversal ID |
|---|--------|--------|--------|-------------|
| 1 | ADD NEG "near me" [PHRASE] | Campaign: Website traffic-Search | ✅ Applied | rev-001 |
| 2 | ADD NEG "debris chute" [PHRASE] | Campaign: Website traffic-Search | ✅ Applied | rev-002 |
| ... | ... | ... | ... | ... |
| 14 | PAUSE KW "waste management" [EXACT] | AG: High-Intent Buyers | ✅ Applied | rev-014 |

---
```

### Session Detail Format (`YYYY-MM-DD-apply-session.md`)

Each session gets a detailed log with:
- Full dry-run output (what was shown to operator)
- Operator's confirmation
- Each API call and response
- Verification query results
- Reversal records generated
- Any errors encountered

### Reversal Registry (`reversal-registry.json`)

```json
{
  "reversals": [
    {
      "id": "rev-001",
      "action": "ADD_NEGATIVE",
      "keyword": "near me",
      "matchType": "PHRASE",
      "scope": "CAMPAIGN",
      "campaignName": "Website traffic-Search",
      "campaignId": "12345678",
      "criterionId": "98765432",
      "accountId": "1234567890",
      "appliedAt": "2026-03-15T14:30:00Z",
      "appliedBy": "operator",
      "draftSource": "2026-03-15-east-coast-negatives.md",
      "reversalAction": "REMOVE_NEGATIVE",
      "reversalResourceName": "customers/1234567890/campaignCriteria/98765432",
      "status": "active",
      "undoneAt": null
    }
  ]
}
```

---

## API Integration

### Google Ads MCP — Write Operations

The current `google-ads-mcp` MCP server is **read-only** (search + list_accessible_customers).
The apply layer requires write access.

**Two paths to write access:**

#### Path A: MCP Server Extension (Preferred)
If/when `google-ads-mcp` adds a `mutate` tool, use it directly:
```
Tool: mutate
Arguments: {
  "customer_id": "1234567890",
  "operations": [
    {
      "create": {
        "campaign": "customers/1234567890/campaigns/CAMPAIGN_ID",
        "negative": true,
        "keyword": {
          "text": "near me",
          "match_type": "PHRASE"
        }
      }
    }
  ]
}
```

#### Path B: Direct Google Ads API (Confirmed Working)
Use the Google Ads API REST endpoint directly via curl:
```bash
curl -X POST \
  "https://googleads.googleapis.com/v20/customers/1234567890/campaignCriteria:mutate" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "developer-token: $DEVELOPER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "operations": [{
      "create": {
        "campaign": "customers/1234567890/campaigns/CAMPAIGN_ID",
        "negative": true,
        "keyword": {
          "text": "near me",
          "matchType": "PHRASE"
        }
      }
    }]
  }'
```

#### Specific Mutations for v1

**Add negative keyword (campaign level):** ✅ Confirmed working
```
POST /v20/customers/{customer_id}/campaignCriteria:mutate
Operation: CREATE
Resource: CampaignCriterion
  campaign: customers/{cid}/campaigns/{campaign_id}
  negative: true
  keyword.text: "{text}"
  keyword.match_type: PHRASE | EXACT | BROAD
```

**Add negative keyword (ad group level):**
```
POST /v20/customers/{customer_id}/adGroupCriteria:mutate
Operation: CREATE
Resource: AdGroupCriterion
  ad_group: customers/{cid}/adGroups/{ad_group_id}
  negative: true
  keyword.text: "{text}"
  keyword.match_type: PHRASE | EXACT | BROAD
```

**Pause keyword:**
```
POST /v20/customers/{customer_id}/adGroupCriteria:mutate
Operation: UPDATE
Resource: AdGroupCriterion
  resource_name: customers/{cid}/adGroupCriteria/{criterion_id}
  status: PAUSED
Update mask: status
```

**Pause ad group:**
```
POST /v20/customers/{customer_id}/adGroups:mutate
Operation: UPDATE
Resource: AdGroup
  resource_name: customers/{cid}/adGroups/{ad_group_id}
  status: PAUSED
Update mask: status
```

---

## Error Handling

### Per-Action Errors
If a single action fails:
1. Log the error (API response code + message)
2. Continue with remaining actions
3. Report failed actions in the session log
4. Failed actions remain in the draft as "not applied"
5. Operator can retry failed actions individually

### Common Failure Modes

| Error | Cause | Recovery |
|-------|-------|----------|
| `AUTHENTICATION_ERROR` | Token expired or invalid | Re-authenticate, retry |
| `AUTHORIZATION_ERROR` | Insufficient permissions | Need manager/admin access to account |
| `DUPLICATE_KEYWORD` | Negative already exists | Skip (already applied), log as "already present" |
| `MUTATE_ERROR` | Invalid resource name or ID | Verify campaign/ad group ID, retry with corrected ID |
| `RATE_LIMIT` | Too many API calls | Back off, retry with delay |
| `INTERNAL_ERROR` | Google Ads API issue | Retry after delay, log for manual follow-up |

### Partial Apply State
If 10 out of 13 actions succeed and 3 fail:
- The draft status becomes `partially_applied`
- The audit trail shows which succeeded and which failed
- A follow-up apply attempt only retries the failed actions

---

## Draft Status Updates After Apply

When a draft is applied (fully or partially), update:

1. **Draft file:** Add applied date, applied actions, failed actions
2. **Draft index (`_index.md`):** Move from "Proposed" or "Approved" to "Applied"
3. **Change log (`workspace/ads/change-log.md`):** Record what changed
4. **Summary (`_summary.md`):** Regenerate to remove applied drafts

```markdown
## Review (updated after apply)
- [x] Reviewed by operator
- [x] Approved for implementation
- Reviewed on: 2026-03-15
- Applied on: 2026-03-15
- Applied actions: 13/14 succeeded
- Failed actions: None
- Reversal IDs: rev-001 through rev-014
- Notes: All negatives applied. Keyword pause applied. Will reassess in 2 weeks.
```

---

## Future Expansion (v2+)

After v1 proves reliable through 30+ successful apply sessions:

### v2: Budget Changes
- Increase/decrease campaign daily budget
- Implemented in `scripts/apply-layer/` behind an `## Apply Manifest` JSON block (manifest-first parsing).
- Safeguards enforced (fail closed):
  - Maximum change per action: ±30% (configurable per action guardrails)
  - Cooldown period between budget changes: 7 days (overrideable with `--force`, logs the override)
  - Tracking gate: block when tracking confidence is Low/Broken or when pending tracking drafts exist
  - Budget-neutral default: sum(proposed) must equal sum(current) across valid budget actions in a draft
  - Optional draft-level net increase: only when `meta.budget_policy.allow_net_increase=true`, capped at +10% by default
  - Strong confirmation prompt: operator must type `confirm budgets`

### v3: Campaign Creation
- Create new campaigns from structure drafts
- Much larger blast radius
- Requires draft-to-API translation for full campaign configuration

### v4: RSA Asset Updates
- Add/remove/modify headlines and descriptions
- Moderate risk — asset performance takes time to evaluate
- Reversible but with 2-3 week learning period impact

### vN: Full Account Management
- Bid strategy changes
- Conversion action configuration
- Account settings
- This is far future — only after extensive v1-v3 reliability data

---

## Implementation Checklist

See `APPLY-IMPLEMENTATION.md` for full implementation notes and testing guide.
Scripts are in `scripts/apply-layer/`.
Operator workflow: `OPERATOR-PLAYBOOK.md`.

### Build Phase (Scaffolded 2026-03-15, expanded 2026-03-15)
- [x] Build direct API integration (Path B — REST, no MCP write dependency)
- [x] Build token refresh / auth helper (`lib/token-refresh.sh`)
- [x] Build draft parser (`lib/parse-draft.sh`)
- [x] Build the per-action executor with error handling (`lib/api-mutate.sh`)
- [x] Build the verification re-query (`lib/api-verify.sh`)
- [x] Build the audit trail writer (`lib/audit-write.sh`)
- [x] Build the dry-run display function (`gads-apply.sh --dry-run`)
- [x] Build the confirmation prompt (`gads-apply.sh`)
- [x] Build the reversal registry (`audit-write.sh` + `reversal-registry.json`)
- [x] Build the undo command (`gads-undo.sh`)
- [x] Build operator status command (`gads-status.sh`)
- [x] Build draft review command (`gads-review.sh`)
- [x] Expand draft parser for keyword + ad group pauses (`_parse_pause_sections`)
- [x] Expand apply script for ad group pause ID resolution
- [x] Create pause-draft template (`drafts/templates/pause-draft.md`)
- [x] Improve dry-run display (action type summary, risk assessment)
- [x] Improve post-apply summary (undo instructions, monitoring guidance)
- [x] Create operator playbook (`OPERATOR-PLAYBOOK.md`)
- [x] Create first live example (`examples/first-live-apply.md`)

### Test Phase
- [x] Validate that Google Ads API write access works with current credentials ✅ 2026-03-15
- [x] API version confirmed: **v20** (v18 sunset 404, v19 unstable 500) ✅ 2026-03-15
- [x] Full write cycle: add negative → GAQL verify → remove → verify removal ✅ 2026-03-15
- [x] Smoke test script created: `scripts/apply-layer/gads-smoke-test.sh` ✅ 2026-03-15
- [ ] Test parse: `gads-apply.sh --parse-only` on real draft
- [ ] Test dry run: `gads-apply.sh --dry-run` with real ID resolution
- [ ] Test with full draft apply on a real account (negatives)
- [ ] Test keyword pause on a real account
- [ ] Test ad group pause on a real account
- [ ] Test undo for each action type (negative remove, keyword enable, ad group enable)
- [ ] Run 5+ apply sessions manually before any automation
- [ ] Review audit trail quality with operator after first 10 sessions
