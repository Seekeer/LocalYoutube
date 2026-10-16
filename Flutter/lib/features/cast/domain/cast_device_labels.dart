/// How a Controller shows the account's devices.
///
/// Names are not unique, and nothing forces them to be: two Receivers can both be called "Living
/// room". Telling them apart is a display concern, solved where the snapshot is rendered rather
/// than by rejecting names or by decorating them on the server.
///
/// The rule, cheapest distinction first, so a viewer never has to read a full identity:
/// 1. a name nobody else uses stands on its own;
/// 2. a shared name is qualified by the Android model;
/// 3. only when the model does not settle it either does a short identity suffix appear.
library;

import 'cast_models.dart';

/// One device, ready to be shown.
class CastDeviceLabel {
  const CastDeviceLabel({
    required this.device,
    required this.name,
    this.detail,
  });

  final CastDevice device;

  /// The device's friendly name, exactly as it registered.
  final String name;

  /// What distinguishes this device from the others sharing its name, or `null` when the name
  /// already stands on its own.
  final String? detail;

  String get deviceId => device.deviceId;

  /// Name and detail on one line, for a surface that has room for only one.
  String get displayLabel => detail == null ? name : '$name ($detail)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastDeviceLabel &&
        other.device == device &&
        other.name == name &&
        other.detail == detail;
  }

  @override
  int get hashCode => Object.hash(device, name, detail);
}

/// The shortest identity suffix a viewer is ever shown. Four characters read as a tag rather than
/// as an identifier, and are enough to separate two devices in practice.
const int castIdentitySuffixLength = 4;

/// Labels [devices] so that no two of them read the same.
///
/// The input order is preserved: the API already returns a stable order, and re-sorting here would
/// make the list jump around whenever a device is renamed.
List<CastDeviceLabel> labelCastDevices(List<CastDevice> devices) {
  final Map<String, List<CastDevice>> byName = <String, List<CastDevice>>{};
  for (final CastDevice device in devices) {
    byName.putIfAbsent(device.name, () => <CastDevice>[]).add(device);
  }

  final List<CastDeviceLabel> labels = <CastDeviceLabel>[];
  for (final CastDevice device in devices) {
    final List<CastDevice> sharingName =
        byName[device.name] ?? <CastDevice>[device];
    if (sharingName.length == 1) {
      labels.add(CastDeviceLabel(device: device, name: device.name));
      continue;
    }

    final List<CastDevice> sharingModel = sharingName
        .where((CastDevice other) => other.model == device.model)
        .toList(growable: false);
    if (device.model.isNotEmpty && sharingModel.length == 1) {
      labels.add(
        CastDeviceLabel(
          device: device,
          name: device.name,
          detail: device.model,
        ),
      );
      continue;
    }

    final String suffix = _identitySuffix(device, sharingModel);
    labels.add(
      CastDeviceLabel(
        device: device,
        name: device.name,
        detail: device.model.isEmpty ? suffix : '${device.model} $suffix',
      ),
    );
  }

  return List<CastDeviceLabel>.unmodifiable(labels);
}

/// The shortest tail of the device identity that is unique among [group], never shorter than
/// [castIdentitySuffixLength]. Two identities that agree all the way fall back to the whole thing,
/// which cannot happen within one snapshot but costs nothing to be right about.
String _identitySuffix(CastDevice device, List<CastDevice> group) {
  int longest = 0;
  for (final CastDevice other in group) {
    if (other.deviceId.length > longest) {
      longest = other.deviceId.length;
    }
  }

  for (int length = castIdentitySuffixLength; length < longest; length++) {
    final String candidate = _tail(device.deviceId, length);
    final bool isUnique = group.every(
      (CastDevice other) =>
          other.deviceId == device.deviceId ||
          _tail(other.deviceId, length) != candidate,
    );
    if (isUnique) {
      return '#$candidate';
    }
  }

  return '#${device.deviceId}';
}

String _tail(String value, int length) {
  if (value.length <= length) {
    return value;
  }
  return value.substring(value.length - length);
}
