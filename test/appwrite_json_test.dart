import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/sync/remote/appwrite_remote_store.dart';
import 'package:remote_cache_sync/sync/sync_types.dart';
import 'package:appwrite/appwrite.dart' as aw;

// Mock classes
class FakeTablesDB implements aw.TablesDB {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test Model
class TestItem implements HasUpdatedAt {
  final String id;
  final String content;
  @override
  final DateTime updatedAt;

  TestItem({required this.id, required this.content, required this.updatedAt});
}

void main() {
  group('AppwriteRemoteStore JSON String Support', () {
    late FakeTablesDB mockTablesDB;
    late AppwriteRemoteStore<TestItem, String> store;
    late AppwriteRemoteConfig<TestItem, String> config;

    setUp(() {
      mockTablesDB = FakeTablesDB();
      config = AppwriteRemoteConfig<TestItem, String>(
        tablesDB: mockTablesDB,
        databaseId: 'db',
        tableId: 'table',
        idField: 'id',
        updatedAtField: 'updatedAt',
        deletedAtField: 'deletedAt',
        scopeNameField: 'scopeName',
        scopeKeysField: 'scopeKeys',
        idOf: (item) => item.id,
        idToString: (id) => id,
        idFromString: (id) => id,
        toJson: (item) => {
          'id': item.id,
          'content': item.content,
          'updatedAt': item.updatedAt.toIso8601String(),
        },
        fromJson: (json) => TestItem(
          id: json['id'],
          content: json['content'],
          updatedAt: DateTime.parse(json['updatedAt']),
        ),
        defaultScope: SyncScope('test', {'key': 'value'}),
        injectScopeOnWrite: true,
      );
      store = AppwriteRemoteStore(config: config);
    });

    test('filterRowsByScope should handle stringified JSON keys', () {
      final scope = SyncScope('test', {'key': 'value'});
      final rows = [
        {
          'id': '1',
          'scopeName': 'test',
          'scopeKeys': '{"key": "value"}', // Stringified JSON
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'id': '2',
          'scopeName': 'test',
          'scopeKeys': {'key': 'value'}, // Map (legacy support)
          'updatedAt': DateTime.now().toIso8601String(),
        },
        {
          'id': '3',
          'scopeName': 'test',
          'scopeKeys': '{"key": "wrong"}', // Mismatch
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ];

      final filtered = store.filterRowsByScope(rows, scope);

      expect(filtered.length, 2);
      expect(filtered[0]['id'], '1');
      expect(filtered[1]['id'], '2');
    });

    test('buildUpsertPayloads should stringify scope keys', () {
      final item = TestItem(
        id: '1',
        content: 'test',
        updatedAt: DateTime.now(),
      );

      final payloads = store.buildUpsertPayloads([item]);

      expect(payloads.length, 1);
      final data = payloads[0].$2;
      expect(data['scopeName'], 'test');
      expect(data['scopeKeys'], isA<String>());
      expect(jsonDecode(data['scopeKeys']), {'key': 'value'});
    });
  });
}
