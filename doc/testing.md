# Testing Guide

This guide explains how to run and extend tests for the plugin, and how to set up a stable environment for persistence and remote adapters.

## Running tests

```sh
flutter test -r compact
```

## Flutter binding initialization

Some tests use Flutter plugins (e.g., `path_provider` via `drift_flutter`). Ensure the Flutter test bindings are initialized in your test's `main()`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ... your tests
}
```

## Drift persistence in tests

`drift_flutter` relies on platform channels. For unit tests, prefer an in-memory database to avoid plugin dependencies.

- Use the testing constructor on `LocalDriftDatabase`:
  - File: `lib/sync/drift/database.dart`
  - Constructor: `LocalDriftDatabase.forTesting()`

Example:

```dart
final db = LocalDriftDatabase.forTesting();
final store = DriftLocalStore<MyModel, String>(
  db: db,
  idOf: (m) => m.id,
  idToString: (s) => s,
  idFromString: (s) => s,
  toJson: (m) => {/* ... */},
  fromJson: (m) => MyModel.fromJson(m),
);
```

## In-memory stores caveats

- `InMemoryLocalStore` and `InMemoryRemoteStore` are for demos only.
- `InMemoryRemoteStore.batchUpsert()` distributes items into scopes that already exist internally and is not strictly scope-aware by input. When testing scope isolation, prefer using different IDs per scope to avoid accidental cross-scope propagation.

## Orchestrator testing tips

- Push pending ops with `enqueueCreate/Update/Delete`, then call `synchronize(scope)`.
- Verify `saveSyncPoint(scope, ts)` is called by checking `local.getSyncPoint(scope)`.
- Use `LastWriteWinsResolver<T>` to validate conflict resolution by `updatedAt`.

## Remote adapter tests (mocking)

For adapters integrating SDKs (Appwrite, PocketBase, Supabase), write unit tests by mocking the SDK clients and focusing on adapter behavior:

- Stub pagination and filters used in `fetchSince()`.
- Verify scope injection (when `injectScopeOnWrite` is enabled).
- Validate soft delete handling and field mapping.
- Mock `getServerTime()` from a trusted source (function/endpoint) and verify the orchestrator saves that timestamp.

You can use your preferred mocking framework (e.g., `mocktail`, `mockito`), or hand-written fakes if the surface is small.
