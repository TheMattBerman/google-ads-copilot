---
name: google-ads-connect
description: >
  Connected-mode onboarding, health check, and customer selection for Google Ads Copilot.
  Verifies MCP server availability, discovers accessible accounts, helps the operator select
  the right customer ID, and writes the selection to workspace memory. Run this before any
  other skill when using connected mode for the first time — or whenever switching accounts.
argument-hint: setup | healthcheck | select [customer_id]
---

# Google Ads Connect

This skill handles the plumbing so the other skills can focus on strategy.

Read workspace if available:
- `workspace/ads/account.md`

---

## What This Skill Does

1. **Setup check** — verifies the MCP server is configured and responsive
2. **Customer discovery** — lists all accessible accounts with names and IDs
3. **Customer selection** — helps the operator choose the right account
4. **Account fingerprint** — pulls basic account metadata and writes to workspace
5. **Health check** — validates that data is flowing and queries return results

---

## Commands

### `/google-ads connect setup`
Full onboarding flow: check MCP → discover accounts → select account → fingerprint.
Use this the first time you connect.

### `/google-ads connect healthcheck`
Quick validation: MCP alive? Account selected? Data flowing?
Use this before an audit or when something feels broken.

### `/google-ads connect select [customer_id]`
Switch to a different account. Updates workspace memory.

---

## Step 1: Verify MCP Server

**Test:** Call `list_accessible_customers` via the google-ads-mcp MCP server.

**If it succeeds:**
```
✅ MCP server is live
   Accessible accounts: N
```

**If it fails, diagnose:**

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| MCP tool not found | Server not configured in MCP host | Add config — see `data/mcp-config.md` |
| "No credentials found" | `GOOGLE_APPLICATION_CREDENTIALS` missing or wrong path | Check the env var points to a valid JSON file |
| "Developer token not approved" | Token missing or pending | Check `GOOGLE_ADS_DEVELOPER_TOKEN` env var |
| "Project not found" | Wrong project ID | **Use `GOOGLE_CLOUD_PROJECT`** (not `GOOGLE_PROJECT_ID`) |
| Connection timeout | pipx or network issue | Verify `pipx` is installed, internet is up |
| "Manager account required" | MCC access needed | Add `GOOGLE_ADS_LOGIN_CUSTOMER_ID` |

### Environment Variable Reference (Canonical)

| Variable | Required | Purpose |
|----------|----------|---------|
| `GOOGLE_APPLICATION_CREDENTIALS` | Yes | Path to OAuth/ADC credentials JSON |
| `GOOGLE_CLOUD_PROJECT` | Yes | Google Cloud project ID (⚠️ NOT `GOOGLE_PROJECT_ID`) |
| `GOOGLE_ADS_DEVELOPER_TOKEN` | Yes | Google Ads API developer token |
| `GOOGLE_ADS_LOGIN_CUSTOMER_ID` | If MCC | Manager account customer ID (no dashes) |

⚠️ **Common gotcha:** The MCP server uses `GOOGLE_CLOUD_PROJECT`, not `GOOGLE_PROJECT_ID`. Earlier docs may reference the wrong name. `GOOGLE_CLOUD_PROJECT` is correct.

---

## Step 2: Customer Discovery

Call `list_accessible_customers`. This returns customer IDs and descriptive names.

**Present as a selection table:**

```markdown
## Accessible Google Ads Accounts

| # | Customer ID | Descriptive Name | Notes |
|---|-------------|-------------------|-------|
| 1 | 1234567890  | Acme Equipment Co. | |
| 2 | 9876543210  | Metro Recycling LLC | |
| 3 | 1234567890  | [Manager Account] | MCC — not a direct account |

Which account should we work with?
```

### Account Selection Rules

1. **If only one account:** Select it automatically, confirm with operator.
2. **If multiple accounts:** Present the table and ask.
3. **If a customer ID was provided in the command:** Use it, but verify it's in the accessible list.
4. **If `workspace/ads/account.md` already has a customer ID:** Mention it — "Currently selected: [Name] ([ID]). Switch?"
5. **Manager (MCC) accounts:** Flag them — these are container accounts, not advertisable accounts. Don't select them for analysis unless the operator explicitly asks.

### Name Verification

**Critical safety check:** If the operator asked about a specific business (e.g., "audit Acme Equipment"), verify the descriptive name matches:

```
✅ Customer "Acme Equipment Co." (1234567890) matches your request.
```

or

```
⚠️ Warning: You asked about "Acme Equipment" but the closest match is 
   "Metro Recycling LLC" (9876543210). Please confirm this is the right account,
   or provide the correct customer ID.
```

