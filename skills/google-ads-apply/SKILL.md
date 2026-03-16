---
name: google-ads-apply
description: >
  Execute approved draft actions in Google Ads accounts. Supports four safe
  mutation types: add campaign-level negatives, add ad-group-level negatives,
  pause keywords, and pause ad groups. Requires human confirmation via
  dry-run → approve → execute → verify → audit flow. All actions are logged
  in the audit trail and fully reversible.
argument-hint: "[draft-file] | review [draft-file|--all] | status | undo [action-id] | undo-draft [draft-file] | log"
---

# Google Ads Apply

## Status: LIVE — Write Access Confirmed
> **API v20 confirmed working** (2026-03-15). v18 is sunset (404), v19 unstable (500).
> Full write cycle proven: add campaign negative → GAQL verify → remove → verify removal.
> Keyword pauses and ad group pauses fully scaffolded and hardened.
> CLI scripts at `scripts/apply-layer/`.
> Smoke test: `scripts/apply-layer/gads-smoke-test.sh <customer_id>`
> See `APPLY-LAYER.md` for design and `APPLY-IMPLEMENTATION.md` for implementation notes.
> See `OPERATOR-PLAYBOOK.md` for the full operator workflow loop.

Read first:
- `OPERATOR-PLAYBOOK.md` — full operator workflow (connect → select → review → apply → verify → undo)
- `APPLY-LAYER.md` — design document, API specs, error handling
- `drafts/DRAFTS.md` — draft system documentation

Read workspace:
- `workspace/ads/drafts/_index.md` — current queue
- `workspace/ads/drafts/_summary.md` — prioritized summary
- `workspace/ads/audit-trail/_log.md` — previous apply sessions (if any)
- `workspace/ads/audit-trail/reversal-registry.json` — active reversals

---

## Commands

### Apply a Draft
```
/google-ads apply [draft-file]
```

**Flow:**
1. Read the draft file
2. Parse all proposed actions (negatives, keyword pauses, ad group pauses)
3. Validate each action (correct account, valid targets, within v1 scope)
4. Resolve human-readable names to Google Ads resource IDs via GAQL
5. Display dry run with every mutation listed, action type summary, and risk assessment
6. Wait for operator confirmation ("confirm" or "cancel")
7. Execute each action via Google Ads REST API v20
8. Verify changes via GAQL re-query
9. Write audit trail (session log, master log, reversal registry)
10. Update draft status to "applied"
11. Show post-apply summary with undo instructions

### Review a Draft (No Apply)
```
/google-ads apply review [draft-file]
/google-ads apply review --all
```

**Flow:**
1. Parse the draft into structured actions
2. Show action breakdown with counts by type and risk levels
3. Show confidence and dependencies
4. Provide a proceed/defer recommendation
5. Show next-step commands (dry-run or full apply)

No network calls, no API access needed. Pure local analysis.

### Check Operator Status
```
/google-ads apply status
```

Shows at a glance:
- Connection state (account, API version, credentials)
- Pending drafts with status
- Active reversals grouped by draft
- Recent apply sessions
- Suggested next step

### Undo a Single Action
```
/google-ads undo [reversal-id]
```

**Flow:**
1. Look up reversal record in `workspace/ads/audit-trail/reversal-registry.json`
2. Display what will be reversed
3. Warn if change has been live >7 days
4. Wait for confirmation
5. Execute reversal via Google Ads API
6. Verify via GAQL
7. Update reversal registry (status: "undone")

### Undo an Entire Draft
```
/google-ads undo-draft [draft-file]
```

Reverses ALL active actions from a specific draft. Same confirmation flow.

### View Apply Log
```
/google-ads apply log
```

Shows recent apply sessions from `workspace/ads/audit-trail/_log.md`.

---

## Scope Guardrails (v1)

### Allowed Actions (4 types)
| Action | Target | Scope | Risk |
|--------|--------|-------|------|
| Add negative keyword | Campaign criterion | Campaign-level negative | Low |
| Add negative keyword | Ad group criterion | Ad group-level negative | Low |
| Pause keyword | Ad group criterion | Set status to PAUSED | Low |
| Pause ad group | Ad group | Set status to PAUSED | Medium |

### Why These Are Safe
- **Negative keywords** can only REDUCE traffic. They cannot increase spend, break ads, or corrupt tracking.
- **Pausing keywords** stops traffic to one keyword. All history, quality scores, and configuration remain intact.
- **Pausing ad groups** stops traffic to a set of keywords. Same preservation guarantees. Broader blast radius than keyword pause, hence Medium risk.
- **All are instantly reversible:** remove the negative, or set status back to ENABLED.

### Blocked Actions (Hard Reject)
If a draft contains actions outside v1 scope, the apply command will:
1. List the out-of-scope actions
2. Explain which are out of scope and why
3. Offer to apply ONLY the in-scope actions
4. Never execute out-of-scope actions regardless of confirmation

| Action | Version | Why Blocked |
|--------|---------|-------------|
| Budget changes | v2 | Can increase spend |
| Bid strategy changes | v2 | Can disrupt Smart Bidding learning |
| Campaign creation | v3 | Large blast radius |
| RSA modifications | v4 | Learning period impact |
| Enable paused entities | Never in v1 | Higher risk than pausing |
| Delete anything | Never | Pause instead |

---

## Draft Parsing

The apply layer parses these sections from draft markdown files:

