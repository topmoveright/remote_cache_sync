import 'sync_types.dart';

/// ConflictResolver decides which side wins when both local and remote changed.
abstract interface class ConflictResolver<T extends HasUpdatedAt> {
  T resolve(T local, T remote);
}

/// Default strategy: last-write-wins based on `updatedAt`.
class LastWriteWinsResolver<T extends HasUpdatedAt>
    implements ConflictResolver<T> {
  const LastWriteWinsResolver();

  @override
  T resolve(T local, T remote) {
    return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
  }
}
