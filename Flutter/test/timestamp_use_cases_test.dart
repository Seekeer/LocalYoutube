import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/player/domain/player_models.dart';
import 'package:localtube_flutter/features/player/domain/usecases/extract_timestamps_use_case.dart';
import 'package:localtube_flutter/features/player/domain/usecases/jump_to_nearest_timestamp_use_case.dart';

void main() {
  group('ExtractTimestampsUseCase', () {
    final ExtractTimestampsUseCase useCase = ExtractTimestampsUseCase();

    test('extracts mm:ss and hh:mm:ss timestamps with labels', () {
      final List<VideoTimestamp> result = useCase.call(
        '''
00:00 Intro
01:23 Setup
1:02:03 Deep dive
''',
      );

      expect(
        result,
        const <VideoTimestamp>[
          VideoTimestamp(position: Duration.zero, label: 'Intro'),
          VideoTimestamp(
              position: Duration(minutes: 1, seconds: 23), label: 'Setup'),
          VideoTimestamp(
            position: Duration(hours: 1, minutes: 2, seconds: 3),
            label: 'Deep dive',
          ),
        ],
      );
    });

    test('extracts multiple timestamps from one line and deduplicates', () {
      final List<VideoTimestamp> result = useCase.call(
        '00:00 Intro 05:10 Middle 05:10 Duplicate',
      );

      expect(
        result,
        const <VideoTimestamp>[
          VideoTimestamp(position: Duration.zero, label: 'Intro'),
          VideoTimestamp(
            position: Duration(minutes: 5, seconds: 10),
            label: 'Middle',
          ),
        ],
      );
    });

    test('uses formatted timestamp as fallback label', () {
      final List<VideoTimestamp> result = useCase.call('00:00');

      expect(
        result,
        const <VideoTimestamp>[
          VideoTimestamp(position: Duration.zero, label: '00:00'),
        ],
      );
    });
  });

  group('JumpToNearestTimestampUseCase', () {
    final JumpToNearestTimestampUseCase useCase =
        JumpToNearestTimestampUseCase();

    test('returns nearest next timestamp for current position', () {
      final VideoTimestamp? result = useCase.call(
        currentPosition: const Duration(minutes: 4, seconds: 20),
        timestamps: const <VideoTimestamp>[
          VideoTimestamp(
            position: Duration(minutes: 10),
            label: 'End',
          ),
          VideoTimestamp(
            position: Duration(minutes: 3),
            label: 'Part 1',
          ),
          VideoTimestamp(
            position: Duration(minutes: 5),
            label: 'Part 2',
          ),
        ],
      );

      expect(
        result,
        const VideoTimestamp(
          position: Duration(minutes: 5),
          label: 'Part 2',
        ),
      );
    });

    test('returns null when there is no next timestamp', () {
      final VideoTimestamp? result = useCase.call(
        currentPosition: const Duration(minutes: 10),
        timestamps: const <VideoTimestamp>[
          VideoTimestamp(
            position: Duration(minutes: 1),
            label: 'Intro',
          ),
          VideoTimestamp(
            position: Duration(minutes: 5),
            label: 'Main',
          ),
        ],
      );

      expect(result, isNull);
    });
  });
}
