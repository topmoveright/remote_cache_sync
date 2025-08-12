# Interfaces and Usage Patterns

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

## LocalStore<T, Id>

Required methods:
- `query(scope)`, `querySince(scope, since)`: Scope-filtered reads.
- `upsertMany(scope, items)`: Scope-aware upserts. Clearing tombstones on upsert is recommended.
- `deleteMany(scope, ids)`: If `supportsSoftDelete` is true, mark deletions with `deletedAt`; otherwise hard delete.
- Metadata: `getSyncPoint(scope)`, `saveSyncPoint(scope)`, pending `get/enqueue/clear` ops.

Implementations:
- `InMemoryLocalStore<T, Id>`: demo-only, not for production.
- `DriftLocalStore<T, Id>`: persistent store using Drift. Provides `supportsSoftDelete = true` by default.

## RemoteStore<T, Id>

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
  - `synchronize(scope)`: Push pending ops, pull delta, merge via resolver, persist, save sync point.
  - `enqueueCreate/Update/Delete`: Write-through to local and queue pending ops; triggers background sync.

## Model Requirements

- `T extends HasUpdatedAt`. When using soft delete, store a `deletedAt` timestamp in the payload (even if not exposed on `T`).
- `updatedAt` must be UTC (ISO8601 when serialized). Use server time to avoid clock skew.

## Example Wiring

See `example/lib/main.dart` and `example/lib/backend_config.dart` for a minimal example using `DriftLocalStore` and a selectable remote store.
