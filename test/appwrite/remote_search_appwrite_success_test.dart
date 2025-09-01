import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';
import 'package:appwrite/appwrite.dart' as aw;

class _Rec implements HasUpdatedAt {
  final String id;
  final String title;
  @override
  final DateTime updatedAt;
  const _Rec(this.id, this.title, this.updatedAt);
}

// Dummy databases to avoid initializing real Appwrite client in tests
class _DummyDatabases implements aw.Databases {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AppwriteRemoteStore.remoteSearch success via searchRunner', () {
    late AppwriteRemoteStore<_Rec, String> store;

    setUp(() {
      final databases = _DummyDatabases(); // searchRunner intercepts remoteSearch
      final cfg = AppwriteRemoteConfig<_Rec, String>(
        databases: databases,
        databaseId: 'db',
        collectionId: 'col',
        idField: 'id',
        updatedAtField: 'updated',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
        scopeKeysField: 'scope_keys',
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => {
          'id': r.id,
          'title': r.title,
          'updated': r.updatedAt.toIso8601String(),
        },
        fromJson: (m) => _Rec(
          m['id'] as String,
          m['title'] as String,
          DateTime.parse(m['updated'] as String).toUtc(),
        ),
        searchRunner: (queries) async {
          // Verify some query parts (either asc or desc present)
          expect(
            queries.where((q) => q.contains('orderAsc') || q.contains('orderDesc')).isNotEmpty,
            isTrue,
          );
          expect(queries, anyElement(contains('limit')));
          // Return mock rows
          return [
            {
              'id': 'x',
              'title': 'X',
              'updated': DateTime.utc(2025, 5, 1).toIso8601String(),
              'scope_name': 'records',
              'scope_keys': {'userId': 'u1'},
            },
          ];
        },
      );
      store = AppwriteRemoteStore<_Rec, String>(config: cfg);
    });

    test('returns parsed records', () async {
      const scope = SyncScope('records', {'userId': 'u1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.eq, value: 'x')],
        orderBy: [OrderSpec('updatedAt')],
        limit: 5,
      );
      final res = await store.remoteSearch(scope, spec);
      expect(res.single.id, 'x');
      expect(res.single.title, 'X');
    });

    test('supports ordering by updatedAt desc', () async {
      const scope = SyncScope('records', {'userId': 'u1'});
      final spec = const QuerySpec(
        orderBy: [OrderSpec('updatedAt', descending: true)],
        limit: 1,
      );
      // searchRunner already asserts orderAsc exists from previous test, but here we primarily
      // check that building queries with desc does not throw and returns rows.
      final res = await store.remoteSearch(scope, spec);
      expect(res, isNotEmpty);
    });

    test('supports ordering by id asc/desc (build only)', () async {
      // Build-only verification using underlying builder to avoid SDK dependencies.
      final queriesAsc = buildAppwriteRemoteSearchQueries(
        scope: const SyncScope('records', {'userId': 'u1'}),
        spec: const QuerySpec(orderBy: [OrderSpec('id')]),
        idField: 'id',
        updatedAtField: 'updated',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
      );
      expect(
        queriesAsc.any((q) => q.contains('orderAsc') && q.contains('"attribute":"id"')),
        isTrue,
      );

      final queriesDesc = buildAppwriteRemoteSearchQueries(
        scope: const SyncScope('records', {'userId': 'u1'}),
        spec: const QuerySpec(orderBy: [OrderSpec('id', descending: true)]),
        idField: 'id',
        updatedAtField: 'updated',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
      );
      expect(
        queriesDesc.any((q) => q.contains('orderDesc') && q.contains('"attribute":"id"')),
        isTrue,
      );
    });
  });
}
