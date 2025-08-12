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
