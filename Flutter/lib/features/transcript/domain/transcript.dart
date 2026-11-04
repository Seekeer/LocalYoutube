class TranscriptWord {
  const TranscriptWord(
      {required this.startOffset,
      required this.endOffset,
      required this.start,
      required this.end});
  final int startOffset;
  final int endOffset;
  final double start;
  final double end;

  factory TranscriptWord.fromJson(Map<String, dynamic> json) => TranscriptWord(
        startOffset: (json['startOffset'] as num).toInt(),
        endOffset: (json['endOffset'] as num).toInt(),
        start: (json['start'] as num).toDouble(),
        end: (json['end'] as num).toDouble(),
      );
}

class Transcript {
  const Transcript({required this.text, required this.words});
  final String text;
  final List<TranscriptWord> words;

  factory Transcript.fromJson(Map<String, dynamic> json) => Transcript(
        text: json['text'] as String,
        words: (json['words'] as List)
            .map((dynamic w) =>
                TranscriptWord.fromJson(Map<String, dynamic>.from(w as Map)))
            .toList(),
      );

  TranscriptWord? wordAt(int offset) {
    int low = 0, high = words.length;
    while (low < high) {
      final int mid = (low + high) ~/ 2;
      if (words[mid].endOffset <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final TranscriptWord? next = low < words.length ? words[low] : null;
    final TranscriptWord? previous = low > 0 ? words[low - 1] : null;
    if (next == null) return previous;
    if (previous == null || offset >= next.startOffset) return next;
    return offset - previous.endOffset <= next.startOffset - offset
        ? previous
        : next;
  }

  String captionAt(Duration position) {
    final double seconds = position.inMilliseconds / 1000;
    int low = 0, high = words.length;
    while (low < high) {
      final int mid = (low + high) ~/ 2;
      if (words[mid].start <= seconds) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low == 0 || words[low - 1].end + 0.3 < seconds) return '';
    final int first = ((low - 1) ~/ 8) * 8;
    final int last = (first + 7).clamp(0, words.length - 1);
    return text
        .substring(words[first].startOffset, words[last].endOffset)
        .replaceAll('\n', ' ');
  }
}
