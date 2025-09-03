import 'dart:async';

import 'package:appwrite/appwrite.dart' as aw;
import 'package:remote_cache_sync/sync/store_interfaces.dart';
import 'package:remote_cache_sync/sync/sync_types.dart';
import 'appwrite_search_plan.dart';

/// Configuration for AppwriteRemoteStore
///
/// Note: This scaffold does not depend on the appwrite SDK to keep the core
/// package lightweight. You can pass any client via [client] and implement
/// the integration inside the TODOs later. All field/collection names are
/// placeholders and should be replaced with your schema.
class AppwriteRemoteConfig<T extends HasUpdatedAt, Id> {
  // Low-level clients
  final aw.TablesDB tablesDB;
  final aw.Functions? functions;

  // Database/table identification
  final String databaseId;
  final String tableId; // <your_table>

  // Field mappings
  final String idField; // <id_field>
  final String updatedAtField; // <updated_at_field>
  final String? deletedAtField; // <deleted_at_field> (null => hard delete)
  final String scopeNameField; // <scope_name_field>
  final String scopeKeysField; // <scope_keys_field> (JSON)

  // ID and JSON mapping
  final Id Function(T) idOf;
  final String Function(Id) idToString;
  final Id Function(String) idFromString;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;

  // Optional server time function identifier
  final String? serverTimeFunctionId;

  // Optional default scope for write operations
  final SyncScope? defaultScope;
  final bool injectScopeOnWrite;
  final Map<String, dynamic> Function(SyncScope scope)? scopeFieldsBuilder;
  // Optional parse stats hook (for testing/observability)
  final void Function({required int skipped, required int total})?
  onParsePageStats;

  /// Optional runner to execute remoteSearch without network.
  /// If provided, `remoteSearch` will call this with the built queries and
  /// expect a list of raw row maps in return. Intended for unit tests.
  final Future<List<Map<String, dynamic>>> Function(List<String> queries)?
  searchRunner;

  const AppwriteRemoteConfig({
    required this.tablesDB,
    this.functions,
    required this.databaseId,
    required this.tableId,
    required this.idField,
    required this.updatedAtField,
    required this.deletedAtField,
    required this.scopeNameField,
    required this.scopeKeysField,
    required this.idOf,
    required this.idToString,
    required this.idFromString,
    required this.toJson,
    required this.fromJson,
    this.serverTimeFunctionId,
    this.defaultScope,
    this.injectScopeOnWrite = false,
    this.scopeFieldsBuilder,
    this.onParsePageStats,
    this.searchRunner,
  });
}

