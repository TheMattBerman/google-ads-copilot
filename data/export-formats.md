# Export Formats — Google Ads Copilot (Export Mode)

When the MCP server is not available (no API access, one-time audit, client handoff), the copilot works with manually exported data.

## How to provide data

Any of these work:
1. **CSV export** from Google Ads UI → paste or attach
2. **Google Ads Editor export** → paste relevant sections
3. **Screenshots** → the copilot can read them but structured data is better
4. **Copy-paste from UI** → tables, lists, whatever you can grab

## Recommended exports by skill

### Daily Operator
- Campaign overview: last 7 days (columns: Campaign, Status, Impressions, Clicks, Cost, Conversions, CPA)
- Any recent change history

### Search Terms
- Search Terms report: last 30 days
- Columns needed: Search term, Campaign, Ad group, Impressions, Clicks, Cost, Conversions, Conv. value
- Sort by Cost descending
- Include at least top 200-500 terms

### Intent Map
- Same as Search Terms, but include all terms (not just top spenders)
- Campaign names help identify which bucket queries landed in

### Negatives
- Current negative keyword list (campaign-level and shared lists)
- Search Terms report (for identifying new negatives)

### Tracking
- Conversion actions list (name, type, counting, include in conversions)
- Google Tag Assistant screenshot or notes
- GA4 conversion import settings if applicable

### Structure
- Campaign list with types, budgets, bid strategies
- Ad group list with campaign parent
- Keywords per ad group (at least the main ones)

### RSAs
- RSA asset report (headlines, descriptions, performance labels)
- Or just the RSA preview from the ads tab

### Budget
- Campaign budget report: Budget, Spend, Conversions, Search IS%, Budget Lost IS%
- Last 30 days preferred

### PMax
- PMax campaign metrics
- Asset group list with performance
- Any listing group or audience signal notes

## CSV format tips

Google Ads UI exports CSVs with headers that the copilot can parse. The most reliable approach:
1. Go to the relevant report in Google Ads
2. Add the columns listed above
3. Download → CSV
4. Paste the content or reference the file path

## What if data is partial?

The copilot will work with whatever you give it. It will note confidence limitations based on data gaps. Partial data is better than no data — the system will tell you what it can and cannot conclude.
