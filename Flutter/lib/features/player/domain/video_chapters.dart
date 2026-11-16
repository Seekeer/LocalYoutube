import 'player_models.dart';

/// One chapter's stretch of the timeline, from its start to the next chapter's.
class ChapterSegment {
  const ChapterSegment({
    required this.start,
    required this.end,
    required this.title,
  });

  final Duration start;
  final Duration end;

  /// Empty for the untitled stretch before a first chapter that does not start at 0:00.
  final String title;

  Duration get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is ChapterSegment &&
      other.start == start &&
      other.end == end &&
      other.title == title;

  @override
  int get hashCode => Object.hash(start, end, title);

  @override
  String toString() => 'ChapterSegment($start-$end, $title)';
}

/// The `chapters` of `GET /files/{id}`: `[{startSeconds, title}]`. Null when the
/// server sent none (an older server), so the caller falls back to the description.
List<VideoTimestamp>? chaptersFromServer(Object? raw) {
  if (raw is! List) {
    return null;
  }
  final List<VideoTimestamp> chapters = <VideoTimestamp>[];
  for (final Object? item in raw) {
    if (item is! Map) {
      continue;
    }
    final Object? start = item['startSeconds'];
    final String title = (item['title'] ?? '').toString().trim();
    if (start is! num || !start.isFinite || start < 0 || title.isEmpty) {
      continue;
    }
    chapters.add(
      VideoTimestamp(
        position: Duration(milliseconds: (start * 1000).round()),
        label: title,
      ),
    );
  }
  chapters.sort(
    (VideoTimestamp a, VideoTimestamp b) => a.position.compareTo(b.position),
  );
  return chapters;
}

// H:MM:SS, or M:SS / MM:SS / MMM:SS — the server's VideoChapterParser rule.
final RegExp _leadingTimestamp =
    RegExp(r'^(?:(\d{1,2}):([0-5]\d)|(\d{1,3})):([0-5]\d)$');
final RegExp _titleSeparators = RegExp(r'^[\s\-–—|:•·.]+');

/// Chapters from description lines that start with a timestamp, such as
/// «01:25 Очень увлекательный сезон»; ordinary text and links are not
/// chapters. Sorted, one per second (the first one wins).
List<VideoTimestamp> chaptersFromDescription(String description) {
  final List<VideoTimestamp> chapters = <VideoTimestamp>[];
  final Set<int> seconds = <int>{};
  for (final String raw in description.split(RegExp(r'\r\n|\n\r|\n|\r'))) {
    final String line = raw.trim();
    final int tokenEnd = line.indexOf(RegExp(r'\s'));
    final String token = tokenEnd < 0 ? line : line.substring(0, tokenEnd);
    final RegExpMatch? match = _leadingTimestamp.firstMatch(token);
    if (match == null) {
      continue;
    }
    final int hours = int.parse(match.group(1) ?? '0');
    final int minutes = int.parse(match.group(2) ?? match.group(3)!);
    final Duration start = Duration(
      hours: hours,
      minutes: minutes,
      seconds: int.parse(match.group(4)!),
    );
    final String title = (tokenEnd < 0 ? '' : line.substring(tokenEnd))
        .replaceFirst(_titleSeparators, '')
        .trim();
    if (title.isEmpty || !seconds.add(start.inSeconds)) {
      continue;
    }
    chapters.add(VideoTimestamp(position: start, label: title));
  }
  chapters.sort(
    (VideoTimestamp a, VideoTimestamp b) => a.position.compareTo(b.position),
  );
  return chapters;
}

/// Splits the timeline at chapter starts, YouTube-style. Chapters past the end
/// are dropped; a first chapter after 0:00 gets an untitled stretch before it.
List<ChapterSegment> buildChapterSegments(
  List<VideoTimestamp> chapters,
  Duration duration,
) {
  if (duration <= Duration.zero || chapters.isEmpty) {
    return const <ChapterSegment>[];
  }
  final List<VideoTimestamp> inside = chapters
      .where((VideoTimestamp c) => c.position < duration)
      .toList(growable: false)
    ..sort(
      (VideoTimestamp a, VideoTimestamp b) => a.position.compareTo(b.position),
    );
  if (inside.isEmpty) {
    return const <ChapterSegment>[];
  }

  final List<VideoTimestamp> starts = <VideoTimestamp>[
    if (inside.first.position > Duration.zero)
      const VideoTimestamp(position: Duration.zero, label: ''),
    ...inside,
  ];
  final List<ChapterSegment> segments = <ChapterSegment>[];
  for (int i = 0; i < starts.length; i++) {
    final Duration end =
        i + 1 < starts.length ? starts[i + 1].position : duration;
    if (end <= starts[i].position) {
      continue; // Two chapters at the same moment: the first one stays.
    }
    segments.add(
      ChapterSegment(start: starts[i].position, end: end, title: starts[i].label),
    );
  }
  return segments;
}

/// Index of the segment playing at [position], or -1.
int chapterSegmentAt(List<ChapterSegment> segments, Duration position) {
  for (int i = segments.length - 1; i >= 0; i--) {
    if (position >= segments[i].start) {
      return i;
    }
  }
  return -1;
}
