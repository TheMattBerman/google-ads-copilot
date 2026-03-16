# Next Steps — Live Google Ads MCP

## What is ready now
- `pipx` is installed on the machine
- Google Ads Copilot package is in place
- MCP config templates/patch examples are written in `data/`

## What is still missing
- Google Ads developer token
- Google Cloud project ID
- OAuth / ADC credentials JSON (or equivalent ADC setup)
- Optional MCC login customer ID
- Active MCP server entry added to the runtime config

## Fastest path from here
1. Get the Google Ads developer token
2. Get/create the Google Cloud project ID with Google Ads API enabled
3. Obtain OAuth credentials JSON or set up ADC
4. Add the MCP config entry using:
   - `data/google-ads-mcp.config.template.json`
   - or `data/mcporter.google-ads-mcp.patch.json`
5. Test with:
   - `mcporter call google-ads-mcp.list_accessible_customers`
6. Then run first live query:
   - campaigns
   - then search terms

## Environment checklist
- `pipx` ✅
- `gcloud` ❌ not currently installed/found
- ADC credentials ❌ not present
- Google Ads env vars ❌ not present

## Recommendation
If you want the smoothest next move, provide the Google Ads developer token + project ID + credential path, and we can wire the MCP config and test immediately.
