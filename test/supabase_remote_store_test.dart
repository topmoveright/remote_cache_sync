import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Rec implements HasUpdatedAt {
  final String id;
  final String title;
  @override
  final DateTime updatedAt;
  const _Rec(this.id, this.title, this.updatedAt);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseRemoteStore helpers', () {
    late SupabaseRemoteStore<_Rec, String> store;
    late SupabaseClient client;

    setUp(() {
      // Dummy client; we do not perform any network calls in these tests.
      client = SupabaseClient('https://example.supabase.co', 'anon');
      final config = SupabaseRemoteConfig<_Rec, String>(
        client: client,
        table: 'records',
        idColumn: 'id',
        updatedAtColumn: 'updated_at',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
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
        scopeColumnsBuilder: (s) => {
          'scope_name': s.name,
          'scope_keys': s.keys,
        },
        // Per-item / per-id scope callbacks set in individual tests
      );
      store = SupabaseRemoteStore<_Rec, String>(config: config);
    });

  group('SupabaseRemoteStore parse/filter helpers', () {
    late SupabaseRemoteStore<_Rec, String> store;
    late SupabaseClient client;
    setUp(() {
      client = SupabaseClient('https://example.supabase.co', 'anon');
      final config = SupabaseRemoteConfig<_Rec, String>(
        client: client,
        table: 'records',
        idColumn: 'id',
        updatedAtColumn: 'updated_at',
        deletedAtColumn: 'deleted_at',
        scopeNameColumn: 'scope_name',
        scopeKeysColumn: 'scope_keys',
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
      );
      store = SupabaseRemoteStore<_Rec, String>(config: config);
    });

    test('filterRowsByScope uses value equality for keys', () {
      const scope = SyncScope('records', {'userId': 'u1'});
      final rows = [
        {'id': 'a', 'title': 'A', 'updated_at': '2024-05-01T00:00:00Z', 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}},
        {'id': 'b', 'title': 'B', 'updated_at': '2024-05-01T00:00:00Z', 'scope_name': 'records', 'scope_keys': {'userId': 'u2'}},
      ];
      final filtered = store.filterRowsByScope(rows, scope);
      expect(filtered.map((e) => e['id']), ['a']);
    });

    test('parsePage defensively skips invalid rows', () {
      final t = DateTime.utc(2024, 5, 1).toIso8601String();
      final rows = [
        {'title': 'no id', 'updated_at': t, 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // missing id
        {'id': 1, 'title': 'bad id', 'updated_at': t, 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // non-string id
        {'id': 'good', 'title': 'ok', 'updated_at': t, 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // good
        {'id': 'del', 'title': 'gone', 'updated_at': t, 'deleted_at': t, 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // delete
      ];
      final (ups, dels) = store.parsePage(rows);
      expect(ups.map((e) => e.id), ['good']);
      expect(dels, ['del']);
    });
  });

  group('SupabaseRemoteStore fetchSince integration (raw pages)', () {
    late int skippedAcc;
    late SupabaseRemoteStore<_Rec, String> storeWithHook;
    setUp(() {
      skippedAcc = 0;
      final client = SupabaseClient('https://example.supabase.co', 'anon');
      storeWithHook = SupabaseRemoteStore<_Rec, String>(
        config: SupabaseRemoteConfig<_Rec, String>(
          client: client,
          table: 'records',
          idColumn: 'id',
          updatedAtColumn: 'updated_at',
          deletedAtColumn: 'deleted_at',
          scopeNameColumn: 'scope_name',
          scopeKeysColumn: 'scope_keys',
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
          {'id': 'a', 'title': 'A', 'updated_at': t0.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // before since
          {'id': 'x', 'title': 'X', 'updated_at': t1.toIso8601String(), 'scope_name': 'other', 'scope_keys': {'userId': 'u1'}}, // scope mismatch
        ],
        [
          {'id': 'b', 'title': 'B', 'updated_at': t1.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // upsert
          {'id': 'c', 'title': 'C', 'updated_at': t2.toIso8601String(), 'deleted_at': t2.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // delete
        ],
      ];
      final delta = await storeWithHook.fetchSinceFromRawPages(scope, t0, pages);
      expect(delta.upserts.map((e) => e.id), ['b']);
      expect(delta.deletes, ['c']);
    });

    test('onParsePageStats accumulates skipped rows', () async {
      const scope = SyncScope('records', {'userId': 'u1'});
      final t1 = DateTime.utc(2024, 5, 1, 0, 0, 1);
      final pages = <List<Map<String, dynamic>>>[
        [
          {'title': 'NoId', 'updated_at': t1.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // missing id
          {'id': 1, 'title': 'BadId', 'updated_at': t1.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // non-string id
          {'id': 'g', 'title': 'Good', 'updated_at': t1.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}}, // good
        ],
      ];
      final delta = await storeWithHook.fetchSinceFromRawPages(scope, null, pages);
      expect(delta.upserts.map((e) => e.id), ['g']);
      expect(skippedAcc, 2);
    });

    test('since boundary is strict (equal timestamp excluded)', () async {
      const scope = SyncScope('records', {'userId': 'u1'});
      final t = DateTime.utc(2024, 5, 1, 0, 0, 1);
      final pages = <List<Map<String, dynamic>>>[
        [
          {'id': 'eq', 'title': 'EQ', 'updated_at': t.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}},
          {'id': 'gt', 'title': 'GT', 'updated_at': t.add(const Duration(milliseconds: 1)).toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}},
        ],
      ];
      final delta = await storeWithHook.fetchSinceFromRawPages(scope, t, pages);
      expect(delta.upserts.map((e) => e.id), ['gt']);
    });

    test('multi-page unordered input still aggregates correctly', () async {
      const scope = SyncScope('records', {'userId': 'u1'});
      final t0 = DateTime.utc(2024, 5, 1, 0, 0, 0);
      final t1 = DateTime.utc(2024, 5, 1, 0, 0, 1);
      final t2 = DateTime.utc(2024, 5, 1, 0, 0, 2);
      final pages = <List<Map<String, dynamic>>>[
        [
          {'id': 'c', 'title': 'C', 'updated_at': t2.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}},
        ],
        [
          {'id': 'a', 'title': 'A', 'updated_at': t0.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}},
          {'id': 'b', 'title': 'B', 'updated_at': t1.toIso8601String(), 'scope_name': 'records', 'scope_keys': {'userId': 'u1'}},
        ],
      ];
      final delta = await storeWithHook.fetchSinceFromRawPages(scope, t0, pages);
      // Order not enforced; assert set equality
      expect(delta.upserts.map((e) => e.id).toSet(), {'b', 'c'});
    });
  });

    test('buildUpsertRows injects per-item scope via scopeForUpsert', () {
      const s1 = SyncScope('records', {'userId': 'u1'});
      const s2 = SyncScope('records', {'userId': 'u2'});
      final now = DateTime.utc(2023, 1, 1);
      final items = <_Rec>[
        _Rec('a', 'A', now),
        _Rec('b', 'B', now.add(const Duration(seconds: 1))),
      ];

      // Override scopeForUpsert to alternate scopes
      final cfg = store.config.copyWith(
        scopeForUpsert: (item) => item.id == 'a' ? s1 : s2,
      );
      final s2Store = SupabaseRemoteStore<_Rec, String>(config: cfg);

      final rows = s2Store.buildUpsertRows(items);
      expect(rows, hasLength(2));
      final rowA = rows.firstWhere((e) => e['id'] == 'a');
      final rowB = rows.firstWhere((e) => e['id'] == 'b');
      expect(rowA['scope_name'], s1.name);
      expect(rowA['scope_keys'], s1.keys);
      expect(rowB['scope_name'], s2.name);
      expect(rowB['scope_keys'], s2.keys);
    });

    test('buildUpsertRows falls back to defaultScope when callback returns null', () {
      final items = <_Rec>[_Rec('a', 'A', DateTime.utc(2023, 1, 1))];
      final cfg = store.config.copyWith(
        scopeForUpsert: (_) => null,
      );
      final s2Store = SupabaseRemoteStore<_Rec, String>(config: cfg);
      final rows = s2Store.buildUpsertRows(items);
      expect(rows.single['scope_name'], store.config.defaultScope!.name);
      expect(rows.single['scope_keys'], store.config.defaultScope!.keys);
    });

    test('groupDeletesByScope groups ids using scopeForDelete then defaultScope', () {
      const s2 = SyncScope('records', {'userId': 'u2'});
      final cfg = store.config.copyWith(
        scopeForDelete: (id) => id == 'x' ? s2 : null, // x uses s2, others fallback to defaultScope
      );
      final s2Store = SupabaseRemoteStore<_Rec, String>(config: cfg);
      final groups = s2Store.groupDeletesByScope(['a', 'x', 'b']);
      expect(groups.length, 2); // defaultScope and s2
      final defIds = groups[store.config.defaultScope]!;
      final s2Ids = groups[s2]!;
      expect(defIds.toSet(), {'a', 'b'});
      expect(s2Ids.toSet(), {'x'});
    });
  });
}
