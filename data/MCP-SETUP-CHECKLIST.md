# Google Ads MCP Setup Checklist

## Machine-side prerequisites
- [ ] `pipx` installed
- [ ] Google Cloud CLI (`gcloud`) installed or alternative ADC method available
- [ ] MCP config entry added for `google-ads-mcp`

## Google-side prerequisites
- [ ] Google Ads developer token
- [ ] Google Cloud project with Google Ads API enabled
- [ ] OAuth credentials / ADC configured
- [ ] Optional MCC login customer ID if needed

## First live test
1. Start MCP host with `google-ads-mcp` configured
2. Call `list_accessible_customers`
3. Choose target customer ID
4. Run a simple campaign query
5. Run a search terms query

## Success criteria
- Account list returns
- GAQL queries return live data
- `/google-ads daily` and `/google-ads search-terms` can operate in connected mode
