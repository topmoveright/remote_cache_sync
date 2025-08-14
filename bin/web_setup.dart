// Dart CLI: remote_cache_sync:web_setup
// Builds a Drift web worker and copies sqlite3.wasm into a Flutter app's web/ directory.
//
// Usage:
//   dart run remote_cache_sync:web_setup [--dest /path/to/app/web] [--wasm /path/to/sqlite3.wasm] [--release]
//
// Behavior:
// - Ensures a web/worker.dart entry exists (creates a minimal default if missing).
// - Runs build_runner to compile worker.dart to JS (debug or release).
// - Copies compiled JS to web/worker.dart.js (debug) or web/worker.dart.min.js (release).
// - Copies sqlite3.wasm to web/.

import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  final cwd = Directory.current;
  var destDir = Directory('${cwd.path}/web');
  String? wasmPath;
  var release = false;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    switch (a) {
      case '--dest':
        destDir = Directory(args[++i]);
        break;
      case '--wasm':
        wasmPath = args[++i];
        break;
      case '--release':
        release = true;
        break;
      case '-h':
      case '--help':
        _printUsage();
        exit(0);
      default:
        stderr.writeln('Unknown argument: $a');
        _printUsage();
        exit(64);
    }
  }

  // Ensure required tools exist
  await _ensureTools();

  // Ensure required dev dependencies exist in the consumer app
  await _ensureDevDeps(cwd.path);

  // Ensure web directory exists
  if (!await destDir.exists()) {
    await destDir.create(recursive: true);
  }

  // Validate destination path is writable
  await _ensureWritable(destDir);

  final appWebDir = destDir.path;
  final appWebWorkerDart = File('$appWebDir/worker.dart');
  if (!await appWebWorkerDart.exists()) {
    stdout.writeln('> Creating default web/worker.dart');
    await appWebWorkerDart.writeAsString(_defaultWorkerDart);
  }

  // Determine wasm source: explicit --wasm or discover bundled asset
  var wasmSource = wasmPath;
  if (wasmSource == null) {
    final discovered = await _locateBundledWasm();
    if (discovered != null) {
      wasmSource = discovered;
    } else {
      stderr.writeln('ERROR: sqlite3.wasm not found. Provide with --wasm <path>.');
      exit(2);
    }
  }

  // Run build_runner to compile worker
  stdout.writeln('> Building web/worker.dart (${release ? 'release' : 'debug'})');
  final outDir = Directory('build/web');
  final argsBuild = [
    'run',
    'build_runner',
    'build',
    if (release) '--release',
    '--delete-conflicting-outputs',
    '-o',
    'web:${outDir.path}/',
  ];
  await _run('dart', argsBuild, cwd: cwd.path);

  final compiled = File('${outDir.path}/worker.dart.js');
  if (!await compiled.exists()) {
    stderr.writeln('ERROR: Compiled worker not found at ${compiled.path}');
    exit(3);
  }

  // Copy outputs
  final workerOut = File(
    '$appWebDir/${release ? 'worker.dart.min.js' : 'worker.dart.js'}',
  );
  await compiled.copy(workerOut.path);
  await File(wasmSource).copy('$appWebDir/sqlite3.wasm');

  stdout
      .writeln('Done. Synced to: $appWebDir\n  - ${workerOut.path}\n  - $appWebDir/sqlite3.wasm');
}

void _printUsage() {
  stdout.writeln('''
Usage: dart run remote_cache_sync:web_setup [--dest DEST_DIR] [--wasm SQLITE3_WASM] [--release]

Examples:
  # Debug build to current project's web/
  dart run remote_cache_sync:web_setup

  # Release build to a specific app's web/
  dart run remote_cache_sync:web_setup --release --dest /path/to/app/web --wasm /path/to/sqlite3.wasm
''');
}

Future<void> _run(String exec, List<String> args, {required String cwd}) async {
  final p = await Process.start(exec, args, workingDirectory: cwd);
  stdout.addStream(p.stdout);
  stderr.addStream(p.stderr);
  final code = await p.exitCode;
  if (code != 0) {
    throw ProcessException(exec, args, 'Process exited with code $code', code);
  }
}

