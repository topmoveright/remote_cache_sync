import 'sync_types.dart';

/// LocalStore abstracts local persistence for syncable models.
abstract interface class LocalStore<T, Id> {
  /// Whether this store performs soft delete (set deletedAt) instead of hard delete.
  bool get supportsSoftDelete => false;

  Future<T?> getById(Id id);
  Future<List<T>> query(SyncScope scope);
  Future<List<T>> querySince(SyncScope scope, DateTime since);

  /// Query with general DB-like filters, ordering and pagination within a scope.
  /// This does not escape the scope and respects soft-delete semantics.
  Future<List<T>> queryWith(SyncScope scope, QuerySpec spec);

  /// Upsert items that belong to the given [scope].
  Future<void> upsertMany(SyncScope scope, List<T> items);

  /// Delete semantics within the given [scope]:
  /// - If [supportsSoftDelete] is true, mark items as deleted (e.g., set deletedAt) and keep rows.
  /// - Otherwise, remove rows permanently (hard delete).
  Future<void> deleteMany(SyncScope scope, List<Id> ids);

  /// Update items that match [spec] within the [scope].
  /// For stores that support soft delete, implementations SHOULD avoid updating tombstoned rows.
  /// Returns the number of affected rows if available, else -1.
  Future<int> updateWhere(SyncScope scope, QuerySpec spec, List<T> newValues);

  /// Delete items that match [spec] within the [scope].
  /// Applies soft/hard delete semantics in the same way as [deleteMany].
  /// Returns the number of affected rows if available, else -1.
  Future<int> deleteWhere(SyncScope scope, QuerySpec spec);

  // Synchronization metadata
  Future<DateTime?> getSyncPoint(SyncScope scope);
  Future<void> saveSyncPoint(SyncScope scope, DateTime timestamp);

  // Offline-first write pending job queue
  Future<List<PendingOp<T, Id>>> getPendingOps(SyncScope scope);
  Future<void> enqueuePendingOp(PendingOp<T, Id> op);
  Future<void> clearPendingOps(SyncScope scope, List<String> opIds);

  /// Cache management APIs
  /// Returns an approximate size of the local cache in bytes. When [scope] is provided,
  /// the size is calculated only for that scope; otherwise it is for the whole store.
  Future<int> approxCacheSizeBytes({SyncScope? scope});

  /// Sets the cache size limit in bytes. When null, no limit is enforced.
  Future<void> setCacheSizeLimitBytes(int? bytes);

  /// Returns the cache size limit in bytes, or null if unlimited.
  Future<int?> getCacheSizeLimitBytes();

  /// Clears cached data. When [scope] is provided, clears only that scope; otherwise clears all data.
  /// Implementations should also clear sync points and pending operations for the cleared scope(s).
  Future<void> clearCache({SyncScope? scope});
}

/// RemoteStore abstracts access to the remote service for syncable models.
abstract interface class RemoteStore<T, Id> {
  Future<T?> getById(Id id);
  Future<Delta<T, Id>> fetchSince(SyncScope scope, DateTime? since);

  /// Search within a scope using a normalized query spec. Implementations should
  /// apply soft-delete semantics and only support operators and fields that are
  /// natively available on the backend. Unsupported operators/fields must throw
  /// ArgumentError with a clear message.
  Future<List<T>> remoteSearch(SyncScope scope, QuerySpec spec);
  Future<void> batchUpsert(List<T> items);
  Future<void> batchDelete(List<Id> ids);
  Future<DateTime> getServerTime();
}

/// Indicates the hold job that will be sent remotely while online.
class PendingOp<T, Id> {
  final String opId; // unique per op
  final SyncScope scope;
  final PendingOpType type;
  final Id id;
  final T? payload; // null for delete
  final DateTime updatedAt;

  const PendingOp({
    required this.opId,
    required this.scope,
    required this.type,
    required this.id,
    required this.payload,
    required this.updatedAt,
  });
}

enum PendingOpType { create, update, delete }

/// A normalized query description that can be mapped to local or remote backends.
class QuerySpec {
  final List<FilterOp> filters;
  final List<OrderSpec> orderBy;
  final int? limit;
  final int? offset;

  const QuerySpec({
    this.filters = const [],
    this.orderBy = const [],
    this.limit,
    this.offset,
  });

  QuerySpec copyWith({
    List<FilterOp>? filters,
    List<OrderSpec>? orderBy,
    int? limit,
    int? offset,
  }) {
    return QuerySpec(
      filters: filters ?? this.filters,
      orderBy: orderBy ?? this.orderBy,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

/// Supported filter operators for general DB-like querying.
enum FilterOperator {
  eq,
  neq,
  gt,
  gte,
  lt,
  lte,
  like, // substring or pattern match depending on backend
  contains, // array contains or string contains depending on backend support
  isNull,
  isNotNull,
  inList, // value IN (...)
}

/// A single filter predicate. Field names should match the serialized payload keys.
class FilterOp {
  final String field;
  final FilterOperator op;
  final Object? value;

  const FilterOp({required this.field, required this.op, this.value});
}

/// Ordering specification.
class OrderSpec {
  final String field;
  final bool descending;

  const OrderSpec(this.field, {this.descending = false});
}
