import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';
import 'package:appwrite/appwrite.dart' as aw;

class _DummyDatabases implements aw.Databases {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'Appwrite remoteSearch throws when offset provided without limit',
    () async {
      final db = _DummyDatabases();
      final store = AppwriteRemoteStore<MapRecord, String>(
        config: AppwriteRemoteConfig<MapRecord, String>(
          databases: db,
          databaseId: 'db',
          collectionId: 'col',
          idField: 'id',
          updatedAtField: 'updated_at',
          deletedAtField: 'deleted_at',
          scopeNameField: 'scope_name',
          scopeKeysField: 'scope_keys',
          idOf: (r) => r.id,
          idToString: (s) => s,
          idFromString: (s) => s,
          toJson: (r) => r.data,
          fromJson: (m) => MapRecord(m['id'] as String, m),
        ),
      );

      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(offset: 1);

      expect(
        () => store.remoteSearch(scope, spec),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test('Appwrite remoteSearch throws on unsupported filter field', () async {
    final db = _DummyDatabases();
    final store = AppwriteRemoteStore<MapRecord, String>(
      config: AppwriteRemoteConfig<MapRecord, String>(
        databases: db,
        databaseId: 'db',
        collectionId: 'col',
        idField: 'id',
        updatedAtField: 'updated_at',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
        scopeKeysField: 'scope_keys',
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => r.data,
        fromJson: (m) => MapRecord(m['id'] as String, m),
      ),
    );

    final scope = SyncScope('s', {'u': '1'});
    const spec = QuerySpec(
      filters: [FilterOp(field: 'name', op: FilterOperator.eq, value: 'x')],
    );
    expect(() => store.remoteSearch(scope, spec), throwsArgumentError);
  });

  test('Appwrite remoteSearch throws on unsupported order field', () async {
    final db = _DummyDatabases();
    final store = AppwriteRemoteStore<MapRecord, String>(
      config: AppwriteRemoteConfig<MapRecord, String>(
        databases: db,
        databaseId: 'db',
        collectionId: 'col',
        idField: 'id',
        updatedAtField: 'updated_at',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
        scopeKeysField: 'scope_keys',
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => r.data,
        fromJson: (m) => MapRecord(m['id'] as String, m),
      ),
    );

    final scope = SyncScope('s', {'u': '1'});
    const spec = QuerySpec(orderBy: [OrderSpec('name')]);
    expect(() => store.remoteSearch(scope, spec), throwsArgumentError);
  });

  test(
    'Appwrite remoteSearch throws on invalid updatedAt value type',
    () async {
      final db = _DummyDatabases();
      final store = AppwriteRemoteStore<MapRecord, String>(
        config: AppwriteRemoteConfig<MapRecord, String>(
          databases: db,
          databaseId: 'db',
          collectionId: 'col',
          idField: 'id',
          updatedAtField: 'updated_at',
          deletedAtField: 'deleted_at',
          scopeNameField: 'scope_name',
          scopeKeysField: 'scope_keys',
          idOf: (r) => r.id,
          idToString: (s) => s,
          idFromString: (s) => s,
          toJson: (r) => r.data,
          fromJson: (m) => MapRecord(m['id'] as String, m),
        ),
      );

      final scope = SyncScope('s', {'u': '1'});
      const spec = QuerySpec(
        filters: [
          FilterOp(field: 'updatedAt', op: FilterOperator.eq, value: 123),
        ],
      );
      expect(() => store.remoteSearch(scope, spec), throwsArgumentError);
    },
  );
}

class MapRecord implements HasUpdatedAt {
  final String id;
  final Map<String, dynamic> data;
  @override
  final DateTime updatedAt;
  MapRecord(this.id, this.data) : updatedAt = DateTime.now().toUtc();
}
