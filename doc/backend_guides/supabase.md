# Supabase Backend Guide

This guide complements the `SupabaseRemoteStore` adapter. Replace placeholders with your schema names.

## Recommended Schema

- Table: `<your_table>` in schema `public` (or your schema)
- Columns
  - `<id_column>`: text/uuid (primary key). If you manage ids client-side, allow insert with explicit id.
  - Domain columns (e.g., `title` etc.).
  - `<updated_at_column>`: timestamptz, default `now()` and updated via trigger.
  - `<deleted_at_column>`: timestamptz NULL for soft delete (omit to use hard delete).
  - `<scope_name_column>`: text (e.g., `tenant`, `workspace`).
  - `<scope_keys_column>`: jsonb (key-value pairs).

## Indexing

Create indexes to support delta and lookups:
- `btree(<scope_name_column>)`
- `btree(<updated_at_column>)`
- `btree(<id_column>)` if not primary or if using a separate unique key
- If querying by specific scope keys, also create jsonb GIN/BTREE indexes on extracted fields or denormalize to columns.

Example SQL:

```sql
-- Replace placeholders accordingly
create index if not exists idx_<table>_scope_name on <your_table>(<scope_name_column>);
create index if not exists idx_<table>_updated_at on <your_table>(<updated_at_column> desc);
create index if not exists idx_<table>_id on <your_table>(<id_column>);
```

## Row Level Security (RLS) Checklist

Enable RLS and restrict access to the proper scope.

```sql
alter table <your_table> enable row level security;

-- Example: allow read within same scope name (customize according to your auth)
create policy "read_same_scope"
  on <your_table>
  for select
  using (
    <scope_name_column> = current_setting('request.jwt.claims', true)::jsonb->>'scope'
  );

-- Example: allow write within same scope
create policy "write_same_scope"
  on <your_table>
  for all
  using (
    <scope_name_column> = current_setting('request.jwt.claims', true)::jsonb->>'scope'
  )
  with check (
    <scope_name_column> = current_setting('request.jwt.claims', true)::jsonb->>'scope'
  );
```

Notes:
- Adapt the claim key (`scope`) to match your JWT. Alternatively, use relationships (e.g., `user_id = auth.uid()`).
- Prevent cross-scope mutations by validating `scope` in `WITH CHECK`.

## Keep `<updated_at_column>` Fresh

Use trigger to auto-update on every mutation.

```sql
create or replace function set_updated_at()
returns trigger as $$
begin
  new.<updated_at_column> = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_set_updated_at on <your_table>;
create trigger trg_set_updated_at
before update on <your_table>
for each row execute function set_updated_at();
```

## Server Time (Edge Function) — Recommended

To avoid client clock skew, expose an Edge Function returning ISO8601 UTC.

Example (Deno/TypeScript):

```ts
// supabase/functions/server-time/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

serve(async (_req) => {
  return new Response(new Date().toISOString(), {
    status: 200,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  });
});
```

- Deploy with `supabase functions deploy server-time` and call via `https://<project-ref>.functions.supabase.co/server-time`.
- Configure your adapter to use this endpoint (if applicable) or map via your existing `getServerTime()` implementation.

## Scope Injection on Writes

If the adapter config enables scope injection, upsert/delete will merge:
- custom `scopeFieldsBuilder(scope)` result, or
- default `{ <scope_name_column>: scope.name, <scope_keys_column>: scope.keys }`

Ensure RLS or database-side logic validates/overrides these values based on the authenticated user.

### Optional Per-Item/Per-Id Scope Callbacks

`SupabaseRemoteConfig` exposes optional callbacks to control scope on a per-record basis when `injectScopeOnWrite` is enabled:

- `scopeForUpsert: (item) => SyncScope?`
- `scopeForDelete: (id) => SyncScope?`

Behavior:
- If the callback returns a non-null scope, that scope is injected (upsert) or used to filter the delete.
- Otherwise, the adapter falls back to `defaultScope` when present.
- If both are null, no scope columns are written/filtered by the adapter (rely entirely on RLS/auth).

This enables multi-tenant writes in a single batch by grouping deletes/updates per scope and applying appropriate filters.

## Query Patterns (Delta)

- Fetch since: `where <scope_name_column> = :scopeName and <updated_at_column> > :since order by <updated_at_column> asc limit :limit`.
- Soft delete: return rows with non-null `<deleted_at_column>` as deletes list.

### Ordering and Pagination

- Always order by `<updated_at_column>` ascending for deterministic pagination.
- Use a stable secondary order (e.g., `<id_column>` asc) when timestamps can collide:

```sql
select * from <your_table>
where <scope_name_column> = :scopeName
  and <updated_at_column> > :since
order by <updated_at_column> asc, <id_column> asc
limit :limit;
```

- For cursor-based pagination in PostgREST, prefer keyset pagination using both `<updated_at_column>` and `<id_column>`.

### Strict boundary (> since)

- The adapter and tests assume a strict `>` boundary for `since`. Rows with `updated_at == since` are excluded. Ensure backend queries mirror this to avoid duplicates.

## Server Time Configuration

- Configure `SupabaseRemoteConfig.serverTimeRpcName` (Edge Function or RPC) to avoid client clock skew.
- `getServerTime()` will call the RPC and coerce the response to UTC. If unset, client time is used (not recommended for multi-device sync).

## Notes

- For heavy sync, consider batching on the server (RPC or Edge Function) to reduce round trips.
- If using UUID for `<id_column>`, either generate on client or database; keep it stable to avoid duplicates.
 - Tests under `test/supabase_remote_store_test.dart` validate defensive parsing, scope filtering, strict-since boundary, and multi-page aggregation without relying on network calls.
