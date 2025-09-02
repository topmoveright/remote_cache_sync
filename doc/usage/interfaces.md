# Interfaces and Usage Patterns

> Start with the orchestrator-first guide for primary usage: see `usage/orchestrator.md`.
> This page summarizes interfaces for reference and advanced customization.

This page summarizes the core sync interfaces and common usage patterns in this plugin.

- Local store: `LocalStore<T, Id>` in `lib/sync/store_interfaces.dart`
- Remote store: `RemoteStore<T, Id>` in `lib/sync/store_interfaces.dart`
- Orchestrator: `SimpleSyncOrchestrator<T, Id>` in `lib/sync/simple_sync_orchestrator.dart`
- Shared types: `SyncScope`, `Delta<T, Id>`, `HasUpdatedAt`, `HasId<Id>`, `HasSoftDelete` in `lib/sync/sync_types.dart`

## Key Concepts

- **Scope-aware sync**: All read/write operations flow through `SyncScope`. Use a stable `scope.name` (e.g., `"records"`) and scope keys (e.g., `{ "userId": "u1" }`).
- **Delta model**: Remote returns `Delta<T, Id>` with `upserts`, `deletes`, and a trusted `serverTimestamp`.
- **Soft delete**: Prefer tombstones via `deletedAt` to preserve last-change time and support reliable delta sync.
- **Last-write-wins (LWW)**: Provided by `LastWriteWinsResolver<T>` based on `updatedAt`.

## LocalStore<T, Id> (reference)

Required methods:
- `query(scope)`, `querySince(scope, since)`: Scope-filtered reads.
- `upsertMany(scope, items)`: Scope-aware upserts. Clearing tombstones on upsert is recommended.
- `deleteMany(scope, ids)`: If `supportsSoftDelete` is true, mark deletions with `deletedAt` and keep rows.
- Metadata: `getSyncPoint(scope)`, `saveSyncPoint(scope)`, pending `get/enqueue/clear` ops.

### Cache management (approximate) 

- `approxCacheSizeBytes({ SyncScope? scope })` → Future<int>
  - Returns an approximate cache size in bytes for the whole store or a specific scope.
  - Drift store sums UTF-8 byte lengths of relevant string payloads across `items`, `pendingOps`, and `syncPoints`.
  - In-memory store uses a heuristic based on counts and fixed weights per entry type.
- `setCacheSizeLimitBytes(int? bytes)` / `getCacheSizeLimitBytes()`
  - Sets/gets the maximum cache size in bytes. `null` disables enforcement.
  - Enforcement runs after write paths (e.g., `upsertMany`, `deleteMany`, and enqueue pending ops for in-memory) and removes data until the size is under the limit.
  - Eviction policy: remove oldest tombstones first, then oldest active items by `updatedAt` (LRU-like by last update time).
- `clearCache({ SyncScope? scope })`
  - Clears cached data for the provided scope or for the entire store when omitted.
  - Implementations also clear sync points and pending operations for cleared scopes.

Example:

```dart
final scope = SyncScope('records', {'userId': 'u1'});
final sizeBefore = await local.approxCacheSizeBytes(scope: scope);
await local.setCacheSizeLimitBytes(200 * 1024); // ~200KB
// Subsequent upserts/deletes may trigger eviction to respect the limit.
await local.clearCache(scope: scope); // Clear only this scope
await local.clearCache(); // Clear all scopes
```

Implementations:
- `InMemoryLocalStore<T, Id>`: demo-only, not for production.
- `DriftLocalStore<T, Id>`: persistent store using Drift. Provides `supportsSoftDelete = true` by default.

## RemoteStore<T, Id> (reference)

Required methods:
- `fetchSince(scope, since)`: Return upserts and deletions since server time `since` (or all if null). Must include a `serverTimestamp` (from a trusted server clock).
- `batchUpsert(items)`, `batchDelete(ids)`, `getServerTime()`.

Implementations:
- `InMemoryRemoteStore<T, Id>`: demo-only; distributes upserts for existing scopes. Not scope-aware by input.
- `AppwriteRemoteStore<T, Id>`
- `PocketBaseRemoteStore<T, Id>`
- `SupabaseRemoteStore<T, Id>` (if enabled)

## Orchestrator

- `SimpleSyncOrchestrator<T, Id>(local, remote, resolver, idOf)`
  - Strongly typed `idOf` avoids dynamic casts.
  - `read(scope, policy)`: `offlineOnly`, `localFirst`, `remoteFirst`, `onlineOnly`.
  - `readWith(scope, spec, { policy = remoteFirst, preferRemoteEval = false, fallbackToLocal = true })`
    - Cache-centric behavior: for online policies it synchronizes, then evaluates the query on the local cache.
    - If `preferRemoteEval` is true, it attempts remote-side evaluation first and upserts results into local; falls back to local when unsupported if `fallbackToLocal` is true.

```dart
final results = await orchestrator.readWith(
  const SyncScope('records', {'userId': 'u1'}),
  QuerySpec(
    filters: [FilterOp(field: 'updatedAt', op: FilterOperator.gte, value: DateTime.utc(2025, 1, 1))],
    orderBy: [OrderSpec('updatedAt', descending: true)],
    limit: 20,
  ),
  policy: CachePolicy.remoteFirst,
);
```
  - `synchronize(scope)`: Push pending ops, pull delta, merge via resolver, persist, save sync point.
  - `enqueueCreate/Update/Delete`: Write-through to local and queue pending ops; triggers background sync.

## Model Requirements

- `T extends HasUpdatedAt`. When using soft delete, store a `deletedAt` timestamp in the payload (even if not exposed on `T`).
- `updatedAt` must be UTC (ISO8601 when serialized). Use server time to avoid clock skew.

## Example Wiring

See `example/lib/main.dart` and `example/lib/backend_config.dart` for a minimal example using `DriftLocalStore` and a selectable remote store.
