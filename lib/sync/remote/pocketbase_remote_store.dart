import 'dart:async';

import 'package:pocketbase/pocketbase.dart';
import 'package:remote_cache_sync/sync/store_interfaces.dart';
import 'package:remote_cache_sync/sync/sync_types.dart';

/// Configuration for PocketBaseRemoteStore
///
/// Note: This scaffold avoids a hard dependency on the pocketbase SDK. Inject
/// your client or HTTP layer via [client] and implement the integration in the
/// TODO sections. Replace placeholders with your schema.
class PocketBaseRemoteConfig<T extends HasUpdatedAt, Id> {
  final PocketBase client; // PocketBase SDK client

  // Collection identification
  final String collection; // <your_collection>

  // Field mappings
  final String idField; // <id_field> (often 'id')
  final String updatedAtField; // <updated_at_field> (often PB 'updated')
  final String? deletedAtField; // <deleted_at_field>
  final String scopeNameField; // <scope_name_field>
  final String scopeKeysField; // <scope_keys_field>

  // ID and JSON mapping
  final Id Function(T) idOf;
  final String Function(Id) idToString;
  final Id Function(String) idFromString;
  final Map<String, dynamic> Function(T) toJson;
  final T Function(Map<String, dynamic>) fromJson;

  // Optional server time endpoint
  final String? serverTimeEndpoint; // e.g. /api/time (absolute or relative)

  // Scope injection options
  final SyncScope? defaultScope;
  final bool injectScopeOnWrite;
  final Map<String, dynamic> Function(SyncScope scope)? scopeFieldsBuilder;
  // Optional parse stats hook (for testing/observability)
  final void Function({required int skipped, required int total})? onParsePageStats;

  const PocketBaseRemoteConfig({
    required this.client,
    required this.collection,
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
    this.serverTimeEndpoint,
    this.defaultScope,
    this.injectScopeOnWrite = false,
    this.scopeFieldsBuilder,
    this.onParsePageStats,
  });
}

