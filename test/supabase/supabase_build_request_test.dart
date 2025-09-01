import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';

void main() {
  group('Supabase buildSupabaseRemoteSearchRequest', () {
    test('filters + sort + pagination map correctly (limit+offset)', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = QuerySpec(
        filters: const [
          FilterOp(field: 'id', op: FilterOperator.inList, value: ['a', 'c']),
        ],
        orderBy: const [
          OrderSpec('id', descending: true),
          OrderSpec('updatedAt'),
        ],
        limit: 25,
        offset: 50,
      );

      final plan = buildSupabaseRemoteSearchRequest(
        scope: scope,
        spec: spec,
        idColumn: 'id',
        updatedAtColumn: 'updated',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
      );

      // base scoping
      expect(
        plan.filters.any(
          (f) => f.method == 'eq' && f.column == 'scope_name' && f.value == 's',
        ),
        isTrue,
      );
      expect(
        plan.filters.any(
          (f) =>
              f.method == 'contains' &&
              f.column == 'scope_keys' &&
              f.value is Map<String, String>,
        ),
        isTrue,
      );
      // soft delete
      expect(
        plan.filters.any(
          (f) => f.method == 'isNull' && f.column == 'deleted_at',
        ),
        isTrue,
      );
      // id inList
      final idIn = plan.filters.where(
        (f) => f.method == 'in' && f.column == 'id',
      );
      expect(idIn.length, 1);
      expect(idIn.first.value, ['a', 'c']);
      // order
      expect(plan.orders.length, 2);
      expect(plan.orders[0].column, 'id');
      expect(plan.orders[0].ascending, isFalse);
      expect(plan.orders[1].column, 'updated');
      expect(plan.orders[1].ascending, isTrue);
      // pagination via range
      expect(plan.limit, isNull);
      expect(plan.rangeFrom, 50);
      expect(plan.rangeTo, 74);
    });

    test('updatedAt operators mapped with ISO formatting', () {
      final scope = SyncScope('s', {'u': '1'});
      final dt = DateTime.utc(2025, 5, 10, 12, 34, 56);
      final spec = QuerySpec(
        filters: [
          FilterOp(field: 'updatedAt', op: FilterOperator.gte, value: dt),
          const FilterOp(
            field: 'updatedAt',
            op: FilterOperator.lte,
            value: '2025-05-11T00:00:00Z',
          ),
        ],
      );

      final plan = buildSupabaseRemoteSearchRequest(
        scope: scope,
        spec: spec,
        idColumn: 'id',
        updatedAtColumn: 'updated',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
      );

      final gte = plan.filters.where(
        (f) => f.method == 'gte' && f.column == 'updated',
      );
      final lte = plan.filters.where(
        (f) => f.method == 'lte' && f.column == 'updated',
      );
      expect(gte.length, 1);
      expect(gte.first.value, dt.toUtc().toIso8601String());
      expect(lte.length, 1);
      expect(lte.first.value, '2025-05-11T00:00:00Z');
    });

    test('offset without limit throws', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(offset: 10);
      expect(
        () => buildSupabaseRemoteSearchRequest(
          scope: scope,
          spec: spec,
          idColumn: 'id',
          updatedAtColumn: 'updated',
          deletedAtColumn: 'deleted_at',
          scopeNameColumn: 'scope_name',
          scopeKeysColumn: 'scope_keys',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on unsupported filter field', () {
      final scope = SyncScope('s', {'u': '1'});
      const spec = QuerySpec(
        filters: [FilterOp(field: 'name', op: FilterOperator.eq, value: 'x')],
      );
      expect(
        () => buildSupabaseRemoteSearchRequest(
          scope: scope,
          spec: spec,
          idColumn: 'id',
          updatedAtColumn: 'updated',
          deletedAtColumn: 'deleted_at',
          scopeNameColumn: 'scope_name',
          scopeKeysColumn: 'scope_keys',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on unsupported operator for id', () {
      final scope = SyncScope('s', {'u': '1'});
      const spec = QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.gt, value: 'a')],
      );
      expect(
        () => buildSupabaseRemoteSearchRequest(
          scope: scope,
          spec: spec,
          idColumn: 'id',
          updatedAtColumn: 'updated',
          deletedAtColumn: 'deleted_at',
          scopeNameColumn: 'scope_name',
          scopeKeysColumn: 'scope_keys',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on wrong value type for id eq', () {
      final scope = SyncScope('s', {'u': '1'});
      const spec = QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.eq, value: 123)],
      );
      expect(
        () => buildSupabaseRemoteSearchRequest(
          scope: scope,
          spec: spec,
          idColumn: 'id',
          updatedAtColumn: 'updated',
          deletedAtColumn: 'deleted_at',
          scopeNameColumn: 'scope_name',
          scopeKeysColumn: 'scope_keys',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on wrong value type for updatedAt eq', () {
      final scope = SyncScope('s', {'u': '1'});
      const spec = QuerySpec(
        filters: [
          FilterOp(field: 'updatedAt', op: FilterOperator.eq, value: 42),
        ],
      );
      expect(
        () => buildSupabaseRemoteSearchRequest(
          scope: scope,
          spec: spec,
          idColumn: 'id',
          updatedAtColumn: 'updated',
          deletedAtColumn: 'deleted_at',
          scopeNameColumn: 'scope_name',
          scopeKeysColumn: 'scope_keys',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on updatedAt inList with non-list value', () {
      final scope = SyncScope('s', {'u': '1'});
      const spec = QuerySpec(
        filters: [
          FilterOp(
            field: 'updatedAt',
            op: FilterOperator.inList,
            value: '2025-05-11T00:00:00Z',
          ),
        ],
      );
      expect(
        () => buildSupabaseRemoteSearchRequest(
          scope: scope,
          spec: spec,
          idColumn: 'id',
          updatedAtColumn: 'updated',
          deletedAtColumn: 'deleted_at',
          scopeNameColumn: 'scope_name',
          scopeKeysColumn: 'scope_keys',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on unsupported order field', () {
      final scope = SyncScope('s', {'u': '1'});
      const spec = QuerySpec(orderBy: [OrderSpec('name')]);
      expect(
        () => buildSupabaseRemoteSearchRequest(
          scope: scope,
          spec: spec,
          idColumn: 'id',
          updatedAtColumn: 'updated',
          deletedAtColumn: 'deleted_at',
          scopeNameColumn: 'scope_name',
          scopeKeysColumn: 'scope_keys',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
