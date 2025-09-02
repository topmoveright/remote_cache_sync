import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:remote_cache_sync/remote_cache_sync.dart';

class R implements HasUpdatedAt {
  final String id;
  final String title;
  @override
  final DateTime updatedAt;
  const R(this.id, this.title, this.updatedAt);
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
  group('DriftLocalStore persistence', () {
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
          'updatedAt': r.updatedAt.toIso8601String(),
        },
        fromJson: (m) => R(
          m['id'] as String,
          m['title'] as String,
          DateTime.parse(m['updatedAt'] as String).toUtc(),
        ),
        supportsSoftDelete: true,
      );
    });

    test('upsert/query and soft delete behavior', () async {
      // Use 2025 baseline year per project testing rule
      final r1 = R('a', 'A', DateTime.utc(2025, 1, 1));
      final r2 = R('b', 'B', DateTime.utc(2025, 1, 2));
      await store.upsertMany(scope, [r1, r2]);

      final list = await store.query(scope);
      expect(list.map((e) => e.id), containsAll(['a', 'b']));

      await store.deleteMany(scope, ['a']);
      final after = await store.query(scope);
      expect(after.map((e) => e.id), isNot(contains('a')));
      expect(after.map((e) => e.id), contains('b'));

      // querySince excludes deleted items
      final since = DateTime.utc(2025, 1, 1).subtract(const Duration(minutes: 1));
      final sinceList = await store.querySince(scope, since);
      expect(sinceList.map((e) => e.id), isNot(contains('a')));
    });

    test('sync point is persisted', () async {
      final ts = DateTime.utc(2025, 2, 3, 4, 5, 6);
      await store.saveSyncPoint(scope, ts);
      final got = await store.getSyncPoint(scope);
      expect(got?.toIso8601String(), ts.toIso8601String());

      // New store instance (same DB) should read the same value
      final store2 = DriftLocalStore<R, String>(
        db: db,
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => {
          'id': r.id,
          'title': r.title,
          'updatedAt': r.updatedAt.toIso8601String(),
        },
        fromJson: (m) => R(
          m['id'] as String,
          m['title'] as String,
          DateTime.parse(m['updatedAt'] as String).toUtc(),
        ),
      );
      final got2 = await store2.getSyncPoint(scope);
      expect(got2?.toIso8601String(), ts.toIso8601String());
    });

    test('pending ops enqueue and clear persists', () async {
      final op = PendingOp<R, String>(
        opId: 'op1',
        scope: scope,
        type: PendingOpType.create,
        id: 'x',
        payload: R('x', 'X', DateTime.now().toUtc()),
        updatedAt: DateTime.now().toUtc(),
      );
      await store.enqueuePendingOp(op);
      final list = await store.getPendingOps(scope);
      expect(list.map((e) => e.opId), contains('op1'));

      await store.clearPendingOps(scope, const ['op1']);
      final after = await store.getPendingOps(scope);
      expect(after, isEmpty);
    });
  });
}
