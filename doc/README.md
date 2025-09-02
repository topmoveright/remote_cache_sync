
# Overview

- Backend Guides
  - [Appwrite](./backend_guides/appwrite.md)
  - [PocketBase](./backend_guides/pocketbase.md)
  - [Supabase](./backend_guides/supabase.md)
- Orchestrator
  - [Orchestrator Usage](./usage/orchestrator.md)
- Usage
  - [Interfaces and Usage Patterns](./usage/interfaces.md)
  - [QuerySpec](./usage/query_spec.md)
- [Testing](./testing.md)

## Backend Guides

For backend-specific schema/indexing, permissions, and server time setup, see:

- [Appwrite Backend Guide](./backend_guides/appwrite.md)
- [PocketBase Backend Guide](./backend_guides/pocketbase.md)
- [Supabase Backend Guide](./backend_guides/supabase.md)

## Flutter Web (Drift WASM)

This package supports Drift on Flutter Web via SQLite WASM using a web worker.

• __Connection expectations__
  - `lib/sync/drift/connection/connection_web.dart` uses `WasmDatabase.open()` and expects at runtime:
    - `web/sqlite3.wasm`
    - `web/worker.dart.js` (debug) or `web/worker.dart.min.js` (release)

• __One-time setup in your app__
  - Add dev deps to your app: `build_runner`, `build_web_compilers`.
  - No manual worker JS download is required.

• __Build & Sync via Dart CLI (recommended)__
```bash
# Debug build to ./web
dart run remote_cache_sync:web_setup

# Release build to ./web
dart run remote_cache_sync:web_setup --release

# Custom destination / wasm path
dart run remote_cache_sync:web_setup \
  --dest /absolute/path/to/your_app/web \
  --wasm /absolute/path/to/sqlite3.wasm \
  --release
```

This compiles `web/worker.dart` (creating a minimal one if missing) and copies `sqlite3.wasm` to your app's `web/`. The connection code expects `worker.dart.js` (debug) or `worker.dart.min.js` (release) at the web root.

• __Run on web__
```bash
flutter run -d chrome
```

If the browser lacks certain APIs (e.g., OPFS in private mode), Drift will fall back to a different implementation. We log `missingFeatures` and `chosenImplementation` in `connection_web.dart` for diagnostics.

### CI example (GitHub Actions)
```yaml
name: web-build

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build-web:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Pub get
        run: flutter pub get

      - name: Prepare WASM & worker (release)
        run: dart run remote_cache_sync:web_setup --release

      - name: Build Web
        run: flutter build web --release
```

## Usage & Testing

- Usage: [Interfaces and Usage Patterns](./usage/interfaces.md)
- Testing: [Testing Guide](./testing.md)

> Detailed backend integration examples have been moved to each backend guide to avoid duplication.
> See: [Appwrite](./backend_guides/appwrite.md) · [PocketBase](./backend_guides/pocketbase.md) · [Supabase](./backend_guides/supabase.md)

# Remote Cache Sync (Flutter/Dart)

Remote-first synchronization with offline cache, pending operations queue, conflict resolution, and scope-aware persistence.

Core sync directory: `lib/sync/`

- `cache_policy.dart`
- `sync_types.dart`
- `conflict_resolver.dart`
- `store_interfaces.dart`
- `sync_orchestrator.dart`
- `simple_sync_orchestrator.dart`
- `drift/` (persistent local store)
  - `database.dart` (Drift schema)
  - `drift_local_store.dart`

Example app: `example/lib/main.dart` demonstrates basic usage with `DriftLocalStore` and an in-memory remote adapter.

---

## Goals

- Remote Source of Truth + local cache (offline backup)
- Offline writes via a Pending Operations queue
- Delta sync (upserts/deletes) + conflict resolution (default LWW)
- Reusable core sync module across features
- Minimal boilerplate, clear separation of concerns, testability

Follows Clean Architecture and SOLID principles. Clear separation of concerns and testability.

---

## Architecture (High Level)

- Presentation → Application → Domain → Data
- Core sync is cross-cutting and orchestrates synchronization

---

## Key Components

- `CachePolicy` (`cache_policy.dart`):
  - `remoteFirst`, `localFirst`, `offlineOnly`, `onlineOnly`
- Types/Utilities (`sync_types.dart`):
  - `SyncScope`: logical sync unit (e.g., `SyncScope('records', {'userId': userId})`)
  - `Delta<T, Id>`: `upserts`, `deletes`, `serverTimestamp`
  - `HasUpdatedAt`: timestamp contract for conflict resolution
  - `HasId<Id>`: strongly-typed model identifier contract
  - `HasSoftDelete`: models supporting soft delete via `deletedAt`
