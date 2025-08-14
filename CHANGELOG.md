[0.0.1]
* Initial version.


## [0.1.0] - 2025-08-14

### Added
- Flutter Web support: Drift WebAssembly (local `sqlite3.wasm` + web worker) connection (`lib/sync/drift/connection/connection_web.dart`).
- Dart CLI utility: `dart run remote_cache_sync:web_setup`
  - Auto-generates a minimal `web/worker.dart` if missing and builds it
  - Copies `worker.dart.js` (debug) / `worker.dart.min.js` (release) and `sqlite3.wasm` into the target app's `web/` directory
  - Options: `--release`, `--dest`, `--wasm`
- CLI environment checks
  - Verifies `dart` / `flutter` availability
  - Verifies destination write permissions
  - Verifies required dev dependencies (`build_runner`, `build_web_compilers`) with actionable guidance
- Documentation updates
  - README includes CLI usage and a GitHub Actions CI example

### Changed
- Connection now selects `worker.dart.js` (debug) or `worker.dart.min.js` (release) based on runtime mode.

### Removed
- Removed legacy shell script `tool/drift_web_assets_sync.sh` (replaced by the CLI).
- Removed package-local `web/` directory (assets are generated in consumer apps via the CLI).

