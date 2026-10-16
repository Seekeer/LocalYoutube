import 'dart:io';

import 'package:flutter/services.dart';

/// The Android device model, used as the default name of a device that has not been renamed.
///
/// Behind an interface so that tests supply a model without a platform channel.
abstract interface class DeviceModelSource {
  /// `android.os.Build.MODEL`, or an empty string where it is unavailable.
  Future<String> androidModel();
}

/// Reads the model from the host activity over a method channel.
///
/// Deliberately not a package: the model is one string from one Android API, and a method channel
/// next to the ones this app already has costs less than another dependency.
class PlatformDeviceModelSource implements DeviceModelSource {
  const PlatformDeviceModelSource();

  static const MethodChannel channel = MethodChannel(
    'org.localtube.app/device_info',
  );

  @override
  Future<String> androidModel() async {
    if (!Platform.isAndroid) {
      return '';
    }
    try {
      final String? model = await channel.invokeMethod<String>('getAndroidModel');
      return model?.trim() ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }
}
