/// The Cast Session device protocol as it travels over SignalR.
///
/// Every literal in this file is the API's wire contract, observed against the real hub in
/// `src/Api.IntegrationTests/CastProtocolWireFormatTests.cs`: the hub serialises with camelCase
/// property names and lower-case role values, and accepts the same casing back. Changing a string
/// here changes the protocol.
///
/// An unrecognised payload never throws and never reaches the UI half-parsed. A device the client
/// cannot make sense of is dropped from the snapshot, which fails safe: an unknown device is simply
/// not offered as a cast target.
library;

/// What a device is doing in a Cast Session.
///
/// The role is always stated explicitly by the device itself. It is never inferred from screen size,
/// platform flags or anything else.
enum CastDeviceRole {
  /// The phone that remote-controls playback.
  controller('controller'),

  /// The explicitly designated device that plays the video.
  receiver('receiver');

  const CastDeviceRole(this.wireValue);

  /// The value the API expects and sends for this role.
  final String wireValue;

  /// Returns `null` for anything this client does not know, so an unknown role can be ignored
  /// instead of being guessed at.
  static CastDeviceRole? tryParse(Object? rawValue) {
    if (rawValue is! String) {
      return null;
    }
    final String value = rawValue.trim().toLowerCase();
    for (final CastDeviceRole role in CastDeviceRole.values) {
      if (role.wireValue == value) {
        return role;
      }
    }
    return null;
  }
}

/// What this installation tells the API about itself when it registers.
class CastDeviceRegistration {
  const CastDeviceRegistration({
    required this.deviceId,
    required this.name,
    required this.model,
    required this.role,
  });

  /// The stable identity generated once per installation and persisted across app restarts.
  final String deviceId;

  /// Human-readable name, shown to the person choosing where to cast.
  final String name;

  /// Android `Build.MODEL`, or an empty string on a platform that has no such notion.
  final String model;

  final CastDeviceRole role;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'deviceId': deviceId,
      'name': name,
      'model': model,
      'role': role.wireValue,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastDeviceRegistration &&
        other.deviceId == deviceId &&
        other.name == name &&
        other.model == model &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(deviceId, name, model, role);
}

/// One device of the account, as the API reports it.
///
/// There is no connection id here on purpose: the SignalR connection is a routing address the server
/// keeps to itself, and a device is addressed by [deviceId].
class CastDevice {
  const CastDevice({
    required this.deviceId,
    required this.name,
    required this.model,
    required this.role,
  });

  final String deviceId;
  final String name;
  final String model;
  final CastDeviceRole role;

  /// Returns `null` when the payload is not a device this client can use.
  static CastDevice? tryParse(Object? rawValue) {
    if (rawValue is! Map<Object?, Object?>) {
      return null;
    }

    final String deviceId = _readString(rawValue['deviceId']);
    if (deviceId.isEmpty) {
      return null;
    }

    final CastDeviceRole? role = CastDeviceRole.tryParse(rawValue['role']);
    if (role == null) {
      return null;
    }

    final String model = _readString(rawValue['model']);
    final String name = _readString(rawValue['name']);

    return CastDevice(
      deviceId: deviceId,
      name: name.isNotEmpty ? name : (model.isNotEmpty ? model : deviceId),
      model: model,
      role: role,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastDevice &&
        other.deviceId == deviceId &&
        other.name == name &&
        other.model == model &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(deviceId, name, model, role);
}

/// The authoritative list of the account's currently online devices.
///
/// The API answers a registration with one and pushes a fresh one whenever the account's devices
/// change. It is always the full list, never a delta, so a client that missed a message still
/// converges on the next one.
class CastDevicesSnapshot {
  const CastDevicesSnapshot(this.devices);

  static const CastDevicesSnapshot empty =
      CastDevicesSnapshot(<CastDevice>[]);

  final List<CastDevice> devices;

  /// The devices that offered themselves as a Receiver.
  List<CastDevice> get receivers => devices
      .where((CastDevice device) => device.role == CastDeviceRole.receiver)
      .toList(growable: false);

  /// Returns `null` when the payload is not a snapshot. Devices that cannot be parsed are left out
  /// rather than failing the whole snapshot.
  static CastDevicesSnapshot? tryParse(Object? rawValue) {
    if (rawValue is! Map<Object?, Object?>) {
      return null;
    }
    final Object? rawDevices = rawValue['devices'];
    if (rawDevices is! List<Object?>) {
      return null;
    }

    final List<CastDevice> devices = <CastDevice>[];
    for (final Object? rawDevice in rawDevices) {
      final CastDevice? device = CastDevice.tryParse(rawDevice);
      if (device != null) {
        devices.add(device);
      }
    }
    return CastDevicesSnapshot(List<CastDevice>.unmodifiable(devices));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! CastDevicesSnapshot || other.devices.length != devices.length) {
      return false;
    }
    for (int index = 0; index < devices.length; index++) {
      if (other.devices[index] != devices[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(devices);
}

String _readString(Object? value) {
  if (value is String) {
    return value.trim();
  }
  return '';
}
