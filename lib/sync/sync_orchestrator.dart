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

  /// Read with a normalized query spec through the orchestrator.
  ///
  /// Default behavior is cache-centric: synchronize first (for online policies)
  /// and then evaluate the query against the local cache to keep results
  /// consistent with offline reads.
  ///
  /// If [preferRemoteEval] is true, the orchestrator will try to evaluate the
  /// query on the remote first (using `RemoteStore.remoteSearch`) and upsert
  /// the results into local before returning the locally-evaluated result.
  /// When the remote does not support certain operators/fields and throws
  /// `ArgumentError`, the call will fall back to local (if [fallbackToLocal]
  /// is true) after performing a synchronization.
  Future<List<T>> readWith(
    SyncScope scope,
    QuerySpec spec, {
    CachePolicy policy = CachePolicy.remoteFirst,
    bool preferRemoteEval = false,
    bool fallbackToLocal = true,
  });

  /// When online, push pending ops, fetch delta, and merge into local.
  Future<void> synchronize(SyncScope scope);

  /// Enqueue local ops and attempt background sync when possible.
  Future<void> enqueueCreate(SyncScope scope, Id id, T payload);
  Future<void> enqueueUpdate(SyncScope scope, Id id, T payload);
  Future<void> enqueueDelete(SyncScope scope, Id id);
}
