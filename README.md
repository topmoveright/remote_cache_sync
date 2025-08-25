# Remote Cache Sync for Flutter

A Flutter/Dart toolkit for remote-first synchronization with offline cache, pending operations, conflict resolution, and scope-aware persistence.

## Installing

Use this package as an executable

1) Install it

```bash
dart pub global activate remote_cache_sync
```

2) Use it

This package exposes the following executable:

```bash
web_setup
```

Run from your Flutter app root to prepare Flutter Web (Drift WASM):

```bash
# Debug build to ./web
dart run remote_cache_sync:web_setup

# Or release build and custom destination
dart run remote_cache_sync:web_setup \
  --release \
  --dest /path/to/app/web \
  --wasm /absolute/path/to/sqlite3.wasm
```

Notes:
- Requires dev dependencies in your app: `build_runner`, `build_web_compilers`.
- If missing, the tool will print commands to add them.
- Copies a compiled `worker.dart.(js|min.js)` and `sqlite3.wasm` into your `web/` directory.

Use this package as a library

1) Depend on it

With Flutter:

```bash
flutter pub add remote_cache_sync
```

This will add a line like this to your pubspec.yaml and run `flutter pub get`:

```yaml
dependencies:
  remote_cache_sync: ^0.1.0
```

2) Import it

```dart
import 'package:remote_cache_sync/remote_cache_sync.dart';
```

Quick start and API examples are available in the docs below.

### Adapters import (Supabase/Appwrite/PocketBase)

To keep the core entrypoint WASM-compatible, backend adapters are provided via a separate barrel. Import adapters only if you use them:

```dart
// Core (WASM-safe)
import 'package:remote_cache_sync/remote_cache_sync.dart';

// Backend adapters (may pull non-web-safe deps)
import 'package:remote_cache_sync/remote_cache_sync_adapters.dart';
```

This keeps web/wasm builds compatible when you only need the core sync APIs.

## Flutter Web setup (Drift WASM quick guide)

Most apps will only need to run the helper once:

```bash
dart run remote_cache_sync:web_setup
```

What it does:
- Ensures `web/worker.dart` exists (creates a minimal default if missing).
- Builds it to JS (debug or release).
- Copies `sqlite3.wasm` to `web/`.

Common options:

```bash
dart run remote_cache_sync:web_setup --release
dart run remote_cache_sync:web_setup --dest ./example/web
dart run remote_cache_sync:web_setup --wasm ./assets/sqlite3.wasm
```

If you prefer a specific compiler:

```bash
dart run remote_cache_sync:web_setup --compiler dart2js
dart run remote_cache_sync:web_setup --compiler build_runner
```

## Documentation
- Full documentation: [Documentation site][docs-site]
- Quick links:
  - [Home][docs-home]
  - [Usage][docs-usage]
  - [Backend Guides][docs-guides]

## Issues and feedback
- Please file issues/feature requests here: [Issues](https://github.com/topmoveright/remote_cache_sync/issues)

## Contributing
- See repository guidelines: [Contributing](https://github.com/topmoveright/remote_cache_sync)

[docs-site]: https://topmoveright.github.io/remote_cache_sync/
[docs-home]: https://topmoveright.github.io/remote_cache_sync/#/
[docs-usage]: https://topmoveright.github.io/remote_cache_sync/#/usage/interfaces
[docs-guides]: https://topmoveright.github.io/remote_cache_sync/#/backend_guides/
