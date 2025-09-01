/// CachePolicy defines which source to prioritize for reads (remote vs. local).
/// It may also guide refresh decisions based on cache freshness (e.g., TTL).
///
/// For consistency, prefer remoteFirst and treat local as cache/offline fallback.
enum CachePolicy {
  /// Remote-first: use remote when online, fall back to local when offline.
  /// Some use cases may return cache first and refresh in the background.
  remoteFirst,

  /// Local-first: reduce latency by returning local first and refreshing remotely in background when online.
  localFirst,

  /// Offline-only: access local only (explicit offline mode).
  offlineOnly,

  /// Online-only: bypass cache and use remote only.
  onlineOnly,
}
