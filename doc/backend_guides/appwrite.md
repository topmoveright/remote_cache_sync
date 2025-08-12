# Appwrite Backend Guide

This guide complements the `AppwriteRemoteStore` adapter. Replace placeholders with your schema names.

## Recommended Schema

- Collection: `<your_collection>` in database `<your_database_id>`
- Fields
  - `<id_field>`: string (unique). Stored as the document id (custom id).
  - `title` or your domain fields.
  - `<updated_at_field>`: string datetime (ISO8601, server-managed if possible).
  - `<deleted_at_field>`: string datetime (nullable) for soft delete. Omit to use hard delete.
  - `<scope_name_field>`: string (e.g., "tenant", "workspace").
  - `<scope_keys_field>`: object/JSON (key-value pairs).

## Indexing

Create indexes on frequently filtered/sorted fields:
- `equal(<scope_name_field>)`
- `greaterThan(<updated_at_field>)` and `orderBy(<updated_at_field>)`
- `equal(<id_field>)` (if not using document id itself)
- If you need to filter by a scope key, consider denormalizing it into a separate field with its own index (e.g., `scope_userId`).

Practical tips:
- Prefer `string` for `<updated_at_field>` storing ISO8601; ensure uniform UTC format for correct lexicographic ordering.
- If you filter by multiple scope keys, denormalize the most selective key(s) into dedicated indexed fields.

## Permissions & Security Checklist

- Restrict read/write to the correct scope:
  - Read rule (template): `(<scope_name_field> = "{runtimeScope}") && user/<relationships>`
  - Write rule (template): `(<scope_name_field> = "{runtimeScope}") && user/<relationships>`
- Prevent cross-scope mutations: validate/override scope fields server-side (functions/hooks) so client cannot set foreign scope values.
- If using soft delete, keep read rules to return soft-deleted records only when syncing, or filter them out in app queries.
- Ensure `updated_at_field` is updated on every write, preferably by server logic.

## Scope Injection on Writes (Adapter)

If the adapter enables `injectScopeOnWrite`, it will merge either custom `scopeFieldsBuilder(scope)` or the default mapping into writes. Ensure your rules or function hooks revalidate the scope against the authenticated context.

## Server Time Function (Recommended)

Clock skew can break delta sync. Provide a server time function returning an ISO8601 UTC string.

### Example (Appwrite Cloud Function, Node.js/TypeScript)

```ts
import type { Payload } from 'node-appwrite';

export default async ({ req, res }: Payload) => {
  // Return ISO-8601 UTC
  return res.send(new Date().toISOString(), 200, {
    'content-type': 'text/plain; charset=utf-8',
    'cache-control': 'no-store',
  });
};
```

- Configure the function id in `AppwriteRemoteConfig.serverTimeFunctionId`.
- The adapter parses the function response body as an ISO string.

## Scope Injection on Writes

If `injectScopeOnWrite` is enabled, the adapter merges one of the following into document data on upsert/delete:
- `scopeFieldsBuilder(scope)` → custom mapping
- default mapping: `{ <scope_name_field>: scope.name, <scope_keys_field>: scope.keys }`

Ensure the server trusts these values or overrides them with its own logic based on the authenticated user.

## Notes

- Filtering by nested keys in `<scope_keys_field>` may be limited. Prefer denormalized fields for search and indexing.
- For high-throughput sync, consider batching via a Cloud Function that accepts arrays and performs multiple mutations server-side.