class PocketBaseRemoteStore<T extends HasUpdatedAt, Id>
    implements RemoteStore<T, Id> {
  final PocketBaseRemoteConfig<T, Id> config;
  const PocketBaseRemoteStore({required this.config});

  @override
  Future<T?> getById(Id id) async {
    // PocketBase record 'id' is not our domain id; query by domain id field
    final filter = "${config.idField}='${config.idToString(id)}'";
    try {
      final rec = await config.client
          .collection(config.collection)
          .getFirstListItem(filter);
      final data = Map<String, dynamic>.from(rec.data);
      return config.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // Parse a page of raw rows into upserts and delete ids. Exposed for tests.
  (List<T> upserts, List<Id> deletes) parsePage(List<Map<String, dynamic>> rows) {
    final upserts = <T>[];
    final deletes = <Id>[];
    var skipped = 0;
    for (final m in rows) {
      // Defensive checks: skip rows without required fields
      if (!m.containsKey(config.idField)) { skipped++; continue; }
      if (!m.containsKey(config.scopeNameField)) { skipped++; continue; }
      if (!m.containsKey(config.scopeKeysField)) { skipped++; continue; }
      final idRaw = m[config.idField];
      if (idRaw is! String) { skipped++; continue; }
      final isDeleted = config.deletedAtField != null && m[config.deletedAtField!] != null;
      if (isDeleted) {
        deletes.add(config.idFromString(idRaw));
      } else {
        upserts.add(config.fromJson(m));
      }
    }
    config.onParsePageStats?.call(skipped: skipped, total: rows.length);
    return (upserts, deletes);
  }

  // Build PB filter used by fetchSince. Exposed for tests.
  String buildFetchFilter(SyncScope scope, DateTime? since) {
    final parts = <String>[
      "${config.scopeNameField}='${scope.name}'",
    ];
    if (since != null) {
      parts.add("${config.updatedAtField}>'${since.toUtc().toIso8601String()}'");
    }
    return parts.join(' && ');
  }

  // Filter raw rows by scope equality. Exposed for tests.
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
      final nameOk = m[config.scopeNameField] == scope.name;
      final keysVal = m[config.scopeKeysField];
      final keysOk = keysVal is Map && shallowMapEquals(
        Map<String, dynamic>.from(keysVal),
        scope.keys,
      );
      return nameOk && keysOk;
    }).toList();
  }

  @override
  Future<Delta<T, Id>> fetchSince(SyncScope scope, DateTime? since) async {
    // Build PB filter string via helper for testability
    final filter = buildFetchFilter(scope, since);

    final upserts = <T>[];
    final deletes = <Id>[];

    int page = 1;
    const perPage = 100;
    while (true) {
      final list = await config.client
          .collection(config.collection)
          .getList(page: page, perPage: perPage, filter: filter, sort: config.updatedAtField);
      for (final rec in list.items) {
        final data = Map<String, dynamic>.from(rec.data);
        final isDeleted = config.deletedAtField != null && data[config.deletedAtField!] != null;
        if (isDeleted) {
          final did = config.idFromString(data[config.idField] as String);
          deletes.add(did);
        } else {
          upserts.add(config.fromJson(data));
        }
      }
      if (list.page >= list.totalPages) break;
      page += 1;
    }

    final serverTs = await getServerTime();
    return Delta<T, Id>(upserts: upserts, deletes: deletes, serverTimestamp: serverTs);
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
      final scoped = filterRowsByScope(page, scope);
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
    return Delta<T, Id>(upserts: upserts, deletes: deletes, serverTimestamp: serverTs);
  }

  @override
  Future<void> batchUpsert(List<T> items) async {
    final payloads = buildUpsertPayloads(items);
    for (final entry in payloads) {
      final idStr = entry.$1;
      final data = entry.$2;
      // Upsert by domain id field
      try {
        final existing = await config.client
            .collection(config.collection)
            .getFirstListItem("${config.idField}='$idStr'");
        await config.client
            .collection(config.collection)
            .update(existing.id, body: data);
      } catch (_) {
        data[config.idField] = idStr;
        await config.client.collection(config.collection).create(body: data);
      }
    }
  }

  @override
  Future<void> batchDelete(List<Id> ids) async {
    final soft = config.deletedAtField != null;
    for (final id in ids) {
      final idStr = config.idToString(id);
      try {
        final rec = await config.client
            .collection(config.collection)
            .getFirstListItem("${config.idField}='$idStr'");
        if (soft) {
          final patch = <String, dynamic>{config.deletedAtField!: DateTime.now().toUtc().toIso8601String()};
          if (config.injectScopeOnWrite && config.defaultScope != null) {
            final scopeMap = config.scopeFieldsBuilder?.call(config.defaultScope!) ?? {
              config.scopeNameField: config.defaultScope!.name,
              config.scopeKeysField: config.defaultScope!.keys,
            };
            patch.addAll(scopeMap);
          }
          await config.client.collection(config.collection).update(rec.id, body: patch);
        } else {
          await config.client.collection(config.collection).delete(rec.id);
        }
      } catch (_) {
        // ignore not found
      }
    }
  }

  @override
  Future<DateTime> getServerTime() async {
    if (config.serverTimeEndpoint != null) {
      try {
        final res = await config.client.send(config.serverTimeEndpoint!, method: 'GET');
        final body = (res.bodyString ?? '').trim();
        if (body.isNotEmpty) {
          return DateTime.parse(body).toUtc();
        }
      } catch (_) {
        // fallback below
      }
    }
    return DateTime.now().toUtc();
  }

  // Build upsert payloads (id, data) with optional scope injection. Exposed for tests.
  List<(String, Map<String, dynamic>)> buildUpsertPayloads(List<T> items) {
    final list = <(String, Map<String, dynamic>)>[];
    for (final item in items) {
      final idStr = config.idToString(config.idOf(item));
      final data = Map<String, dynamic>.from(config.toJson(item));
      if (config.injectScopeOnWrite && config.defaultScope != null) {
        final scopeMap = config.scopeFieldsBuilder?.call(config.defaultScope!) ?? {
          config.scopeNameField: config.defaultScope!.name,
          config.scopeKeysField: config.defaultScope!.keys,
        };
        data.addAll(scopeMap);
      }
      list.add((idStr, data));
    }
    return list;
  }
}
