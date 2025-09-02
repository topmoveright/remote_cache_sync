import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  test(
    'PocketBase remoteSearch throws when offset provided without limit',
    () async {
      final client = PocketBase('http://localhost');
      final store = PocketBaseRemoteStore<MapRecord, String>(
        config: PocketBaseRemoteConfig<MapRecord, String>(
          client: client,
          collection: 'c',
          idField: 'id',
          updatedAtField: 'updated',
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

  test('PocketBase remoteSearch throws on unsupported filter field', () async {
    final client = PocketBase('http://localhost');
    final store = PocketBaseRemoteStore<MapRecord, String>(
      config: PocketBaseRemoteConfig<MapRecord, String>(
        client: client,
        collection: 'c',
        idField: 'id',
        updatedAtField: 'updated',
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

  test('PocketBase remoteSearch throws on unsupported order field', () async {
    final client = PocketBase('http://localhost');
    final store = PocketBaseRemoteStore<MapRecord, String>(
      config: PocketBaseRemoteConfig<MapRecord, String>(
        client: client,
        collection: 'c',
        idField: 'id',
        updatedAtField: 'updated',
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
    'PocketBase remoteSearch throws on invalid updatedAt value type',
    () async {
      final client = PocketBase('http://localhost');
      final store = PocketBaseRemoteStore<MapRecord, String>(
        config: PocketBaseRemoteConfig<MapRecord, String>(
          client: client,
          collection: 'c',
          idField: 'id',
          updatedAtField: 'updated',
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

  test(
    'PocketBase remoteSearch throws when offset is not a multiple of limit',
    () async {
      final client = PocketBase('http://localhost');
      final store = PocketBaseRemoteStore<MapRecord, String>(
        config: PocketBaseRemoteConfig<MapRecord, String>(
          client: client,
          collection: 'c',
          idField: 'id',
          updatedAtField: 'updated',
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
      final spec = const QuerySpec(limit: 10, offset: 7); // not multiple of 10

      expect(
        () => store.remoteSearch(scope, spec),
        throwsA(isA<ArgumentError>()),
      );
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
