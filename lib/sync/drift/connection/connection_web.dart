// Web connection using drift's WebAssembly backend.
// No FFI symbols are referenced here; safe for Flutter Web builds.

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/foundation.dart';

DatabaseConnection openConnection() {
  // Use a delayed connection to asynchronously load sqlite3.wasm and the drift worker.
  return DatabaseConnection.delayed(
    Future(() async {
      const workerJs = kReleaseMode ? 'worker.dart.min.js' : 'worker.dart.js';
      final opened = await WasmDatabase.open(
        databaseName: 'remote_cache_sync', // prefer simple identifiers
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse(workerJs),
      );
      if (opened.missingFeatures.isNotEmpty) {
        // Consider surfacing this to the user if persistence is critical.
        // e.g., Safari Private Mode may fall back to in-memory storage.
        // ignore: avoid_print
        print(
          'Drift(web) missing features: ${opened.missingFeatures}. '
          'Using ${opened.chosenImplementation}.',
        );
      }
      return opened.resolvedExecutor;
    }),
  );
}

DatabaseConnection openConnectionForTesting() {
  // Use a separate database name for tests to avoid sharing state.
  return DatabaseConnection.delayed(
    Future(() async {
      const workerJs = kReleaseMode ? 'worker.dart.min.js' : 'worker.dart.js';
      final opened = await WasmDatabase.open(
        databaseName: 'remote_cache_sync_test',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse(workerJs),
      );
      return opened.resolvedExecutor;
    }),
  );
}
