import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('PocketBase buildRemoteSearchRequest', () {
    late PocketBaseRemoteStore<MapRecord, String> store;

    setUp(() {
      final client = PocketBase('http://localhost');
      store = PocketBaseRemoteStore<MapRecord, String>(
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
    });

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
        limit: 10,
        offset: 20,
      );

      final req = store.buildRemoteSearchRequest(scope, spec);

      // filter should include scope name, deleted_at null, id inList formatted with ||
      expect(req.$1.contains("scope_name='s'"), isTrue);
      expect(req.$1.contains('deleted_at = null'), isTrue);
      expect(req.$1.contains("(id='a' || id='c')"), isTrue);

      // sort should map to PocketBase format
      expect(req.$2, equals('-id,updated'));

      // pagination: limit 10, offset 20 => page 3, perPage 10
      expect(req.$3, equals(3));
      expect(req.$4, equals(10));
    });

    test('updatedAt filters map to ISO and operators', () {
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

      final req = store.buildRemoteSearchRequest(scope, spec);
      expect(
        req.$1.contains("updated>='${dt.toUtc().toIso8601String()}'"),
        isTrue,
      );
      expect(req.$1.contains("updated<='2025-05-11T00:00:00Z'"), isTrue);
    });

    test('offset without limit throws', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(limit: null, offset: 10);
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
        throwsArgumentError,
      );
    });

    test(
      'offset must be a multiple of limit (PocketBase paging constraint)',
      () {
        final scope = SyncScope('s', {'u': '1'});
        final spec = const QuerySpec(limit: 10, offset: 15);
        expect(
          () => store.buildRemoteSearchRequest(scope, spec),
          throwsArgumentError,
        );
      },
    );

    test('unsupported filter field throws', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'name', op: FilterOperator.eq, value: 'a')],
      );
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
        throwsArgumentError,
      );
    });

    test('id eq expects String or List<String>', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.eq, value: 123)],
      );
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
        throwsArgumentError,
      );
    });

    test('id neq expects String', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.neq, value: 123)],
      );
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
        throwsArgumentError,
      );
    });

    test('id like expects String', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.like, value: 5)],
      );
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
        throwsArgumentError,
      );
    });

    test('id inList expects List<String>', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.inList, value: 'x')],
      );
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
        throwsArgumentError,
      );
    });

    test('unsupported operator for id throws', () {
      // use an operator not handled for id (e.g., gt)
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(
        filters: [FilterOp(field: 'id', op: FilterOperator.gt, value: 'a')],
      );
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
        throwsArgumentError,
      );
    });

    test('updatedAt requires value for comparison operators', () {
      final scope = SyncScope('s', {'u': '1'});
      for (final op in const [
        FilterOperator.eq,
        FilterOperator.neq,
        FilterOperator.gt,
        FilterOperator.gte,
        FilterOperator.lt,
        FilterOperator.lte,
      ]) {
        final spec = QuerySpec(
          filters: [FilterOp(field: 'updatedAt', op: op, value: null)],
        );
        expect(
          () => store.buildRemoteSearchRequest(scope, spec),
          throwsArgumentError,
        );
      }
    });

    test('updatedAt value type validation', () {
      final scope = SyncScope('s', {'u': '1'});
      // invalid single value type
      var spec = const QuerySpec(
        filters: [
          FilterOp(field: 'updatedAt', op: FilterOperator.eq, value: 123),
        ],
      );
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
        throwsArgumentError,
      );
      // invalid list element types
      spec = QuerySpec(
        filters: [
          FilterOp(
            field: 'updatedAt',
            op: FilterOperator.inList,
            value: [DateTime.utc(2025, 1, 1), 123],
          ),
        ],
      );
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
        throwsArgumentError,
      );
    });

    test('unsupported order field throws', () {
      final scope = SyncScope('s', {'u': '1'});
      final spec = const QuerySpec(orderBy: [OrderSpec('name')]);
      expect(
        () => store.buildRemoteSearchRequest(scope, spec),
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
