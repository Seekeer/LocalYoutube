import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/notes/domain/notes_models.dart';
import 'package:localtube_flutter/features/notes/presentation/rating_dialog.dart';

Future<void> _open(
  WidgetTester tester, {
  required Future<void> Function(RatingDialogResult result) onSave,
  Future<VideoNotes?>? current,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RatingDialog(
                title: 'Лекция',
                current: current,
                onSave: onSave,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offers ten scores and saves the picked one with the Review',
      (WidgetTester tester) async {
    RatingDialogResult? saved;
    await _open(tester, onSave: (RatingDialogResult result) async => saved = result);

    for (int score = 1; score <= 10; score++) {
      expect(find.byKey(RatingDialog.scoreKey(score)), findsOneWidget);
    }
    expect(
      tester.widget<FilledButton>(find.byKey(RatingDialog.saveKey)).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(RatingDialog.scoreKey(3)));
    await tester.enterText(find.byKey(RatingDialog.reviewFieldKey), '  Скучно  ');
    await tester.pump();
    await tester.tap(find.byKey(RatingDialog.saveKey));
    await tester.pumpAndSettle();

    expect(saved?.rating, 3);
    expect(saved?.review, 'Скучно');
    expect(find.byType(RatingDialog), findsNothing);
  });

  testWidgets('a failed save stays open with the reason and keeps what was typed',
      (WidgetTester tester) async {
    int attempts = 0;
    await _open(
      tester,
      onSave: (RatingDialogResult result) async {
        attempts++;
        if (attempts == 1) {
          throw const NotesFailure('Нет связи с сервером.', offline: true);
        }
      },
    );

    await tester.tap(find.byKey(RatingDialog.scoreKey(9)));
    await tester.enterText(find.byKey(RatingDialog.reviewFieldKey), 'Отлично');
    await tester.pump();
    await tester.tap(find.byKey(RatingDialog.saveKey));
    await tester.pumpAndSettle();

    expect(find.byType(RatingDialog), findsOneWidget);
    expect(find.text('Нет связи с сервером.'), findsOneWidget);
    expect(find.text('Отлично'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.byKey(RatingDialog.scoreKey(9))).selected,
      isTrue,
    );

    await tester.tap(find.byKey(RatingDialog.saveKey));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(RatingDialog), findsNothing);
  });

  testWidgets('what arrives late does not overwrite what the person started',
      (WidgetTester tester) async {
    final Future<VideoNotes?> arrivingLate = Future<VideoNotes?>.delayed(
      const Duration(seconds: 1),
      () => const VideoNotes(videoId: 1, rating: 2, review: 'Старое'),
    );
    await _open(tester, onSave: (_) async {}, current: arrivingLate);

    await tester.tap(find.byKey(RatingDialog.scoreKey(7)));
    await tester.pump(const Duration(seconds: 2));

    expect(
      tester.widget<ChoiceChip>(find.byKey(RatingDialog.scoreKey(7))).selected,
      isTrue,
    );
    expect(find.text('Старое'), findsNothing);
  });

  test('a Rating is read from the server only inside the scale', () {
    expect(VideoNotes.fromJson(<String, dynamic>{'videoId': 1, 'rating': 8}).rating, 8);
    expect(VideoNotes.fromJson(<String, dynamic>{'videoId': 1, 'rating': null}).rating, isNull);
    expect(VideoNotes.fromJson(<String, dynamic>{'videoId': 1, 'rating': 0}).rating, isNull);
    expect(VideoNotes.fromJson(<String, dynamic>{'videoId': 1, 'rating': 11}).rating, isNull);
    expect(
      VideoNotes.fromJson(
        const VideoNotes(videoId: 1, rating: 5).toJson(),
      ).rating,
      5,
    );
  });
}
