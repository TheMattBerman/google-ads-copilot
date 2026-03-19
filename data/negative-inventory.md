# Negative Inventory Retrieval

Shared verification path for answering:
- Are there any negatives running anywhere?
- Where do they live?
- What are the actual negative keywords?

## Retrieval ladder

1. **Campaign-level negatives** via `campaign_criterion`
2. **Ad-group-level negatives** via `ad_group_criterion`
3. **Shared negative lists** via `shared_set` (minimal fields first)
4. **Campaign/shared-list attachments** via `campaign_shared_set`
5. **Shared-list keyword members** via `shared_criterion`

## Important implementation detail
For shared-list resources, start with minimal field sets first.
Do not assume `type`, `status`, or enum filters will work on the first query path through MCP.

Prefer these minimal queries first:

```sql
SELECT
  shared_set.id,
  shared_set.name
FROM shared_set
LIMIT 100
```

```sql
SELECT
  campaign.name,
  campaign_shared_set.shared_set
FROM campaign_shared_set
LIMIT 100
```

```sql
SELECT
  shared_criterion.shared_set,
  shared_criterion.keyword.text
FROM shared_criterion
LIMIT 200
```

Once those work, you can enrich the query shape if needed.

## Diagnostic output shape

```md
## Negative Inventory Diagnostics
- Campaign negatives: <count>
- Ad-group negatives: <count>
- Shared negative lists: <count>
- Shared-list attachments: <count>
- Shared-list keyword members: <count>
- Verification result: <none found anywhere | negatives are active in the account>
```

## Script reference

`scripts/negative-inventory.sh <customer-id>` implements this verification path.
