# Negative Inventory Retrieval

Shared verification path for answering:
- Are there any negatives running anywhere?
- Where do they live?
- What are the actual negative keywords?

## Retrieval ladder

1. **Campaign-level negatives** via `campaign_criterion`
2. **Ad-group-level negatives** via `ad_group_criterion`
3. **Shared sets (minimal discovery)** via `shared_set`
4. **Shared-set type verification** via `shared_set.resource_name`, `shared_set.name`, `shared_set.type`
5. **Campaign/shared negative-list attachments** via `campaign_shared_set` after filtering to verified `NEGATIVE_KEYWORDS` shared sets
6. **Shared negative-list keyword members** via `shared_criterion` after filtering to verified `NEGATIVE_KEYWORDS` shared sets

## Important implementation detail
For shared-set resources, start with minimal field sets first.
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

When typed verification works, only call something a "shared negative list" if `shared_set.type = NEGATIVE_KEYWORDS`.
If typed verification fails, keep the output generic (`shared sets`, `shared-set attachments`, `shared-set keyword members`) and add a diagnostic note that negative-list type could not be verified.

## Diagnostic output shape

```md
## Negative Inventory Diagnostics
- Campaign negatives: <count>
- Ad-group negatives: <count>
- Shared sets discovered: <count>
- Shared negative lists: <count>  # only when type verification succeeds
- Shared negative-list attachments: <count>  # only when type verification succeeds
- Shared negative-list keyword members: <count>  # only when type verification succeeds
- Shared-set type verification: unavailable  # when typed verification fails
- Diagnostic note: <type verification note>
- Verification result: <none found anywhere | negatives are active in the account | shared-set negatives could not be verified>
```

## Script reference

`scripts/negative-inventory.sh <customer-id>` implements this verification path.
