import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';
import 'package:appwrite/appwrite.dart' as aw;

class _Rec implements HasUpdatedAt {
  final String id;
  final String title;
  @override
  final DateTime updatedAt;
  const _Rec(this.id, this.title, this.updatedAt);
}

class _FakeDatabases implements aw.Databases {
  // Minimal fake to satisfy type, methods unused in helper tests
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppwriteRemoteStore helpers', () {
    late AppwriteRemoteStore<_Rec, String> store;

    setUp(() {
      final databases = _FakeDatabases();
      final config = AppwriteRemoteConfig<_Rec, String>(
        databases: databases,
        functions: null,
        databaseId: 'db',
        collectionId: 'col',
        idField: 'id',
        updatedAtField: 'updated_at',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
        scopeKeysField: 'scope_keys',
        idOf: (r) => r.id,
        idToString: (s) => s,
        idFromString: (s) => s,
        toJson: (r) => {
          'id': r.id,
          'title': r.title,
          'updated_at': r.updatedAt.toIso8601String(),
        },
        fromJson: (m) => _Rec(
          m['id'] as String,
          m['title'] as String,
          DateTime.parse(m['updated_at'] as String).toUtc(),
        ),
        defaultScope: const SyncScope('records', {'userId': 'u1'}),
        injectScopeOnWrite: true,
        scopeFieldsBuilder: (s) => {'scope_name': s.name, 'scope_keys': s.keys},
      );
      store = AppwriteRemoteStore<_Rec, String>(config: config);
    });

    group('AppwriteRemoteStore fetchSince integration (raw pages)', () {
      late int skippedAcc;
      late AppwriteRemoteStore<_Rec, String> storeWithHook;
      setUp(() {
        skippedAcc = 0;
        storeWithHook = AppwriteRemoteStore<_Rec, String>(
          config: AppwriteRemoteConfig<_Rec, String>(
            databases: _FakeDatabases(),
            functions: null,
            databaseId: 'db',
            collectionId: 'col',
            idField: 'id',
            updatedAtField: 'updated_at',
            deletedAtField: 'deleted_at',
            scopeNameField: 'scope_name',
            scopeKeysField: 'scope_keys',
            idOf: (r) => r.id,
            idToString: (s) => s,
            idFromString: (s) => s,
            toJson: (r) => {
              'id': r.id,
              'title': r.title,
              'updated_at': r.updatedAt.toIso8601String(),
            },
            fromJson: (m) => _Rec(
              m['id'] as String,
              m['title'] as String,
              DateTime.parse(m['updated_at'] as String).toUtc(),
            ),
            onParsePageStats: ({required int skipped, required int total}) {
              // Accumulate skipped count from parsePage. 'total' is ignored in this test.
              skippedAcc += skipped;
            },
          ),
        );
      });

      test('aggregates pages with since and scope filters applied', () async {
        const scope = SyncScope('records', {'userId': 'u1'});
        final t0 = DateTime.utc(2025, 5, 1, 0, 0, 0);
        final t1 = DateTime.utc(2025, 5, 1, 0, 0, 1);
        final t2 = DateTime.utc(2025, 5, 1, 0, 0, 2);
        final pages = <List<Map<String, dynamic>>>[
          [
            // older than since -> excluded
            {
              'id': 'a',
              'title': 'A',
              'updated_at': t0.toIso8601String(),
              'scope_name': 'records',
              'scope_keys': {'userId': 'u1'},
            },
            // mismatched scope -> excluded
            {
              'id': 'x',
              'title': 'X',
              'updated_at': t1.toIso8601String(),
              'scope_name': 'other',
              'scope_keys': {'userId': 'u1'},
            },
          ],
          [
            // upsert
            {
              'id': 'b',
              'title': 'B',
              'updated_at': t1.toIso8601String(),
              'scope_name': 'records',
              'scope_keys': {'userId': 'u1'},
            },
            // delete
            {
              'id': 'c',
              'title': 'C',
              'updated_at': t2.toIso8601String(),
              'deleted_at': t2.toIso8601String(),
              'scope_name': 'records',
              'scope_keys': {'userId': 'u1'},
            },
          ],
        ];
        final delta = await storeWithHook.fetchSinceFromRawPages(
          scope,
          t0,
          pages,
        );
        expect(delta.upserts.map((e) => e.id), ['b']);
        expect(delta.deletes, ['c']);
      });

      test('onParsePageStats accumulates skipped rows', () async {
        const scope = SyncScope('records', {'userId': 'u1'});
        final t1 = DateTime.utc(2025, 5, 1, 0, 0, 1);
        final pages = <List<Map<String, dynamic>>>[
          [
            // missing id -> skipped
            {
              'title': 'NoId',
              'updated_at': t1.toIso8601String(),
              'scope_name': 'records',
              'scope_keys': {'userId': 'u1'},
            },
            // non-string id -> skipped
            {
              'id': 1,
              'title': 'BadId',
              'updated_at': t1.toIso8601String(),
              'scope_name': 'records',
              'scope_keys': {'userId': 'u1'},
            },
            // good -> upsert
            {
              'id': 'g',
              'title': 'Good',
              'updated_at': t1.toIso8601String(),
              'scope_name': 'records',
              'scope_keys': {'userId': 'u1'},
            },
          ],
        ];
        final delta = await storeWithHook.fetchSinceFromRawPages(
          scope,
          null,
          pages,
        );
        expect(delta.upserts.map((e) => e.id), ['g']);
        expect(skippedAcc, 2);
      });
    });

