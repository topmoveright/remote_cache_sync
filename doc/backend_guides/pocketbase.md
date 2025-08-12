# PocketBase Backend Guide

This guide complements the `PocketBaseRemoteStore` adapter. Replace placeholders with your schema names.

## Recommended Schema

- Collection: `<your_collection>`
- Fields
  - `<id_field>`: string (your domain id). Keep distinct from PocketBase internal `id`.
  - Domain fields (e.g., `title`, etc.).
  - `<updated_at_field>`: string datetime (ISO8601, UTC). Update on every write.
  - `<deleted_at_field>`: string datetime (nullable) for soft delete. Omit to use hard delete.
  - `<scope_name_field>`: string (e.g., "tenant", "workspace").
  - `<scope_keys_field>`: JSON/object (key-value pairs).

## Indexing

Create indexes on:
- `=<scope_name_field>`
- `ORDER BY <updated_at_field>`
- `=<id_field>`
- If you need to filter by scope keys, denormalize important keys to top-level fields (e.g., `scope_userId`) and index them.

## Collection Rules (Security)

- Read rule: only allow records for the caller scope. Example pseudo-rule:
  - `<scope_name_field> = @request.query.scopeName` (or resolve from auth claims) AND user authorization.
- Write rule: ensure incoming writes cannot cross scopes. Either validate in rules or via server hooks to override scope fields from auth.
- Exclude soft-deleted records from normal app queries (or filter them out in the client). Keep them visible for sync fetches if desired.

> Note: Implementing scope-aware rules depends on how you model auth in PocketBase. Consider creating a relation to the `users` collection and referencing `@request.auth.id` or `@collection.users.id` in rules.

## Server Time Endpoint (Recommended)

To avoid clock skew, expose a simple HTTP endpoint that returns ISO8601 UTC time. You can host it anywhere (e.g., Cloudflare Workers, Vercel, your API).

### Example (Cloudflare Workers / JavaScript)

```js
export default {
  async fetch(request) {
    return new Response(new Date().toISOString(), {
      status: 200,
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'cache-control': 'no-store',
      },
    });
  },
};
```

- Configure the URL in `PocketBaseRemoteConfig.serverTimeEndpoint`.
- The adapter parses the response body as an ISO8601 UTC string.

## Scope Injection on Writes

If `injectScopeOnWrite` is enabled, `batchUpsert` and `batchDelete` merge one of:
- `scopeFieldsBuilder(scope)` → custom mapping
- default mapping: `{ <scope_name_field>: scope.name, <scope_keys_field>: scope.keys }`

Ensure your rules/hooks either trust or override these values based on the authenticated user to prevent cross-scope data access.

## Notes

- The adapter queries records by your domain id field (`<id_field>`), not PocketBase's internal `id`.
- Large sync windows: use pagination (`getList(page, perPage)`) and index `<updated_at_field>`.
- Soft delete keeps `deleted` ids discoverable during delta sync; hard delete physically removes records.
