import 'cache_policy.dart';
import 'conflict_resolver.dart';
import 'store_interfaces.dart';
import 'sync_types.dart';

/// 동기화 오케스트레이터 인터페이스
/// - 로컬에 누적된 보류 작업(pending ops)을 원격으로 전송하고,
/// - 원격에서 델타(delta)를 가져와 ConflictResolver로 병합한 뒤,
/// - 로컬 상태를 갱신하고 동기화 시점을 저장합니다.
abstract interface class SyncOrchestrator<T extends HasUpdatedAt, Id> {
  LocalStore<T, Id> get local;
  RemoteStore<T, Id> get remote;
  ConflictResolver<T> get resolver;

  Future<List<T>> read(
    SyncScope scope, {
    CachePolicy policy,
  });

  /// (온라인일 경우) 보류 작업을 원격으로 전송한 뒤 델타를 받아 로컬에 병합합니다.
  Future<void> synchronize(SyncScope scope);

  /// 로컬 작업을 큐에 적재하고, 가능하면 백그라운드로 즉시 전송을 시도합니다.
  Future<void> enqueueCreate(SyncScope scope, Id id, T payload);
  Future<void> enqueueUpdate(SyncScope scope, Id id, T payload);
  Future<void> enqueueDelete(SyncScope scope, Id id);
}
