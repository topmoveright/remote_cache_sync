// Drift database schema and connection setup.
// This file defines the tables used by the persistent LocalStore and
// provides a database instance via platform-conditional connection.

import 'package:drift/drift.dart';
import 'connection/connection.dart' as conn; // conditional openConnection

part 'database.g.dart';

// Tables
class Items extends Table {
  // Scope identification
  TextColumn get scopeName => text()();
  TextColumn get scopeKeys => text()(); // JSON-encoded keys map

  // Entity identity
  TextColumn get id => text()();

  // Serialized payload (JSON)
  TextColumn get payload => text()();

  // Timestamps (stored as ISO8601 strings)
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {scopeName, scopeKeys, id};
}

class SyncPoints extends Table {
  TextColumn get scopeName => text()();
  TextColumn get scopeKeys => text()();
  TextColumn get lastServerTs => text()();

  @override
  Set<Column<Object>>? get primaryKey => {scopeName, scopeKeys};
}

enum PendingOpTypeDB { create, update, delete }

class PendingOps extends Table {
  TextColumn get opId => text()();
  TextColumn get scopeName => text()();
  TextColumn get scopeKeys => text()();
  TextColumn get type => text()(); // one of PendingOpTypeDB
  TextColumn get id => text()();
  TextColumn get payload => text().nullable()(); // JSON when present
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>>? get primaryKey => {opId};
}

@DriftDatabase(tables: [Items, SyncPoints, PendingOps])
class LocalDriftDatabase extends _$LocalDriftDatabase {
  // Use `super.connect` to pass a DatabaseConnection (works for web/native).
  LocalDriftDatabase._(super.e);

  factory LocalDriftDatabase() => LocalDriftDatabase._(conn.openConnection());

  // Testing-friendly factory using platform-appropriate test connection.
  factory LocalDriftDatabase.forTesting() =>
      LocalDriftDatabase._(_openConnectionForTesting());

  @override
  int get schemaVersion => 1;
}

DatabaseConnection _openConnectionForTesting() {
  // Use testing variant when available; falls back to normal connection.
  try {
    return (conn.openConnectionForTesting)();
  } catch (_) {
    return conn.openConnection();
  }
}
