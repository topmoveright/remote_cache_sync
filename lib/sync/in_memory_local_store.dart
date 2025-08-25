import 'dart:collection';

import 'store_interfaces.dart';
import 'sync_types.dart';

/// Simple in-memory LocalStore implementation for demos/examples.
/// Not intended for production use.
class InMemoryLocalStore<T extends HasUpdatedAt, Id>
    implements LocalStore<T, Id> {
  @override
  final bool supportsSoftDelete;

  final Id Function(T) idOf;

  // Data per scope
  final Map<String, Map<Id, T>> _data = {};
  // Tombstones per scope (only used when supportsSoftDelete)
  final Map<String, Map<Id, DateTime>> _tombstones = {};
  // Sync points per scope
  final Map<String, DateTime> _syncPoints = {};
  // Pending ops per scope
  final Map<String, List<PendingOp<T, Id>>> _pending = {};

  InMemoryLocalStore({required this.idOf, this.supportsSoftDelete = true});

  String _scopeKey(SyncScope scope) => '${scope.name}|${scope.keys}';

  Map<Id, T> _dataOf(String sk) => _data.putIfAbsent(sk, () => <Id, T>{});
  Map<Id, DateTime> _tombOf(String sk) =>
      _tombstones.putIfAbsent(sk, () => <Id, DateTime>{});
  List<PendingOp<T, Id>> _pendingOf(String sk) =>
      _pending.putIfAbsent(sk, () => <PendingOp<T, Id>>[]);

  @override
  Future<T?> getById(Id id) async {
    for (final sk in _data.keys) {
      final tmap = supportsSoftDelete ? _tombstones[sk] : null;
      if (tmap != null && tmap.containsKey(id)) continue;
      final v = _data[sk]?[id];
      if (v != null) return v;
    }
    return null;
  }

  @override
  Future<List<T>> query(SyncScope scope) async {
    final sk = _scopeKey(scope);
    final items = _dataOf(sk).values;
    if (!supportsSoftDelete) return items.toList(growable: false);
    final t = _tombOf(sk);
    return items.where((e) => !t.containsKey(idOf(e))).toList(growable: false);
  }

  @override
  Future<List<T>> querySince(SyncScope scope, DateTime since) async {
    final sk = _scopeKey(scope);
    final t = supportsSoftDelete ? _tombOf(sk) : <Id, DateTime>{};
    final data = _dataOf(sk).values.where((e) => e.updatedAt.isAfter(since));
    // Exclude soft-deleted ones
    final active = data.where((e) => !t.containsKey(idOf(e))).toList();
    return active;
  }

  @override
  Future<void> upsertMany(SyncScope scope, List<T> items) async {
    if (items.isEmpty) return;
    // Scope-aware upsert: place items into the concrete scope only.
    final sk = _scopeKey(scope);
    final map = _dataOf(sk);
    for (final it in items) {
      map[idOf(it)] = it;
    }
    // Clear tombstones for upserted items within the same scope (soft delete).
    if (supportsSoftDelete) {
      final tomb = _tombOf(sk);
      for (final it in items) {
        tomb.remove(idOf(it));
      }
    }
  }

  @override
  Future<void> deleteMany(SyncScope scope, List<Id> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now().toUtc();
    final sk = _scopeKey(scope);
    final map = _dataOf(sk);
    for (final id in ids) {
      map.remove(id);
      if (supportsSoftDelete) {
        _tombOf(sk)[id] = now;
      }
    }
  }

  @override
  Future<DateTime?> getSyncPoint(SyncScope scope) async {
    return _syncPoints[_scopeKey(scope)];
  }

  @override
  Future<void> saveSyncPoint(SyncScope scope, DateTime timestamp) async {
    _syncPoints[_scopeKey(scope)] = timestamp;
  }

  @override
  Future<List<PendingOp<T, Id>>> getPendingOps(SyncScope scope) async {
    return List.unmodifiable(_pendingOf(_scopeKey(scope)));
  }

  @override
  Future<void> enqueuePendingOp(PendingOp<T, Id> op) async {
    _pendingOf(_scopeKey(op.scope)).add(op);
  }

  @override
  Future<void> clearPendingOps(SyncScope scope, List<String> opIds) async {
    final list = _pendingOf(_scopeKey(scope));
    final set = HashSet.of(opIds);
    list.removeWhere((e) => set.contains(e.opId));
  }
}
