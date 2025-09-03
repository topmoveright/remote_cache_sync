# Remote Cache Sync for Flutter

Remote Cache Sync lets you manage remote data via a single cache-first query API. You don't call remote SDKs directly; the orchestrator keeps your local cache synchronized and evaluates your queries consistently offline and online.

## Overview

- Single entrypoint: orchestrator handles reads/writes, sync, conflicts
- Cache-consistent queries using `QuerySpec`
- Policies: `remoteFirst`, `localFirst`, `offlineOnly`, `onlineOnly`
- Adapters included: Appwrite, PocketBase, Supabase; Local store: Drift

## Quick Setup (Supabase)

```yaml
dependencies:
  remote_cache_sync:
  supabase_flutter:
```

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';

await Supabase.initialize(url: 'https://YOUR_PROJECT.supabase.co', anonKey: 'YOUR_ANON_OR_SERVICE_ROLE_KEY');
final client = Supabase.instance.client;

final remote = SupabaseRemoteStore<Todo, String>(
  config: SupabaseRemoteConfig<Todo, String>(
    client: client,
    table: 'todos',
    idColumn: 'id',
    updatedAtColumn: 'updated_at',
    deletedAtColumn: 'deleted_at',
    scopeNameColumn: 'scope_name',
    scopeKeysColumn: 'scope_keys',
    idOf: (t) => t.id,
    idToString: (s) => s,
    idFromString: (s) => s,
    toJson: (t) => {/* map Todo -> row */},
    fromJson: (m) => /* map row -> Todo */,
    serverTimeRpcName: 'server_time_utc',
  ),
);
```

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
- [README.md][README]
- Backend Guides
  - [Supabase][Supabase]
  - [Appwrite][Appwrite]
  - [PocketBase][PocketBase]
- Orchestrator
  - [Orchestrator][Orchestrator]
- Usage
  - [Interfaces][Interfaces]
  - [QuerySpec][QuerySpec]
- [Testing][Testing]

## Issues and feedback
- File issues/feature requests: [Issues](https://github.com/topmoveright/remote_cache_sync/issues)

## Contributing
- See repository guidelines: [Contributing](https://github.com/topmoveright/remote_cache_sync)

[README]: https://topmoveright.github.io/remote_cache_sync/
[docs-home]: https://topmoveright.github.io/remote_cache_sync/#/
[Supabase]: https://topmoveright.github.io/remote_cache_sync/#/backend_guides/supabase
[Appwrite]: https://topmoveright.github.io/remote_cache_sync/#/backend_guides/appwrite
[PocketBase]: https://topmoveright.github.io/remote_cache_sync/#/backend_guides/pocketbase
[Orchestrator]: https://topmoveright.github.io/remote_cache_sync/#/usage/orchestrator
[Interfaces]: https://topmoveright.github.io/remote_cache_sync/#/usage/interfaces
[QuerySpec]: https://topmoveright.github.io/remote_cache_sync/#/usage/query_spec
[Testing]: https://topmoveright.github.io/remote_cache_sync/#/testing
