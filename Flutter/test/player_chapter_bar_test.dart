import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/player/domain/player_models.dart';
import 'package:localtube_flutter/features/player/domain/video_chapters.dart';
import 'package:localtube_flutter/features/player/presentation/player_chapter_bar.dart';

const List<VideoTimestamp> _chapters = <VideoTimestamp>[
  VideoTimestamp(position: Duration.zero, label: 'Вступление'),
  VideoTimestamp(position: Duration(minutes: 2), label: 'Середина'),
  VideoTimestamp(position: Duration(minutes: 8), label: 'Финал'),
];

void main() {
  group('chaptersFromServer', () {
    test('reads startSeconds and title, sorted, skipping broken entries', () {
      expect(
        chaptersFromServer(<Object?>[
          <String, Object?>{'startSeconds': 38.48, 'title': 'The side cast'},
          <String, Object?>{'startSeconds': 0, 'title': ' Начало '},
          <String, Object?>{'startSeconds': 'x', 'title': 'Сломано'},
          <String, Object?>{'startSeconds': 10, 'title': ''},
          'не глава',
        ]),
        const <VideoTimestamp>[
          VideoTimestamp(position: Duration.zero, label: 'Начало'),
          VideoTimestamp(
            position: Duration(milliseconds: 38480),
            label: 'The side cast',
          ),
        ],
      );
    });

    test('is null without chapters from the server, empty with none', () {
      expect(chaptersFromServer(null), isNull);
      expect(chaptersFromServer(<Object?>[]), isEmpty);
    });
  });

  group('chaptersFromDescription', () {
    test('reads only lines that start with a timestamp and have a title', () {
      expect(
        chaptersFromDescription(
          <String>[
            'Промокод 11.11 — https://clck.ru/3MEdLf',
            'Обсудили в 01:30 вчера',
            '00:00 Приветики!',
            '01:25 — Очень увлекательный сезон',
            '1:02:03 С часами',
            '12:00',
            '10:60 нет',
            '01:25 Повтор',
          ].join('\r\n'),
        ),
        const <VideoTimestamp>[
          VideoTimestamp(position: Duration.zero, label: 'Приветики!'),
          VideoTimestamp(
            position: Duration(seconds: 85),
            label: 'Очень увлекательный сезон',
          ),
          VideoTimestamp(
            position: Duration(hours: 1, minutes: 2, seconds: 3),
            label: 'С часами',
          ),
        ],
      );
    });
  });

  group('buildChapterSegments', () {
    test('splits at chapter starts with an untitled lead-in and drops chapters past the end', () {
      expect(
        buildChapterSegments(
          const <VideoTimestamp>[
            VideoTimestamp(position: Duration(minutes: 1), label: 'Первая'),
            VideoTimestamp(position: Duration(minutes: 4), label: 'Вторая'),
            VideoTimestamp(position: Duration(minutes: 15), label: 'За концом'),
          ],
          const Duration(minutes: 10),
        ),
        const <ChapterSegment>[
          ChapterSegment(start: Duration.zero, end: Duration(minutes: 1), title: ''),
          ChapterSegment(
            start: Duration(minutes: 1),
            end: Duration(minutes: 4),
            title: 'Первая',
          ),
          ChapterSegment(
            start: Duration(minutes: 4),
            end: Duration(minutes: 10),
            title: 'Вторая',
          ),
        ],
      );
      expect(buildChapterSegments(_chapters, Duration.zero), isEmpty);
    });

    test('finds the segment playing at a position', () {
      final List<ChapterSegment> segments =
          buildChapterSegments(_chapters, const Duration(minutes: 10));
      expect(chapterSegmentAt(segments, const Duration(seconds: 119)), 0);
      expect(chapterSegmentAt(segments, const Duration(minutes: 2)), 1);
      expect(chapterSegmentAt(segments, const Duration(minutes: 9)), 2);
    });
  });

  group('PlayerChapterBar', () {
    Future<List<Duration>> pump(
      WidgetTester tester, {
      Duration position = const Duration(minutes: 3),
      bool isSeeking = false,
      bool enabled = true,
      bool compact = false,
    }) async {
      final List<Duration> seeks = <Duration>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: PlayerChapterBar(
                chapters: _chapters,
                duration: const Duration(minutes: 10),
                position: position,
                isSeeking: isSeeking,
                enabled: enabled,
                compact: compact,
                onSeek: seeks.add,
              ),
            ),
          ),
        ),
      );
      return seeks;
    }

    testWidgets('draws one segment per chapter, sized by its length', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      final double first =
          tester.getSize(find.byKey(const ValueKey<String>('player-chapter-segment-0'))).width;
      final double second =
          tester.getSize(find.byKey(const ValueKey<String>('player-chapter-segment-1'))).width;
      expect(find.byKey(const ValueKey<String>('player-chapter-segment-2')), findsOneWidget);
      expect(second / first, closeTo(3, 0.05));
      expect(find.text('Глава: Середина'), findsOneWidget);
    });

    testWidgets('tapping a segment seeks to the chapter start', (
      WidgetTester tester,
    ) async {
      final List<Duration> seeks = await pump(tester);

      await tester.tap(find.byKey(const ValueKey<String>('player-chapter-segment-2')));

      expect(seeks, const <Duration>[Duration(minutes: 8)]);
    });

    testWidgets('a locked bar does not seek', (WidgetTester tester) async {
      final List<Duration> seeks = await pump(tester, enabled: false);

      await tester.tap(find.byKey(const ValueKey<String>('player-chapter-segment-2')));

      expect(seeks, isEmpty);
    });

    testWidgets('hovering shows the chapter start and title', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey<String>('player-chapter-segment-2'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('8:00 · Финал'), findsOneWidget);
    });

    testWidgets('segments line up with the slider track under them', (
      WidgetTester tester,
    ) async {
      for (final EdgeInsets? padding in <EdgeInsets?>[
        null,
        const EdgeInsets.symmetric(horizontal: 2),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                child: ChapterTimeline(
                  sliderPadding: padding,
                  chapterBar: PlayerChapterBar(
                    chapters: _chapters,
                    duration: const Duration(minutes: 10),
                    position: Duration.zero,
                    onSeek: (_) {},
                  ),
                  slider: Slider(
                    key: const ValueKey<String>('slider'),
                    value: 0,
                    padding: padding,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        final Rect slider = tester.getRect(find.byKey(const ValueKey<String>('slider')));
        final double inset = padding?.left ??
            sliderTrackInset(
              SliderTheme.of(tester.element(find.byType(Slider))),
            );
        final Rect first = tester.getRect(
          find.byKey(const ValueKey<String>('player-chapter-segment-0')),
        );
        final Rect last = tester.getRect(
          find.byKey(const ValueKey<String>('player-chapter-segment-2')),
        );
        expect(first.left, moreOrLessEquals(slider.left + inset, epsilon: 0.5));
        expect(last.right, moreOrLessEquals(slider.right - inset, epsilon: 0.5));
      }
    });

    testWidgets('dragging the timeline shows the chapter under it', (
      WidgetTester tester,
    ) async {
      await pump(tester, position: const Duration(minutes: 9), isSeeking: true);

      expect(find.text('8:00 · Финал'), findsOneWidget);
    });

    testWidgets('fullscreen bar takes only the segments\' height', (
      WidgetTester tester,
    ) async {
      await pump(tester, compact: true);
      expect(tester.getSize(find.byType(PlayerChapterBar)).height, 16);
      expect(find.byKey(const ValueKey<String>('player-chapter-title')), findsNothing);

      await pump(
        tester,
        compact: true,
        position: const Duration(minutes: 9),
        isSeeking: true,
      );
      expect(tester.getSize(find.byType(PlayerChapterBar)).height, 16);
      expect(find.text('8:00 · Финал'), findsOneWidget);
    });
  });
}
