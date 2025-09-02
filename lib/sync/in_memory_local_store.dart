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

  // Optional cache size limit (bytes). Approximated using heuristics.
  int? _sizeLimitBytes;

  // Heuristic byte costs per entry (very rough; for demos only).
  static const int _bytesPerItem = 1024; // assume ~1KB per item
  static const int _bytesPerTomb = 128; // tombstone marker cost
  static const int _bytesPerPending = 256; // pending op cost
  static const int _bytesPerSyncPoint = 64; // sync point cost

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
  Future<List<T>> queryWith(SyncScope scope, QuerySpec spec) async {
    // Start from active items within the scope
    final items = await query(scope);
    // Filter by spec (only supports 'id' and 'updatedAt' fields here)
    final filtered = items
        .where((e) => _matchesSpec(idOf(e), e.updatedAt, spec))
        .toList();

    // Sorting
    if (spec.orderBy.isNotEmpty) {
      filtered.sort((a, b) {
        for (final o in spec.orderBy) {
          final c = _compareBy(a, b, o.field, o.descending);
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
    return filtered.sublist(start, end);
  }

  bool _matchesSpec(Id id, DateTime updatedAt, QuerySpec spec) {
    for (final f in spec.filters) {
      dynamic left;
      switch (f.field) {
        case 'id':
          left = id;
          break;
        case 'updatedAt':
          left = updatedAt;
          break;
        default:
          // In-memory store does not support arbitrary payload field filtering
          return false;
      }
      if (!_evalFilter(left, f)) return false;
    }
    return true;
  }

  int _compareBy(T a, T b, String field, bool desc) {
    int c;
    switch (field) {
      case 'id':
        c = idOf(a).toString().compareTo(idOf(b).toString());
        break;
      case 'updatedAt':
        c = a.updatedAt.compareTo(b.updatedAt);
        break;
      default:
        // Unknown fields sort as equal
        c = 0;
    }
    return desc ? -c : c;
  }

  bool _evalFilter(dynamic left, FilterOp f) {
    switch (f.op) {
      case FilterOperator.eq:
        return _cmp(left, f.value) == 0;
      case FilterOperator.neq:
        return _cmp(left, f.value) != 0;
      case FilterOperator.gt:
        return _cmp(left, f.value) > 0;
      case FilterOperator.gte:
        return _cmp(left, f.value) >= 0;
      case FilterOperator.lt:
        return _cmp(left, f.value) < 0;
      case FilterOperator.lte:
        return _cmp(left, f.value) <= 0;
      case FilterOperator.like:
        if (left is String && f.value is String) {
          return left.contains(f.value as String);
        }
        return false;
      case FilterOperator.contains:
        if (left is Iterable) {
          return (left).contains(f.value);
        }
        if (left is String && f.value is String) {
          return left.contains(f.value as String);
        }
        return false;
      case FilterOperator.isNull:
        return left == null;
      case FilterOperator.isNotNull:
        return left != null;
      case FilterOperator.inList:
        if (f.value is Iterable) {
          return (f.value as Iterable).contains(left);
        }
        return false;
    }
  }

  int _cmp(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is DateTime && b is DateTime) return a.compareTo(b);
    if (a is num && b is num) return a.compareTo(b);
    // attempt DateTime parse when strings
    if (a is String && b is String) {
      final ad = DateTime.tryParse(a);
      final bd = DateTime.tryParse(b);
      if (ad != null && bd != null) return ad.compareTo(bd);
      return a.compareTo(b);
    }
    return a.toString().compareTo(b.toString());
  }

  @override
  Future<int> updateWhere(
    SyncScope scope,
    QuerySpec spec,
    List<T> newValues,
  ) async {
    if (newValues.isEmpty) return 0;
    final matched = await queryWith(scope, spec);
    if (matched.isEmpty) return 0;
    final sk = _scopeKey(scope);
    final map = _dataOf(sk);
    final ids = matched.map(idOf).toSet();
    int count = 0;
    for (final nv in newValues) {
      if (ids.contains(idOf(nv))) {
        map[idOf(nv)] = nv;
        if (supportsSoftDelete) {
          _tombOf(sk).remove(idOf(nv));
        }
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> deleteWhere(SyncScope scope, QuerySpec spec) async {
    final matched = await queryWith(scope, spec);
    if (matched.isEmpty) return 0;
    await deleteMany(scope, matched.map(idOf).toList(growable: false));
    return matched.length;
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
    await _maybeEnforceLimit();
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
    await _maybeEnforceLimit();
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
    await _maybeEnforceLimit();
  }

  @override
  Future<void> clearPendingOps(SyncScope scope, List<String> opIds) async {
    final list = _pendingOf(_scopeKey(scope));
    final set = HashSet.of(opIds);
    list.removeWhere((e) => set.contains(e.opId));
  }

  // ---- Cache management implementation ----
  @override
  Future<int> approxCacheSizeBytes({SyncScope? scope}) async {
    int items = 0, tombs = 0, pend = 0, sps = 0;
    if (scope == null) {
      for (final sk in _data.keys) {
        items += _dataOf(sk).length;
        tombs += supportsSoftDelete ? _tombOf(sk).length : 0;
      }
      for (final sk in _pending.keys) {
        pend += _pendingOf(sk).length;
      }
      sps = _syncPoints.length;
    } else {
      final sk = _scopeKey(scope);
      items = _dataOf(sk).length;
      tombs = supportsSoftDelete ? _tombOf(sk).length : 0;
      pend = _pendingOf(sk).length;
      sps = _syncPoints.containsKey(sk) ? 1 : 0;
    }
    return items * _bytesPerItem +
        tombs * _bytesPerTomb +
        pend * _bytesPerPending +
        sps * _bytesPerSyncPoint;
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
      _data.clear();
      _tombstones.clear();
      _pending.clear();
      _syncPoints.clear();
    } else {
      final sk = _scopeKey(scope);
      _data.remove(sk);
      _tombstones.remove(sk);
      _pending.remove(sk);
      _syncPoints.remove(sk);
    }
  }

  Future<void> _maybeEnforceLimit() async {
    final limit = _sizeLimitBytes;
    if (limit == null) return;
    int current = await approxCacheSizeBytes();
    int guard = 0;
    while (current > limit && guard < 1000) {
      guard++;
      // 1) Drop oldest tombstones first across all scopes
      Id? tombToRemoveId;
      String? tombSk;
      DateTime? oldestTomb;
      if (supportsSoftDelete) {
        for (final entry in _tombstones.entries) {
          for (final tEntry in entry.value.entries) {
            if (oldestTomb == null || tEntry.value.isBefore(oldestTomb)) {
              oldestTomb = tEntry.value;
              tombToRemoveId = tEntry.key;
              tombSk = entry.key;
            }
          }
        }
      }
      if (tombToRemoveId != null && tombSk != null) {
        _tombOf(tombSk).remove(tombToRemoveId);
        current = await approxCacheSizeBytes();
        continue;
      }

      // 2) Drop oldest active items by updatedAt across all scopes
      String? targetSk;
      Id? targetId;
      DateTime? oldest;
      for (final entry in _data.entries) {
        final sk = entry.key;
        final tomb = supportsSoftDelete ? _tombOf(sk) : <Id, DateTime>{};
        for (final item in entry.value.values) {
          if (supportsSoftDelete && tomb.containsKey(idOf(item))) continue;
          if (oldest == null || item.updatedAt.isBefore(oldest)) {
            oldest = item.updatedAt;
            targetSk = sk;
            targetId = idOf(item);
          }
        }
      }
      if (targetSk != null && targetId != null) {
        _dataOf(targetSk).remove(targetId);
        if (supportsSoftDelete) {
          _tombOf(targetSk).remove(targetId);
        }
        current = await approxCacheSizeBytes();
        continue;
      }
      break; // nothing to remove
    }
  }
}
