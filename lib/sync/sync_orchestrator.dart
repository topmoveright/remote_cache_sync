import 'cache_policy.dart';
import 'conflict_resolver.dart';
import 'store_interfaces.dart';
import 'sync_types.dart';

/// Synchronization orchestrator interface.
/// - Sends accumulated pending ops from local to remote.
/// - Fetches delta from remote and merges using `ConflictResolver`.
/// - Updates local state and persists the sync point.
abstract interface class SyncOrchestrator<T extends HasUpdatedAt, Id> {
  LocalStore<T, Id> get local;
  RemoteStore<T, Id> get remote;
  ConflictResolver<T> get resolver;

  Future<List<T>> read(SyncScope scope, {CachePolicy policy});

  /// When online, push pending ops, fetch delta, and merge into local.
  Future<void> synchronize(SyncScope scope);

  /// Enqueue local ops and attempt background sync when possible.
  Future<void> enqueueCreate(SyncScope scope, Id id, T payload);
  Future<void> enqueueUpdate(SyncScope scope, Id id, T payload);
  Future<void> enqueueDelete(SyncScope scope, Id id);
}
