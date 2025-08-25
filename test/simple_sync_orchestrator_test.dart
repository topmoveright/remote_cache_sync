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
  group('SimpleSyncOrchestrator', () {
    late InMemoryLocalStore<R, String> local;
    late InMemoryRemoteStore<R, String> remote;
    late SimpleSyncOrchestrator<R, String> orch;
    const scope = SyncScope('records', {'userId': 'u1'});

    setUp(() async {
      local = InMemoryLocalStore<R, String>(idOf: (r) => r.id);
      remote = InMemoryRemoteStore<R, String>(idOf: (r) => r.id);
      // Seed remote scope maps so batchUpsert/batchDelete affect this scope
      await remote.fetchSince(scope, null);
      orch = SimpleSyncOrchestrator<R, String>(
        local: local,
        remote: remote,
        resolver: const LastWriteWinsResolver<R>(),
        idOf: (r) => r.id,
      );
    });

    test(
      'enqueueCreate + synchronize pushes to remote and clears pending',
      () async {
        final now = DateTime.now().toUtc();
        final r = R('id1', 'A', now);

        await orch.enqueueCreate(scope, r.id, r);
        await orch.synchronize(scope);

        // Local contains the item
        final localItems = await local.query(scope);
        expect(localItems.map((e) => e.id), contains(r.id));

        // Remote delta with since=null contains the item as upsert
        final delta = await remote.fetchSince(scope, null);
        expect(delta.upserts.map((e) => e.id), contains(r.id));

        // Pending cleared
        final pending = await local.getPendingOps(scope);
        expect(pending, isEmpty);

        // Sync point saved close to server time (within a few seconds)
        final sp = await local.getSyncPoint(scope);
        expect(sp, isNotNull);
        final serverNow = await remote.getServerTime();
        expect(serverNow.difference(sp!).inSeconds.abs() < 5, isTrue);
      },
    );

    test('delete flows through and is excluded by soft-delete', () async {
      // Prepare a record present remotely and locally after initial sync
      final t0 = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      final rec = R('id2', 'B', t0);
      await remote.batchUpsert([rec]);
      await orch.synchronize(scope);

      // Ensure local has it
      expect((await local.query(scope)).map((e) => e.id), contains('id2'));

      // Delete via orchestrator
      await orch.enqueueDelete(scope, 'id2');
      await orch.synchronize(scope);

      // Local query excludes it (soft-delete behavior)
      final after = await local.query(scope);
      expect(after.map((e) => e.id), isNot(contains('id2')));

      // Remote delta since t0 should include the deletion
      final delta = await remote.fetchSince(scope, t0);
      expect(delta.deletes, contains('id2'));
    });

    test(
      'delta upsert prefers resolver (LastWriteWins by updatedAt)',
      () async {
        // Existing local record with older updatedAt
        final old = R(
          'id3',
          'old',
          DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        );
        await local.upsertMany(scope, [old]);

        // Remote provides newer version
        final newer = R('id3', 'new', DateTime.now().toUtc());
        await remote.batchUpsert([newer]);

        await orch.synchronize(scope);
        final items = await local.query(scope);
        final r = items.firstWhere((e) => e.id == 'id3');
        expect(r.title, 'new');
      },
    );

    test('scope isolation: sync on A does not affect B', () async {
      const scopeA = SyncScope('records', {'userId': 'uA'});
      const scopeB = SyncScope('records', {'userId': 'uB'});

      // Seed scopes
      await remote.fetchSince(scopeA, null);
      await remote.fetchSince(scopeB, null);

      // Use different IDs to avoid InMemoryRemoteStore distributing same-ID upserts across scopes.
      final recA = R('idA', 'A', DateTime.now().toUtc());
      final recB = R('idB', 'B', DateTime.now().toUtc());

      // Put different records per scope directly on remote by manipulating maps via batchUpsert
      // Since InMemoryRemoteStore upserts across existing scope entries, ensure both scopes exist (seeded above)
      await remote.batchUpsert([recA, recB]);

      // Sync only scopeA
      await orch.synchronize(scopeA);
      final a = await local.query(scopeA);
      expect(a.map((e) => e.id), contains('idA'));
      expect(a.map((e) => e.title), contains('A'));

      final bBefore = await local.query(scopeB);
      // Still empty because we didn't sync scopeB
      expect(bBefore, isEmpty);
    });
  });
}
