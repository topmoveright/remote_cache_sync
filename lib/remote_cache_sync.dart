// Package entrypoint: expose sync contracts, default orchestrator, and demo stores.

export 'sync/cache_policy.dart';
export 'sync/conflict_resolver.dart';
// Demo adapters for example apps
export 'sync/in_memory_local_store.dart';
export 'sync/in_memory_remote_store.dart';
export 'sync/simple_sync_orchestrator.dart';
export 'sync/store_interfaces.dart';
export 'sync/sync_orchestrator.dart';
export 'sync/sync_types.dart';
// Export Drift artifacts but hide the generated data class `PendingOp`
// to avoid name clash with domain model `PendingOp<T, Id>`.
export 'sync/drift/database.dart' hide PendingOp;
export 'sync/drift/drift_local_store.dart';
// NOTE: Remote adapters (Supabase/Appwrite/PocketBase) are moved to
// `remote_cache_sync_adapters.dart` to keep this core entrypoint WASM-safe.
// Import `package:remote_cache_sync/remote_cache_sync_adapters.dart` explicitly
// when you need those adapters.

// (duplicate exports removed)

// Backwards-compatible minimal facade expected by the generated example/tests.
import 'remote_cache_sync_platform_interface.dart';

/// Minimal class kept for backwards compatibility with older examples/tests.
class RemoteCacheSync {
  Future<String?> getPlatformVersion() {
    return RemoteCacheSyncPlatform.instance.getPlatformVersion();
  }
}
