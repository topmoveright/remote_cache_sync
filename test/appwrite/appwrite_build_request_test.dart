import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';

void main() {
  group('Appwrite buildRemoteSearchQueries', () {
    test('filters + sort + pagination map correctly', () {
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

      final queries = buildAppwriteRemoteSearchQueries(
        scope: scope,
        spec: spec,
        idField: 'id',
        updatedAtField: 'updated',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
      );

      // base + soft delete
      expect(queries, anyElement(contains("\"method\":\"equal\"")));
      expect(queries, anyElement(contains("\"attribute\":\"scope_name\"")));
      expect(queries, anyElement(contains("\"values\":[\"s\"]")));
      expect(queries, anyElement(contains("\"method\":\"isNull\"")));
      expect(queries, anyElement(contains("\"attribute\":\"deleted_at\"")));

      // id inList
      expect(queries, anyElement(contains("\"attribute\":\"id\"")));
      expect(queries, anyElement(contains("\"values\":[\"a\",\"c\"]")));

      // order
      expect(queries, anyElement(contains("\"method\":\"orderDesc\"")));
      expect(queries, anyElement(contains("\"attribute\":\"id\"")));
      expect(queries, anyElement(contains("\"method\":\"orderAsc\"")));
      expect(queries, anyElement(contains("\"attribute\":\"updated\"")));

      // pagination
      expect(queries, anyElement(contains("\"method\":\"limit\"")));
      expect(queries, anyElement(contains("\"values\":[25]")));
      expect(queries, anyElement(contains("\"method\":\"offset\"")));
      expect(queries, anyElement(contains("\"values\":[50]")));
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

      final queries = buildAppwriteRemoteSearchQueries(
        scope: scope,
        spec: spec,
        idField: 'id',
        updatedAtField: 'updated',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
      );
      expect(queries, anyElement(contains("\"method\":\"greaterThanEqual\"")));
      expect(queries, anyElement(contains("\"attribute\":\"updated\"")));
      expect(queries, anyElement(contains("${dt.toUtc().toIso8601String()}")));
      expect(queries, anyElement(contains("\"method\":\"lessThanEqual\"")));
      expect(queries, anyElement(contains("2025-05-11T00:00:00Z")));
    });

    test('throws when offset provided without limit', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(limit: null, offset: 10);
      expect(
        () => buildAppwriteRemoteSearchQueries(
          scope: scope,
          spec: spec,
          idField: 'id',
          updatedAtField: 'updated',
          deletedAtField: 'deleted_at',
          scopeNameField: 'scope_name',
        ),
        throwsArgumentError,
      );
    });

    test('throws on unsupported filter field', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'name', op: FilterOperator.eq, value: 'x')],
      );
      expect(
        () => buildAppwriteRemoteSearchQueries(
          scope: scope,
          spec: spec,
          idField: 'id',
          updatedAtField: 'updated',
          deletedAtField: 'deleted_at',
          scopeNameField: 'scope_name',
        ),
        throwsArgumentError,
      );
    });

    test('throws on unsupported operator for id', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.gt, value: 'a')],
      );
      expect(
        () => buildAppwriteRemoteSearchQueries(
          scope: scope,
          spec: spec,
          idField: 'id',
          updatedAtField: 'updated',
          deletedAtField: 'deleted_at',
          scopeNameField: 'scope_name',
        ),
        throwsArgumentError,
      );
    });

    test('throws on wrong value type for id eq', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.eq, value: 123)],
      );
      expect(
        () => buildAppwriteRemoteSearchQueries(
          scope: scope,
          spec: spec,
          idField: 'id',
          updatedAtField: 'updated',
          deletedAtField: 'deleted_at',
          scopeNameField: 'scope_name',
        ),
        throwsArgumentError,
      );
    });

    test('throws on wrong value type for updatedAt (non ISO/non DateTime)', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [
          FilterOp(field: 'updatedAt', op: FilterOperator.eq, value: 42),
        ],
      );
      expect(
        () => buildAppwriteRemoteSearchQueries(
          scope: scope,
          spec: spec,
          idField: 'id',
          updatedAtField: 'updated',
          deletedAtField: 'deleted_at',
          scopeNameField: 'scope_name',
        ),
        throwsArgumentError,
      );
    });

    test('throws on updatedAt inList with non-list value', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [
          FilterOp(
            field: 'updatedAt',
            op: FilterOperator.inList,
            value: '2025-05-11T00:00:00Z',
          ),
        ],
      );
      expect(
        () => buildAppwriteRemoteSearchQueries(
          scope: scope,
          spec: spec,
          idField: 'id',
          updatedAtField: 'updated',
          deletedAtField: 'deleted_at',
          scopeNameField: 'scope_name',
        ),
        throwsArgumentError,
      );
    });

    test('throws on unsupported order field', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(orderBy: [OrderSpec('name')]);
      expect(
        () => buildAppwriteRemoteSearchQueries(
          scope: scope,
          spec: spec,
          idField: 'id',
          updatedAtField: 'updated',
          deletedAtField: 'deleted_at',
          scopeNameField: 'scope_name',
        ),
        throwsArgumentError,
      );
    });
  });
}

class MapRecord implements HasUpdatedAt {
  final String id;
  final Map<String, dynamic> data;
  @override
  final DateTime updatedAt;
  MapRecord(this.id, this.data) : updatedAt = DateTime.now().toUtc();
}
