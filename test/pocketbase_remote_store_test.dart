import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';
import 'package:pocketbase/pocketbase.dart';

class _Rec implements HasUpdatedAt {
  final String id;
  final String title;
  @override
  final DateTime updatedAt;
  const _Rec(this.id, this.title, this.updatedAt);
}

class _FakePB extends PocketBase {
  _FakePB() : super('http://localhost');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PocketBaseRemoteStore helpers', () {
    late PocketBaseRemoteStore<_Rec, String> store;

    setUp(() {
      final client = _FakePB();
      final config = PocketBaseRemoteConfig<_Rec, String>(
        client: client,
        collection: 'records',
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
      store = PocketBaseRemoteStore<_Rec, String>(config: config);
    });

    group('PocketBaseRemoteStore fetchSince integration (raw pages)', () {
      late int skippedAcc;
      late PocketBaseRemoteStore<_Rec, String> storeWithHook;
      setUp(() {
        skippedAcc = 0;
        storeWithHook = PocketBaseRemoteStore<_Rec, String>(
          config: PocketBaseRemoteConfig<_Rec, String>(
            client: _FakePB(),
            collection: 'records',
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
              skippedAcc += skipped;
            },
          ),
        );
      });

      test('aggregates pages with since and scope filters applied', () async {
        const scope = SyncScope('records', {'userId': 'u1'});
        final t0 = DateTime.utc(2024, 5, 1, 0, 0, 0);
        final t1 = DateTime.utc(2024, 5, 1, 0, 0, 1);
        final t2 = DateTime.utc(2024, 5, 1, 0, 0, 2);
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
        final t1 = DateTime.utc(2024, 5, 1, 0, 0, 1);
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
      final (idStr, data) = payloads.single;
      expect(idStr, 'a');
      expect(data['scope_name'], store.config.defaultScope!.name);
      expect(data['scope_keys'], store.config.defaultScope!.keys);
    });

    test('buildFetchFilter builds scope + since filter', () {
      const scope = SyncScope('records', {'userId': 'u1'});
      final since = DateTime.utc(2024, 1, 1);
      final filter = store.buildFetchFilter(scope, since);
      expect(filter, contains("scope_name='records'"));
      expect(filter, contains("updated_at>'${since.toIso8601String()}'"));
      expect(filter, contains('&&'));
    });

    test('buildFetchFilter without since returns only scope clause', () {
      const scope = SyncScope('records', {'userId': 'u1'});
      final filter = store.buildFetchFilter(scope, null);
      expect(filter, contains("scope_name='records'"));
      expect(filter, isNot(contains('updated_at>')));
    });

    test('parsePage splits upserts and deletes', () {
      final now = DateTime.utc(2024, 1, 1);
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
      final ts = DateTime.utc(2024, 1, 1, 12, 0, 0);
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
      final ts = DateTime.utc(2024, 1, 2);
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
      final ts = DateTime.utc(2024, 4, 1);
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
      final ts = DateTime.utc(2024, 4, 2);
      final rows = <Map<String, dynamic>>[
        {
          'id': 456, // invalid type
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
      final ts = DateTime.utc(2024, 4, 3);
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
          'updated_at': DateTime.utc(2024, 4, 4).toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u1'},
        },
        {
          'id': 'nm1',
          'title': 'NameMismatch',
          'updated_at': DateTime.utc(2024, 4, 4).toIso8601String(),
          'scope_name': 'others',
          'scope_keys': {'userId': 'u1'},
        },
        {
          'id': 'nm2',
          'title': 'KeysMismatch',
          'updated_at': DateTime.utc(2024, 4, 4).toIso8601String(),
          'scope_name': 'records',
          'scope_keys': {'userId': 'u2'},
        },
      ];
      final filtered = store.filterRowsByScope(rows, scope);
      expect(filtered.map((e) => e['id']), ['m1']);
    });
  });
}