    test('buildUpsertPayloads injects default scope', () {
      final now = DateTime.utc(2023, 1, 1);
      final items = <_Rec>[_Rec('a', 'A', now)];
      final payloads = store.buildUpsertPayloads(items);
      expect(payloads, hasLength(1));
      final (id, data) = payloads.single;
      expect(id, 'a');
      expect(data['scope_name'], store.config.defaultScope!.name);
      expect(data['scope_keys'], store.config.defaultScope!.keys);
    });

    test('buildFetchQueries builds scope + since filters', () {
      const scope = SyncScope('records', {'userId': 'u1'});
      final since = DateTime.utc(2025, 1, 1);
      final queries = store.buildFetchQueries(scope, since);
      // Should contain equality on scopeName and greaterThan on updatedAt
      expect(
        queries.any((q) => q.contains('scope_name') && q.contains('records')),
        isTrue,
      );
      expect(
        queries.any(
          (q) =>
              q.contains('updated_at') && q.contains(since.toIso8601String()),
        ),
        isTrue,
      );
    });

    test('buildFetchQueries without since builds only scope filter', () {
      const scope = SyncScope('records', {'userId': 'u1'});
      final queries = store.buildFetchQueries(scope, null);
      expect(queries.length, greaterThanOrEqualTo(1));
      expect(
        queries.any((q) => q.contains('scope_name') && q.contains('records')),
        isTrue,
      );
      expect(queries.any((q) => q.contains('updated_at')), isFalse);
    });

    test('parsePage splits upserts and deletes', () {
      final now = DateTime.utc(2025, 1, 1);
      final rows = <Map<String, dynamic>>[
        {
          'id': 'a',
          'title': 'A',
          'updated_at': now.toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
        {
          'id': 'b',
          'title': 'B',
          'updated_at': now.toIso8601String(),
          'deleted_at': now.toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
      ];
      final (upserts, deletes) = store.parsePage(rows);
      expect(upserts.map((e) => e.id), ['a']);
      expect(deletes, ['b']);
    });

    test('parsePage handles same-timestamp mixed rows', () {
      final ts = DateTime.utc(2025, 2, 1, 12);
      final rows = <Map<String, dynamic>>[
        {
          'id': 'x1',
          'title': 'X1',
          'updated_at': ts.toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
        {
          'id': 'x2',
          'title': 'X2',
          'updated_at': ts.toIso8601String(),
          'deleted_at': ts.toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
        {
          'id': 'x3',
          'title': 'X3',
          'updated_at': ts.toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
      ];
      final (upserts, deletes) = store.parsePage(rows);
      expect(upserts.map((e) => e.id), ['x1', 'x3']);
      expect(deletes, ['x2']);
    });

    test('parsePage treats explicit null deleted_at as upsert', () {
      final ts = DateTime.utc(2025, 3, 1);
      final rows = <Map<String, dynamic>>[
        {
          'id': 'n1',
          'title': 'N1',
          'updated_at': ts.toIso8601String(),
          'deleted_at': null,
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
      ];
      final (upserts, deletes) = store.parsePage(rows);
      expect(upserts.map((e) => e.id), ['n1']);
      expect(deletes, isEmpty);
    });

    test('parsePage skips rows with missing id', () {
      final ts = DateTime.utc(2025, 4, 1);
      final rows = <Map<String, dynamic>>[
        {
          // 'id' missing
          'title': 'NoId',
          'updated_at': ts.toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
      ];
      final (upserts, deletes) = store.parsePage(rows);
      expect(upserts, isEmpty);
      expect(deletes, isEmpty);
    });

    test('parsePage skips rows with non-string id type', () {
      final ts = DateTime.utc(2025, 4, 2);
      final rows = <Map<String, dynamic>>[
        {
          'id': 123, // invalid type
          'title': 'BadIdType',
          'updated_at': ts.toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
      ];
      final (upserts, deletes) = store.parsePage(rows);
      expect(upserts, isEmpty);
      expect(deletes, isEmpty);
    });

    test('parsePage skips rows with missing scope fields', () {
      final ts = DateTime.utc(2025, 4, 3);
      final rows = <Map<String, dynamic>>[
        {
          'id': 'ok1',
          'title': 'NoScopeName',
          'updated_at': ts.toIso8601String(),
          // 'scope_name' missing
          'scope_keys': {'userId': 'u1'},
        },
        {
          'id': 'ok2',
          'title': 'NoScopeKeys',
          'updated_at': ts.toIso8601String(),
          'scope_name': 'records',
          // 'scope_keys' missing
        },
      ];
      final (upserts, deletes) = store.parsePage(rows);
      expect(upserts, isEmpty);
      expect(deletes, isEmpty);
    });

    test('filterRowsByScope keeps only matching scope rows', () {
      const scope = SyncScope('records', {'userId': 'u1'});
      final rows = <Map<String, dynamic>>[
        {
          'id': 'm1',
          'title': 'Match',
          'updated_at': DateTime.utc(2025, 4, 4).toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
        {
          'id': 'nm1',
          'title': 'NameMismatch',
          'updated_at': DateTime.utc(2025, 4, 4).toIso8601String(),
          'scope_name': 'others',
          'scope_keys': {'userId': 'u1'},
        },
        {
          'id': 'nm2',
          'title': 'KeysMismatch',
          'updated_at': DateTime.utc(2025, 4, 4).toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u2'},
        },
      ];
      final filtered = store.filterRowsByScope(rows, scope);
      expect(filtered.map((e) => e['id']), ['m1']);
    });
  });
}
