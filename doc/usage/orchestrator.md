# Orchestrator: Single-entry Cache-first Querying

This page explains how to use the orchestrator to manage remote data via a single, cache-first API. You do not need to talk to remote backends directly. The orchestrator keeps your local cache synchronized and evaluates your queries consistently offline and online.

- Class: `SimpleSyncOrchestrator<T, Id>` in `lib/sync/simple_sync_orchestrator.dart`
- Interfaces: `SyncOrchestrator<T, Id>` in `lib/sync/sync_orchestrator.dart`
- Query: `QuerySpec`, `FilterOp`, `FilterOperator`, `OrderSpec` in `lib/sync/store_interfaces.dart`

## Why orchestrator-first

- Single entrypoint for reads/writes across offline/online.
- Cache-consistent query evaluation (the same `QuerySpec` logic applies when offline).
- Background synchronization and conflict resolution (LWW by default).

## Quickstart

```dart
final orchestrator = SimpleSyncOrchestrator<Todo, String>(
  local: DriftLocalStore<Todo, String>(/* ... */),
  remote: SupabaseRemoteStore<Todo, String>(/* ... */),
  resolver: const LastWriteWinsResolver<Todo>(),
  idOf: (t) => t.id,
);

const scope = SyncScope('todos', {'userId': 'u1'});

final results = await orchestrator.readWith(
  scope,
  QuerySpec(
    filters: [
      FilterOp(field: 'updatedAt', op: FilterOperator.gte, value: DateTime.utc(2025, 1, 1)),
    ],
    orderBy: [OrderSpec('updatedAt', descending: true)],
    limit: 20,
  ),
  policy: CachePolicy.remoteFirst,
);
```

## API overview

- `read(scope, {policy})`
  - Simple read of the whole scope (no `QuerySpec`).
- `readWith(scope, spec, {policy = remoteFirst, preferRemoteEval = false, fallbackToLocal = true})`
  - Default cache-centric behavior: for online policies, synchronize first, then evaluate `spec` on the local cache.
  - `preferRemoteEval = true`: try to evaluate the `spec` remotely and upsert the result into local. If unsupported filters/operators raise `ArgumentError`, it will fall back to local if `fallbackToLocal` is `true`.
- `synchronize(scope)`
  - Push pending ops, fetch delta, resolve conflicts, persist merged state, and save sync point.
- `enqueueCreate/Update/Delete`
  - Write-through to local and queue pending ops. Triggers background sync.

## Cache policies

- `offlineOnly`
  - Never touches remote; evaluates locally with `queryWith`.
- `localFirst`
  - Returns local immediately; performs `synchronize(scope)` in the background.
- `remoteFirst`
  - Performs `synchronize(scope)` and returns `local.queryWith(scope, spec)`.
- `onlineOnly`
  - Behaves like `remoteFirst` but you can signal intent to always go online.

## Patterns

- Prefer `remoteFirst` for user-facing lists to keep cache fresh.
- Use `localFirst` for fast UX when immediate response matters; rely on background refresh.
- Turn on `preferRemoteEval` if your backend supports efficient server-side filtering for your `QuerySpec`. Keep `fallbackToLocal = true` to avoid errors.

## Notes

- Remote backends (Appwrite/PocketBase/Supabase) may not support all `QuerySpec` operators or arbitrary fields. When unsupported, the orchestrator still delivers correct results by evaluating on the local cache after synchronization.
- Ensure `updatedAt` is stored as UTC on your model. Conflict resolution uses `updatedAt` in the default LWW resolver.
