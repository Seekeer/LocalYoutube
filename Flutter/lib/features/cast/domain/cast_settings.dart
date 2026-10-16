/// What a person has chosen about casting on this installation.
///
/// All three values are local to the installation and survive an app restart. None of them is ever
/// derived from the device: Receiver Mode in particular is a setting, not a guess made from screen
/// size, platform flags or anything else.
class CastSettings {
  const CastSettings({
    required this.isReceiverMode,
    required this.deviceName,
    required this.lastSelectedReceiverDeviceId,
  });

  /// What an installation that has never been configured looks like: an ordinary Controller with no
  /// chosen name and no remembered Receiver.
  static const CastSettings defaults = CastSettings(
    isReceiverMode: false,
    deviceName: '',
    lastSelectedReceiverDeviceId: null,
  );

  /// Whether this installation offers itself as a Receiver.
  ///
  /// A Receiver is available only while the regular Android application is open; turning this on
  /// does not start a service and does not survive the app being closed as anything more than a
  /// remembered intention.
  final bool isReceiverMode;

  /// The name the person chose for this installation, or an empty string while it has never been
  /// renamed - in which case the Android device model is the name.
  final String deviceName;

  /// The Receiver this installation cast to last, remembered so repeat casting is quick.
  ///
  /// It is only preselected while that Receiver is currently online, and selecting a Receiver never
  /// starts a cast by itself.
  final String? lastSelectedReceiverDeviceId;

  CastSettings copyWith({
    bool? isReceiverMode,
    String? deviceName,
    String? lastSelectedReceiverDeviceId,
    bool clearLastSelectedReceiver = false,
  }) {
    return CastSettings(
      isReceiverMode: isReceiverMode ?? this.isReceiverMode,
      deviceName: deviceName ?? this.deviceName,
      lastSelectedReceiverDeviceId: clearLastSelectedReceiver
          ? null
          : lastSelectedReceiverDeviceId ?? this.lastSelectedReceiverDeviceId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastSettings &&
        other.isReceiverMode == isReceiverMode &&
        other.deviceName == deviceName &&
        other.lastSelectedReceiverDeviceId == lastSelectedReceiverDeviceId;
  }

  @override
  int get hashCode =>
      Object.hash(isReceiverMode, deviceName, lastSelectedReceiverDeviceId);
}
