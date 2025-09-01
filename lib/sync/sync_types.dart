/// Common sync-related types shared across features.
library;

/// Marker interface for models that carry an `updatedAt` timestamp.
abstract interface class HasUpdatedAt {
  DateTime get updatedAt;
}

/// Marker interface for models that expose a stable identifier.
abstract interface class HasId<Id> {
  Id get id;
}

/// Optional marker for models that support soft delete semantics.
///
/// Note: Implementers typically provide either a `deletedAt` timestamp or an
/// `isDeleted` boolean flag. We standardize on `deletedAt` to preserve the
/// last-change time and enable LWW semantics across deletes as well.
abstract interface class HasSoftDelete {
  DateTime? get deletedAt; // null means not deleted
}

/// Scope identifies a logical subset for syncing, e.g., per user or template.
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
