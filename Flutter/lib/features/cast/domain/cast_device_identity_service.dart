import '../data/cast_device_identity_repository.dart';
import '../data/device_model_source.dart';
import 'cast_models.dart';

/// Assembles what this installation registers itself as: its stable identity, a human-readable
/// name, its Android model and the role it is asking for.
///
/// A device that has not been renamed defaults to its Android model, so the name is useful before
/// anyone customises it. The role is always passed in by the caller and never guessed.
class CastDeviceIdentityService {
  CastDeviceIdentityService({
    required CastDeviceIdentityRepository identityRepository,
    required DeviceModelSource deviceModelSource,
  })  : _identityRepository = identityRepository,
        _deviceModelSource = deviceModelSource;

  /// Used only when the platform reports no model and nothing has been named.
  static const String fallbackName = 'LocalTube device';

  final CastDeviceIdentityRepository _identityRepository;
  final DeviceModelSource _deviceModelSource;

  /// The name a device carries given what the person chose and what the platform reports.
  ///
  /// Stated once here because the settings screen has to show the same answer the registration
  /// sends: a device that has never been renamed is called after its Android model, and only a
  /// platform with no model at all falls back to [fallbackName].
  static String resolveName({
    required String preferredName,
    required String model,
  }) {
    final String requestedName = preferredName.trim();
    if (requestedName.isNotEmpty) {
      return requestedName;
    }
    final String trimmedModel = model.trim();
    return trimmedModel.isNotEmpty ? trimmedModel : fallbackName;
  }

  Future<CastDeviceRegistration> describe({
    required CastDeviceRole role,
    String? preferredName,
  }) async {
    final String deviceId = await _identityRepository.deviceId();
    final String model = await _readModel();

    return CastDeviceRegistration(
      deviceId: deviceId,
      name: resolveName(preferredName: preferredName ?? '', model: model),
      model: model,
      role: role,
    );
  }

  Future<String> _readModel() async {
    try {
      return (await _deviceModelSource.androidModel()).trim();
    } catch (_) {
      // A missing model costs a nicer default name, nothing else.
      return '';
    }
  }
}
