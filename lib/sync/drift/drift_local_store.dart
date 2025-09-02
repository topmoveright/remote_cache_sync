import 'dart:convert';

import 'package:drift/drift.dart' as d;

import '../store_interfaces.dart' as store;
import '../sync_types.dart';
import 'database.dart';

/// Drift-backed LocalStore implementation.
/// Persists items, sync points, and pending operations with scope awareness.
class DriftLocalStore<T extends HasUpdatedAt, Id>
    implements store.LocalStore<T, Id> {
  final LocalDriftDatabase db;
  final Id Function(T) idOf;
  final String Function(Id) idToString;
  final Id Function(String) idFromString;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;

  @override
  final bool supportsSoftDelete;

  // Optional in-memory cache size limit in bytes. When null, unlimited.
  int? _sizeLimitBytes;

  DriftLocalStore({
    required this.db,
    required this.idOf,
    required this.idToString,
    required this.idFromString,
    required this.toJson,
    required this.fromJson,
    this.supportsSoftDelete = true,
  });

  String _scopeKey(SyncScope scope) => jsonEncode(scope.keys);

  @override
  Future<T?> getById(Id id) async {
    // Search across all scopes for the given id. This keeps the API simple,
    // though most flows should use query(scope) for better performance.
    final idStr = idToString(id);
    final q = db.select(db.items)..where((t) => t.id.equals(idStr));
    // Prefer non-deleted row if supportsSoftDelete
    final rows = await q.get();
    if (rows.isEmpty) return null;
    // Filter soft-deleted if applicable
    final active = supportsSoftDelete
        ? rows.where((r) => r.deletedAt == null).toList()
        : rows;
    final row = (active.isNotEmpty ? active.first : rows.first);
    return fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
  }

  @override
  Future<List<T>> query(SyncScope scope) async {
    final sk = _scopeKey(scope);
    final q = db.select(db.items)
      ..where(
        (t) => supportsSoftDelete
            ? (t.scopeName.equals(scope.name) &
                  t.scopeKeys.equals(sk) &
                  t.deletedAt.isNull())
            : (t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk)),
      );
    final rows = await q.get();
    return rows
        .map((r) => fromJson(jsonDecode(r.payload) as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<T>> queryWith(SyncScope scope, store.QuerySpec spec) async {
    // First, constrain by scope and soft-delete at SQL level for efficiency.
    final sk = _scopeKey(scope);
    final baseQ = db.select(db.items)
      ..where(
        (t) => supportsSoftDelete
            ? (t.scopeName.equals(scope.name) &
                  t.scopeKeys.equals(sk) &
                  t.deletedAt.isNull())
            : (t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk)),
      );
    final rows = await baseQ.get();

    // Apply filters on JSON payload (and special fields) in Dart.
    final filtered = <_RowHolder>[];
    for (final r in rows) {
      final payloadMap = jsonDecode(r.payload) as Map<String, dynamic>;
      if (_matchesSpec(payloadMap, r.id, r.updatedAt, spec)) {
        filtered.add(
          _RowHolder(id: r.id, updatedAtIso: r.updatedAt, payload: payloadMap),
        );
      }
    }

    // Sort
    if (spec.orderBy.isNotEmpty) {
      filtered.sort((a, b) {
        for (final o in spec.orderBy) {
          final c = _compareField(a, b, o.field, o.descending);
          if (c != 0) return c;
        }
        return 0;
      });
    }

    // Pagination
    final start = (spec.offset ?? 0).clamp(0, filtered.length);
    final end = spec.limit == null
        ? filtered.length
        : (start + spec.limit!).clamp(0, filtered.length);
    final window = filtered.sublist(start, end);

    // Map to T
    return window.map((h) => fromJson(h.payload)).toList(growable: false);
  }

  @override
  Future<int> updateWhere(
    SyncScope scope,
    store.QuerySpec spec,
    List<T> newValues,
  ) async {
    if (newValues.isEmpty) return 0;
    // Find matching ids, then upsert only those provided in newValues whose id is in the match set.
    final matched = await queryWith(scope, spec);
    if (matched.isEmpty) return 0;
    final matchIds = matched.map(idOf).toSet();
    final toApply = newValues.where((e) => matchIds.contains(idOf(e))).toList();
    if (toApply.isEmpty) return 0;
    await upsertMany(scope, toApply);
    return toApply.length;
  }

  @override
  Future<int> deleteWhere(SyncScope scope, store.QuerySpec spec) async {
    final matched = await queryWith(scope, spec);
    if (matched.isEmpty) return 0;
    final ids = matched.map(idOf).toList(growable: false);
    await deleteMany(scope, ids);
    return ids.length;
  }

  bool _matchesSpec(
    Map<String, dynamic> payload,
    String id,
    String updatedAtIso,
    store.QuerySpec spec,
  ) {
    for (final f in spec.filters) {
      final field = f.field;
      dynamic value;
      if (field == 'id') {
        value = id;
      } else if (field == 'updatedAt') {
        value = updatedAtIso;
      } else {
        value = payload[field];
      }
      if (!_evalFilter(value, f)) return false;
    }
    return true;
  }

  int _compareField(_RowHolder a, _RowHolder b, String field, bool desc) {
    final av = field == 'id'
        ? a.id
        : field == 'updatedAt'
        ? a.updatedAtIso
        : a.payload[field];
    final bv = field == 'id'
        ? b.id
        : field == 'updatedAt'
        ? b.updatedAtIso
        : b.payload[field];
    final c = _compareDynamic(av, bv);
    return desc ? -c : c;
  }

  int _compareDynamic(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    // Try parse ISO date
    DateTime? ad, bd;
    if (a is String && b is String) {
      ad = DateTime.tryParse(a);
      bd = DateTime.tryParse(b);
      if (ad != null && bd != null) return ad.compareTo(bd);
      return a.compareTo(b);
    }
    // Fallback using string compare
    return a.toString().compareTo(b.toString());
  }

  bool _evalFilter(dynamic left, store.FilterOp f) {
    switch (f.op) {
      case store.FilterOperator.eq:
        return left == f.value;
      case store.FilterOperator.neq:
        return left != f.value;
      case store.FilterOperator.gt:
        return _cmp(left, f.value) > 0;
      case store.FilterOperator.gte:
        return _cmp(left, f.value) >= 0;
      case store.FilterOperator.lt:
        return _cmp(left, f.value) < 0;
      case store.FilterOperator.lte:
        return _cmp(left, f.value) <= 0;
      case store.FilterOperator.like:
        if (left is String && f.value is String) {
          return left.contains(f.value as String);
        }
        return false;
      case store.FilterOperator.contains:
        if (left is Iterable) {
          return (left).contains(f.value);
        }
        if (left is String && f.value is String) {
          return left.contains(f.value as String);
        }
        return false;
      case store.FilterOperator.isNull:
        return left == null;
      case store.FilterOperator.isNotNull:
        return left != null;
      case store.FilterOperator.inList:
        if (f.value is Iterable) {
          return (f.value as Iterable).contains(left);
        }
        return false;
    }
  }

  int _cmp(dynamic a, dynamic b) => _compareDynamic(a, b);

  @override
  Future<List<T>> querySince(SyncScope scope, DateTime since) async {
    final sk = _scopeKey(scope);
    final q = db.select(db.items)
      ..where(
        (t) => supportsSoftDelete
            ? (t.scopeName.equals(scope.name) &
                  t.scopeKeys.equals(sk) &
                  t.updatedAt.isBiggerThanValue(since.toIso8601String()) &
                  t.deletedAt.isNull())
            : (t.scopeName.equals(scope.name) &
                  t.scopeKeys.equals(sk) &
                  t.updatedAt.isBiggerThanValue(since.toIso8601String())),
      );
    final rows = await q.get();
    return rows
        .map((r) => fromJson(jsonDecode(r.payload) as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<void> upsertMany(SyncScope scope, List<T> items) async {
    if (items.isEmpty) return;
    final sk = _scopeKey(scope);
    await db.batch((b) {
      for (final it in items) {
        final idStr = idToString(idOf(it));
        b.insert(
          db.items,
          ItemsCompanion.insert(
            scopeName: scope.name,
            scopeKeys: sk,
            id: idStr,
            payload: jsonEncode(toJson(it)),
            updatedAt: it.updatedAt.toIso8601String(),
            deletedAt: const d.Value.absent(),
          ),
          onConflict: d.DoUpdate(
            (old) => ItemsCompanion(
              payload: d.Value(jsonEncode(toJson(it))),
              updatedAt: d.Value(it.updatedAt.toIso8601String()),
              deletedAt: const d.Value(null), // clear tombstone on upsert
            ),
          ),
        );
      }
    });
    // Enforce cache size limit if configured.
    await _maybeEnforceLimit();
  }

  @override
  Future<void> deleteMany(SyncScope scope, List<Id> ids) async {
    if (ids.isEmpty) return;
    final sk = _scopeKey(scope);
    if (supportsSoftDelete) {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.batch((b) {
        for (final id in ids) {
          final idStr = idToString(id);
          b.insert(
            db.items,
            ItemsCompanion.insert(
              scopeName: scope.name,
              scopeKeys: sk,
              id: idStr,
              payload: jsonEncode({}), // payload may be empty on tombstone
              updatedAt: nowIso,
              deletedAt: d.Value(nowIso),
            ),
            onConflict: d.DoUpdate(
              (old) => ItemsCompanion(
                deletedAt: d.Value(nowIso),
                updatedAt: d.Value(nowIso),
              ),
            ),
          );
        }
      });
    } else {
      await (db.delete(db.items)..where(
            (t) =>
                (t.scopeName.equals(scope.name) &
                t.scopeKeys.equals(sk) &
                t.id.isIn(ids.map(idToString))),
          ))
          .go();
    }
    await _maybeEnforceLimit();
  }

  @override
  Future<DateTime?> getSyncPoint(SyncScope scope) async {
    final sk = _scopeKey(scope);
    final q = db.select(db.syncPoints)
      ..where((t) => t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk));
    final row = await q.getSingleOrNull();
    return row == null ? null : DateTime.parse(row.lastServerTs).toUtc();
  }

  @override
  Future<void> saveSyncPoint(SyncScope scope, DateTime timestamp) async {
    final sk = _scopeKey(scope);
    await db
        .into(db.syncPoints)
        .insert(
          SyncPointsCompanion.insert(
            scopeName: scope.name,
            scopeKeys: sk,
            lastServerTs: timestamp.toIso8601String(),
          ),
          mode: d.InsertMode.insertOrReplace,
        );
  }

  @override
  Future<List<store.PendingOp<T, Id>>> getPendingOps(SyncScope scope) async {
    final sk = _scopeKey(scope);
    final q = db.select(db.pendingOps)
      ..where((t) => t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk));
    final rows = await q.get();
    return rows
        .map(
          (r) => store.PendingOp<T, Id>(
            opId: r.opId,
            scope: scope,
            type: _parseType(r.type),
            id: idFromString(r.id),
            payload: r.payload == null
                ? null
                : fromJson(jsonDecode(r.payload!) as Map<String, dynamic>),
            updatedAt: DateTime.parse(r.updatedAt).toUtc(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> enqueuePendingOp(store.PendingOp<T, Id> op) async {
    await db
        .into(db.pendingOps)
        .insert(
          PendingOpsCompanion.insert(
            opId: op.opId,
            scopeName: op.scope.name,
            scopeKeys: _scopeKey(op.scope),
            type: op.type.name,
            id: idToString(op.id),
            payload: d.Value(
              op.payload == null ? null : jsonEncode(toJson(op.payload as T)),
            ),
            updatedAt: op.updatedAt.toIso8601String(),
          ),
          mode: d.InsertMode.insertOrAbort,
        );
  }

  @override
  Future<void> clearPendingOps(SyncScope scope, List<String> opIds) async {
    if (opIds.isEmpty) return;
    await (db.delete(db.pendingOps)..where((t) => t.opId.isIn(opIds))).go();
  }

  // ---- Cache management implementation ----

  @override
  Future<int> approxCacheSizeBytes({SyncScope? scope}) async {
    int total = 0;
    // Items table
    final itemsQ = db.select(db.items);
    if (scope != null) {
      final sk = _scopeKey(scope);
      itemsQ.where((t) => t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk));
    }
    final itemRows = await itemsQ.get();
    for (final r in itemRows) {
      total += utf8.encode(r.scopeName).length;
      total += utf8.encode(r.scopeKeys).length;
      total += utf8.encode(r.id).length;
      total += utf8.encode(r.payload).length;
      total += utf8.encode(r.updatedAt).length;
      if (r.deletedAt != null) total += utf8.encode(r.deletedAt!).length;
    }

    // PendingOps table
    final pendQ = db.select(db.pendingOps);
    if (scope != null) {
      final sk = _scopeKey(scope);
      pendQ.where((t) => t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk));
    }
    final pendRows = await pendQ.get();
    for (final r in pendRows) {
      total += utf8.encode(r.opId).length;
      total += utf8.encode(r.scopeName).length;
      total += utf8.encode(r.scopeKeys).length;
      total += utf8.encode(r.type).length;
      total += utf8.encode(r.id).length;
      if (r.payload != null) total += utf8.encode(r.payload!).length;
      total += utf8.encode(r.updatedAt).length;
    }

    // SyncPoints table (small but include for completeness)
    final spQ = db.select(db.syncPoints);
    if (scope != null) {
      final sk = _scopeKey(scope);
      spQ.where((t) => t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk));
    }
    final spRows = await spQ.get();
    for (final r in spRows) {
      total += utf8.encode(r.scopeName).length;
      total += utf8.encode(r.scopeKeys).length;
      total += utf8.encode(r.lastServerTs).length;
    }
    return total;
  }

  @override
  Future<void> setCacheSizeLimitBytes(int? bytes) async {
    _sizeLimitBytes = bytes;
    await _maybeEnforceLimit();
  }

  @override
  Future<int?> getCacheSizeLimitBytes() async => _sizeLimitBytes;

  @override
  Future<void> clearCache({SyncScope? scope}) async {
    if (scope == null) {
      await (db.delete(db.items)).go();
      await (db.delete(db.pendingOps)).go();
      await (db.delete(db.syncPoints)).go();
    } else {
      final sk = _scopeKey(scope);
      await (db.delete(db.items)
            ..where((t) => t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk)))
          .go();
      await (db.delete(db.pendingOps)
            ..where((t) => t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk)))
          .go();
      await (db.delete(db.syncPoints)
            ..where((t) => t.scopeName.equals(scope.name) & t.scopeKeys.equals(sk)))
          .go();
    }
  }

  Future<void> _maybeEnforceLimit() async {
    final limit = _sizeLimitBytes;
    if (limit == null) return;
    // Iterate in small batches to avoid long transactions.
    // 1) Remove oldest tombstoned (soft-deleted) items first.
    int current = await approxCacheSizeBytes();
    int guard = 0;
    while (current > limit && guard < 1000) {
      guard++;
      // Try delete up to 100 tombstones ordered by deletedAt asc
      final tombQ = db.select(db.items)
        ..where((t) => t.deletedAt.isNotNull())
        ..orderBy([(t) => d.OrderingTerm(expression: t.deletedAt, mode: d.OrderingMode.asc)])
        ..limit(100);
      final tombs = await tombQ.get();
      if (tombs.isNotEmpty) {
        final ids = tombs.map((r) => r.id).toList();
        await (db.delete(db.items)..where((t) => t.id.isIn(ids))).go();
        current = await approxCacheSizeBytes();
        continue;
      }

      // 2) Remove oldest active items by updatedAt asc
      final actQ = db.select(db.items)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => d.OrderingTerm(expression: t.updatedAt, mode: d.OrderingMode.asc)])
        ..limit(100);
      final olds = await actQ.get();
      if (olds.isEmpty) break;
      final ids2 = olds.map((r) => r.id).toList();
      await (db.delete(db.items)..where((t) => t.id.isIn(ids2))).go();
      current = await approxCacheSizeBytes();
    }
  }

  store.PendingOpType _parseType(String s) {
    switch (s) {
      case 'create':
        return store.PendingOpType.create;
      case 'update':
        return store.PendingOpType.update;
      case 'delete':
        return store.PendingOpType.delete;
      default:
        throw ArgumentError('Unknown pending op type: $s');
    }
  }
}

/// Internal row holder used for JSON-based filtering/sorting windowing.
class _RowHolder {
  final String id;
  final String updatedAtIso;
  final Map<String, dynamic> payload;

  const _RowHolder({
    required this.id,
    required this.updatedAtIso,
    required this.payload,
  });
}
