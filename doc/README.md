
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

### Supabase TL;DR

If you're integrating with Supabase, follow this quick checklist and then see the full guide:

1) Create table `<your_table>` with columns:
- `<id_column>` (text/uuid, PK)
- `<updated_at_column>` (timestamptz)
- `<deleted_at_column>` (timestamptz, nullable) for soft delete
- `<scope_name_column>` (text)
- `<scope_keys_column>` (jsonb)

2) Add indexes:
```sql
create index if not exists idx_<table>_scope_name on <your_table>(<scope_name_column>);
create index if not exists idx_<table>_updated_at on <your_table>(<updated_at_column> desc);
```

3) Enable RLS and add scope policies (see full guide for examples).

4) Keep `<updated_at_column>` fresh via trigger (see full guide).

5) Deploy Edge Function `server-time` that returns `new Date().toISOString()`; use it for `getServerTime()`.

Full details: [Supabase Backend Guide](./backend_guides/supabase.md)

### Backend Checklist (All Backends)

- Define consistent fields: id, updatedAt, optional deletedAt, scopeName, scopeKeys
- Index: scopeName, updatedAt, id
- RLS/Rules: enforce same-scope read/write, prevent cross-scope writes
- Server Time: provide an endpoint/function returning ISO8601 UTC
- Soft Delete: prefer tombstones for reliable delta sync

---

## Appwrite Integration (Example)

This section shows an example of using `AppwriteRemoteStore<T, Id>`.

> Note: Replace placeholders with your schema: `<your_collection>`, `<id_field>`, `<updated_at_field>`, `<deleted_at_field>`, `<scope_name_field>`, `<scope_keys_field>`.

### 1) Recommended Fields

Add fields to your Appwrite collection:

```text
<id_field>: string (unique)
<updated_at_field>: datetime (server-controlled if possible)
<deleted_at_field>: datetime (nullable; optional for soft delete)
<scope_name_field>: string
<scope_keys_field>: object/json
```

### 2) Server Time (Recommended)

Expose an Appwrite Function returning UTC now. Configure its ID in `serverTimeFunctionId`.

### 3) Usage

```dart
import 'package:appwrite/appwrite.dart' as aw;
import 'package:remote_cache_sync/remote_cache_sync.dart';

final client = aw.Client()
  ..setEndpoint('<your_appwrite_endpoint>')
  ..setProject('<your_project_id>')
  ..setKey('<your_api_key>');
final databases = aw.Databases(client);
final functions = aw.Functions(client);

final remote = AppwriteRemoteStore<Record, String>(
  config: AppwriteRemoteConfig<Record, String>(
    databases: databases,
    functions: functions,
    databaseId: '<your_database_id>',
    collectionId: '<your_collection>',
    idField: '<id_field>',
    updatedAtField: '<updated_at_field>',
    deletedAtField: '<deleted_at_field>', // or null => hard delete
    scopeNameField: '<scope_name_field>',
    scopeKeysField: '<scope_keys_field>',
    idOf: (r) => r.id,
    idToString: (s) => s,
    idFromString: (s) => s,
    toJson: (r) => {
      '<id_field>': r.id,
      'title': r.title,
      '<updated_at_field>': r.updatedAt.toIso8601String(),
      '<scope_name_field>': r.scopeName,
      '<scope_keys_field>': r.scopeKeys,
    },
    fromJson: (m) => Record(
      id: m['<id_field>'] as String,
      title: m['title'] as String,
      updatedAt: DateTime.parse(m['<updated_at_field>'] as String).toUtc(),
      scopeName: m['<scope_name_field>'] as String,
      scopeKeys: Map<String, dynamic>.from(m['<scope_keys_field>'] as Map),
    ),
    serverTimeFunctionId: '<your_function_id>',
    // Optional scope injection
    defaultScope: SyncScope(name: '<your_scope_name>', keys: {'userId': 'u1'}),
    injectScopeOnWrite: true,
    scopeFieldsBuilder: (s) => {
      '<scope_name_field>': s.name,
      '<scope_keys_field>': s.keys,
    },
  ),
);
```

---

## PocketBase Integration (Example)

This section shows an example of using `PocketBaseRemoteStore<T, Id>`.

> Note: Replace placeholders with your schema: `<your_collection>`, `<id_field>`, `<updated_at_field>`, `<deleted_at_field>`, `<scope_name_field>`, `<scope_keys_field>`. PocketBase has built-in `id/created/updated` fields you can leverage.

