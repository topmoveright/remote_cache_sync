# Remote Cache Sync for Flutter

Remote Cache Sync lets you manage remote data via a single cache-first query API. You do not need to call remote backends directly; the orchestrator keeps your local cache synchronized and evaluates your queries consistently offline and online.

## Orchestrator-first Quickstart

```dart
final orchestrator = SimpleSyncOrchestrator<Todo, String>(
  local: DriftLocalStore<Todo, String>(/* ... */),
  remote: SupabaseRemoteStore<Todo, String>(/* ... */),
  resolver: const LastWriteWinsResolver<Todo>(),
  idOf: (t) => t.id,
);

final scope = const SyncScope('todos', {'userId': 'u1'});

final items = await orchestrator.readWith(
  scope,
  QuerySpec(
    filters: [
      FilterOp(field: 'updatedAt', op: FilterOperator.gte, value: DateTime.utc(2025, 1, 1)),
    ],
    orderBy: [OrderSpec('updatedAt', descending: true)],
    limit: 20,
  ),
  policy: CachePolicy.remoteFirst,       // sync then evaluate on local cache
  preferRemoteEval: false,               // set true to try remote-side filtering first
  fallbackToLocal: true,                 // fall back when remote can't support a filter
);
```

Key benefits:
- Orchestrator-driven single entrypoint for reads/writes
- Cache-consistent query evaluation with `QuerySpec`
- Seamless offline/online via `CachePolicy`
- Pluggable remotes (Appwrite, PocketBase, Supabase) and local stores (Drift)

## Documentation
- Start here: Orchestrator usage [docs-orch]
- Interfaces overview: [docs-usage]
- QuerySpec: [docs-query-spec]
- Backend Guides: [Supabase] · [Appwrite] · [PocketBase]
- Testing: [docs-testing]

## Issues and feedback
- File issues/feature requests: [Issues](https://github.com/topmoveright/remote_cache_sync/issues)

## Contributing
- See repository guidelines: [Contributing](https://github.com/topmoveright/remote_cache_sync)

[docs-site]: https://topmoveright.github.io/remote_cache_sync/
[docs-home]: https://topmoveright.github.io/remote_cache_sync/#/
[docs-usage]: https://topmoveright.github.io/remote_cache_sync/#/usage/interfaces
[docs-orch]: https://topmoveright.github.io/remote_cache_sync/#/usage/orchestrator
[docs-query-spec]: https://topmoveright.github.io/remote_cache_sync/#/usage/query_spec
[docs-testing]: https://topmoveright.github.io/remote_cache_sync/#/testing
[Supabase]: https://topmoveright.github.io/remote_cache_sync/#/backend_guides/supabase
[Appwrite]: https://topmoveright.github.io/remote_cache_sync/#/backend_guides/appwrite
[PocketBase]: https://topmoveright.github.io/remote_cache_sync/#/backend_guides/pocketbase
