import 'sync_types.dart';

/// ConflictResolver는 로컬과 원격이 모두 변경된 경우 어느 쪽이 우선할지 결정합니다.
abstract interface class ConflictResolver<T extends HasUpdatedAt> {
  T resolve(T local, T remote);
}

/// 기본 전략: `updatedAt` 기준으로 가장 최근 수정이 이긴다고 판단합니다 (Last-Write-Wins).
class LastWriteWinsResolver<T extends HasUpdatedAt>
    implements ConflictResolver<T> {
  const LastWriteWinsResolver();

  @override
  T resolve(T local, T remote) {
    return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
  }
}
