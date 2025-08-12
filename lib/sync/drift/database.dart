// Drift database schema and connection setup.
// This file defines the tables used by the persistent LocalStore and
// provides a database instance backed by drift_flutter.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:drift/native.dart' as dn; // For in-memory DB in tests

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
  LocalDriftDatabase() : super(_openConnection());

  // Testing-friendly constructor using an in-memory database.
  LocalDriftDatabase.forTesting() : super(dn.NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  // Lifts platform-specific initialization automatically.
  return driftDatabase(name: 'remote_cache_sync.db');
}
