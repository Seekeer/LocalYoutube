import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/network/network_status.dart';
import 'package:localtube_flutter/features/notes/data/notes_api.dart';
import 'package:localtube_flutter/features/notes/data/notes_local_store.dart';
import 'package:localtube_flutter/features/notes/data/notes_repository.dart';
import 'package:localtube_flutter/features/notes/data/voice_recorder.dart';
import 'package:localtube_flutter/features/notes/domain/notes_models.dart';
import 'package:localtube_flutter/features/notes/presentation/notes_section.dart';

class FakeNotesRepository extends NotesRepository {
  FakeNotesRepository(this.snapshot)
      : super(
          api: NotesApi(Dio()),
          store: NotesLocalStore(AppDatabase(executor: NativeDatabase.memory())),
        );

  NotesSnapshot snapshot;
  List<SuggestedTopic> suggestions = const <SuggestedTopic>[];
  final List<String> calls = <String>[];
  List<String>? savedTopics;
  String? savedReview;
  int? confirmedDraftId;

  @override
  Future<NotesSnapshot> load(int videoId) async => snapshot;

  @override
  Future<List<NoteDraft>> drafts(int videoId) async => snapshot.drafts;

  @override
  Future<List<NoteTopic>> vocabulary() async => const <NoteTopic>[
        NoteTopic(id: 1, name: 'История'),
        NoteTopic(id: 2, name: 'Политика'),
      ];

  @override
  Future<List<SuggestedTopic>> suggestTopics(int videoId) async {
    calls.add('suggest');
    return suggestions;
  }

  @override
  Future<bool> saveTopics(
    int videoId, {
    required List<String> topics,
    required bool noTopics,
    String title = '',
  }) async {
    calls.add('topics');
    savedTopics = topics;
    return true;
  }

  @override
  Future<bool> confirmReview(
    int videoId,
    String text, {
    int? draftId,
    String title = '',
  }) async {
    calls.add('review');
    savedReview = text;
    confirmedDraftId = draftId;
    return !snapshot.offline;
  }

  @override
  Future<bool> ask(
    int videoId,
    String query, {
    int? draftId,
    String title = '',
  }) async {
    calls.add('ask');
    return true;
  }
}

class _NoMicrophone implements VoiceRecorder {
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> start() async => false;

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Stream<void> get interruptions => const Stream<void>.empty();
}

VideoNotes notes({bool telegramLinked = true, bool aiAvailable = true}) =>
    VideoNotes(
      videoId: 7,
      topics: const <NoteTopic>[NoteTopic(id: 1, name: 'История')],
      review: 'Сохранённый отзыв',
      description: 'Описание из отзыва',
      descriptionStatus: 'ready',
      answers: <NoteAnswer>[
        const NoteAnswer(
          id: 1,
          query: 'Какие книги упомянуты?',
          answer: 'Три книги.',
          status: 'ready',
          error: '',
        ),
      ],
      aiAvailable: aiAvailable,
      speechAvailable: true,
      telegramLinked: telegramLinked,
    );

