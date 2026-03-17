# Operator Playbook — Google Ads Copilot

## The Loop

This is how you run an account with the agent. Connect, analyze, review what it found, approve or reject its proposals, apply the good ones, verify they worked. Repeat.

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   CONNECT  →  SELECT  →  REVIEW  →  DRAFT  →  APPLY  →  VERIFY    │
│      ↑                                                    │         │
│      │              ← ← ← ← UNDO ← ← ← ← ← ← ← ← ← ←┘         │
│      │                                                              │
│      └──────────────── NEXT SESSION ────────────────────────────────┘
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Connect

**Command:** `/google-ads connect setup` or `/google-ads connect healthcheck`

**What happens:**
1. MCP server is verified (google-ads-mcp responds to queries)
2. OAuth2 credentials are validated (token refresh works)
3. Developer token is confirmed (API calls succeed)

**What you see:**
```
✅ MCP server: responding
✅ OAuth2 token: valid (expires in 3598s)
✅ Developer token: valid
✅ API version: v20
```

**If something fails:** The connect skill provides a diagnosis table with exact symptoms, causes, and fixes. Don't guess — run the healthcheck.

**State after:** Credentials confirmed. Ready to select an account.

---

## Phase 2: Select Account

**Command:** `/google-ads connect select` or automatic during setup

**What happens:**
1. All accessible accounts are discovered via `list_accessible_customers`
2. Each account gets a name, ID, and type (direct vs MCC)
3. You pick the one you want to work with
4. An account fingerprint is written to `workspace/ads/account.md`

**What you see:**
```
## Accessible Google Ads Accounts

| # | Customer ID | Name                    | Type    |
|---|-------------|-------------------------|---------|
| 1 | 1234567890  | Acme Equipment Co.      | Direct  |
| 2 | 9876543210  | Metro Recycling LLC     | Direct  |
| 3 | 5551234567  | [Manager Account]       | MCC     |

Currently selected: Acme Equipment Co. (1234567890)
```

**Safety check:** If you asked about "Metro Recycling" but selected a different CID, the agent warns you. Wrong-account audits are a real risk.

**State after:** Account selected. `workspace/ads/account.md` is populated. All subsequent commands target this account.

---

## Phase 3: Review Findings

**Command:** `/google-ads audit` or `/google-ads daily` or individual skills

**What happens:**
1. Live data is pulled from the selected account
2. The agent runs its analytical engine (intent mapping, waste detection, tracking diagnosis)
3. Findings are written to `workspace/ads/findings.md`

**What you see:** A structured operator briefing with:
- Account status and health flags
- Tracking confidence (HIGH/MEDIUM/LOW/BROKEN)
- Waste patterns identified
- Intent mixing problems
- Landing page issues
- Opportunities

**Key rule:** Findings are READ-ONLY observations. They don't change anything in the account. They inform drafts.

**State after:** Analytical context established. Ready to generate or review drafts.

---

## Phase 4: Review Drafts

**Command:** `/google-ads draft-summary` to see all pending drafts

**What happens:**
1. All pending drafts in `workspace/ads/drafts/` are read
2. Each is classified by priority (P0–P3), impact, risk, and reversibility
3. Dependencies between drafts are mapped
4. A recommended apply order is produced

**Note:** This updates `workspace/ads/drafts/_summary.md`, which is the current backlog snapshot. Audit runs that create multiple drafts should also leave behind `_batch-YYYY-MM-DD-[account-slug].md` as the point-in-time packet for that run.

**What you see:**
```
## Draft Summary — 2026-03-15
Pending: 4 drafts | Quick-apply: 2 | Blocked: 1

### Apply Order:
1. P0 CRITICAL — Tracking Fix (blocks budget decisions)
2. P1 QUICK WIN — 13 Negatives + KW Pause ($1,550/mo waste)
3. P2 STRATEGIC — Structure Changes (needs negatives first)
4. P0 CRITICAL — Landing Page Fix (needs client resources)
```

**Decision point:** You decide which drafts to approve, defer, or reject.

**Individual draft review:** Read any draft file directly to see full reasoning, evidence, and risk analysis for each proposed action.

**State after:** You know what's proposed and what you want to apply.

---

## Phase 5: Apply

**Command:** `/google-ads apply [draft-file]`

**What happens — in this exact order:**
1. **Parse** — Draft markdown is parsed into structured actions
2. **Validate** — Each action is checked: target exists, within v1 scope, no duplicates
3. **Resolve** — Human-readable names are resolved to Google Ads resource IDs via GAQL
4. **Dry Run** — Every proposed mutation is displayed in a clean table
5. **Confirm** — You must type "confirm" — no auto-approve, no timeout
6. **Execute** — Mutations are applied one at a time with error handling
7. **Verify** — GAQL queries confirm each change took effect
8. **Audit** — Full session is logged to the audit trail

