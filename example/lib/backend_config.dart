// Backend selection and configuration for the example app.
// Comments are in English as per project preference.

import 'package:remote_cache_sync/remote_cache_sync.dart';

// Demo model used in example
class Record implements HasUpdatedAt {
  final String id;
  final String title;
  @override
  final DateTime updatedAt;

  const Record({
    required this.id,
    required this.title,
    required this.updatedAt,
  });
}

// Choose which backend to use in the example.
enum BackendType { inMemory, appwrite, pocketbase, supabase }

// Active backend for the example. Keep inMemory by default so the app runs out-of-the-box.
const BackendType activeBackend = BackendType.inMemory;

// Scope used by all examples
const SyncScope demoScope = SyncScope('records', {'userId': 'u1'});

// Factory to create a RemoteStore based on the active backend.
RemoteStore<Record, String> createRemoteStore() {
  switch (activeBackend) {
    case BackendType.inMemory:
      return InMemoryRemoteStore<Record, String>(idOf: (r) => r.id);
    case BackendType.appwrite:
      // TODO: Replace with your actual Appwrite client and config values.
      // import 'package:appwrite/appwrite.dart' as aw; (add at top if you enable)
      // final client = aw.Client()
      //   ..setEndpoint('<your_appwrite_endpoint>')
      //   ..setProject('<your_project_id>')
      //   ..setKey('<your_api_key>');
      // final databases = aw.Databases(client);
      // final functions = aw.Functions(client);
      // return AppwriteRemoteStore<Record, String>(
      //   config: AppwriteRemoteConfig<Record, String>(
      //     databases: databases,
      //     functions: functions,
      //     databaseId: '<your_database_id>',
      //     collectionId: '<your_collection>',
      //     idField: '<id_field>',
      //     updatedAtField: '<updated_at_field>',
      //     deletedAtField: '<deleted_at_field>',
      //     scopeNameField: '<scope_name_field>',
      //     scopeKeysField: '<scope_keys_field>',
      //     idOf: (r) => r.id,
      //     idToString: (s) => s,
      //     idFromString: (s) => s,
      //     toJson: (r) => {
      //       '<id_field>': r.id,
      //       'title': r.title,
      //       '<updated_at_field>': r.updatedAt.toIso8601String(),
      //       '<scope_name_field>': demoScope.name,
      //       '<scope_keys_field>': demoScope.keys,
      //     },
      //     fromJson: (m) => Record(
      //       id: m['<id_field>'] as String,
      //       title: m['title'] as String,
      //       updatedAt: DateTime.parse(m['<updated_at_field>'] as String).toUtc(),
      //     ),
      //     serverTimeFunctionId: '<your_function_id>',
      //     defaultScope: demoScope,
      //     injectScopeOnWrite: true,
      //   ),
      // );
      throw UnimplementedError(
        'Configure Appwrite backend and set activeBackend = BackendType.appwrite',
      );
    case BackendType.pocketbase:
      // TODO: Replace with your actual PocketBase client and config values.
      // import 'package:pocketbase/pocketbase.dart'; (add at top if you enable)
      // final pb = PocketBase('https://your-pocketbase.example');
      // return PocketBaseRemoteStore<Record, String>(
      //   config: PocketBaseRemoteConfig<Record, String>(
      //     client: pb,
      //     collection: '<your_collection>',
      //     idField: '<id_field>',
      //     updatedAtField: '<updated_at_field>',
      //     deletedAtField: '<deleted_at_field>',
      //     scopeNameField: '<scope_name_field>',
      //     scopeKeysField: '<scope_keys_field>',
      //     idOf: (r) => r.id,
      //     idToString: (s) => s,
      //     idFromString: (s) => s,
      //     toJson: (r) => {
      //       '<id_field>': r.id,
      //       'title': r.title,
      //       '<updated_at_field>': r.updatedAt.toIso8601String(),
      //       '<scope_name_field>': demoScope.name,
      //       '<scope_keys_field>': demoScope.keys,
      //     },
      //     fromJson: (m) => Record(
      //       id: m['<id_field>'] as String,
      //       title: m['title'] as String,
      //       updatedAt: DateTime.parse(m['<updated_at_field>'] as String).toUtc(),
      //     ),
      //     serverTimeEndpoint: 'https://your-api.example/time',
      //     defaultScope: demoScope,
      //     injectScopeOnWrite: true,
      //   ),
      // );
      throw UnimplementedError(
        'Configure PocketBase backend and set activeBackend = BackendType.pocketbase',
      );
    case BackendType.supabase:
      // TODO: Replace with your actual Supabase client and config values.
      // import 'package:supabase_flutter/supabase_flutter.dart'; (add at top if you enable)
      // final client = SupabaseClient('https://<project-ref>.supabase.co', '<anon_or_service_key>');
      // return SupabaseRemoteStore<Record, String>(
      //   config: SupabaseRemoteConfig<Record, String>(
      //     client: client,
      //     table: '<your_table>',
      //     idColumn: '<id_column>',
      //     updatedAtColumn: '<updated_at_column>',
      //     deletedAtColumn: '<deleted_at_column>', // or null for hard delete
      //     scopeNameColumn: '<scope_name_column>',
      //     scopeKeysColumn: '<scope_keys_column>',
      //     idOf: (r) => r.id,
      //     idToString: (s) => s,
      //     idFromString: (s) => s,
      //     toJson: (r) => {
      //       '<id_column>': r.id,
      //       'title': r.title,
      //       '<updated_at_column>': r.updatedAt.toIso8601String(),
      //     },
      //     fromJson: (m) => Record(
      //       id: m['<id_column>'] as String,
      //       title: m['title'] as String,
      //       updatedAt: DateTime.parse(m['<updated_at_column>'] as String).toUtc(),
      //     ),
      //     serverTimeRpcName: 'server_time',
      //     defaultScope: demoScope,
      //     injectScopeOnWrite: true,
      //     // Optional: per-item/per-id scope callbacks
      //     scopeColumnsBuilder: (s) => {
      //       '<scope_name_column>': s.name,
      //       '<scope_keys_column>': s.keys,
      //     },
      //     scopeForUpsert: (item) => demoScope, // or derive from item
      //     scopeForDelete: (id) => demoScope,   // or derive from id
      //   ),
      // );
      throw UnimplementedError(
        'Configure Supabase backend and set activeBackend = BackendType.supabase',
      );
  }
}
