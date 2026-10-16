import 'dart:io';

import 'package:flutter/services.dart';

class AndroidRemotePlaybackNetworkLock {
  AndroidRemotePlaybackNetworkLock._();

  static final AndroidRemotePlaybackNetworkLock instance =
      AndroidRemotePlaybackNetworkLock._();

  static const MethodChannel _channel = MethodChannel(
    'org.localtube.app/player_network_lock',
  );

  bool get _supportsPlatform => Platform.isAndroid;

  Future<void> setEnabled(bool enabled) async {
    if (!_supportsPlatform) {
      return;
    }
    await _channel.invokeMethod<void>('setEnabled', <String, Object?>{
      'enabled': enabled,
    });
  }
}