**What you see (dry run):**
```
═══════════════════════════════════════════════════════
 DRY RUN: 2026-03-15-acme-negatives.md
═══════════════════════════════════════════════════════

Account: Acme Equipment Co. (CID: 1234567890)
Actions: 14 total (13 valid, 1 skip)

#    Action           Target                      Detail                     Risk
---  ---------------  --------------------------  -------------------------  ------
1    ADD NEG          Campaign: Website traffic   "near me" [PHRASE]         Low
2    ADD NEG          Campaign: Website traffic   "debris chute" [PHRASE]    Low
...
14   PAUSE KW         AG: High-Intent Buyers      "waste management" [EXACT] Low

⚠️  This will make REAL changes to account 1234567890.
Type 'confirm' to proceed, or 'cancel' to abort:
```

**What you see (after execution):**
```
═══════════════════════════════════════════════════════
 Apply Session Complete
═══════════════════════════════════════════════════════

  Executed:  14 succeeded, 0 failed
  Verified:  14 confirmed, 0 unconfirmed
  Audit:     workspace/ads/audit-trail/2026-03-15-apply-session.md
  Registry:  14 reversal records created (rev-001 through rev-014)
```

### v1 Scope — What Can Be Applied

| Action | What It Does | Risk | Undo |
|--------|-------------|------|------|
| Add negative keyword (campaign) | Blocks search terms from triggering ads | Low — can only REDUCE traffic | Remove the negative |
| Add negative keyword (ad group) | Same, scoped to one ad group | Low | Remove the negative |
| Pause keyword | Stops a specific keyword from serving | Low — preserves all history | Re-enable keyword |
| Pause ad group | Stops an entire ad group from serving | Medium — multiple keywords affected | Re-enable ad group |

### What CANNOT Be Applied (v1)
- ❌ Budget changes
- ❌ Bid strategy changes
- ❌ Creating campaigns or ad groups
- ❌ Modifying RSA assets
- ❌ Enabling paused entities
- ❌ Deleting anything
- ❌ Account-level settings

These are explicitly rejected with a clear explanation.

**State after:** Changes are live in Google Ads. Reversal records exist for every action.

---

## Phase 6: Verify

**What happens — automatically after apply:**
1. Each applied action is verified via a GAQL query
2. Negative keywords are confirmed to exist in the target campaign/ad group
3. Paused entities are confirmed to have status PAUSED
4. Results are reported in the apply session output

**Additionally, you can verify manually:**
- Check Google Ads UI → Campaign → Negative Keywords to see your additions
- Check Google Ads UI → Keywords to see paused status
- Run `/google-ads apply log` to see the full audit trail

**What to watch for in the next 7 days:**
- Did waste queries stop appearing in search term reports?
- Did the paused keyword stop accruing spend?
- Are any good search terms being blocked by your negatives?

**State after:** Changes confirmed. Agent is monitoring.

---

## Phase 7: Undo (When Needed)

**Commands:**
- `/google-ads undo [reversal-id]` — undo a single action
- `/google-ads undo-draft [draft-file]` — undo all actions from a draft
- `/google-ads apply log` — see what's been applied and what can be undone

**When to undo:**
- A negative keyword is blocking good traffic (check search term report)
- A paused keyword was actually performing well (rare if analysis was good)
- Client/operator changes strategy direction
- You applied to the wrong account (should be caught by validation, but safety net)

**Undo flow:**
1. Show what will be reversed
2. Warn if the change has been live >7 days
3. Require explicit confirmation
4. Execute the reversal
5. Verify via GAQL
6. Update the reversal registry

**State after:** Change is reversed. Reversal is logged. Draft can be re-applied with modifications.

---

## Session Rhythm

### Daily Operator Check (~10 minutes)
```
/google-ads daily
```
Quick scan: anything bleeding? Any new patterns? Any verification failures?

### Weekly Review Session (~30 minutes)
```
/google-ads draft-summary
```
Review all pending drafts. Apply quick wins. Plan strategic moves.

### Monthly Deep Dive (~2 hours)
```
/google-ads audit
```
Full intent map refresh. New search term patterns. Structure reassessment.

---

## Quick Reference

| What You Want | Command | Time |
|---------------|---------|------|
| Check connection health | `/google-ads connect healthcheck` | 30s |
| Switch accounts | `/google-ads connect select [CID]` | 30s |
| See what's pending | `/google-ads draft-summary` | 2 min |
| See what's been applied | `/google-ads apply log` | 30s |
| See what can be undone | `/google-ads undo --list` | 30s |
| Apply a draft | `/google-ads apply [draft-file]` | 5 min |
| Undo one action | `/google-ads undo [rev-ID]` | 1 min |
| Undo entire draft | `/google-ads undo-draft [draft-file]` | 3 min |
| Full account audit | `/google-ads audit` | 15 min |
| Fast daily check | `/google-ads daily` | 5 min |

---

## Safety Principles (Never Violated)

1. **No change without dry run.** You always see what will happen first.
2. **No change without confirmation.** You must explicitly type "confirm."
3. **Every change is logged.** Audit trail is append-only.
4. **Every change is reversible.** Every action has a stored undo instruction.
5. **Scope is bounded.** Only v1 actions (negatives + pauses) are allowed.
6. **Fail-forward.** One failed action doesn't block the rest.
7. **Verify after apply.** Re-query confirms changes took effect.
