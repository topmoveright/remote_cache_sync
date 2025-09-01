import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:remote_cache_sync/remote_cache_sync.dart';

class R implements HasUpdatedAt {
  final String id;
  final String title;
  final String status;
  final int count;
  final List<String> tags;
  @override
  final DateTime updatedAt;
  const R(this.id, this.title, this.status, this.count, this.tags, this.updatedAt);
}

Future<void> _clearAll(LocalDriftDatabase db) async {
  await (db.delete(db.items)).go();
  await (db.delete(db.pendingOps)).go();
  await (db.delete(db.syncPoints)).go();
}

void main() {
  // Required for drift_flutter/path_provider in tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    // Suppress multiple database warning in tests where the same executor can be reused.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('DriftLocalStore QuerySpec', () {
    late LocalDriftDatabase db;
    late DriftLocalStore<R, String> store;
    const scope = SyncScope('records', {'userId': 'u1'});

    setUp(() async {
      db = LocalDriftDatabase.forTesting();
      await _clearAll(db);
      store = DriftLocalStore<R, String>(
        db: db,
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => {
          'id': r.id,
          'title': r.title,
          'status': r.status,
          'count': r.count,
          'tags': r.tags,
          'updatedAt': r.updatedAt.toIso8601String(),
        },
        fromJson: (m) => R(
          m['id'] as String,
          m['title'] as String,
          m['status'] as String,
          m['count'] as int,
          (m['tags'] as List).cast<String>(),
          DateTime.parse(m['updatedAt'] as String).toUtc(),
        ),
        supportsSoftDelete: true,
      );
    });

    test('queryWith: payload filters + order + limit/offset', () async {
      final now = DateTime.now().toUtc();
      final items = <R>[
        R('a', 'Alpha', 'open', 5, ['x','y'], now.subtract(const Duration(minutes: 3))),
        R('b', 'Beta', 'open', 10, ['y'], now.subtract(const Duration(minutes: 2))),
        R('c', 'Gamma', 'closed', 2, ['z'], now.subtract(const Duration(minutes: 1))),
        R('d', 'Alpine', 'open', 8, ['x','z'], now),
      ];
      await store.upsertMany(scope, items);

      // status == 'open' AND count > 5, order by count desc, limit 2
      final spec = QuerySpec(
        filters: const [
          FilterOp(field: 'status', op: FilterOperator.eq, value: 'open'),
          FilterOp(field: 'count', op: FilterOperator.gt, value: 5),
        ],
        orderBy: const [OrderSpec('count', descending: true)],
        limit: 2,
      );
      final res = await store.queryWith(scope, spec);
      expect(res.map((e) => e.id).toList(), ['b', 'd']);

      // like on title, contains on tags, inList on status
      final spec2 = QuerySpec(
        filters: const [
          FilterOp(field: 'title', op: FilterOperator.like, value: 'Al'),
          FilterOp(field: 'tags', op: FilterOperator.contains, value: 'x'),
          FilterOp(field: 'status', op: FilterOperator.inList, value: ['open','closed']),
        ],
        orderBy: const [OrderSpec('id')],
      );
      final res2 = await store.queryWith(scope, spec2);
      expect(res2.map((e) => e.id).toList(), ['a', 'd']);
    });

    test('updateWhere/deleteWhere work with spec', () async {
      final now = DateTime.now().toUtc();
      await store.upsertMany(scope, [
        R('x', 'X', 'open', 1, [], now),
        R('y', 'Y', 'open', 1, [], now),
      ]);

      // updateWhere: only ids that match spec should be updated
      final spec = QuerySpec(filters: const [FilterOp(field: 'id', op: FilterOperator.inList, value: ['x'])]);
      final changed = await store.updateWhere(scope, spec, [
        R('x', 'X2', 'open', 1, [], now.add(const Duration(seconds: 1))),
        R('z', 'Z', 'open', 1, [], now), // should be ignored
      ]);
      expect(changed, 1);
      final after = await store.queryWith(scope, QuerySpec(filters: const [FilterOp(field: 'id', op: FilterOperator.eq, value: 'x')]));
      expect(after.single.title, 'X2');

      // deleteWhere by id
      final deleted = await store.deleteWhere(scope, QuerySpec(filters: const [FilterOp(field: 'id', op: FilterOperator.eq, value: 'y')])) ;
      expect(deleted, 1);
      final remain = await store.query(scope);
      expect(remain.map((e) => e.id), contains('x'));
      expect(remain.map((e) => e.id), isNot(contains('y')));
    });
  });
}