This prevents auditing the wrong account — a real problem we encountered in live testing.

---

## Step 3: Account Fingerprint

Once a customer is selected, pull basic metadata:

**Account overview query:**
```
Resource: customer
Fields: customer.id, customer.descriptive_name, customer.currency_code, customer.time_zone, customer.auto_tagging_enabled, customer.status
```

**Campaign summary query:**
```
Resource: campaign
Fields: campaign.name, campaign.status, campaign.advertising_channel_type
Conditions: campaign.status != 'REMOVED'
```

**Present the fingerprint:**

```markdown
## Account Fingerprint

| Field | Value |
|-------|-------|
| Customer ID | 1234567890 |
| Name | Acme Equipment Co. |
| Currency | USD |
| Timezone | America/New_York |
| Auto-tagging | Enabled ✅ |
| Account status | ENABLED |

### Campaigns
| Campaign | Status | Type |
|----------|--------|------|
| Search - Core Services | ENABLED | SEARCH |
| Brand - Acme Equipment | ENABLED | SEARCH |
| PMax - Lead Gen | PAUSED | PERFORMANCE_MAX |

**Active campaigns:** 2 search, 0 PMax
**Total campaigns:** 3 (1 paused)
```

### Account Status Interpretation

| Status | Meaning | Action |
|--------|---------|--------|
| ENABLED | Active, can serve ads | Proceed with analysis |
| SUSPENDED | Billing/policy issue, not serving | Flag immediately — this is P0 |
| CLOSED | Permanently closed | Cannot analyze, need different account |
| CANCELLED | Cancelled by user | Cannot serve, may be recoverable |

**If suspended:** Stop and surface this as the #1 finding. No amount of optimization matters if ads can't serve. Direct the operator to check Billing and Policy Center in the Google Ads UI.

---

## Step 4: Write to Workspace

Update `workspace/ads/account.md` with the fingerprint:

```markdown
## Last Updated
2026-03-14 by /google-ads connect

# Account Profile

## Identity
- Customer ID: 1234567890
- Descriptive Name: Acme Equipment Co.
- Currency: USD
- Timezone: America/New_York
- Account Status: ENABLED
- Auto-tagging: Enabled

## Connection
- Mode: Connected (google-ads-mcp)
- Last verified: 2026-03-14
- Accessible accounts: 3 (selected this one)

## Business
- Business model: [to be filled by audit]
- Industry: [to be filled by audit]
- Primary offer: [to be filled by audit]
- Geo scope: [to be filled by audit]

## Campaign Summary
- Search campaigns: 2 active
- PMax campaigns: 0 active (1 paused)
- Total campaigns: 3

## Notes
- [Any observations from the fingerprint]
```

---

## Step 5: Health Check (standalone or end of setup)

Run a quick data flow validation:

1. ✅ MCP server responds to `list_accessible_customers`
2. ✅ Selected customer ID is accessible
3. ✅ Account metadata query returns data
4. ✅ Campaign query returns results
5. ✅ At least one campaign is ENABLED (or note if all paused/suspended)
6. ✅ A date-ranged query returns data (test: campaign metrics LAST_7_DAYS)

**If step 6 returns zero rows:** The account may be dormant. This is NOT a failure — it's useful information. Note: "Account is dormant — no activity in the last 7 days. Date range fallback will be needed for analysis."

**Output:**
```
## Health Check Results

| Check | Status | Notes |
|-------|--------|-------|
| MCP server | ✅ | Responding |
| Account access | ✅ | CID 1234567890 accessible |
| Account metadata | ✅ | Acme Equipment Co. |
| Campaign data | ✅ | 3 campaigns found |
| Active campaigns | ✅ | 2 ENABLED |
| Recent data (7d) | ⚠️ | No activity — account may be dormant |

**Ready for analysis:** Yes (use date range fallback for dormant periods)
```

---

## Output Shape

1. MCP server status
2. Accessible accounts table
3. Selected account fingerprint
4. Account status and health flags
5. Workspace memory update confirmation
6. Readiness assessment for next steps

## Rules
- **Always verify the account name matches the operator's intent** — wrong-account audits waste everyone's time
- **Always note account status (suspended/dormant/active) prominently** — it gates everything else
- **Always write the selection to workspace** — other skills depend on `account.md`
- **Use `GOOGLE_CLOUD_PROJECT`** in all docs and examples — not `GOOGLE_PROJECT_ID`
- **Flag MCC/manager accounts** — they can't be analyzed directly
