import 'package:supabase_flutter/supabase_flutter.dart';

import '../store_interfaces.dart';
import '../sync_types.dart';

/// Supabase-backed implementation of RemoteStore using PostgREST.
///
/// This adapter assumes a table schema that contains at least the following columns:
/// - id (text or uuid)
/// - updated_at (timestamptz, UTC)
/// - optional deleted_at (timestamptz, UTC) for soft delete
/// - scope_name (text)
/// - scope_keys (jsonb)
///
/// The adapter is backend-agnostic for the model T; callers provide JSON (de)serialization
/// and ID mapping via the config object.
class SupabaseRemoteConfig<T, Id> {
  final SupabaseClient client;
  final String table;
  final String idColumn;
  final String updatedAtColumn;
  final String? deletedAtColumn; // null => hard delete
  final String scopeNameColumn;
  final String scopeKeysColumn;

  final Id Function(T) idOf;
  final String Function(Id) idToString;
  final Id Function(String) idFromString;

  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;

  /// Optional hook to expose parse statistics for testing/observability.
  /// Called after parsePage completes with the number of skipped rows and total rows.
  final void Function({required int skipped, required int total})? onParsePageStats;

  /// Optional RPC name to fetch authoritative server time (UTC).
  /// If null, falls back to client-side time (not recommended).
  final String? serverTimeRpcName;

  /// Optional default scope used for write operations (upsert/delete) when
  /// the backend cannot infer scope from auth context (e.g., RLS claims).
  /// When provided and [injectScopeOnWrite] is true, this scope will be
  /// injected into rows on upsert and used to filter delete operations.
  final SyncScope? defaultScope;

  /// If true, write operations will inject or filter by scope using
  /// [defaultScope]. Defaults to false.
  final bool injectScopeOnWrite;

  /// Optional builder to construct scope columns map for writes.
  /// If not provided, a default map using [scopeNameColumn] and [scopeKeysColumn]
  /// with values from [defaultScope] is used.
  final Map<String, dynamic> Function(SyncScope scope)? scopeColumnsBuilder;

  /// Optional per-item scope selector for upserts when [injectScopeOnWrite] is true.
  /// If provided and returns non-null, that scope will be injected for the item.
  final SyncScope? Function(T item)? scopeForUpsert;

  /// Optional per-id scope selector for deletes when [injectScopeOnWrite] is true.
  /// If provided and returns non-null, that scope will be used to filter the delete.
  final SyncScope? Function(Id id)? scopeForDelete;

  const SupabaseRemoteConfig({
    required this.client,
    required this.table,
    required this.idColumn,
    required this.updatedAtColumn,
    required this.deletedAtColumn,
    required this.scopeNameColumn,
    required this.scopeKeysColumn,
    required this.idOf,
    required this.idToString,
    required this.idFromString,
    required this.toJson,
    required this.fromJson,
    this.onParsePageStats,
    this.serverTimeRpcName,
    this.defaultScope,
    this.injectScopeOnWrite = false,
    this.scopeColumnsBuilder,
    this.scopeForUpsert,
    this.scopeForDelete,
  });

  SupabaseRemoteConfig<T, Id> copyWith({
    SupabaseClient? client,
    String? table,
    String? idColumn,
    String? updatedAtColumn,
    String? deletedAtColumn,
    String? scopeNameColumn,
    String? scopeKeysColumn,
    Id Function(T)? idOf,
    String Function(Id)? idToString,
    Id Function(String)? idFromString,
    Map<String, dynamic> Function(T)? toJson,
    T Function(Map<String, dynamic>)? fromJson,
    void Function({required int skipped, required int total})? onParsePageStats,
    String? serverTimeRpcName,
    SyncScope? defaultScope,
    bool? injectScopeOnWrite,
    Map<String, dynamic> Function(SyncScope scope)? scopeColumnsBuilder,
    SyncScope? Function(T item)? scopeForUpsert,
    SyncScope? Function(Id id)? scopeForDelete,
  }) {
    return SupabaseRemoteConfig<T, Id>(
      client: client ?? this.client,
      table: table ?? this.table,
      idColumn: idColumn ?? this.idColumn,
      updatedAtColumn: updatedAtColumn ?? this.updatedAtColumn,
      deletedAtColumn: deletedAtColumn ?? this.deletedAtColumn,
      scopeNameColumn: scopeNameColumn ?? this.scopeNameColumn,
      scopeKeysColumn: scopeKeysColumn ?? this.scopeKeysColumn,
      idOf: idOf ?? this.idOf,
      idToString: idToString ?? this.idToString,
      idFromString: idFromString ?? this.idFromString,
      toJson: toJson ?? this.toJson,
      fromJson: fromJson ?? this.fromJson,
      onParsePageStats: onParsePageStats ?? this.onParsePageStats,
      serverTimeRpcName: serverTimeRpcName ?? this.serverTimeRpcName,
      defaultScope: defaultScope ?? this.defaultScope,
      injectScopeOnWrite: injectScopeOnWrite ?? this.injectScopeOnWrite,
      scopeColumnsBuilder: scopeColumnsBuilder ?? this.scopeColumnsBuilder,
      scopeForUpsert: scopeForUpsert ?? this.scopeForUpsert,
      scopeForDelete: scopeForDelete ?? this.scopeForDelete,
    );
  }
}

