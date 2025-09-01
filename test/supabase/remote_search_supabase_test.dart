import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Supabase remoteSearch throws when offset provided without limit', () async {
    final dummy = SupabaseClient('http://localhost', 'anon');
    final store = SupabaseRemoteStore<MapRecord, String>(
      config: SupabaseRemoteConfig<MapRecord, String>(
        client: dummy,
        table: 't',
        idColumn: 'id',
        updatedAtColumn: 'updated_at',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => r.data,
        fromJson: (m) => MapRecord(m['id'] as String, m),
      ),
    );

    final scope = SyncScope('s', {'u': '1'});
    final spec = const QuerySpec(offset: 5);

    expect(
      () => store.remoteSearch(scope, spec),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('Supabase remoteSearch throws on unsupported filter field', () async {
    final dummy = SupabaseClient('http://localhost', 'anon');
    final store = SupabaseRemoteStore<MapRecord, String>(
      config: SupabaseRemoteConfig<MapRecord, String>(
        client: dummy,
        table: 't',
        idColumn: 'id',
        updatedAtColumn: 'updated_at',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => r.data,
        fromJson: (m) => MapRecord(m['id'] as String, m),
      ),
    );

    final scope = SyncScope('s', {'u': '1'});
    const spec = QuerySpec(filters: [FilterOp(field: 'name', op: FilterOperator.eq, value: 'x')]);
    expect(() => store.remoteSearch(scope, spec), throwsArgumentError);
  });

  test('Supabase remoteSearch throws on unsupported order field', () async {
    final dummy = SupabaseClient('http://localhost', 'anon');
    final store = SupabaseRemoteStore<MapRecord, String>(
      config: SupabaseRemoteConfig<MapRecord, String>(
        client: dummy,
        table: 't',
        idColumn: 'id',
        updatedAtColumn: 'updated_at',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
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

  test('Supabase remoteSearch throws on invalid updatedAt value type', () async {
    final dummy = SupabaseClient('http://localhost', 'anon');
    final store = SupabaseRemoteStore<MapRecord, String>(
      config: SupabaseRemoteConfig<MapRecord, String>(
        client: dummy,
        table: 't',
        idColumn: 'id',
        updatedAtColumn: 'updated_at',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => r.data,
        fromJson: (m) => MapRecord(m['id'] as String, m),
      ),
    );

    final scope = SyncScope('s', {'u': '1'});
    const spec = QuerySpec(
      filters: [FilterOp(field: 'updatedAt', op: FilterOperator.eq, value: 123)],
    );
    expect(() => store.remoteSearch(scope, spec), throwsArgumentError);
  });
}

class MapRecord implements HasUpdatedAt {
  final String id;
  final Map<String, dynamic> data;
  @override
  final DateTime updatedAt;
  MapRecord(this.id, this.data) : updatedAt = DateTime.now().toUtc();
}