| Section | Action Type | Template |
|---------|-------------|----------|
| **Section A: Negatives to ADD** | `ADD_NEGATIVE` | `negative-draft.md` |
| **Section D: CRITICAL KEYWORD-LEVEL RECOMMENDATION** | `PAUSE_KEYWORD` | `negative-draft.md` |
| **Section A: Keywords to PAUSE** | `PAUSE_KEYWORD` | `pause-draft.md` |
| **Section B: Ad Groups to PAUSE** | `PAUSE_ADGROUP` | `pause-draft.md` |

Both `negative-draft.md` and `pause-draft.md` templates are supported. Mixed-type drafts (negatives + pauses in one file) are fully supported — the parser extracts from all applicable sections and deduplicates.

### Draft Templates
- `drafts/templates/negative-draft.md` — negative keyword additions + removals + narrows
- `drafts/templates/pause-draft.md` — keyword pauses + ad group pauses + impact summary

---

## Validation Checks (Before Dry Run)

Before showing the dry run, validate:

1. **Account match:** Draft account ID matches connected account
2. **Campaign exists:** Campaign referenced in draft is still present (GAQL lookup)
3. **Ad group exists:** For ad-group-scoped actions (GAQL lookup)
4. **No duplicates:** Negative keyword doesn't already exist at the same scope
5. **Match type valid:** PHRASE, EXACT, or BROAD only
6. **Target exists:** Keyword being paused still exists and is currently ENABLED
7. **Ad group status:** For ad group pause, target is currently ENABLED
8. **Within scope:** All actions are v1 (add negative, pause keyword, pause ad group)

If validation fails, report which actions failed and why. Don't block the entire apply — allow valid actions to proceed.

---

## Dry Run Display

```markdown
═══════════════════════════════════════════════════════
 DRY RUN: [draft-file]
═══════════════════════════════════════════════════════

Account: [Name] (CID: [ID])
Actions: [N] valid / [M] total

#    Action           Target                       Detail                      Risk
---  ---------------  ---------------------------  --------------------------  ------
1    ADD NEG          Campaign: [name]             "near me" [PHRASE]          Low
2    ADD NEG          Campaign: [name]             "debris chute" [PHRASE]     Low
...
13   PAUSE KW         AG: [name]                   "waste mgmt" [EXACT]        Low
14   PAUSE AG         Campaign: [name]             [ad group name]             Medium

Summary:
  • 12 negative keyword addition(s)
  • 1 keyword pause(s)
  • 1 ad group pause(s)
  • Reversibility: All actions reversible

⚠️  This will make REAL changes to account [CID].
Type 'confirm' to proceed, or 'cancel' to abort:
```

---

## Post-Apply Verification

After execution, run verification queries:

| Action | Verification Query | What's Confirmed |
|--------|-------------------|------------------|
| Add campaign negative | `campaign_criterion` WHERE negative=TRUE | Keyword exists in campaign |
| Add ad group negative | `ad_group_criterion` WHERE negative=TRUE | Keyword exists in ad group |
| Pause keyword | `keyword_view` + status check | Status is PAUSED |
| Pause ad group | `ad_group` + status check | Status is PAUSED |

---

## Audit Trail

After every apply session, these files are updated:

1. **Master log:** `workspace/ads/audit-trail/_log.md` — append-only session summary
2. **Session detail:** `workspace/ads/audit-trail/YYYY-MM-DD-apply-session.md` — full action-by-action log
3. **Reversal registry:** `workspace/ads/audit-trail/reversal-registry.json` — machine-readable undo records
4. **Draft file:** Updated with applied date and reversal IDs
5. **Draft index:** `workspace/ads/drafts/_index.md` — moved to Applied section
6. **Change log:** `workspace/ads/change-log.md` — record of what changed

---

## CLI Scripts

| Script | Purpose |
|--------|---------|
| `gads-apply.sh` | Full apply flow: parse → validate → dry-run → confirm → execute → verify → audit |
| `gads-apply.sh --dry-run` | Parse and show dry run only |
| `gads-apply.sh --parse-only` | Parse draft to JSON (debugging) |
| `gads-review.sh` | Parse and show operator-facing review (no API calls) |
| `gads-review.sh --all` | Review all pending drafts |
| `gads-undo.sh <rev-id>` | Undo a single action |
| `gads-undo.sh --draft <file>` | Undo all actions from a draft |
| `gads-undo.sh --list` | List all active reversals |
| `gads-status.sh` | Full operator status overview |
| `gads-status.sh --applied` | Show only applied actions |
| `gads-status.sh --pending` | Show only pending drafts |
| `gads-smoke-test.sh` | End-to-end write cycle test |

---

## Safety Rules

1. **Never apply without dry run.** The operator must see exactly what will change.
2. **Never auto-approve.** The operator must explicitly type "confirm."
3. **Never apply out-of-scope actions.** Hard reject, clear explanation.
4. **Never delete anything.** Pause is the maximum severity in v1.
5. **Log everything.** Every action, every error, every reversal.
6. **Fail gracefully.** If one action fails, continue with the rest. Report the failure.
7. **Verify after apply.** Re-query to confirm changes took effect.
8. **Make undo easy.** Every action has a stored reversal instruction.
9. **Rate limit.** Max 50 mutations per apply session. 500ms delay between mutations.
10. **No batch apply across accounts.** One account per apply session.
