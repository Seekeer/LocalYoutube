import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/transcript/data/transcript_repository.dart';
import 'package:localtube_flutter/features/transcript/domain/transcript.dart';
import 'package:localtube_flutter/features/transcript/presentation/transcript_panel.dart';

const transcript = Transcript(text: 'Первое слово. Второе слово.', words: [
  TranscriptWord(startOffset: 0, endOffset: 6, start: .5, end: 1),
  TranscriptWord(startOffset: 7, endOffset: 13, start: 1.5, end: 2),
  TranscriptWord(startOffset: 14, endOffset: 20, start: 20, end: 20.5),
  TranscriptWord(startOffset: 21, endOffset: 27, start: 21, end: 22),
]);

class FakeRepository extends TranscriptRepository {
  FakeRepository() : super(Dio(), 'test');
  @override
  Future<Transcript?> cached(int id) async => null;
  @override
  Future<Map<String, dynamic>> status(int id) async => {'status': 'ready'};
  @override
  Future<Transcript> load(int id) async => transcript;
  @override
  Future<String> srt(int id) async => '';
}

class DelayedRepository extends FakeRepository {
  final previousVideo = Completer<Transcript>();

  @override
  Future<Transcript> load(int id) => id == 1
      ? previousVideo.future
      : Future.value(const Transcript(text: 'Другое видео.', words: []));
}

void main() {
  testWidgets('a late transcript cannot replace the newly selected video',
      (tester) async {
    final repository = DelayedRepository();
    final video = ValueNotifier<int>(1);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: ValueListenableBuilder<int>(
                        valueListenable: video,
                        builder: (context, id, _) => TranscriptPanel(
                            videoId: id,
                            onSeek: (_) async {},
                            onBookmark: (_, __) async => true)))))));
    await tester.tap(find.text('Текст видео'));
    await tester.pumpAndSettle();
    video.value = 2;
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Другое видео.');
    repository.previousVideo.complete(transcript);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Другое видео.');
    await tester.pumpWidget(const SizedBox.shrink());
    video.dispose();
  });

  testWidgets(
      'selection creates a normal bookmark at its own time, without seeking',
      (tester) async {
    double? position;
    String? caption;
    Duration? seek;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          transcriptRepositoryProvider.overrideWithValue(FakeRepository()),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: TranscriptPanel(
          videoId: 1,
          onSeek: (value) async {
            seek = value;
          },
          onBookmark: (value, text) async {
            position = value;
            caption = text;
            return true;
          },
        ))))));
    await tester.tap(find.text('Текст видео'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.selection =
        const TextSelection(baseOffset: 14, extentOffset: 27);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Создать закладку'));
    await tester.tap(find.text('Создать закладку'));
    await tester.pumpAndSettle();
    expect(position, 20);
    expect(caption, 'Второе слово.');
    expect(seek, isNull);
    await tester.tap(find.text('Перейти к 0:18'));
    await tester.pump();
    expect(seek, const Duration(milliseconds: 18500));
  });
}
