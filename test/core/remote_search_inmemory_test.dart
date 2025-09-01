import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';

class MapRecord implements HasUpdatedAt {
  final String id;
  final Map<String, dynamic> data;
  @override
  final DateTime updatedAt;
  MapRecord(this.id, this.updatedAt, [Map<String, dynamic>? m])
    : data = (m ?? {})
        ..addAll({'id': id, 'updated_at': updatedAt.toIso8601String()});
}

void main() {
  group('InMemory remoteSearch success cases', () {
    late InMemoryRemoteStore<MapRecord, String> store;
    final scope = SyncScope('s', {'u': '1'});
    final base = DateTime.utc(2025, 01, 01, 00, 00, 00);

    final a = MapRecord('a', base.add(const Duration(seconds: 1)));
    final b = MapRecord('b', base.add(const Duration(seconds: 2)));
    final c = MapRecord('c', base.add(const Duration(seconds: 3)));

    setUp(() {
      store = InMemoryRemoteStore<MapRecord, String>(idOf: (r) => r.id);
      store.seedScope(scope, items: [a, b, c]);
    });

    test('filter by id eq (single)', () async {
      final res = await store.remoteSearch(
        scope,
        const QuerySpec(
          filters: [FilterOp(field: 'id', op: FilterOperator.eq, value: 'b')],
        ),
      );
      expect(res.map((e) => e.id).toList(), ['b']);
    });

    test('filter by id inList', () async {
      final res = await store.remoteSearch(
        scope,
        const QuerySpec(
          filters: [
            FilterOp(field: 'id', op: FilterOperator.inList, value: ['a', 'c']),
          ],
          orderBy: [OrderSpec('id')],
        ),
      );
      expect(res.map((e) => e.id).toList(), ['a', 'c']);
    });

    test('filter by id like', () async {
      final res = await store.remoteSearch(
        scope,
        const QuerySpec(
          filters: [FilterOp(field: 'id', op: FilterOperator.like, value: 'b')],
        ),
      );
      expect(res.map((e) => e.id).toList(), ['b']);
    });

    test('filter by updatedAt gt', () async {
      final res = await store.remoteSearch(
        scope,
        QuerySpec(
          filters: [
            FilterOp(
              field: 'updatedAt',
              op: FilterOperator.gt,
              value: base.add(const Duration(seconds: 1)),
            ),
          ],
          orderBy: const [OrderSpec('updatedAt')],
        ),
      );
      expect(res.map((e) => e.id).toList(), ['b', 'c']);
    });

    test('order by updatedAt desc then id', () async {
      final res = await store.remoteSearch(
        scope,
        const QuerySpec(
          orderBy: [OrderSpec('updatedAt', descending: true), OrderSpec('id')],
        ),
      );
      expect(res.map((e) => e.id).toList(), ['c', 'b', 'a']);
    });

    test('pagination with limit/offset', () async {
      final res = await store.remoteSearch(
        scope,
        const QuerySpec(orderBy: [OrderSpec('id')], limit: 2, offset: 1),
      );
      // ordered by id => a, b, c; slice from 1 of length 2 => b, c
      expect(res.map((e) => e.id).toList(), ['b', 'c']);
    });
  });
}
