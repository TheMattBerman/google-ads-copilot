# MCP Server Configuration — Google Ads Copilot

## Overview

Google Ads Copilot uses the **official `googleads/google-ads-mcp`** server for live account data. This is Google's own MCP implementation — read-only, maintained by the Google Ads team, and built on the Google Ads API v21.

**Repo:** https://github.com/googleads/google-ads-mcp
**Docs:** https://developers.google.com/google-ads/api/docs/developer-toolkit/mcp-server

## What it exposes

Two tools:

| Tool | Purpose |
|------|---------|
| `search` | Execute GAQL (Google Ads Query Language) queries against any accessible account |
| `list_accessible_customers` | List customer IDs the authenticated user can access |

That's it. Two tools, but `search` with GAQL covers nearly everything in the Google Ads data model.

## Setup Steps

### 1. Get a Developer Token
- Go to https://developers.google.com/google-ads/api/docs/get-started/dev-token
- Basic access is sufficient for read-only operations
- Record `YOUR_DEVELOPER_TOKEN`

### 2. Enable the Google Ads API
- Go to https://console.cloud.google.com/apis/library/googleads.googleapis.com
- Enable it in your Google Cloud project

### 3. Configure OAuth Credentials

**Option A: Desktop OAuth (recommended for personal/agency use)**
```bash
# Download your OAuth client JSON first, then:
gcloud auth application-default login \
  --scopes https://www.googleapis.com/auth/adwords,https://www.googleapis.com/auth/cloud-platform \
  --client-id-file=YOUR_CLIENT_JSON_FILE
```

**Option B: Service Account (for automated/server use)**
```bash
gcloud auth application-default login \
  --impersonate-service-account=SERVICE_ACCOUNT_EMAIL \
  --scopes=https://www.googleapis.com/auth/adwords,https://www.googleapis.com/auth/cloud-platform
```

Save the credentials path printed after auth completes.

### 4. Install pipx
```bash
# If not already installed
pip install pipx
pipx ensurepath
```

### 5. Configure MCP Server

Add to your MCP host configuration (e.g., `~/.gemini/settings.json`, Claude MCP config, or OpenClaw MCP config):

```json
{
  "mcpServers": {
    "google-ads-mcp": {
      "command": "pipx",
      "args": [
        "run",
        "--spec",
        "git+https://github.com/googleads/google-ads-mcp.git",
        "google-ads-mcp"
      ],
      "env": {
        "GOOGLE_APPLICATION_CREDENTIALS": "/path/to/credentials.json",
        "GOOGLE_CLOUD_PROJECT": "your-project-id",
        "GOOGLE_ADS_DEVELOPER_TOKEN": "your-developer-token"
      }
    }
  }
}
```

**If using a manager account** (common for agencies), add:
```json
"GOOGLE_ADS_LOGIN_CUSTOMER_ID": "your-manager-customer-id"
```

### 6. Verify
Launch your MCP host and test:
- "What customers do I have access to?" → should list account names and IDs
- "How many active campaigns does customer 1234567890 have?" → should return campaign data

## OpenClaw Integration

For OpenClaw, the MCP server can be configured via `mcporter` or the OpenClaw MCP config. The copilot skills will detect whether the MCP server is available and fall back to export mode if not.

```bash
# Test MCP availability
mcporter call google-ads-mcp list_accessible_customers '{}'
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "No credentials found" | Check `GOOGLE_APPLICATION_CREDENTIALS` path is correct |
| "Developer token not approved" | Basic access should work; check token status in API Center |
| "Customer not accessible" | Verify the authenticated user has access to the account |
| "Manager account required" | Add `GOOGLE_ADS_LOGIN_CUSTOMER_ID` for MCC accounts |
| "pipx not found" | Run `pip install pipx && pipx ensurepath` |

## Security Notes

- The MCP server is **read-only by design** — it cannot modify campaigns, bids, budgets, or any account settings
- Credentials stay local — the server runs on your machine
- No data is sent to third parties (beyond the Google Ads API itself)
- The developer token identifies your app but does not grant access — OAuth handles auth
