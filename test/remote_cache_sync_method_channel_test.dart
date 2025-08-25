import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelRemoteCacheSync platform = MethodChannelRemoteCacheSync();
  const MethodChannel channel = MethodChannel('remote_cache_sync');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