Future<void> pumpNotes(WidgetTester tester, FakeNotesRepository repository,
    {bool section = false}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        notesRepositoryProvider.overrideWithValue(repository),
        voiceRecorderProvider.overrideWithValue(_NoMicrophone()),
        networkStatusProvider.overrideWith(
          (Ref ref) => Stream<NetworkStatus>.value(NetworkStatus.online),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: section
                ? const NotesSection(videoId: 7, title: 'Видео')
                : const NotesContent(videoId: 7, title: 'Видео'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the section is collapsed until opened and then shows notes',
      (WidgetTester tester) async {
    final FakeNotesRepository repository = FakeNotesRepository(
      NotesSnapshot(notes: notes(), drafts: const <NoteDraft>[], offline: false),
    );
    await pumpNotes(tester, repository, section: true);
    expect(find.text('Заметки'), findsOneWidget);
    expect(find.text('Отзыв'), findsNothing);

    await tester.tap(find.text('Заметки'));
    await tester.pumpAndSettle();
    expect(find.text('Отзыв'), findsOneWidget);
    expect(find.text('Описание из отзыва'), findsOneWidget);
  });

  testWidgets('AI suggestions mark new topics and are saved with the rest',
      (WidgetTester tester) async {
    final FakeNotesRepository repository = FakeNotesRepository(
      NotesSnapshot(notes: notes(), drafts: const <NoteDraft>[], offline: false),
    )..suggestions = const <SuggestedTopic>[
        SuggestedTopic(name: 'Политика', isNew: false),
        SuggestedTopic(name: 'Война', isNew: true),
      ];
    await pumpNotes(tester, repository);

    expect(find.widgetWithText(InputChip, 'История'), findsOneWidget);
    await tester.tap(find.text('Предложить темы'));
    await tester.pumpAndSettle();
    expect(find.text('Война · новая'), findsOneWidget);

    await tester.tap(find.text('Война · новая'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить темы'));
    await tester.tap(find.text('Сохранить темы'));
    await tester.pumpAndSettle();
    expect(repository.savedTopics, <String>['История', 'Война']);
  });

  testWidgets('the Review is sent only by «Сохранить отзыв»',
      (WidgetTester tester) async {
    final FakeNotesRepository repository = FakeNotesRepository(
      NotesSnapshot(notes: notes(), drafts: const <NoteDraft>[], offline: false),
    );
    await pumpNotes(tester, repository);

    final Finder field = find.widgetWithText(TextField, 'Что вы думаете о видео');
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Новый отзыв');
    await tester.pumpAndSettle();
    expect(repository.calls, isNot(contains('review')));

    await tester.ensureVisible(find.text('Сохранить отзыв'));
    await tester.tap(find.text('Сохранить отзыв'));
    await tester.pumpAndSettle();
    expect(repository.savedReview, 'Новый отзыв');
  });

  testWidgets('without Telegram, Action and Ask say so',
      (WidgetTester tester) async {
    final FakeNotesRepository repository = FakeNotesRepository(
      NotesSnapshot(
        notes: notes(telegramLinked: false),
        drafts: const <NoteDraft>[],
        offline: false,
      ),
    );
    await pumpNotes(tester, repository);
    expect(find.text('Telegram не привязан'), findsNWidgets(2));
    expect(find.text('Сформулировать'), findsNothing);
  });

  testWidgets('without AI, suggestions and questions are hidden',
      (WidgetTester tester) async {
    final FakeNotesRepository repository = FakeNotesRepository(
      NotesSnapshot(
        notes: notes(aiAvailable: false),
        drafts: const <NoteDraft>[],
        offline: false,
      ),
    );
    await pumpNotes(tester, repository);
    expect(find.text('Предложить темы'), findsNothing);
    expect(find.text('Перегенерировать'), findsNothing);
    expect(find.widgetWithText(TextField, 'Вопрос по содержанию видео'),
        findsNothing);
  });

  testWidgets('offline, saved notes are read-only and Drafts await confirmation',
      (WidgetTester tester) async {
    final FakeNotesRepository repository = FakeNotesRepository(
      NotesSnapshot(
        notes: notes(),
        drafts: <NoteDraft>[
          NoteDraft(
            id: 5,
            videoId: 7,
            kind: NoteDraftKind.review,
            status: NoteDraftStatus.ready,
            text: 'Надиктовано без связи',
            createdAt: DateTime(2026, 11, 5),
          ),
          NoteDraft(
            id: 6,
            videoId: 7,
            kind: NoteDraftKind.query,
            status: NoteDraftStatus.recognitionFailed,
            clipPath: '/tmp/clip.m4a',
            error: 'Сервер недоступен.',
            createdAt: DateTime(2026, 11, 5),
          ),
        ],
        offline: true,
      ),
    );
    await pumpNotes(tester, repository);

    expect(find.text('Есть черновики'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Сохранённый отзыв'), findsOneWidget);
    expect(find.text('Изменить'), findsNothing);
    expect(repository.calls, isEmpty);

    await tester.tap(find.text('Использовать'));
    await tester.pumpAndSettle();
    final TextField review = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Черновик отзыва'),
    );
    expect(review.controller!.text, 'Надиктовано без связи');
    expect(repository.calls, isEmpty);

    await tester.ensureVisible(find.text('Сохранить черновик').first);
    await tester.tap(find.text('Сохранить черновик').first);
    await tester.pumpAndSettle();
    expect(repository.savedReview, 'Надиктовано без связи');
    expect(repository.confirmedDraftId, 5);
  });

  testWidgets('reloading keeps a half-typed Review',
      (WidgetTester tester) async {
    final FakeNotesRepository repository = FakeNotesRepository(
      NotesSnapshot(notes: notes(), drafts: const <NoteDraft>[], offline: false),
    );
    await pumpNotes(tester, repository);

    final Finder review =
        find.widgetWithText(TextField, 'Что вы думаете о видео');
    await tester.ensureVisible(review);
    await tester.enterText(review, 'Половина мысли');
    await tester.pumpAndSettle();

    // Saving Topics reloads the section.
    final Finder phrase = find.widgetWithText(TextField, 'Тема или фраза о темах');
    await tester.ensureVisible(phrase);
    await tester.enterText(phrase, 'Политика');
    await tester.ensureVisible(find.text('Добавить'));
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить темы'));
    await tester.tap(find.text('Сохранить темы'));
    await tester.pumpAndSettle();
    expect(repository.calls, contains('topics'));

    final TextField field = tester.widget<TextField>(review);
    expect(field.controller!.text, 'Половина мысли');
  });

  testWidgets('refused Topics offer «Повторить»',
      (WidgetTester tester) async {
    final FakeNotesRepository repository = FakeNotesRepository(
      NotesSnapshot(
        notes: notes(),
        drafts: <NoteDraft>[
          NoteDraft(
            id: 8,
            videoId: 7,
            kind: NoteDraftKind.topics,
            status: NoteDraftStatus.ready,
            text: '{"topics":["Политика"],"noTopics":false}',
            error: 'Тема не подходит.',
            createdAt: DateTime(2026, 11, 5),
          ),
        ],
        offline: false,
      ),
    );
    await pumpNotes(tester, repository);
    expect(find.text('Не применены: Тема не подходит.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Использовать'), findsNothing);
  });

  testWidgets('Topics waiting for the connection are not «есть черновики»',
      (WidgetTester tester) async {
    // They apply on their own and need nothing from the person.
    final FakeNotesRepository repository = FakeNotesRepository(NotesSnapshot(
      notes: notes(),
      drafts: <NoteDraft>[
        NoteDraft(
          id: 9,
          videoId: 7,
          kind: NoteDraftKind.topics,
          status: NoteDraftStatus.ready,
          text: '{"topics":["Политика"],"noTopics":false}',
          createdAt: DateTime(2026, 11, 5),
        ),
      ],
      offline: true,
    ));
    await pumpNotes(tester, repository, section: true);
    expect(find.text('есть черновики'), findsNothing);
  });
}