- Conflict Resolution (`conflict_resolver.dart`):
  - `ConflictResolver<T>` interface
  - Default `LastWriteWinsResolver<T>` (LWW: newest `updatedAt` wins)
- Store Contracts (`store_interfaces.dart`):
  - `LocalStore<T, Id>`, `RemoteStore<T, Id>`
  - `PendingOp<T, Id>` and `PendingOpType`
  - LocalStore API is scope-aware: `upsertMany(scope, items)`, `deleteMany(scope, ids)`
- Orchestrator (`sync_orchestrator.dart`, `simple_sync_orchestrator.dart`):
  - `SyncOrchestrator<T, Id>` interface with default implementation

---

## Flow

- Read: `read(scope, policy)`
  - remoteFirst: `synchronize(scope)` → return from local
  - localFirst: return local immediately → background sync
  - offlineOnly: local only
  - onlineOnly: sync then return local
- Write: `enqueueCreate/Update/Delete(scope, id, payload?)`
  - update local → push `PendingOp` → background `synchronize(scope)`
- Synchronize: `SimpleSyncOrchestrator.synchronize()`
  1) Flush pending ops: upsert/delete to remote; on success `clearPendingOps`
  2) Fetch delta: `remote.fetchSince(scope, lastSync)`
  3) Merge: upserts (LWW), deletions (remove by id)
  4) Persist locally: `local.upsertMany`, `local.deleteMany`
  5) Save sync point: use `delta.serverTimestamp` (avoid clock skew)

See `lib/sync/simple_sync_orchestrator.dart` for implementation.

---

## Store Contracts

- `LocalStore<T, Id>`
  - Data: `getById`, `query`, `querySince`, `upsertMany(scope, items)`, `deleteMany(scope, ids)`
  - Metadata: `getSyncPoint(scope)`, `saveSyncPoint(scope, ts)`
  - Queue: `getPendingOps(scope)`, `enqueuePendingOp(op)`, `clearPendingOps(opIds)`
- `RemoteStore<T, Id>`
  - `getById`, `fetchSince`, `batchUpsert`, `batchDelete`, `getServerTime`

The default persistent local adapter is Drift-based: `DriftLocalStore<T, Id>`.

---

## Drift Integration

- Package: `drift`, `drift_flutter`
- Tables: `Items`, `SyncPoints`, `PendingOps` (all scope-aware)
- Soft delete is supported when `supportsSoftDelete = true`.
  - deleteMany on soft-delete store sets a tombstone (`deletedAt`) rather than hard-deleting rows.
  - Upsert clears tombstones when a newer record arrives.
- JSON (de)serialization is injected via constructor: `toJson`, `fromJson`.
- ID mapping is injected: `idOf`, `idToString`, `idFromString`.

Code generation: run once after changes to Drift schema

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Error Handling

- This package surfaces regular Dart exceptions from adapters.
- Consumers can map them into their own error model.

---

## TODO / Limitations

- Tests: soft delete, metadata persistence, conflict handling, and scope isolation
- Server time source: rely on real server timestamp API
- Background scheduler: periodic sync with connectivity/lifecycle awareness

---

## Quick Start Example (Drift)

```dart
class Record implements HasUpdatedAt {
  final String id;
  final String title;
  @override
  final DateTime updatedAt;
  const Record({required this.id, required this.title, required this.updatedAt});
}

final db = LocalDriftDatabase();
final local = DriftLocalStore<Record, String>(
  db: db,
  idOf: (r) => r.id,
  idToString: (s) => s,
  idFromString: (s) => s,
  toJson: (r) => {
    'id': r.id,
    'title': r.title,
    'updatedAt': r.updatedAt.toIso8601String(),
  },
  fromJson: (m) => Record(
    id: m['id'] as String,
    title: m['title'] as String,
    updatedAt: DateTime.parse(m['updatedAt'] as String).toUtc(),
  ),
);

final remote = InMemoryRemoteStore<Record, String>(idOf: (r) => r.id);
final orchestrator = SimpleSyncOrchestrator<Record, String>(
  local: local,
  remote: remote,
  resolver: const LastWriteWinsResolver<Record>(),
  idOf: (r) => r.id,
);

final scope = SyncScope('records', {'userId': 'u1'});
await orchestrator.synchronize(scope);
final items = await local.query(scope);
```

See `example/lib/main.dart` for a runnable demo (Flutter app with UI buttons).

## Soft Delete Semantics

