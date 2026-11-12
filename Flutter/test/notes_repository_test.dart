import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/features/notes/data/notes_api.dart';
import 'package:localtube_flutter/features/notes/data/notes_local_store.dart';
import 'package:localtube_flutter/features/notes/data/notes_repository.dart';
import 'package:localtube_flutter/features/notes/domain/notes_models.dart';

/// A fake `api/notes` server behind a Dio interceptor.
class _FakeServer {
  bool unreachable = false;
  String? speechError;
  String? topicsError;

  /// Requests ('METHOD /path') that reach the server but get no answer in time.
  final Set<String> timeouts = <String>{};
  String recognized = 'Распознанный текст';
  final List<String> requests = <String>[];
  final List<Object?> bodies = <Object?>[];

  Map<String, dynamic> notes({
    List<String> topics = const <String>[],
    String? review,
  }) =>
      <String, dynamic>{
        'videoId': 7,
        'topics': <Map<String, dynamic>>[
          for (int i = 0; i < topics.length; i++)
            <String, dynamic>{'id': i + 1, 'name': topics[i], 'definition': ''},
        ],
        'noTopics': false,
        'review': review,
        'description': null,
        'descriptionStatus': null,
        'answers': <dynamic>[],
        'aiAvailable': true,
        'speechAvailable': true,
        'telegramLinked': true,
      };

  void attach(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          if (unreachable) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          final String key = '${options.method} ${options.path}';
          requests.add(key);
          bodies.add(options.data);
          if (timeouts.contains(key)) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
            return;
          }
          Object? data;
          int status = 200;
          if (key == 'GET /notes/videos/7') {
            data = notes(topics: <String>['История']);
          } else if (key == 'GET /notes/vocabulary') {
            data = <Map<String, dynamic>>[
              <String, dynamic>{'id': 1, 'name': 'История', 'definition': ''},
              <String, dynamic>{'id': 2, 'name': 'Политика', 'definition': ''},
            ];
          } else if (key == 'PUT /notes/videos/7/topics' &&
              topicsError != null) {
            status = 400;
            data = topicsError;
          } else if (key == 'PUT /notes/videos/7/topics') {
            final Map<String, dynamic> body =
                notesJsonMap(options.data);
            final Object? topics = body['topics'];
            data = notes(
              topics: topics is List
                  ? topics.map((dynamic t) => '$t').toList()
                  : const <String>[],
            );
          } else if (key == 'PUT /notes/videos/7/review') {
            data = notes(review: '${notesJsonMap(options.data)['text']}');
          } else if (key == 'POST /notes/speech') {
            if (speechError != null) {
              status = 503;
              data = speechError;
            } else {
              data = <String, dynamic>{'text': recognized};
            }
          } else if (key == 'GET /files/7') {
            data = <String, dynamic>{'id': 7, 'videoType': 10};
          } else if (key == 'GET /files/8') {
            data = <String, dynamic>{'id': 8, 'videoType': 2};
          } else if (key == 'GET /files/9') {
            data = <String, dynamic>{'id': 9, 'videoType': null};
          } else if (key == 'GET /notes/triage') {
            data = <String, dynamic>{
              'count': 1,
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'videoId': 9,
                  'title': 'Лекция',
                  'seriesName': 'Курс',
                  'watchedDate': '2026-11-01T10:00:00Z',
                  'reason': 'classify',
                },
              ],
            };
          } else {
            status = 404;
            data = 'Не найдено.';
          }
          final Response<dynamic> response = Response<dynamic>(
            requestOptions: options,
            statusCode: status,
            data: data,
          );
          if (status >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }
          handler.resolve(response);
        },
      ),
    );
  }
}

