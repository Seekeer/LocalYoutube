import '../player_models.dart';

class ExtractTimestampsUseCase {
  static final RegExp _timestampPattern = RegExp(
    r'(?<!\d)(?:(\d{1,2}):)?([0-5]?\d):([0-5]\d)(?!\d)',
  );

  List<VideoTimestamp> call(String description) {
    if (description.trim().isEmpty) {
      return const <VideoTimestamp>[];
    }

    final List<VideoTimestamp> result = <VideoTimestamp>[];
    final Set<int> seenPositions = <int>{};
    final List<String> lines = description.split(RegExp(r'\r?\n'));

    for (final String line in lines) {
      final List<RegExpMatch> matches =
          _timestampPattern.allMatches(line).toList(growable: false);
      for (int i = 0; i < matches.length; i++) {
        final RegExpMatch match = matches[i];
        final Duration? position = _toDuration(match);
        if (position == null) {
          continue;
        }
        if (!seenPositions.add(position.inSeconds)) {
          continue;
        }

        final int nextMatchStart =
            i + 1 < matches.length ? matches[i + 1].start : line.length;
        String label = line.substring(match.end, nextMatchStart).trim();
        if (label.isEmpty) {
          label = line.substring(0, match.start).trim();
        }
        label = _normalizeLabel(label);
        if (label.isEmpty) {
          label = _formatDuration(position);
        }

        result.add(
          VideoTimestamp(
            position: position,
            label: label,
          ),
        );
      }
    }

    return result;
  }

  Duration? _toDuration(RegExpMatch match) {
    final String? hoursRaw = match.group(1);
    final String? minutesRaw = match.group(2);
    final String? secondsRaw = match.group(3);
    if (minutesRaw == null || secondsRaw == null) {
      return null;
    }
    final int hours = int.tryParse(hoursRaw ?? '0') ?? -1;
    final int minutes = int.tryParse(minutesRaw) ?? -1;
    final int seconds = int.tryParse(secondsRaw) ?? -1;
    if (hours < 0 || minutes < 0 || seconds < 0) {
      return null;
    }

    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  String _normalizeLabel(String value) {
    return value
        .replaceFirst(RegExp(r'^[\s\-\:\|\.\)\(]+'), '')
        .replaceFirst(RegExp(r'[\s\-\:\|]+$'), '')
        .trim();
  }

  String _formatDuration(Duration value) {
    final int totalSeconds = value.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds ~/ 60) % 60;
    final int seconds = totalSeconds % 60;

    String twoDigits(int raw) => raw.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
