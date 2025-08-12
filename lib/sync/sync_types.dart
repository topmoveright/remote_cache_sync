/// Common sync-related types shared across features.
/// 기능 전반에서 재사용되는 동기화 관련 공통 타입들입니다.
library;

/// Marker interface for models that carry an `updatedAt` timestamp.
/// `updatedAt` 타임스탬프를 보유한 모델을 표시하기 위한 인터페이스입니다.
abstract interface class HasUpdatedAt {
  DateTime get updatedAt;
}

/// Marker interface for models that expose a stable identifier.
/// 고유한 식별자(ID)를 노출하는 모델을 위한 인터페이스입니다.
abstract interface class HasId<Id> {
  Id get id;
}

/// Optional marker for models that support soft delete semantics.
/// 모델이 소프트 삭제(행 보존 + 삭제 마크)를 지원함을 나타냅니다.
///
/// Note: Implementers typically provide either a `deletedAt` timestamp or an
/// `isDeleted` boolean flag. We standardize on `deletedAt` to preserve the
/// last-change time and enable LWW semantics across deletes as well.
abstract interface class HasSoftDelete {
  DateTime? get deletedAt; // null means not deleted
}

/// Scope identifies a logical subset for syncing, e.g. per user or template.
/// SyncScope는 동기화 단위를 식별합니다 (예: 사용자/템플릿 등).
class SyncScope {
  final String name; // e.g., 'records'
  final Map<String, String>
  keys; // e.g., { 'userId': 'u1', 'templateId': 't1' }

  const SyncScope(this.name, [this.keys = const {}]);

  @override
  String toString() => 'SyncScope(name=$name, keys=$keys)';

  @override
  bool operator ==(Object other) {
    return other is SyncScope &&
        other.name == name &&
        _mapEquals(other.keys, keys);
  }

  @override
  int get hashCode => Object.hash(
    name,
    keys.entries
        .map((e) => e.key.hashCode ^ e.value.hashCode)
        .fold<int>(0, (a, b) => a ^ b),
  );
}

bool _mapEquals(Map a, Map b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Delta returned by remote: upserts and deletions since a point in time.
/// 원격이 반환하는 델타: 특정 시점 이후의 upsert와 삭제 목록입니다.
class Delta<T, Id> {
  final List<T> upserts;
  final List<Id> deletes;
  final DateTime serverTimestamp;

  const Delta({
    required this.upserts,
    required this.deletes,
    required this.serverTimestamp,
  });
}