Future<void> _ensureTools() async {
  // Check dart
  try {
    final r = await Process.run('dart', ['--version']);
    if (r.exitCode != 0) {
      stderr.writeln('ERROR: Dart SDK not available (dart --version failed).');
      exit(20);
    }
  } catch (_) {
    stderr.writeln('ERROR: Dart SDK not found. Install Flutter/Dart SDK and ensure "dart" is on PATH.');
    exit(21);
  }

  // Check flutter (non-fatal but useful)
  try {
    final r = await Process.run('flutter', ['--version']);
    if (r.exitCode != 0) {
      stdout.writeln('[WARN] Flutter not found or not working. You can still build the worker, but flutter build web will require Flutter.');
    }
  } catch (_) {
    stdout.writeln('[WARN] Flutter not found on PATH. Worker build can proceed; web build requires Flutter.');
  }
}

Future<void> _ensureWritable(Directory destDir) async {
  try {
    final testFile = File('${destDir.path}/.rcs_write_test_${DateTime.now().millisecondsSinceEpoch}');
    await testFile.writeAsString('ok');
    await testFile.delete();
  } catch (e) {
    stderr.writeln('ERROR: Destination not writable: ${destDir.path}');
    stderr.writeln('Details: $e');
    exit(22);
  }
}

Future<void> _ensureDevDeps(String cwd) async {
  // Check dev deps via `dart pub deps` output
  try {
    final result = await Process.run('dart', ['pub', 'deps'], workingDirectory: cwd);
    if (result.exitCode != 0) {
      stderr.writeln('ERROR: Failed to run "dart pub deps" in $cwd');
      stderr.write(result.stderr);
      exit(10);
    }
    final out = (result.stdout ?? '').toString();
    final hasRunner = out.contains(RegExp(r'\bbuild_runner\b'));
    final hasWebCompilers = out.contains(RegExp(r'\bbuild_web_compilers\b'));
    final missing = <String>[];
    if (!hasRunner) missing.add('build_runner');
    if (!hasWebCompilers) missing.add('build_web_compilers');
    if (missing.isNotEmpty) {
      stderr.writeln('ERROR: Missing dev dependency in this app: ${missing.join(', ')}');
      stderr.writeln('Please run in your app root:');
      if (!hasRunner) {
        stderr.writeln('  dart pub add --dev build_runner');
      }
      if (!hasWebCompilers) {
        stderr.writeln('  dart pub add --dev build_web_compilers');
      }
      exit(11);
    }
  } on ProcessException catch (e) {
    stderr.writeln('ERROR: Unable to execute dart in $cwd: ${e.message}');
    exit(12);
  }
}

Future<String?> _locateBundledWasm() async {
  // Attempt 1: Use package_config to resolve this package's root and look for assets/sqlite3.wasm
  try {
    final config = File('${Directory.current.path}/.dart_tool/package_config.json');
    if (await config.exists()) {
      final json = jsonDecode(await config.readAsString()) as Map<String, dynamic>;
      final pkgs = (json['packages'] as List).cast<Map<String, dynamic>>();
      final self = pkgs.firstWhere(
        (p) => p['name'] == 'remote_cache_sync',
        orElse: () => {},
      );
      if (self.isNotEmpty) {
        final rootUri = self['rootUri'] as String?;
        if (rootUri != null) {
          final root = Uri.parse(rootUri).toFilePath(windows: Platform.isWindows);
          final candidate = File('$root/assets/sqlite3.wasm');
          if (await candidate.exists()) return candidate.path;
          final candidateLib = File('$root/lib/src/assets/sqlite3.wasm');
          if (await candidateLib.exists()) return candidateLib.path;
        }
      }
    }
  } catch (_) {
    // ignore
  }

  // Attempt 2: Walk up from the current script location
  try {
    var dir = File(Platform.script.toFilePath()).parent;
    for (var i = 0; i < 10; i++) {
      final candidate = File('${dir.path}/assets/sqlite3.wasm');
      if (await candidate.exists()) return candidate.path;
      final candidateLib = File('${dir.path}/lib/src/assets/sqlite3.wasm');
      if (await candidateLib.exists()) return candidateLib.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {
    // ignore errors during search
  }
  return null;
}

const _defaultWorkerDart = r'''
// Generated by remote_cache_sync:web_setup
// Minimal Drift worker entry used for Flutter Web (WASM backend)
import 'package:drift/wasm.dart';

void main() {
  WasmDatabase.workerMainForOpen();
}
''';
