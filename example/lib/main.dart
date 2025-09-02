import 'package:flutter/material.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'backend_config.dart';

void main() => runApp(const MyApp());

// Model `Record` is defined in backend_config.dart

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final DriftLocalStore<Record, String> local;
  late final LocalDriftDatabase db;
  late final RemoteStore<Record, String> remote;
  late final SimpleSyncOrchestrator<Record, String> orchestrator;

  final scope = const SyncScope('records', {'userId': 'u1'});
  List<Record> items = const [];
  int _cacheSize = 0; // in bytes
  int? _cacheLimit; // null means unlimited

  @override
  void initState() {
    super.initState();
    // Initialize persistent Drift-backed local store
    db = LocalDriftDatabase();
    local = DriftLocalStore<Record, String>(
      db: db,
      idOf: (r) => r.id,
      idToString: (s) => s,
      idFromString: (s) => s,
      toJson: (r) => {
        'id': r.id,
        'title': r.title,
        'updatedAt': r.updatedAt.toIso8601String(),
      },
      fromJson: (m) => Record(
        id: m['id'] as String,
        title: m['title'] as String,
        updatedAt: DateTime.parse(m['updatedAt'] as String).toUtc(),
      ),
    );
    remote = createRemoteStore();
    orchestrator = SimpleSyncOrchestrator<Record, String>(
      local: local,
      remote: remote,
      resolver: const LastWriteWinsResolver<Record>(),
      idOf: (r) => r.id,
    );
    _refresh();
    _refreshCacheMeta();
  }

  Future<void> _refresh() async {
    final list = await local.query(scope);
    setState(() => items = list);
  }

  Future<void> _add() async {
    final now = DateTime.now().toUtc();
    final id = 'r_${now.microsecondsSinceEpoch}';
    final rec = Record(
      id: id,
      title: 'Item ${items.length + 1}',
      updatedAt: now,
    );
    await orchestrator.enqueueCreate(scope, id, rec);
    await _refresh();
    await _refreshCacheMeta();
  }

  Future<void> _updateFirst() async {
    if (items.isEmpty) return;
    final first = items.first;
    final rec = Record(
      id: first.id,
      title: '${first.title}*',
      updatedAt: DateTime.now().toUtc(),
    );
    await orchestrator.enqueueUpdate(scope, first.id, rec);
    await _refresh();
    await _refreshCacheMeta();
  }

  Future<void> _deleteFirst() async {
    if (items.isEmpty) return;
    await orchestrator.enqueueDelete(scope, items.first.id);
    await _refresh();
    await _refreshCacheMeta();
  }

  Future<void> _sync() async {
    await orchestrator.synchronize(scope);
    await _refresh();
    await _refreshCacheMeta();
  }

  // Cache management helpers
  Future<void> _refreshCacheMeta() async {
    final size = await local.approxCacheSizeBytes();
    final limit = await local.getCacheSizeLimitBytes();
    if (mounted) {
      setState(() {
        _cacheSize = size;
        _cacheLimit = limit;
      });
    }
  }

  Future<void> _setLimit(int? bytes) async {
    await local.setCacheSizeLimitBytes(bytes);
    await _refresh();
    await _refreshCacheMeta();
  }

  Future<void> _clearScope() async {
    await local.clearCache(scope: scope);
    await _refresh();
    await _refreshCacheMeta();
  }

  Future<void> _clearAll() async {
    await local.clearCache();
    await _refresh();
    await _refreshCacheMeta();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Remote Cache Sync Demo')),
        body: Column(
          children: [
            OverflowBar(
              alignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _add, child: const Text('Add')),
                ElevatedButton(
                  onPressed: _updateFirst,
                  child: const Text('Update First'),
                ),
                ElevatedButton(
                  onPressed: _deleteFirst,
                  child: const Text('Delete First'),
                ),
                ElevatedButton(onPressed: _sync, child: const Text('Sync')),
              ],
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cache size: \\${_cacheSize} B'),
                  Text('Limit: \\${_cacheLimit?.toString() ?? 'unlimited'}'),
                  const SizedBox(height: 8),
                  OverflowBar(
                    alignment: MainAxisAlignment.start,
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _setLimit(200 * 1024),
                        child: const Text('Set 200KB Limit'),
                      ),
                      ElevatedButton(
                        onPressed: () => _setLimit(null),
                        child: const Text('Remove Limit'),
                      ),
                      ElevatedButton(
                        onPressed: _clearScope,
                        child: const Text('Clear Scope'),
                      ),
                      ElevatedButton(
                        onPressed: _clearAll,
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final r = items[index];
                  return ListTile(
                    title: Text(r.title),
                    subtitle: Text(
                      '${r.id} | ${r.updatedAt.toIso8601String()}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
