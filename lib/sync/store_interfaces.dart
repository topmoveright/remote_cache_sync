import 'sync_types.dart';

/// LocalStore abstracts local persistence for syncable models.
/// 로컬 저장소는 소프트 삭제를 선택적으로 지원할 수 있습니다.
abstract interface class LocalStore<T, Id> {
  /// Whether this store performs soft delete (set deletedAt) instead of hard delete.
  /// 해당 스토어가 하드 삭제 대신 소프트 삭제(예: `deletedAt` 설정)를 수행하는지 여부.
  bool get supportsSoftDelete => false;

  Future<T?> getById(Id id);
  Future<List<T>> query(SyncScope scope);
  Future<List<T>> querySince(SyncScope scope, DateTime since);
  /// Upsert items that belong to the given [scope].
  Future<void> upsertMany(SyncScope scope, List<T> items);
  /// Delete semantics within the given [scope]:
  /// - If [supportsSoftDelete] is true, mark items as deleted (e.g., set deletedAt) and keep rows.
  /// - Otherwise, remove rows permanently (hard delete).
  Future<void> deleteMany(SyncScope scope, List<Id> ids);

  // 동기화 메타데이터
  Future<DateTime?> getSyncPoint(SyncScope scope);
  Future<void> saveSyncPoint(SyncScope scope, DateTime timestamp);

  // 오프라인 우선 쓰기를 위한 보류 작업 큐
  Future<List<PendingOp<T, Id>>> getPendingOps(SyncScope scope);
  Future<void> enqueuePendingOp(PendingOp<T, Id> op);
  Future<void> clearPendingOps(SyncScope scope, List<String> opIds);
}

/// RemoteStore abstracts access to the remote service for syncable models.
abstract interface class RemoteStore<T, Id> {
  Future<T?> getById(Id id);
  Future<Delta<T, Id>> fetchSince(SyncScope scope, DateTime? since);
  Future<void> batchUpsert(List<T> items);
  Future<void> batchDelete(List<Id> ids);
  Future<DateTime> getServerTime();
}

/// 온라인 상태에서 원격으로 전송될 보류 작업을 나타냅니다.
class PendingOp<T, Id> {
  final String opId; // unique per op
  final SyncScope scope;
  final PendingOpType type;
  final Id id;
  final T? payload; // null for delete
  final DateTime updatedAt;

  const PendingOp({
    required this.opId,
    required this.scope,
    required this.type,
    required this.id,
    required this.payload,
    required this.updatedAt,
  });
}

enum PendingOpType { create, update, delete }