void main() {
  late AppDatabase database;
  late NotesLocalStore store;
  late _FakeServer server;
  late Dio dio;
  late NotesRepository repository;
  late Directory clips;
  bool autonomous = false;
  String account = 'alice';

  Future<String> clip(String name) async {
    final File file = File('${clips.path}/$name.m4a');
    await file.writeAsBytes(<int>[1, 2, 3, 4]);
    return file.path;
  }

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await database.initialize();
    account = 'alice';
    store = NotesLocalStore(database, account: () async => account);
    server = _FakeServer();
    dio = Dio();
    server.attach(dio);
    autonomous = false;
    repository = NotesRepository(
      api: NotesApi(dio),
      store: store,
      isOffline: () => autonomous,
    );
    clips = await Directory.systemTemp.createTemp('localtube-notes-');
  });

  tearDown(() async {
    dio.close(force: true);
    await database.close();
    if (await clips.exists()) {
      await clips.delete(recursive: true);
    }
  });

  test('loads notes online and shows the cached copy when unreachable',
      () async {
    final NotesSnapshot online = await repository.load(7);
    expect(online.offline, isFalse);
    expect(online.notes!.topics.single.name, 'История');

    server.unreachable = true;
    final NotesSnapshot offline = await repository.load(7);
    expect(offline.offline, isTrue);
    expect(offline.notes!.topics.single.name, 'История');
  });

  test('server errors come back with their own message', () async {
    server.speechError = 'Распознавание речи не настроено.';
    final String path = await clip('a');
    await expectLater(
      repository.recognizeClip(path),
      throwsA(
        isA<NotesFailure>().having(
          (NotesFailure f) => f.message,
          'message',
          'Распознавание речи не настроено.',
        ),
      ),
    );
    // The Mark caption clip stays for «Повторить» or «Удалить».
    expect(await File(path).exists(), isTrue);

    server.speechError = null;
    expect(await repository.recognizeClip(path), 'Распознанный текст');
    expect(await File(path).exists(), isFalse);
  });

  test('a Mark caption clip dictated offline is kept until deleted', () async {
    autonomous = true;
    final String path = await clip('mark');
    await expectLater(
      repository.recognizeClip(path),
      throwsA(isA<NotesFailure>().having(
        (NotesFailure f) => f.offline,
        'offline',
        isTrue,
      )),
    );
    expect(await File(path).exists(), isTrue);
    expect(server.requests, isEmpty);

    await repository.deleteClip(path);
    expect(await File(path).exists(), isFalse);
  });

  test('a timeout is a failure to show, not a lost connection', () async {
    server.timeouts.addAll(<String>{
      'POST /notes/speech',
      'POST /notes/videos/7/action/formulate',
      'POST /notes/videos/7/action/send',
    });

    final String path = await clip('slow');
    final DictationResult dictation =
        await repository.dictate(7, NoteDraftKind.review, path);
    expect(dictation.failure!.offline, isFalse);
    expect(dictation.failure!.timedOut, isTrue);
    NoteDraft draft = (await repository.drafts(7)).single;
    // Kept for «Повторить», not re-uploaded by every sync.
    expect(draft.status, NoteDraftStatus.recognitionFailed);
    server.requests.clear();
    await repository.syncDrafts();
    expect(server.requests, isNot(contains('POST /notes/speech')));
    await repository.deleteDraft(draft.id);

    await expectLater(
      repository.formulateAction(7, 'Купить книгу'),
      throwsA(isA<NotesFailure>().having(
        (NotesFailure f) => f.timedOut,
        'timedOut',
        isTrue,
      )),
    );
    expect(await repository.drafts(7), isEmpty);

    // It may have reached Telegram: never a Draft that would be sent twice.
    await expectLater(
      repository.sendAction(7, 'Купить книгу'),
      throwsA(isA<NotesFailure>().having(
        (NotesFailure f) => f.offline,
        'offline',
        isFalse,
      )),
    );
    expect(await repository.drafts(7), isEmpty);
  });

  test('a timeout while reading falls back to the cached notes', () async {
    await repository.load(7);
    server.timeouts.add('GET /notes/videos/7');
    final NotesSnapshot snapshot = await repository.load(7);
    expect(snapshot.offline, isTrue);
    expect(snapshot.notes!.topics.single.name, 'История');
  });

  test('a Review typed offline stays a Draft and is never sent on reconnect',
      () async {
    autonomous = true;
    final bool sent = await repository.confirmReview(7, 'Мой отзыв');
    expect(sent, isFalse);

    autonomous = false;
    await repository.syncDrafts();
    await repository.load(7);

    expect(server.requests, isNot(contains('PUT /notes/videos/7/review')));
    final List<NoteDraft> drafts = await repository.drafts(7);
    expect(drafts.single.kind, NoteDraftKind.review);
    expect(drafts.single.text, 'Мой отзыв');

    // Only the person's confirmation sends it, and that clears the Draft.
    final bool confirmed = await repository.confirmReview(
      7,
      drafts.single.text,
      draftId: drafts.single.id,
    );
    expect(confirmed, isTrue);
    expect(server.requests, contains('PUT /notes/videos/7/review'));
    expect(await repository.drafts(7), isEmpty);
  });

  test('a clip dictated offline is recognized after reconnect but not sent',
      () async {
    autonomous = true;
    final String path = await clip('offline');
    final DictationResult result =
        await repository.dictate(7, NoteDraftKind.query, path);
    expect(result.keptAsDraft, isTrue);
    expect(server.requests, isEmpty);
    expect(await File(path).exists(), isTrue);

    autonomous = false;
    await repository.syncDrafts();

    expect(server.requests, <String>['POST /notes/speech']);
    final NoteDraft draft = (await repository.drafts(7)).single;
    expect(draft.status, NoteDraftStatus.ready);
    expect(draft.text, 'Распознанный текст');
    expect(draft.hasClip, isFalse);
    expect(await File(path).exists(), isFalse);
    expect(server.requests, isNot(contains('POST /notes/videos/7/answers')));
  });

  test('a network failure during dictation keeps the clip for later',
      () async {
    server.unreachable = true;
    final String path = await clip('lost');
    final DictationResult result =
        await repository.dictate(7, NoteDraftKind.review, path);
    expect(result.keptAsDraft, isTrue);
    expect(result.failure!.offline, isTrue);
    final NoteDraft draft = (await repository.drafts(7)).single;
    expect(draft.status, NoteDraftStatus.pendingRecognition);
    expect(await File(path).exists(), isTrue);
  });

  test('failed recognition keeps the clip until it is retried or deleted',
      () async {
    autonomous = true;
    final String path = await clip('failing');
    await repository.dictate(7, NoteDraftKind.action, path);

    autonomous = false;
    server.speechError = 'Не удалось распознать запись.';
    await repository.syncDrafts();

    NoteDraft draft = (await repository.drafts(7)).single;
    expect(draft.status, NoteDraftStatus.recognitionFailed);
    expect(draft.error, 'Не удалось распознать запись.');
    expect(draft.hasClip, isTrue);
    expect(await File(path).exists(), isTrue);

    // A failed clip is not retried behind the person's back.
    server.speechError = null;
    server.requests.clear();
    await repository.syncDrafts();
    expect(server.requests, isEmpty);

    await repository.retryDraft(draft.id);
    draft = (await repository.drafts(7)).single;
    expect(draft.status, NoteDraftStatus.ready);
    expect(draft.text, 'Распознанный текст');
    expect(await File(path).exists(), isFalse);

    await repository.deleteDraft(draft.id);
    expect(await repository.drafts(7), isEmpty);
  });

  test('deleting a failed Draft removes its clip', () async {
    server.speechError = 'Ошибка.';
    final String path = await clip('delete');
    await repository.dictate(7, NoteDraftKind.review, path);
    final NoteDraft draft = (await repository.drafts(7)).single;
    expect(draft.status, NoteDraftStatus.recognitionFailed);

    await repository.deleteDraft(draft.id);
    expect(await File(path).exists(), isFalse);
    expect(await repository.drafts(7), isEmpty);
  });

  test('Topics selected offline use the cached Vocabulary and sync later',
      () async {
    await repository.vocabulary();
    autonomous = true;
    final bool online = await repository.saveTopics(
      7,
      topics: <String>['Политика'],
      noTopics: false,
    );
    expect(online, isFalse);
    final NotesSnapshot offline = await repository.load(7);
    expect(offline.notes!.topics.single.id, 2);

    autonomous = false;
    await repository.syncDrafts();
    expect(server.requests, contains('PUT /notes/videos/7/topics'));
    expect(await repository.drafts(7), isEmpty);
  });

  test('Topics the server refused wait for «Повторить»', () async {
    autonomous = true;
    await repository.saveTopics(
      7,
      topics: <String>['Политика'],
      noTopics: false,
    );
    expect((await repository.drafts(7)).single.needsPerson, isFalse);

    autonomous = false;
    server.topicsError = 'Тема не подходит.';
    await repository.syncDrafts();
    final NoteDraft draft = (await repository.drafts(7)).single;
    expect(draft.error, 'Тема не подходит.');
    expect(draft.needsPerson, isTrue);

    server.requests.clear();
    await repository.syncDrafts();
    await repository.syncDrafts();
    expect(server.requests, isNot(contains('PUT /notes/videos/7/topics')));

    server.topicsError = null;
    await repository.retryDraft(draft.id);
    expect(server.requests, contains('PUT /notes/videos/7/topics'));
    expect(await repository.drafts(7), isEmpty);
  });

  test('another account neither sees nor syncs the Drafts and cached notes',
      () async {
    await repository.load(7);
    autonomous = true;
    final String path = await clip('alice');
    await repository.dictate(7, NoteDraftKind.review, path);
    await repository.saveDraftText(7, NoteDraftKind.query, 'Вопрос Алисы');

    account = 'bob';
    expect(await repository.drafts(7), isEmpty);
    final NotesSnapshot offline = await repository.load(7);
    expect(offline.notes, isNull);
    expect(offline.drafts, isEmpty);

    autonomous = false;
    server.requests.clear();
    await repository.syncDrafts();
    expect(server.requests, isNot(contains('POST /notes/speech')));
    final NotesShelfData shelf = await repository.shelf();
    expect(shelf.items.where((NotesShelfItem item) => item.hasDrafts), isEmpty);
    expect(await File(path).exists(), isTrue);

    // Alice gets everything back.
    account = 'Alice';
    expect(await repository.drafts(7), hasLength(2));
  });

  test('signing out forgets Drafts, clips and cached notes', () async {
    await repository.load(7);
    autonomous = true;
    final String path = await clip('signout');
    await repository.dictate(7, NoteDraftKind.review, path);

    await repository.clearLocalData();
    expect(await File(path).exists(), isFalse);
    expect(await repository.drafts(7), isEmpty);
    expect((await repository.load(7)).notes, isNull);

    // Signed out, nothing is kept and nothing syncs.
    account = '';
    autonomous = false;
    server.requests.clear();
    await repository.syncDrafts();
    expect(server.requests, isEmpty);
    expect((await repository.shelf()).items, isEmpty);
  });

  test('note_drafts from before accounts get the column once', () async {
    final AppDatabase old = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(old.close);
    await old.execute(
      '''
      CREATE TABLE note_drafts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_id INTEGER NOT NULL,
        kind TEXT NOT NULL,
        status TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        clip_path TEXT NOT NULL DEFAULT '',
        error TEXT NOT NULL DEFAULT '',
        title TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
    );
    await old.execute(
      '''
      INSERT INTO note_drafts(video_id, kind, status, text, created_at, updated_at)
      VALUES (7, 'review', 'ready', 'Чей-то отзыв', '2026-11-01', '2026-11-01')
      ''',
    );
    await old.initialize();

    final List<Map<String, Object?>> columns =
        await old.query('PRAGMA table_info(note_drafts)');
    expect(
      columns.where((Map<String, Object?> c) => c['name'] == 'account'),
      hasLength(1),
    );
    // Nobody knows whose it was, so no account sees it.
    final NotesLocalStore oldStore =
        NotesLocalStore(old, account: () async => 'alice');
    expect(await oldStore.draftsForVideo(7), isEmpty);
  });

  test('only ExternalVideo and Courses get the post-viewing menu', () async {
    expect(await repository.isPostViewingVideo(7), isTrue);
    expect(await repository.isPostViewingVideo(8), isFalse);
    expect(await repository.isPostViewingVideo(9), isFalse);
    autonomous = true;
    expect(await repository.isPostViewingVideo(7), isFalse);
  });

  test('the shelf lists the Triage Queue and videos with Drafts', () async {
    autonomous = true;
    await repository.saveDraftText(
      7,
      NoteDraftKind.query,
      'Какие книги?',
      title: 'Подкаст',
    );
    autonomous = false;

    final NotesShelfData shelf = await repository.shelf();
    expect(shelf.count, 2);
    expect(shelf.items.first.videoId, 7);
    expect(shelf.items.first.reasonLabel, 'черновики');
    expect(shelf.items.first.title, 'Подкаст');
    expect(shelf.items.last.videoId, 9);
    expect(shelf.items.last.reasonLabel, 'разобрать');
  });
}
