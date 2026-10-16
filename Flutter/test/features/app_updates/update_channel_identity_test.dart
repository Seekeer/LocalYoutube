import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/app_updates/update_models.dart';

import 'app_updates_widget_test.dart' show metadata;

void main() {
  const identities = {
    'preview': String.fromEnvironment('LOCALTUBE_PREVIEW_APPLICATION_ID',
        defaultValue: 'org.localtube.app.debug'),
    'stable': String.fromEnvironment('LOCALTUBE_STABLE_APPLICATION_ID',
        defaultValue: 'org.localtube.app.stable'),
  };

  for (final entry in identities.entries) {
    test(
        '${entry.key} keeps its configured identity and rejects the other channel',
        () {
      final installed = InstalledApp(entry.value, 10, '1.0.10');
      expect(installed.channel, entry.key);
      expect(
          AvailableUpdate.parse(metadata(entry.key, entry.value, 11), installed)
              .versionCode,
          11);
      final other = entry.key == 'preview' ? 'stable' : 'preview';
      expect(
          () => AvailableUpdate.parse(
              metadata(other, entry.value, 11), installed),
          throwsFormatException);
      expect(
          () => AvailableUpdate.parse(
              metadata(entry.key, identities[other]!, 11), installed),
          throwsFormatException);
    });
  }
}
