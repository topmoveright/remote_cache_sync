import 'dart:async';

import 'cache_policy.dart';
import 'conflict_resolver.dart';
import 'store_interfaces.dart';
import 'sync_orchestrator.dart';
import 'sync_types.dart';

/// Generic, reusable synchronization orchestrator.
/// Assumes `RemoteStore` provides deltas via `fetchSince`, and `LocalStore`
/// persists the last sync point and pending operations.
class SimpleSyncOrchestrator<T extends HasUpdatedAt, Id>
    implements SyncOrchestrator<T, Id> {
  @override
  final LocalStore<T, Id> local;
  @override
  final RemoteStore<T, Id> remote;
  @override
  final ConflictResolver<T> resolver;
  // Strongly-typed ID selector to avoid dynamic casts.
  final Id Function(T) idOf;

  const SimpleSyncOrchestrator({
    required this.local,
    required this.remote,
    required this.resolver,
    required this.idOf,
  });

  @override
  Future<List<T>> read(
    SyncScope scope, {
    CachePolicy policy = CachePolicy.remoteFirst,
  }) async {
    switch (policy) {
      case CachePolicy.offlineOnly:
        return local.query(scope);
      case CachePolicy.onlineOnly:
        await synchronize(scope);
        final items = await local.query(scope);
        return items;
      case CachePolicy.localFirst:
        // Return local quickly and refresh from remote in the background.
        final localItems = await local.query(scope);
        unawaited(synchronize(scope));
        return localItems;
      case CachePolicy.remoteFirst:
        await synchronize(scope);
        return local.query(scope);
    }
  }

  @override
  Future<List<T>> readWith(
    SyncScope scope,
    QuerySpec spec, {
    CachePolicy policy = CachePolicy.remoteFirst,
    bool preferRemoteEval = false,
    bool fallbackToLocal = true,
  }) async {
    switch (policy) {
      case CachePolicy.offlineOnly:
        // Pure offline: evaluate QuerySpec against local cache only.
        return local.queryWith(scope, spec);
      case CachePolicy.localFirst:
        // Return local immediately; refresh in background.
        final localItems = await local.queryWith(scope, spec);
        unawaited(synchronize(scope));
        return localItems;
      case CachePolicy.remoteFirst:
      case CachePolicy.onlineOnly:
        // Keep cache-centric results: sync then evaluate on local.
        // Optionally try remote-side evaluation first for accuracy/perf,
        // but still return the locally evaluated result for consistency.
        if (preferRemoteEval) {
          try {
            final remoteItems = await remote.remoteSearch(scope, spec);
            // Upsert remote-evaluated results into local cache to keep it fresh.
            if (remoteItems.isNotEmpty) {
              await local.upsertMany(scope, remoteItems);
            }
          } on ArgumentError catch (_) {
            // Backend did not support part of the spec. Fall back to sync+local.
            if (!fallbackToLocal) rethrow;
          }
        }

        await synchronize(scope);
        return local.queryWith(scope, spec);
    }
  }

  @override
  Future<void> synchronize(SyncScope scope) async {
    // 1) Push pending operations
    final pending = await local.getPendingOps(scope);
    if (pending.isNotEmpty) {
      final creates = pending.where((p) => p.type == PendingOpType.create);
      final updates = pending.where((p) => p.type == PendingOpType.update);
      final deletes = pending.where((p) => p.type == PendingOpType.delete);

      if (creates.isNotEmpty) {
        await remote.batchUpsert(creates.map((p) => p.payload as T).toList());
      }
      if (updates.isNotEmpty) {
        await remote.batchUpsert(updates.map((p) => p.payload as T).toList());
      }
      if (deletes.isNotEmpty) {
        await remote.batchDelete(deletes.map((p) => p.id).toList());
      }
      await local.clearPendingOps(scope, pending.map((p) => p.opId).toList());
    }

    // 2) Fetch remote delta since the last sync point
    final last = await local.getSyncPoint(scope);
    final delta = await remote.fetchSince(scope, last);

    // 3) Merge with local using the conflict resolver
    final localNow = await local.query(scope);
    final byId = {for (final item in localNow) idOf(item): item};

    // Apply upserts (with conflict resolution)
    for (final up in delta.upserts) {
      final k = idOf(up);
      final existing = byId[k];
      if (existing == null) {
        byId[k] = up;
      } else {
        byId[k] = resolver.resolve(existing, up);
      }
    }

    // Apply deletes
    for (final id in delta.deletes) {
      byId.remove(id);
    }

    // 4) Persist merged state to local
    await local.upsertMany(scope, byId.values.toList());
    if (delta.deletes.isNotEmpty) {
      await local.deleteMany(scope, delta.deletes);
    }

    // 5) Save sync point using server timestamp (avoid clock skew)
    await local.saveSyncPoint(scope, delta.serverTimestamp);
  }

  @override
  Future<void> enqueueCreate(SyncScope scope, Id id, T payload) async {
    await local.upsertMany(scope, [payload]);
    await local.enqueuePendingOp(
      PendingOp<T, Id>(
        opId: _uuid(),
        scope: scope,
        type: PendingOpType.create,
        id: id,
        payload: payload,
        updatedAt: payload.updatedAt,
      ),
    );
    // Fire-and-forget background sync attempt
    unawaited(synchronize(scope));
  }

  @override
  Future<void> enqueueUpdate(SyncScope scope, Id id, T payload) async {
    await local.upsertMany(scope, [payload]);
    await local.enqueuePendingOp(
      PendingOp<T, Id>(
        opId: _uuid(),
        scope: scope,
        type: PendingOpType.update,
        id: id,
        payload: payload,
        updatedAt: payload.updatedAt,
      ),
    );
    unawaited(synchronize(scope));
  }

  @override
  Future<void> enqueueDelete(SyncScope scope, Id id) async {
    await local.deleteMany(scope, [id]);
    await local.enqueuePendingOp(
      PendingOp<T, Id>(
        opId: _uuid(),
        scope: scope,
        type: PendingOpType.delete,
        id: id,
        payload: null,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    unawaited(synchronize(scope));
  }

  // ID equality provided by Id type; avoid dynamic casts.
}

String _uuid() {
  // Lightweight unique ID generator. Consider a UUID package in production.
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = now.hashCode ^ DateTime.now().millisecondsSinceEpoch.hashCode;
  return 'op_${now}_$rand';
}
