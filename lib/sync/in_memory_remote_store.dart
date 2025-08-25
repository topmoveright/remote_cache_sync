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
}
