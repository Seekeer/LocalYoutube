import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/transcript/domain/transcript.dart';

void main() {
  const transcript = Transcript(text: 'Hello 🌍\n\nworld', words: [
    TranscriptWord(startOffset: 0, endOffset: 5, start: 0, end: 1),
    TranscriptWord(startOffset: 6, endOffset: 8, start: 2, end: 3),
    TranscriptWord(startOffset: 10, endOffset: 15, start: 4, end: 5),
  ]);
  test('cursor, whitespace, paragraph and UTF-16 selections retain word timing',
      () {
    expect(transcript.wordAt(2)?.start, 0);
    expect(transcript.wordAt(6)?.start, 2);
    expect(transcript.wordAt(9)?.start, 2);
    expect(transcript.wordAt(10)?.start, 4);
    expect(transcript.wordAt(999)?.start, 4);
  });
  test('captions disappear in silence and before the first word', () {
    expect(transcript.captionAt(const Duration(milliseconds: 1700)), '');
    expect(transcript.captionAt(const Duration(seconds: 10)), '');
    expect(transcript.captionAt(Duration.zero), contains('Hello'));
  });
}