class AppwriteRemoteStore<T extends HasUpdatedAt, Id>
    implements RemoteStore<T, Id> {
  final AppwriteRemoteConfig<T, Id> config;
  const AppwriteRemoteStore({required this.config});

  @override
  Future<T?> getById(Id id) async {
    try {
      final row = await config.tablesDB.getRow(
        databaseId: config.databaseId,
        tableId: config.tableId,
        rowId: config.idToString(id),
      );
      final data = Map<String, dynamic>.from(row.data);
      return config.fromJson(data);
    } on aw.AppwriteException {
      // Not found or other error
      return null;
    }
  }

  // Parse a page of raw rows (as maps) into upserts and delete ids. Exposed for tests.
  (List<T> upserts, List<Id> deletes) parsePage(
    List<Map<String, dynamic>> rows,
  ) {
    final upserts = <T>[];
    final deletes = <Id>[];
    var skipped = 0;
    for (final m in rows) {
      // Defensive checks: skip rows without required fields
      if (!m.containsKey(config.idField)) {
        skipped++;
        continue;
      }
      if (!m.containsKey(config.scopeNameField)) {
        skipped++;
        continue;
      }
      if (!m.containsKey(config.scopeKeysField)) {
        skipped++;
        continue;
      }
      final idRaw = m[config.idField];
      if (idRaw is! String) {
        skipped++;
        continue;
      }
      final isDeleted =
          config.deletedAtField != null && m[config.deletedAtField!] != null;
      if (isDeleted) {
        deletes.add(config.idFromString(idRaw));
      } else {
        upserts.add(config.fromJson(m));
      }
    }
    config.onParsePageStats?.call(skipped: skipped, total: rows.length);
    return (upserts, deletes);
  }

  // Build Appwrite queries used by fetchSince. Exposed for tests.
  List<String> buildFetchQueries(SyncScope scope, DateTime? since) {
    // Scope filter + optional since filter
    final queries = <String>[];
    queries.add(aw.Query.equal(config.scopeNameField, scope.name));
    // NOTE: Filtering by nested keys in JSON may require specific Appwrite indexing or is unsupported.
    // If unsupported, consider storing denormalized keys (e.g., scope_userId) for indexing.
    if (since != null) {
      queries.add(
        aw.Query.greaterThan(config.updatedAtField, since.toIso8601String()),
      );
    }
    return queries;
  }

  // Filter raw rows by scope equality. Exposed for tests.
  List<Map<String, dynamic>> filterRowsByScope(
    List<Map<String, dynamic>> rows,
    SyncScope scope,
  ) {
    bool shallowMapEquals(Map a, Map b) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k)) return false;
        if (a[k] != b[k]) return false;
      }
      return true;
    }

    return rows.where((m) {
      final nameOk = m[config.scopeNameField] == scope.name;
      final keysVal = m[config.scopeKeysField];
      final keysOk =
          keysVal is Map &&
          shallowMapEquals(Map<String, dynamic>.from(keysVal), scope.keys);
      return nameOk && keysOk;
    }).toList();
  }

  @override
  Future<Delta<T, Id>> fetchSince(SyncScope scope, DateTime? since) async {
    // Build queries via helper for testability
    final queries = buildFetchQueries(scope, since);

    // Fetch paginated
    final upserts = <T>[];
    final deletes = <Id>[];
    String? cursor;
    const limit = 100;
    while (true) {
      final res = await config.tablesDB.listRows(
        databaseId: config.databaseId,
        tableId: config.tableId,
        queries: [
          ...queries,
          if (cursor != null) aw.Query.cursorAfter(cursor),
          aw.Query.limit(limit),
          aw.Query.orderAsc(config.updatedAtField),
        ],
      );
      for (final r in res.rows) {
        final data = Map<String, dynamic>.from(r.data);
        final isDeleted =
            config.deletedAtField != null &&
            data[config.deletedAtField!] != null;
        if (isDeleted) {
          deletes.add(config.idFromString(r.$id));
        } else {
          upserts.add(config.fromJson(data));
        }
      }
      if (res.total <= (res.rows.length + (cursor == null ? 0 : limit))) {
        // Heuristic: stop when we've likely reached the end. Appwrite doesn't return a next cursor; we can break when page shorter than limit.
        if (res.rows.length < limit) {
          break;
        }
      }
      if (res.rows.isEmpty) break;
      cursor = res.rows.last.$id;
    }

    final serverTs = await getServerTime();
    return Delta<T, Id>(
      upserts: upserts,
      deletes: deletes,
      serverTimestamp: serverTs,
    );
  }

  // Test-only: simulate fetchSince using raw pages without SDK.
  // Applies scope filtering and since filtering (client-side) to mimic server.
  Future<Delta<T, Id>> fetchSinceFromRawPages(
    SyncScope scope,
    DateTime? since,
    List<List<Map<String, dynamic>>> pages,
  ) async {
    final upserts = <T>[];
    final deletes = <Id>[];
    for (final page in pages) {
      // Apply scope filter as server would
      final scoped = filterRowsByScope(page, scope);
      // Apply since filter as server would
      final filtered = since == null
          ? scoped
          : scoped.where((m) {
              final ts = m[config.updatedAtField];
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
    return Delta<T, Id>(
      upserts: upserts,
      deletes: deletes,
      serverTimestamp: serverTs,
    );
  }

  @override
  Future<void> batchUpsert(List<T> items) async {
    // Appwrite doesn't have multi-document transactions for Databases.
    // Perform sequential upserts (create or update by id).
    final payloads = buildUpsertPayloads(items);
    for (final entry in payloads) {
      final id = entry.$1;
      final data = entry.$2;
      try {
        // Try update first
        await config.tablesDB.updateRow(
          databaseId: config.databaseId,
          tableId: config.tableId,
          rowId: id,
          data: data,
        );
      } on aw.AppwriteException catch (_) {
        // Create if not exists
        await config.tablesDB.createRow(
          databaseId: config.databaseId,
          tableId: config.tableId,
          rowId: id, // custom id to align with our domain id
          data: data,
        );
      }
    }
  }

  @override
  Future<void> batchDelete(List<Id> ids) async {
    final soft = config.deletedAtField != null;
    for (final id in ids) {
      final docId = config.idToString(id);
      if (soft) {
        final patch = <String, dynamic>{
          config.deletedAtField!: DateTime.now().toUtc().toIso8601String(),
        };
        if (config.injectScopeOnWrite && config.defaultScope != null) {
          final scopeMap =
              config.scopeFieldsBuilder?.call(config.defaultScope!) ??
              {
                config.scopeNameField: config.defaultScope!.name,
                config.scopeKeysField: config.defaultScope!.keys,
              };
          patch.addAll(scopeMap);
        }
        try {
          await config.tablesDB.updateRow(
            databaseId: config.databaseId,
            tableId: config.tableId,
            rowId: docId,
            data: patch,
          );
        } on aw.AppwriteException {
          // ignore
        }
      } else {
        try {
          await config.tablesDB.deleteRow(
            databaseId: config.databaseId,
            tableId: config.tableId,
            rowId: docId,
          );
        } on aw.AppwriteException {
          // ignore
        }
      }
    }
  }

  @override
  Future<DateTime> getServerTime() async {
    if (config.serverTimeFunctionId != null && config.functions != null) {
      try {
        final exec = await config.functions!.createExecution(
          functionId: config.serverTimeFunctionId!,
          body: '',
        );
        // Expecting ISO-8601 UTC in response body
        final body = exec.responseBody.trim();
        if (body.isNotEmpty) {
          return DateTime.parse(body).toUtc();
        }
      } catch (_) {
        // fallback below
      }
    }
    // Fallback (not recommended for production sync): client time
    return DateTime.now().toUtc();
  }

  // Build upsert payloads (id, data) with optional scope injection. Exposed for tests.
  List<(String, Map<String, dynamic>)> buildUpsertPayloads(List<T> items) {
    final list = <(String, Map<String, dynamic>)>[];
    for (final item in items) {
      final id = config.idToString(config.idOf(item));
      final data = Map<String, dynamic>.from(config.toJson(item));
      if (config.injectScopeOnWrite && config.defaultScope != null) {
        final scopeMap =
            config.scopeFieldsBuilder?.call(config.defaultScope!) ??
            {
              config.scopeNameField: config.defaultScope!.name,
              config.scopeKeysField: config.defaultScope!.keys,
            };
        data.addAll(scopeMap);
      }
      list.add((id, data));
    }
    return list;
  }

  @override
  Future<List<T>> remoteSearch(SyncScope scope, QuerySpec spec) async {
    final queries = buildRemoteSearchQueries(scope, spec);
    // Test hook: execute via injected runner when provided
    if (config.searchRunner != null) {
      final rows = await config.searchRunner!(queries);
      return rows
          .map((e) => config.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }
    final res = await config.tablesDB.listRows(
      databaseId: config.databaseId,
      tableId: config.tableId,
      queries: queries,
    );
    return res.rows
        .map((r) => config.fromJson(Map<String, dynamic>.from(r.data)))
        .toList(growable: false);
  }

  /// Build Appwrite remoteSearch queries as a list of query strings.
  /// Exposed for tests to validate translation from QuerySpec.
  List<String> buildRemoteSearchQueries(SyncScope scope, QuerySpec spec) {
    return buildAppwriteRemoteSearchQueries(
      scope: scope,
      spec: spec,
      idField: config.idField,
      updatedAtField: config.updatedAtField,
      deletedAtField: config.deletedAtField,
      scopeNameField: config.scopeNameField,
    );
  }
}
