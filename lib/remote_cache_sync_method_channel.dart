import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'remote_cache_sync_platform_interface.dart';

/// An implementation of [RemoteCacheSyncPlatform] that uses method channels.
class MethodChannelRemoteCacheSync extends RemoteCacheSyncPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('remote_cache_sync');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