- If `supportsSoftDelete` is true:
  - `deleteMany(scope, ids)` sets `deletedAt` for matching rows (tombstone).
  - `query/querySince` exclude soft-deleted rows.
  - `upsertMany(scope, items)` clears `deletedAt` when an incoming record has a newer `updatedAt`.
- If false:
  - `deleteMany` removes rows.

## Scope Awareness

- All LocalStore operations require a `SyncScope` to isolate data per logical context.
- `scope.name` and `scope.keys` are persisted for every record and metadata row.

## Troubleshooting

- Re-run code generation after editing Drift schema: `dart run build_runner build`.
- Name clash: package exports hide generated `PendingOp` data class from `database.dart`. Use domain `PendingOp<T, Id>` from `store_interfaces.dart`.
- Web builds: ensure `drift_flutter` is up to date.

---

## API Reference (Summary)

Below is a concise reference. See source files under `lib/sync/` for details and inline comments.

### Types (`sync_types.dart`)

- `class SyncScope`:
  - `String name`
  - `Map<String, String> keys`
- `class Delta<T, Id>`:
  - `List<T> upserts`
  - `List<Id> deletes`
  - `DateTime serverTimestamp`
- `mixin HasUpdatedAt { DateTime get updatedAt; }`
- `mixin HasId<Id> { Id get id; }`
- `mixin HasSoftDelete { DateTime? get deletedAt; }`

### Local Store (`store_interfaces.dart`)

```dart
abstract interface class LocalStore<T, Id> {
  bool get supportsSoftDelete => false;

  Future<T?> getById(Id id);
  Future<List<T>> query(SyncScope scope);
  Future<List<T>> querySince(SyncScope scope, DateTime since);
  Future<void> upsertMany(SyncScope scope, List<T> items);
  Future<void> deleteMany(SyncScope scope, List<Id> ids);

  Future<DateTime?> getSyncPoint(SyncScope scope);
  Future<void> saveSyncPoint(SyncScope scope, DateTime timestamp);

  Future<List<PendingOp<T, Id>>> getPendingOps(SyncScope scope);
  Future<void> enqueuePendingOp(PendingOp<T, Id> op);
  Future<void> clearPendingOps(SyncScope scope, List<String> opIds);
}
```

Semantics:
- `deleteMany`: soft-delete if `supportsSoftDelete` is true, else hard-delete.
- All data/metadata are scope-aware.

### Remote Store (`store_interfaces.dart`)

```dart
abstract interface class RemoteStore<T, Id> {
  Future<T?> getById(Id id);
  Future<Delta<T, Id>> fetchSince(SyncScope scope, DateTime? since);
  Future<void> batchUpsert(List<T> items);
  Future<void> batchDelete(List<Id> ids);
  Future<DateTime> getServerTime();
}
```

Semantics:
- `fetchSince`: return only changes since `since` timestamp (UTC). Include deletions as ID list.
- `getServerTime`: authoritative UTC server timestamp (used for sync point).

### Pending Operation (`store_interfaces.dart`)

```dart
class PendingOp<T, Id> {
  final String opId; // unique per op
  final SyncScope scope;
  final PendingOpType type; // create | update | delete
  final Id id; // target id
  final T? payload; // null for delete
  final DateTime updatedAt; // client timestamp (UTC)
}

enum PendingOpType { create, update, delete }
```

### Orchestrator (`sync_orchestrator.dart`, `simple_sync_orchestrator.dart`)

- `SyncOrchestrator<T, Id>`: interface.
- `SimpleSyncOrchestrator<T, Id>`: default implementation with methods:
  - `Future<void> synchronize(SyncScope scope)`
  - `Future<void> enqueueCreate(SyncScope scope, Id id, T payload)`
  - `Future<void> enqueueUpdate(SyncScope scope, Id id, T payload)`
  - `Future<void> enqueueDelete(SyncScope scope, Id id)`

### Drift Local Store (`drift/drift_local_store.dart`)

```dart
class DriftLocalStore<T extends HasUpdatedAt, Id> implements LocalStore<T, Id> {
  DriftLocalStore({
    required LocalDriftDatabase db,
    required Id Function(T) idOf,
    required String Function(Id) idToString,
    required Id Function(String) idFromString,
    required Map<String, dynamic> Function(T) toJson,
    required T Function(Map<String, dynamic>) fromJson,
    bool supportsSoftDelete = false,
  });
}
```

Behavior:
- Scope-aware persistence into Drift tables.
- Optional soft delete via `deletedAt` tombstone.
- Persists sync points and pending operations.
