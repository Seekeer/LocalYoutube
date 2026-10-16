import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/config/app_config.dart';

void main() {
  test('stage keeps network logs disabled by default without dart define', () {
    final AppConfig config = AppConfig.fromEnvironment(
      environmentOverride: AppEnvironment.stage,
    );

    expect(config.enableNetworkLogs, isFalse);
  });

  test('dev still enables network logs by default without dart define', () {
    final AppConfig config = AppConfig.fromEnvironment(
      environmentOverride: AppEnvironment.dev,
    );

    expect(config.enableNetworkLogs, isTrue);
  });
}
