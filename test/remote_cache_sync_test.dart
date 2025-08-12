import 'package:flutter_test/flutter_test.dart';
import 'package:remote_cache_sync/remote_cache_sync.dart';
import 'package:remote_cache_sync/remote_cache_sync_platform_interface.dart';
import 'package:remote_cache_sync/remote_cache_sync_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRemoteCacheSyncPlatform
    with MockPlatformInterfaceMixin
    implements RemoteCacheSyncPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RemoteCacheSyncPlatform initialPlatform = RemoteCacheSyncPlatform.instance;

  test('$MethodChannelRemoteCacheSync is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRemoteCacheSync>());
  });

  test('getPlatformVersion', () async {
    RemoteCacheSync remoteCacheSyncPlugin = RemoteCacheSync();
    MockRemoteCacheSyncPlatform fakePlatform = MockRemoteCacheSyncPlatform();
    RemoteCacheSyncPlatform.instance = fakePlatform;

    expect(await remoteCacheSyncPlugin.getPlatformVersion(), '42');
  });
}
