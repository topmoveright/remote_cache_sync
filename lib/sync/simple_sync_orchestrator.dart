import 'dart:async';

import 'cache_policy.dart';
import 'conflict_resolver.dart';
import 'store_interfaces.dart';
import 'sync_orchestrator.dart';
import 'sync_types.dart';

/// 범용 재사용 가능한 오케스트레이터 구현입니다.
/// RemoteStore는 `fetchSince`로 델타를 제공하고,
/// LocalStore는 동기화 시점과 보류 작업을 저장한다고 가정합니다.
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
        // 로컬을 먼저 빠르게 반환하고, 백그라운드에서 원격으로 갱신합니다.
        final localItems = await local.query(scope);
        unawaited(synchronize(scope));
        return localItems;
      case CachePolicy.remoteFirst:
        await synchronize(scope);
        return local.query(scope);
    }
  }

  @override
  Future<void> synchronize(SyncScope scope) async {
    // 1) 보류 작업(pending ops) 전송
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

    // 2) 마지막 동기화 시점 이후의 원격 델타 가져오기
    final last = await local.getSyncPoint(scope);
    final delta = await remote.fetchSince(scope, last);

    // 3) 리졸버를 사용해 로컬과 병합
    final localNow = await local.query(scope);
    final byId = {for (final item in localNow) idOf(item): item};

    // 업서트 적용 (충돌 해결 포함)
    for (final up in delta.upserts) {
      final k = idOf(up);
      final existing = byId[k];
      if (existing == null) {
        byId[k] = up;
      } else {
        byId[k] = resolver.resolve(existing, up);
      }
    }

    // 삭제 적용
    for (final id in delta.deletes) {
      byId.remove(id);
    }

    // 4) 병합된 상태를 로컬에 반영
    await local.upsertMany(scope, byId.values.toList());
    if (delta.deletes.isNotEmpty) {
      await local.deleteMany(scope, delta.deletes);
    }

    // 5) 서버 타임스탬프로 동기화 시점 저장 (클럭 스큐 방지)
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
    // 전송 시도를 백그라운드로 실행 (Fire-and-forget)
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

  // ID equality provided by Id type; no dynamic casts.
  // Id 타입의 동등성에 의존하며, 동적 캐스트를 사용하지 않습니다.
}

String _uuid() {
  // 경량 고유 ID 생성기. 프로덕션 환경에서는 UUID 패키지 사용을 고려하세요.
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = now.hashCode ^ DateTime.now().millisecondsSinceEpoch.hashCode;
  return 'op_${now}_$rand';
}