### 1) Recommended Fields

Add the following fields to your collection (in addition to PB defaults):

```text
<deleted_at_field>: datetime (nullable; optional for soft delete)
<scope_name_field>: text
<scope_keys_field>: json
```

### 2) Server Time (Recommended)

Expose a minimal endpoint (e.g., `/api/time`) that returns UTC now and configure `serverTimeEndpoint`.

### 3) Usage

```dart
import 'package:pocketbase/pocketbase.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';

final pb = PocketBase('https://your-pocketbase.example');

final remote = PocketBaseRemoteStore<Record, String>(
  config: PocketBaseRemoteConfig<Record, String>(
    client: pb,
    collection: '<your_collection>',
    idField: '<id_field>', // often 'id'
    updatedAtField: '<updated_at_field>', // often 'updated'
    deletedAtField: '<deleted_at_field>',
    scopeNameField: '<scope_name_field>',
    scopeKeysField: '<scope_keys_field>',
    idOf: (r) => r.id,
    idToString: (s) => s,
    idFromString: (s) => s,
    toJson: (r) => {
      '<id_field>': r.id,
      'title': r.title,
      '<updated_at_field>': r.updatedAt.toIso8601String(),
      '<scope_name_field>': r.scopeName,
      '<scope_keys_field>': r.scopeKeys,
    },
    fromJson: (m) => Record(
      id: m['<id_field>'] as String,
      title: m['title'] as String,
      updatedAt: DateTime.parse(m['<updated_at_field>'] as String).toUtc(),
      scopeName: m['<scope_name_field>'] as String,
      scopeKeys: Map<String, dynamic>.from(m['<scope_keys_field>'] as Map),
    ),
    serverTimeEndpoint: '/api/time',
    // Optional scope injection
    defaultScope: SyncScope(name: '<your_scope_name>', keys: {'userId': 'u1'}),
    injectScopeOnWrite: true,
    scopeFieldsBuilder: (s) => {
      '<scope_name_field>': s.name,
      '<scope_keys_field>': s.keys,
    },
  ),
);
```

## Supabase Integration (Example)

This section shows an example of using `SupabaseRemoteStore<T, Id>` with a Supabase (PostgREST) table.

> Note: All names below (table and column names) are examples. Replace them with your actual schema, e.g. `<your_table>`, `<id_column>`, `<updated_at_column>`, `<deleted_at_column>`, `<scope_name_column>`, `<scope_keys_column>`.

### 1) Database Schema (Recommended)

Create a table with columns to support delta sync, scope isolation, and optional soft delete:

```sql
-- Example only. Replace <your_table> and business columns.
create table if not exists public.<your_table> (
  <id_column> text primary key,
  <updated_at_column> timestamptz not null,
  <deleted_at_column> timestamptz null,
  <scope_name_column> text not null,
  <scope_keys_column> jsonb not null,
  -- your business fields ...
  title text
);

-- Useful index for delta queries (adjust to your keys)
create index if not exists idx_<your_table>_scope_updated on public.<your_table>
  (<scope_name_column>, (<scope_keys_column>->>'userId'), <updated_at_column>);
```

Notes:
- `<updated_at_column>` should be server-controlled or trusted to increase monotonically per update.
- `<deleted_at_column>` is optional; when present, the adapter uses soft delete semantics.
- `<scope_name_column>` and `<scope_keys_column>` allow isolating logical sync units.

### 2) Server Time RPC (Recommended)

Expose a simple RPC to return authoritative UTC time for sync points:

```sql
create or replace function public.server_time_utc()
returns timestamptz language sql stable as $$
  select now() at time zone 'utc';
$$;
```

Configure the adapter with `serverTimeRpcName: 'server_time_utc'` to avoid client clock skew.

### 3) Security (RLS)

Enable Row Level Security and write policies that limit access by scope (e.g., to a given user):

```sql
alter table public.records enable row level security;

-- Example policies (adjust to your auth model)
create policy "read by scope" on public.records
  for select using (
    scope_keys ? 'userId' and scope_keys->>'userId' = auth.jwt() ->> 'sub'
  );

create policy "write by scope" on public.records
  for all using (
    scope_keys ? 'userId' and scope_keys->>'userId' = auth.jwt() ->> 'sub'
  ) with check (
    scope_keys ? 'userId' and scope_keys->>'userId' = auth.jwt() ->> 'sub'
  );
```

