import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';

class R implements HasUpdatedAt {
  final String id;
  final String title;
  @override
  final DateTime updatedAt;
  const R(this.id, this.title, this.updatedAt);
}

void main() {
  group('SimpleSyncOrchestrator.readWith', () {
    late InMemoryLocalStore<R, String> local;
    late InMemoryRemoteStore<R, String> remote;
    late SimpleSyncOrchestrator<R, String> orch;
    const scope = SyncScope('records', {'userId': 'u1'});

    setUp(() async {
      local = InMemoryLocalStore<R, String>(idOf: (r) => r.id);
      remote = InMemoryRemoteStore<R, String>(idOf: (r) => r.id);
      // Seed remote scope maps so batchUpsert/fetchSince affect this scope
      await remote.fetchSince(scope, null);
      orch = SimpleSyncOrchestrator<R, String>(
        local: local,
        remote: remote,
        resolver: const LastWriteWinsResolver<R>(),
        idOf: (r) => r.id,
      );
    });

    test('offlineOnly evaluates only local cache', () async {
      // Local has items, remote has different items which should be ignored.
      final t2025 = DateTime.utc(2025, 1, 1);
      await local.upsertMany(scope, [
        R('L1', 'local-1', t2025),
        R('L2', 'local-2', t2025.add(const Duration(minutes: 1))),
      ]);
      await remote.batchUpsert([
        R('R1', 'remote-1', t2025.add(const Duration(minutes: 2))),
      ]);

      final spec = QuerySpec(
        filters: [
          FilterOp(field: 'updatedAt', op: FilterOperator.gte, value: t2025),
        ],
        orderBy: [OrderSpec('updatedAt', descending: false)],
      );

      final items = await orch.readWith(
        scope,
        spec,
        policy: CachePolicy.offlineOnly,
      );
      expect(items.map((e) => e.id), containsAll(['L1', 'L2']));
      expect(items.any((e) => e.id == 'R1'), isFalse);
    });

    test(
      'localFirst returns local immediately and triggers background sync',
      () async {
        final base = DateTime.utc(2025, 2, 1);
        // Local has one item, remote has another item which should appear after sync.
        await local.upsertMany(scope, [R('L1', 'local', base)]);
        await remote.batchUpsert([
          R('R1', 'remote', base.add(const Duration(minutes: 1))),
        ]);

        final spec = QuerySpec(
          filters: [
            FilterOp(field: 'updatedAt', op: FilterOperator.gte, value: base),
          ],
        );

        final first = await orch.readWith(
          scope,
          spec,
          policy: CachePolicy.localFirst,
        );
        expect(first.map((e) => e.id), contains('L1')); // immediate local

        // Allow background sync to complete
        await orch.synchronize(scope);
        final after = await local.queryWith(scope, spec);
        expect(after.map((e) => e.id), containsAll(['L1', 'R1']));
      },
    );

    test('remoteFirst syncs then evaluates locally', () async {
      final base = DateTime.utc(2025, 3, 1);
      await remote.batchUpsert([
        R('R1', 'remote-1', base),
        R('R2', 'remote-2', base.add(const Duration(minutes: 1))),
      ]);

      final spec = QuerySpec(
        filters: [
          FilterOp(field: 'updatedAt', op: FilterOperator.gte, value: base),
        ],
        orderBy: [OrderSpec('updatedAt', descending: true)],
        limit: 1,
      );

      final items = await orch.readWith(
        scope,
        spec,
        policy: CachePolicy.remoteFirst,
      );
      expect(items.length, 1);
      expect(items.first.id, 'R2');
    });

    test(
      'preferRemoteEval upserts remote-evaluated results before local evaluation',
      () async {
        final base = DateTime.utc(2025, 4, 1);
        await remote.batchUpsert([
          R('R1', 'title-A', base),
          R('R2', 'title-B', base.add(const Duration(minutes: 1))),
        ]);

        final spec = QuerySpec(
          filters: [
            FilterOp(field: 'updatedAt', op: FilterOperator.gte, value: base),
          ],
          orderBy: [OrderSpec('updatedAt', descending: false)],
        );

        final items = await orch.readWith(
          scope,
          spec,
          policy: CachePolicy.remoteFirst,
          preferRemoteEval: true,
        );

        // After preferRemoteEval, local should contain the remote-evaluated rows
        final localNow = await local.queryWith(scope, spec);
        expect(localNow.map((e) => e.id), containsAll(['R1', 'R2']));
        expect(items.map((e) => e.id), containsAll(['R1', 'R2']));
      },
    );
  });
}
