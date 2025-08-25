[0.0.1]
* Initial version.


[0.1.0]

##### Added
- Flutter Web: Drift WASM + web worker (`lib/sync/drift/connection/connection_web.dart`).
- CLI: `dart run remote_cache_sync:web_setup` (generates `web/worker.dart`, builds, copies `worker*.js` + `sqlite3.wasm`; flags: `--release`, `--dest`, `--wasm`).
- Docs: README updates incl. CLI usage and CI example.

##### Changed
- Auto-select `worker.dart.js` (debug) or `worker.dart.min.js` (release) by runtime mode.

##### Removed
- Legacy script `tool/drift_web_assets_sync.sh` (replaced by CLI).
- Package-local `web/` directory (assets now generated in consumer apps).


[0.1.1]

##### Changed
- Widened dependency constraints to include latest majors for better pub.dev score:
  - `appwrite: ">=11.0.1 <18.0.0"`
  - `pocketbase: ">=0.17.0 <0.24.0"`

##### Docs
- README: Added explicit adapter import section to keep core entrypoint WASM-safe.

##### Tests
- Updated tests to import `remote_cache_sync_adapters.dart` for adapter symbols.