You may also derive scope on the server (via triggers/edge functions) rather than sending it from the client.

### 4) Flutter Setup

Add the dependency (already added in this repo):

```yaml
dependencies:
  supabase_flutter: ^2.6.0
```

Initialize Supabase in your app (typically at startup):

```dart
await Supabase.initialize(
  url: 'https://YOUR_PROJECT.supabase.co',
  anonKey: 'YOUR_ANON_OR_SERVICE_ROLE_KEY',
);
final supa = Supabase.instance.client;
```

### 5) Using SupabaseRemoteStore

Configure and instantiate the adapter. You must provide JSON serialization/deserialization and ID mapping. Replace placeholders with your schema.

```dart
import 'package:remote_cache_sync/remote_cache_sync.dart';

final remote = SupabaseRemoteStore<Record, String>(
  config: SupabaseRemoteConfig<Record, String>(
    client: supa,
    table: '<your_table>',
    idColumn: '<id_column>',
    updatedAtColumn: '<updated_at_column>',
    deletedAtColumn: '<deleted_at_column>', // or null => hard delete
    scopeNameColumn: '<scope_name_column>',
    scopeKeysColumn: '<scope_keys_column>',
    idOf: (r) => r.id,
    idToString: (s) => s,
    idFromString: (s) => s,
    toJson: (r) => {
      '<id_column>': r.id,
      'title': r.title,
      '<updated_at_column>': r.updatedAt.toIso8601String(),
      '<scope_name_column>': r.scopeName, // if your model stores it
      '<scope_keys_column>': r.scopeKeys,
    },
    fromJson: (m) => Record(
      id: m['<id_column>'] as String,
      title: m['title'] as String,
      updatedAt: DateTime.parse(m['<updated_at_column>'] as String).toUtc(),
      scopeName: m['<scope_name_column>'] as String,
      scopeKeys: Map<String, dynamic>.from(m['<scope_keys_column>'] as Map),
    ),
    serverTimeRpcName: 'server_time_utc',
  ),
);
```

Use with the orchestrator as the `RemoteStore<T, Id>` implementation.

### 6) Scope Injection (Optional)

By default, `batchUpsert`/`batchDelete` do not include scope filters because `RemoteStore` methods have no scope parameter. If your backend cannot infer scope from auth context, you can instruct the adapter to inject scope columns during writes and to filter delete operations by scope. Replace placeholders with your schema:

```dart
final remote = SupabaseRemoteStore<Record, String>(
  config: SupabaseRemoteConfig<Record, String>(
    client: supa,
    table: '<your_table>',
    idColumn: '<id_column>',
    updatedAtColumn: '<updated_at_column>',
    deletedAtColumn: '<deleted_at_column>',
    scopeNameColumn: '<scope_name_column>',
    scopeKeysColumn: '<scope_keys_column>',
    idOf: (r) => r.id,
    idToString: (s) => s,
    idFromString: (s) => s,
    toJson: (r) => { /* ... */ },
    fromJson: (m) => /* ... */,
    serverTimeRpcName: 'server_time_utc',
    // Scope injection options:
    defaultScope: SyncScope(name: '<your_scope_name>', keys: {'userId': 'u1'}),
    injectScopeOnWrite: true,
    scopeColumnsBuilder: (scope) => {
      '<scope_name_column>': scope.name,
      '<scope_keys_column>': scope.keys,
    },
  ),
);
```

With `injectScopeOnWrite: true` and `defaultScope` set, the adapter:
- Adds `scope_name` and `scope_keys` to rows during `batchUpsert`.
- Applies scope filters to `batchDelete` operations.

If your RLS policies derive scope from the JWT or a session context, you can leave this option off.

### 7) Delta Semantics

`fetchSince(scope, since)` returns:
- Upserts: rows where `updated_at > since` and `deleted_at IS NULL` (when `deleted_at` exists)
- Deletes: ids where `updated_at > since` and `deleted_at IS NOT NULL`
- `serverTimestamp`: authoritative UTC time from your RPC

Ensure your server updates `updated_at` on each change. For hard delete setups (no `deleted_at`), you must supply tombstones (e.g., via a separate table or soft delete emulation) to allow clients to detect removals.

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
