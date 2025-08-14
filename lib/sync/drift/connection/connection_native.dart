// Native (mobile/desktop) connection using drift_flutter helper.
// Uses sqlite3 via platform libraries; not included in web builds.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/native.dart' as dn; // For in-memory DB in tests

DatabaseConnection openConnection() {
  // driftDatabase handles proper file location per platform.
  final executor = driftDatabase(name: 'remote_cache_sync.db');
  return DatabaseConnection(executor);
}

DatabaseConnection openConnectionForTesting() {
  // Use an in-memory database for fast, isolated tests.
  final exec = dn.NativeDatabase.memory();
  return DatabaseConnection(exec);
}
