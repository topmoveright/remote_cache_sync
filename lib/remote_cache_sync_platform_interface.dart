import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'remote_cache_sync_method_channel.dart';

abstract class RemoteCacheSyncPlatform extends PlatformInterface {
  /// Constructs a RemoteCacheSyncPlatform.
  RemoteCacheSyncPlatform() : super(token: _token);

  static final Object _token = Object();

  static RemoteCacheSyncPlatform _instance = MethodChannelRemoteCacheSync();

  /// The default instance of [RemoteCacheSyncPlatform] to use.
  ///
  /// Defaults to [MethodChannelRemoteCacheSync].
  static RemoteCacheSyncPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RemoteCacheSyncPlatform] when
  /// they register themselves.
  static set instance(RemoteCacheSyncPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
