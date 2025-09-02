import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';

class R implements HasUpdatedAt {
  final String id;
  @override
  final DateTime updatedAt;
  const R(this.id, this.updatedAt);
}

void main() {
  group('InMemoryLocalStore QuerySpec (id/updatedAt only)', () {
    late InMemoryLocalStore<R, String> store;
    const scope = SyncScope('records', {'userId': 'u1'});

    setUp(() {
      store = InMemoryLocalStore<R, String>(idOf: (r) => r.id);
    });

    test('queryWith by id inList + order + limit/offset', () async {
      final now = DateTime.now().toUtc();
      await store.upsertMany(scope, [
        R('a', now.subtract(const Duration(minutes: 3))),
        R('b', now.subtract(const Duration(minutes: 2))),
        R('c', now.subtract(const Duration(minutes: 1))),
        R('d', now),
      ]);

      final spec = QuerySpec(
        filters: const [
          FilterOp(
            field: 'id',
            op: FilterOperator.inList,
            value: ['a', 'c', 'd'],
          ),
        ],
        orderBy: const [OrderSpec('id', descending: true)],
        limit: 2,
        offset: 0,
      );
      final res = await store.queryWith(scope, spec);
      expect(res.map((e) => e.id).toList(), ['d', 'c']);

      // pagination next page
      final res2 = await store.queryWith(
        scope,
        const QuerySpec(
          filters: [
            FilterOp(
              field: 'id',
              op: FilterOperator.inList,
              value: ['a', 'c', 'd'],
            ),
          ],
          orderBy: [OrderSpec('id', descending: true)],
          limit: 2,
          offset: 2,
        ),
      );
      expect(res2.map((e) => e.id).toList(), ['a']);
    });

    test('updateWhere/deleteWhere by id', () async {
      final now = DateTime.now().toUtc();
      await store.upsertMany(scope, [R('x', now), R('y', now)]);

      final changed = await store.updateWhere(
        scope,
        const QuerySpec(
          filters: [FilterOp(field: 'id', op: FilterOperator.eq, value: 'x')],
        ),
        [R('x', now.add(const Duration(seconds: 1)))],
      );
      expect(changed, 1);

      final after = await store.queryWith(
        scope,
        const QuerySpec(
          filters: [FilterOp(field: 'id', op: FilterOperator.eq, value: 'x')],
        ),
      );
      expect(after.single.updatedAt.isAfter(now), isTrue);

      final deleted = await store.deleteWhere(
        scope,
        const QuerySpec(
          filters: [FilterOp(field: 'id', op: FilterOperator.eq, value: 'y')],
        ),
      );
      expect(deleted, 1);
      final remain = await store.query(scope);
      expect(remain.map((e) => e.id), contains('x'));
      expect(remain.map((e) => e.id), isNot(contains('y')));
    });
  });
}
