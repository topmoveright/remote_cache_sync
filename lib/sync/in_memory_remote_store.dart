import 'store_interfaces.dart';
import 'sync_types.dart';

/// Simple in-memory RemoteStore implementation for demos/examples.
/// Not intended for production use.
class InMemoryRemoteStore<T extends HasUpdatedAt, Id>
    implements RemoteStore<T, Id> {
  final Id Function(T) idOf;

  // Per-scope data and deletion logs
  final Map<String, Map<Id, T>> _data = {};
  final Map<String, Map<Id, DateTime>> _deletions = {};

  InMemoryRemoteStore({required this.idOf});

  String _scopeKey(SyncScope scope) => '${scope.name}|${scope.keys}';
  Map<Id, T> _dataOf(String sk) => _data.putIfAbsent(sk, () => <Id, T>{});
  Map<Id, DateTime> _delOf(String sk) =>
      _deletions.putIfAbsent(sk, () => <Id, DateTime>{});

  /// Test-only utility to seed data for a given scope.
  /// This is intended solely for unit tests to control the in-memory state.
  /// It overwrites any existing entries with the same IDs in the target scope.
  void seedScope(
    SyncScope scope, {
    List<T> items = const [],
    Map<Id, DateTime> deletions = const {},
  }) {
    final sk = _scopeKey(scope);
    final map = _dataOf(sk);
    for (final it in items) {
      map[idOf(it)] = it;
    }
    final dels = _delOf(sk);
    dels.addAll(deletions);
  }

  @override
  Future<T?> getById(Id id) async {
    for (final sk in _data.keys) {
      final v = _data[sk]?[id];
      if (v != null) return v;
    }
    return null;
  }

  @override
  Future<Delta<T, Id>> fetchSince(SyncScope scope, DateTime? since) async {
    final sk = _scopeKey(scope);
    final now = await getServerTime();
    final items = _dataOf(sk).values;
    final dels = _delOf(sk);

    final upserts = since == null
        ? items.toList(growable: false)
        : items
              .where((e) => e.updatedAt.isAfter(since))
              .toList(growable: false);

    final deletes = since == null
        ? dels.keys.toList(growable: false)
        : dels.entries
              .where((e) => e.value.isAfter(since))
              .map((e) => e.key)
              .toList(growable: false);

    return Delta<T, Id>(
      upserts: upserts,
      deletes: deletes,
      serverTimestamp: now,
    );
  }

  @override
  Future<void> batchUpsert(List<T> items) async {
    if (items.isEmpty) return;
    // Items are expected to be scoped by callers consistently; we cannot infer scope.
    // For demo purposes, place them into all scopes where data already exists for the ID,
    // otherwise ignore (no-op) unless explicitly seeded.
    final byId = {for (final it in items) idOf(it): it};
    for (final entry in _data.entries) {
      final map = entry.value;
      for (final id in byId.keys) {
        final v = byId[id];
        if (v != null) {
          map[id] = v;
        }
      }
      // Clear deletion marks for upserted IDs in this scope.
      final dels = _deletions[entry.key];
      if (dels != null) {
        for (final id in byId.keys) {
          dels.remove(id);
        }
      }
    }
  }

  @override
  Future<void> batchDelete(List<Id> ids) async {
    if (ids.isEmpty) return;
    final now = await getServerTime();
    for (final sk in _data.keys) {
      final map = _data[sk]!;
      for (final id in ids) {
        map.remove(id);
        _delOf(sk)[id] = now;
      }
    }
  }

  @override
  Future<DateTime> getServerTime() async => DateTime.now().toUtc();

  @override
  Future<List<T>> remoteSearch(SyncScope scope, QuerySpec spec) async {
    // Keep validation consistent with other adapters
    if (spec.offset != null && spec.limit == null) {
      throw ArgumentError('offset requires limit for remoteSearch (InMemory)');
    }

    final sk = _scopeKey(scope);
    final items = List<T>.from(_dataOf(sk).values);

    bool match(T item) {
      for (final f in spec.filters) {
        final field = f.field;
        switch (field) {
          case 'id':
            final id = idOf(item).toString();
            switch (f.op) {
              case FilterOperator.eq:
                if (f.value is List) {
                  final list = (f.value as List)
                      .map((e) => e.toString())
                      .toList();
                  if (!list.contains(id)) return false;
                } else {
                  if (f.value is! String) {
                    throw ArgumentError('id eq expects String or List<String>');
                  }
                  if (id != f.value) return false;
                }
                break;
              case FilterOperator.neq:
                if (f.value is! String) {
                  throw ArgumentError('id neq expects String');
                }
                if (id == f.value) return false;
                break;
              case FilterOperator.inList:
                if (f.value is! List) {
                  throw ArgumentError('id inList expects List<String>');
                }
                final list = (f.value as List)
                    .map((e) => e.toString())
                    .toList();
                if (!list.contains(id)) return false;
                break;
              case FilterOperator.like:
                if (f.value is! String) {
                  throw ArgumentError('id like expects String');
                }
                if (!id.contains(f.value as String)) return false;
                break;
              default:
                throw ArgumentError('Unsupported operator for id: ${f.op}');
            }
            break;
          case 'updatedAt':
            final ts = item.updatedAt.toUtc();
            DateTime asDt(Object v) => v is DateTime
                ? v.toUtc()
                : DateTime.parse(v.toString()).toUtc();
            switch (f.op) {
              case FilterOperator.eq:
                if (f.value == null)
                  throw ArgumentError('updatedAt eq requires value');
                if (ts != asDt(f.value!)) return false;
                break;
              case FilterOperator.neq:
                if (f.value == null)
                  throw ArgumentError('updatedAt neq requires value');
                if (ts == asDt(f.value!)) return false;
                break;
              case FilterOperator.gt:
                if (f.value == null)
                  throw ArgumentError('updatedAt gt requires value');
                if (!(ts.isAfter(asDt(f.value!)))) return false;
                break;
              case FilterOperator.gte:
                if (f.value == null)
                  throw ArgumentError('updatedAt gte requires value');
                final dt = asDt(f.value!);
                if (!(ts.isAfter(dt) || ts.isAtSameMomentAs(dt))) return false;
                break;
              case FilterOperator.lt:
                if (f.value == null)
                  throw ArgumentError('updatedAt lt requires value');
                if (!(ts.isBefore(asDt(f.value!)))) return false;
                break;
              case FilterOperator.lte:
                if (f.value == null)
                  throw ArgumentError('updatedAt lte requires value');
                final dt = asDt(f.value!);
                if (!(ts.isBefore(dt) || ts.isAtSameMomentAs(dt))) return false;
                break;
              case FilterOperator.inList:
                if (f.value is! List) {
                  throw ArgumentError(
                    'updatedAt inList expects List<DateTime|String>',
                  );
                }
                final list = (f.value as List).map((e) => asDt(e)).toList();
                if (!list.contains(ts)) return false;
                break;
              default:
                throw ArgumentError(
                  'Unsupported operator for updatedAt: ${f.op}',
                );
            }
            break;
          default:
            throw ArgumentError('Unsupported filter field: $field');
        }
      }
      return true;
    }

    // Apply filters
    final filtered = items.where(match).toList();

    // Apply ordering
    int cmp(T a, T b) {
      for (final o in spec.orderBy) {
        int c = 0;
        switch (o.field) {
          case 'id':
            c = idOf(a).toString().compareTo(idOf(b).toString());
            break;
          case 'updatedAt':
            c = a.updatedAt.toUtc().compareTo(b.updatedAt.toUtc());
            break;
          default:
            throw ArgumentError('Unsupported order field: ${o.field}');
        }
        if (c != 0) return o.descending ? -c : c;
      }
      return 0;
    }

    if (spec.orderBy.isNotEmpty) {
      filtered.sort(cmp);
    }

    // Pagination
    if (spec.limit != null) {
      final start = spec.offset ?? 0;
      final end = (start + spec.limit!).clamp(0, filtered.length);
      return filtered.sublist(start.clamp(0, filtered.length), end);
    }
    return filtered;
  }
}