class SupabaseRemoteStore<T extends HasUpdatedAt, Id>
    implements RemoteStore<T, Id> {
  final SupabaseRemoteConfig<T, Id> config;

  const SupabaseRemoteStore({required this.config});

  SupabaseQueryBuilder _table() => config.client.from(config.table);

  // Scope is applied via filters on scope columns (name + jsonb keys).

  @override
  Future<T?> getById(Id id) async {
    final res = await _table()
        .select()
        .eq(config.idColumn, config.idToString(id))
        .maybeSingle();
    if (res == null) return null;
    return config.fromJson(Map<String, dynamic>.from(res));
  }

  @override
  Future<Delta<T, Id>> fetchSince(SyncScope scope, DateTime? since) async {
    var upsertQuery = _table()
        .select()
        .eq(config.scopeNameColumn, scope.name)
        .contains(config.scopeKeysColumn, scope.keys);
    if (since != null) {
      upsertQuery = upsertQuery.gt(
          config.updatedAtColumn, since.toUtc().toIso8601String());
    }
    if (config.deletedAtColumn != null) {
      // `is` operator to check for NULL
      upsertQuery = upsertQuery.filter(config.deletedAtColumn!, 'is', null);
    }
    final upsertsRaw = await upsertQuery;
    final upserts = (upsertsRaw as List)
        .map((e) => config.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    // Deletes: updated_at > since and soft-deleted (if supported). For hard delete, server must provide tombstones.
    List<Id> deletes = const [];
    if (config.deletedAtColumn != null) {
      var delQ = _table()
          .select(config.idColumn)
          .eq(config.scopeNameColumn, scope.name)
          .contains(config.scopeKeysColumn, scope.keys);
      if (since != null) {
        delQ = delQ.gt(
            config.updatedAtColumn, since.toUtc().toIso8601String());
      }
      delQ = delQ.not(config.deletedAtColumn!, 'is', null);
      final delsRaw = await delQ;
      deletes = (delsRaw as List)
          .map((e) => config.idFromString('${(e as Map)[config.idColumn]}'))
          .toList(growable: false);
    }

    final serverTs = await getServerTime();
    return Delta<T, Id>(upserts: upserts, deletes: deletes, serverTimestamp: serverTs);
  }

  /// Filter raw rows (maps) by scope equality.
  /// Uses shallow map equality on scope keys to avoid reference equality pitfalls.
  List<Map<String, dynamic>> filterRowsByScope(
      List<Map<String, dynamic>> rows, SyncScope scope) {
    bool shallowMapEquals(Map a, Map b) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k)) return false;
        if (a[k] != b[k]) return false;
      }
      return true;
    }

    return rows.where((m) {
      final nameOk = m[config.scopeNameColumn] == scope.name;
      final keysVal = m[config.scopeKeysColumn];
      final keysOk = keysVal is Map &&
          shallowMapEquals(Map<String, dynamic>.from(keysVal), scope.keys);
      return nameOk && keysOk;
    }).toList();
  }

  /// Parse a page of raw rows into upserts and deletes with defensive checks.
  (List<T> upserts, List<Id> deletes) parsePage(List<Map<String, dynamic>> rows) {
    final upserts = <T>[];
    final deletes = <Id>[];
    var skipped = 0;
    for (final m in rows) {
      if (!m.containsKey(config.idColumn)) { skipped++; continue; }
      if (!m.containsKey(config.scopeNameColumn)) { skipped++; continue; }
      if (!m.containsKey(config.scopeKeysColumn)) { skipped++; continue; }
      final idRaw = m[config.idColumn];
      if (idRaw is! String) { skipped++; continue; }
      final isDeleted = config.deletedAtColumn != null && m[config.deletedAtColumn!] != null;
      if (isDeleted) {
        deletes.add(config.idFromString(idRaw));
      } else {
        upserts.add(config.fromJson(m));
      }
    }
    config.onParsePageStats?.call(skipped: skipped, total: rows.length);
    return (upserts, deletes);
  }

  /// Test-only helper: simulate fetchSince over raw paginated pages without SDK.
  Future<Delta<T, Id>> fetchSinceFromRawPages(
    SyncScope scope,
    DateTime? since,
    List<List<Map<String, dynamic>>> pages,
  ) async {
    final upserts = <T>[];
    final deletes = <Id>[];
    for (final page in pages) {
      final scoped = filterRowsByScope(page, scope);
      final filtered = since == null
          ? scoped
          : scoped.where((m) {
              final ts = m[config.updatedAtColumn];
              if (ts is String) {
                return DateTime.parse(ts).isAfter(since);
              }
              return false;
            }).toList();
      final (ups, dels) = parsePage(filtered);
      upserts.addAll(ups);
      deletes.addAll(dels);
    }
    final serverTs = await getServerTime();
    return Delta<T, Id>(upserts: upserts, deletes: deletes, serverTimestamp: serverTs);
  }

  @override
  Future<void> batchUpsert(List<T> items) async {
    if (items.isEmpty) return;
    final rows = buildUpsertRows(items);
    await _table().upsert(rows, onConflict: config.idColumn);
  }

  @override
  Future<void> batchDelete(List<Id> ids) async {
    if (ids.isEmpty) return;
    // If per-id scope is provided and injection is enabled, group by scope and issue scoped queries.
    if (config.injectScopeOnWrite && config.scopeForDelete != null) {
      final groups = groupDeletesByScope(ids);
      for (final entry in groups.entries) {
        final idsForScope = entry.value;
        if (idsForScope.isEmpty) continue;
        if (config.deletedAtColumn != null) {
          var q = _table().update({
            config.deletedAtColumn!: DateTime.now().toUtc().toIso8601String()
          });
          final s = entry.key;
          if (s != null) {
            q = q
                .eq(config.scopeNameColumn, s.name)
                .contains(config.scopeKeysColumn, s.keys);
          }
          await q.inFilter(config.idColumn, idsForScope);
        } else {
          var dq = _table().delete();
          final s = entry.key;
          if (s != null) {
            dq = dq
                .eq(config.scopeNameColumn, s.name)
                .contains(config.scopeKeysColumn, s.keys);
          }
          await dq.inFilter(config.idColumn, idsForScope);
        }
      }
      return;
    }

    // Fallback: single query with optional default scope filter
    final idList = ids.map(config.idToString).toList(growable: false);
    if (config.deletedAtColumn != null) {
      var q = _table().update({
        config.deletedAtColumn!: DateTime.now().toUtc().toIso8601String()
      });
      if (config.injectScopeOnWrite && config.defaultScope != null) {
        q = q
            .eq(config.scopeNameColumn, config.defaultScope!.name)
            .contains(config.scopeKeysColumn, config.defaultScope!.keys);
      }
      await q.inFilter(config.idColumn, idList);
    } else {
      var dq = _table().delete();
      if (config.injectScopeOnWrite && config.defaultScope != null) {
        dq = dq
            .eq(config.scopeNameColumn, config.defaultScope!.name)
            .contains(config.scopeKeysColumn, config.defaultScope!.keys);
      }
      await dq.inFilter(config.idColumn, idList);
    }
  }

  Map<String, dynamic> _scopeColsFor(SyncScope s) => config.scopeColumnsBuilder != null
      ? config.scopeColumnsBuilder!(s)
      : {
          config.scopeNameColumn: s.name,
          config.scopeKeysColumn: s.keys,
        };

  /// Build upsert rows with optional scope injection. Exposed for tests.
  List<Map<String, dynamic>> buildUpsertRows(List<T> items) {
    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      Map<String, dynamic> scopeCols = const {};
      if (config.injectScopeOnWrite) {
        final s = config.scopeForUpsert?.call(item) ?? config.defaultScope;
        if (s != null) scopeCols = _scopeColsFor(s);
      }
      rows.add({
        ...config.toJson(item),
        config.idColumn: config.idToString(config.idOf(item)),
        ...scopeCols,
      });
    }
    return rows;
  }

  /// Group delete ids by scope (from callback or default). Exposed for tests.
  Map<SyncScope?, List<String>> groupDeletesByScope(List<Id> ids) {
    final Map<SyncScope?, List<String>> groups = {};
    for (final id in ids) {
      final scope = config.scopeForDelete?.call(id) ?? config.defaultScope;
      (groups[scope] ??= <String>[]).add(config.idToString(id));
    }
    return groups;
  }

  @override
  Future<DateTime> getServerTime() async {
    if (config.serverTimeRpcName == null) {
      // Fallback to client time (non-ideal); recommended to configure RPC.
      return DateTime.now().toUtc();
    }
    final res = await config.client.rpc(config.serverTimeRpcName!);
    // Supabase returns ISO8601 string or timestamp depending on RPC
    if (res is String) return DateTime.parse(res).toUtc();
    if (res is Map && res['server_time'] is String) {
      return DateTime.parse(res['server_time'] as String).toUtc();
    }
    // Try to coerce to ISO string
    return DateTime.parse(res.toString()).toUtc();
  }
}
