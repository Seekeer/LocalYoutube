import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/playback/initialize_video_playback.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  test('hardware fallback diagnostic preserves subsequent video events',
      () async {
    final initialized = VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 3),
      size: const Size(160, 90),
    );
    final completed = VideoEvent(eventType: VideoEventType.completed);
    final events = Stream<VideoEvent>.multi((controller) {
      controller.add(initialized);
      controller.addError(PlatformException(
          code: '', message: 'Failed to allocate AVHWDeviceContext.\n'));
      controller.add(completed);
      controller.close();
    });
    expect(await filterWindowsVideoEvents(events).toList(),
        [initialized, completed]);
  });

  test('source and decoding failures still reach the controller', () async {
    final failure =
        PlatformException(code: '', message: 'Failed to open media');
    await expectLater(
      filterWindowsVideoEvents(Stream<VideoEvent>.error(failure)),
      emitsError(same(failure)),
    );
  });
}
