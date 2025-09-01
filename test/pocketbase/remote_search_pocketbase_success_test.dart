import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/sync/remote/pocketbase_search_plan.dart';

void main() {
  group('PocketBase buildRemoteSearchRequest success (builder only)', () {
    test('produces sort for updatedAt desc and id asc/desc', () {
      const scope = SyncScope('s', {'u': '1'});

      // updatedAt desc
      final reqUpdatedDesc = buildPocketBaseRemoteSearchRequest(
        scope: scope,
        spec: const QuerySpec(orderBy: [OrderSpec('updatedAt', descending: true)]),
        idField: 'id',
        updatedAtField: 'updated',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
      );
      expect(reqUpdatedDesc.$2, '-updated');
      expect(reqUpdatedDesc.$1, contains("scope_name='s'"));
      expect(reqUpdatedDesc.$1, contains('deleted_at = null'));

      // id asc
      final reqIdAsc = buildPocketBaseRemoteSearchRequest(
        scope: scope,
        spec: const QuerySpec(orderBy: [OrderSpec('id')]),
        idField: 'id',
        updatedAtField: 'updated',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
      );
      expect(reqIdAsc.$2, 'id');

      // id desc
      final reqIdDesc = buildPocketBaseRemoteSearchRequest(
        scope: scope,
        spec: const QuerySpec(orderBy: [OrderSpec('id', descending: true)]),
        idField: 'id',
        updatedAtField: 'updated',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
      );
      expect(reqIdDesc.$2, '-id');
    });

    test('calculates page/perPage when offset is multiple of limit', () {
      const scope = SyncScope('s', {'u': '1'});
      final req = buildPocketBaseRemoteSearchRequest(
        scope: scope,
        spec: const QuerySpec(limit: 10, offset: 20), // page should be 3
        idField: 'id',
        updatedAtField: 'updated',
        deletedAtField: 'deleted_at',
        scopeNameField: 'scope_name',
      );
      expect(req.$3, 3); // page
      expect(req.$4, 10); // perPage
    });
  });
}
