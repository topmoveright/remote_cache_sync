# QuerySpec: General Filtering for Local Stores

QuerySpec enables DB-like filtering, ordering, and pagination on LocalStore implementations, while respecting sync scope and soft-delete semantics.

- Supports: equality, inequality, range, like/contains, isNull/isNotNull, in-list
- Works with: DriftLocalStore (payload-based filtering), InMemoryLocalStore (id/updatedAt only)
- Non-goal (for now): Full SQL translation for arbitrary payload fields (Drift filters run in Dart after scoped SQL selection)

## Data Model Assumptions

All syncable models implement `HasUpdatedAt` and are serialized via `toJson`/`fromJson`. Special fields supported across stores:

- `id`: primary identifier
- `updatedAt`: last update timestamp (ISO-8601 string in Drift payload)

## API Overview

```dart
class QuerySpec {
  final List<FilterOp> filters;
  final List<OrderSpec> orderBy;
  final int? limit;
  final int? offset;
}

class FilterOp {
  final String field;          // e.g., 'status', 'count', 'id', 'updatedAt'
  final FilterOperator op;     // eq, neq, gt, gte, lt, lte, like, contains, isNull, isNotNull, inList
  final Object? value;         // operator-dependent
}

class OrderSpec {
  final String field;          // e.g., 'count', 'title', 'id', 'updatedAt'
  final bool descending;       // default false
}

abstract interface class LocalStore<T, Id> {
  Future<List<T>> queryWith(SyncScope scope, QuerySpec spec);
  Future<int> updateWhere(SyncScope scope, QuerySpec spec, List<T> newValues);
  Future<int> deleteWhere(SyncScope scope, QuerySpec spec);
}
```

## Examples (DriftLocalStore)

```dart
// Model
class R implements HasUpdatedAt {
  final String id;
  final String title;
  final String status;
  final int count;
  final List<String> tags;
  @override
  final DateTime updatedAt;
}

// Build a store (abridged)
final store = DriftLocalStore<R, String>(
  db: db,
  idOf: (r) => r.id,
  idToString: (s) => s,
  idFromString: (s) => s,
  toJson: (r) => {
    'id': r.id,
    'title': r.title,
    'status': r.status,
    'count': r.count,
    'tags': r.tags,
    'updatedAt': r.updatedAt.toIso8601String(),
  },
  fromJson: (m) => R(
    m['id'] as String,
    m['title'] as String,
    m['status'] as String,
    m['count'] as int,
    (m['tags'] as List).cast<String>(),
    DateTime.parse(m['updatedAt'] as String).toUtc(),
  ),
);

// 1) Filter + order + limit
final spec = QuerySpec(
  filters: const [
    FilterOp(field: 'status', op: FilterOperator.eq, value: 'open'),
    FilterOp(field: 'count', op: FilterOperator.gt, value: 5),
  ],
  orderBy: const [OrderSpec('count', descending: true)],
  limit: 10,
);
final result = await store.queryWith(scope, spec);

// 2) Like/contains/in-list
final spec2 = QuerySpec(
  filters: const [
    FilterOp(field: 'title', op: FilterOperator.like, value: 'Al'),
    FilterOp(field: 'tags', op: FilterOperator.contains, value: 'x'),
    FilterOp(field: 'status', op: FilterOperator.inList, value: ['open','closed']),
  ],
  orderBy: const [OrderSpec('id')],
);
final result2 = await store.queryWith(scope, spec2);

// 3) Update/delete by spec
final changed = await store.updateWhere(
  scope,
  const QuerySpec(filters: [FilterOp(field: 'id', op: FilterOperator.inList, value: ['a','b'])]),
  [
    updatedA, // only items whose id ∈ spec will be applied
    updatedC, // ignored if id not matched by spec
  ],
);

final deleted = await store.deleteWhere(
  scope,
  const QuerySpec(filters: [FilterOp(field: 'status', op: FilterOperator.eq, value: 'archived')]),
);
```

## Examples (InMemoryLocalStore)

For simplicity, the in-memory store only supports `id` and `updatedAt` fields in filters and ordering. All other fields return no matches.

```dart
final mem = InMemoryLocalStore<R, String>(idOf: (r) => r.id);

final res = await mem.queryWith(
  scope,
  const QuerySpec(
    filters: [FilterOp(field: 'id', op: FilterOperator.inList, value: ['a','c'])],
    orderBy: [OrderSpec('id', descending: true)],
    limit: 1,
  ),
);

final changed = await mem.updateWhere(
  scope,
  const QuerySpec(filters: [FilterOp(field: 'id', op: FilterOperator.eq, value: 'a')]),
  [raNew],
);

final removed = await mem.deleteWhere(
  scope,
  const QuerySpec(filters: [FilterOp(field: 'updatedAt', op: FilterOperator.lt, value: someDate)]),
);
```

## Behavior & Semantics

- Scope: all operations are constrained to the provided `SyncScope`.
- Soft delete: if `supportsSoftDelete == true`, queries exclude tombstoned rows and deletes create tombstones.
- Special fields: `id`, `updatedAt` are universally supported; other fields depend on store implementation.
- Ordering: multiple `OrderSpec` are honored in priority order.
- Pagination: `offset` defaults to 0; `limit` optional.

## Performance Notes (Drift)

- For arbitrary payload fields, filtering happens in Dart after a scoped SQL select, which may be memory-intensive for large datasets.
- Prefer adding more selective scope keys where possible.
- If specific heavy filters are common, consider extending the Drift schema and mapping particular fields to SQL columns.

## Remote evaluation via RemoteStore and Orchestrator

- `RemoteStore<T, Id>.remoteSearch(scope, spec)` is implemented and maps a subset of `QuerySpec` to each backend's native query DSL (Appwrite, Supabase, PocketBase).
- Each adapter supports only operators/fields that are natively available. Unsupported items must throw `ArgumentError` with a clear message.
- Orchestrator integration:
  - `orchestrator.readWith(scope, spec, preferRemoteEval: true)` will attempt `remoteSearch` first.
  - Successful remote results are upserted into local, then the same `spec` is evaluated locally to ensure cache-consistent ordering/pagination.
  - If `remoteSearch` throws due to unsupported filters and `fallbackToLocal: true`, the orchestrator synchronizes and evaluates locally instead.
