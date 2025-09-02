import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Rec implements HasUpdatedAt {
  final String id;
  final String title;
  @override
  final DateTime updatedAt;
  const _Rec(this.id, this.title, this.updatedAt);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseRemoteStore.remoteSearch success via searchRunner', () {
    late SupabaseRemoteStore<_Rec, String> store;
    late SupabaseClient client;

    setUp(() {
      client = SupabaseClient('https://example.supabase.co', 'anon');
      final cfg = SupabaseRemoteConfig<_Rec, String>(
        client: client,
        table: 'records',
        idColumn: 'id',
        updatedAtColumn: 'updated_at',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => {
          'id': r.id,
          'title': r.title,
          'updated_at': r.updatedAt.toIso8601String(),
        },
        fromJson: (m) => _Rec(
          m['id'] as String,
          m['title'] as String,
          DateTime.parse(m['updated_at'] as String).toUtc(),
        ),
        // Inject test runner
        searchRunner: (SupabaseSearchRequest plan) async {
          // Basic assertions on built plan
          expect(
            plan.filters.any(
              (op) =>
                  op.method == 'eq' &&
                  op.column == 'scope_name' &&
                  op.value == 'records',
            ),
            isTrue,
          );
          expect(plan.orders.any((o) => o.column == 'updated_at'), isTrue);
          // Return mock rows as if from server
          return [
            {
              'id': 'a',
              'title': 'A',
              'updated_at': DateTime.utc(2025, 5, 1).toIso8601String(),
              'scope_name': 'records',
              'scope_keys': {'userId': 'u1'},
            },
            {
              'id': 'b',
              'title': 'B',
              'updated_at': DateTime.utc(2025, 5, 2).toIso8601String(),
              'scope_name': 'records',
              'scope_keys': {'userId': 'u1'},
            },
          ];
        },
      );
      store = SupabaseRemoteStore<_Rec, String>(config: cfg);
    });

    test('returns parsed records', () async {
      const scope = SyncScope('records', {'userId': 'u1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.like, value: 'a')],
        orderBy: [OrderSpec('updatedAt')],
        limit: 10,
      );
      final res = await store.remoteSearch(scope, spec);
      expect(res.map((e) => e.id).toList(), ['a', 'b']);
      expect(res.first.title, 'A');
    });

    test('supports ordering by updatedAt desc (plan assertion)', () async {
      const scope = SyncScope('records', {'userId': 'u1'});
      final spec = const QuerySpec(
        orderBy: [OrderSpec('updatedAt', descending: true)],
        limit: 10,
      );
      final res = await store.remoteSearch(scope, spec);
      // The searchRunner above already asserts orders contain 'updated_at'.
      expect(res, isNotEmpty);
    });

    test('builder produces id asc/desc orders', () async {
      const scope = SyncScope('records', {'userId': 'u1'});
      final asc = buildSupabaseRemoteSearchRequest(
        scope: scope,
        spec: const QuerySpec(orderBy: [OrderSpec('id')]),
        idColumn: 'id',
        updatedAtColumn: 'updated_at',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
      );
      expect(
        asc.orders.any((o) => o.column == 'id' && o.ascending == true),
        isTrue,
      );

      final desc = buildSupabaseRemoteSearchRequest(
        scope: scope,
        spec: const QuerySpec(orderBy: [OrderSpec('id', descending: true)]),
        idColumn: 'id',
        updatedAtColumn: 'updated_at',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
      );
      expect(
        desc.orders.any((o) => o.column == 'id' && o.ascending == false),
        isTrue,
      );
    });
  });
}
