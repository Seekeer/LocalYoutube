import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/auth_notifier.dart';
import '../../../core/playback/playback_mode.dart';
import '../domain/notes_models.dart';
import 'notes_api.dart';
import 'notes_local_store.dart';

final Provider<NotesRepository> notesRepositoryProvider =
    Provider<NotesRepository>(
  (Ref ref) => NotesRepository(
    api: NotesApi(ref.watch(dioProvider)),
    store: NotesLocalStore(ref.watch(appDatabaseProvider)),
    isOffline: () =>
        ref.read(effectiveAutonomousModeProvider) ||
        ref.read(authNotifierProvider).isOfflineFallback,
  ),
);

/// Bumped whenever notes or Drafts change, so the home shelf and the player
/// section reload.
final StateProvider<int> notesRevisionProvider =
    StateProvider<int>((Ref ref) => 0);

final FutureProvider<NotesShelfData> notesShelfProvider =
    FutureProvider<NotesShelfData>((Ref ref) async {
  ref.watch(notesRevisionProvider);
  ref.watch(effectiveAutonomousModeProvider);
  // Signing in or out may change the account the shelf belongs to.
  ref.watch(
    authNotifierProvider.select((AuthNotifier auth) => auth.accessMode),
  );
  return ref.watch(notesRepositoryProvider).shelf();
});

/// Video notes with offline Drafts.
///
/// Nothing dictated or typed reaches the review, action or query endpoints
/// without the person confirming it: Drafts are only recognized and kept here.
/// Topics selected offline are applied on reconnect, because selecting them was
/// the confirmation.
class NotesRepository {
  NotesRepository({
    required NotesApi api,
    required NotesLocalStore store,
    bool Function()? isOffline,
  })  : _api = api,
        _store = store,
        _isOffline = isOffline;

  final NotesApi _api;
  final NotesLocalStore _store;
  final bool Function()? _isOffline;

  /// Shared by every instance: the sync coordinator and the screens must not
  /// upload the same clip twice.
  static bool _isSyncing = false;

  /// Post-viewing lookups by video, started when the player opens so the
  /// end of the video does not wait for the network.
  final Map<int, Future<bool>> _postViewing = <int, Future<bool>>{};

  bool get isOffline {
    try {
      return _isOffline?.call() ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---- Reading ----

  Future<NotesSnapshot> load(int videoId) async {
    if (!isOffline) {
      await syncDrafts(videoId: videoId);
      try {
        final VideoNotes notes = await _api.get(videoId);
        await _store.saveNotes(notes);
        return NotesSnapshot(
          notes: notes,
          drafts: await _store.draftsForVideo(videoId),
          offline: false,
        );
      } catch (error) {
        final NotesFailure failure = notesFailureFrom(error);
        // Reading is safe to fall back on: the last known copy is shown.
        if (!failure.offline && !failure.timedOut) {
          throw failure;
        }
      }
    }
    return NotesSnapshot(
      notes: await _store.readNotes(videoId),
      drafts: await _store.draftsForVideo(videoId),
      offline: true,
    );
  }

  Future<List<NoteTopic>> vocabulary() async {
    if (!isOffline) {
      try {
        final List<NoteTopic> topics = await _api.vocabulary();
        await _store.saveVocabulary(topics);
        return topics;
      } catch (error) {
        final NotesFailure failure = notesFailureFrom(error);
        if (!failure.offline && !failure.timedOut) {
          throw failure;
        }
      }
    }
    return _store.readVocabulary();
  }

  Future<NotesShelfData> shelf() async {
    if ((await _store.currentAccount()).isEmpty) {
      return const NotesShelfData(items: <NotesShelfItem>[]);
    }
    List<TriageItem> triage = await _store.readTriage();
    if (!isOffline) {
      try {
        triage = await _api.triage();
        await _store.saveTriage(triage);
      } catch (_) {
        // The cached Triage Queue is shown.
      }
    }
    final List<NoteDraft> drafts = await _store.allDrafts();
    final Map<int, NoteDraft> draftByVideo = <int, NoteDraft>{};
    for (final NoteDraft draft in drafts) {
      // Selected topics waiting for sync are not something to confirm.
      if (draft.needsPerson) {
        draftByVideo.putIfAbsent(draft.videoId, () => draft);
      }
    }
    final List<NotesShelfItem> items = <NotesShelfItem>[];
    final Set<int> seen = <int>{};
    for (final NoteDraft draft in draftByVideo.values) {
      final TriageItem? queued = _find(triage, draft.videoId);
      seen.add(draft.videoId);
      items.add(
        NotesShelfItem(
          videoId: draft.videoId,
          title: queued?.title ??
              (draft.title.isEmpty ? 'Видео #${draft.videoId}' : draft.title),
          seriesName: queued?.seriesName ?? '',
          needsClassification: queued != null,
          hasDrafts: true,
        ),
      );
    }
    for (final TriageItem item in triage) {
      if (seen.add(item.videoId)) {
        items.add(
          NotesShelfItem(
            videoId: item.videoId,
            title: item.title,
            seriesName: item.seriesName,
            needsClassification: true,
          ),
        );
      }
    }
    return NotesShelfData(items: items);
  }

  TriageItem? _find(List<TriageItem> items, int videoId) {
    for (final TriageItem item in items) {
      if (item.videoId == videoId) {
        return item;
      }
    }
    return null;
  }

  /// VideoType values that get the post-viewing menu: Courses and ExternalVideo.
  static const Set<int> postViewingTypes = <int>{8, 10};

  /// Whether the post-viewing menu applies: ExternalVideo or Courses only.
  /// The file's `videoType` decides; only an older server without that field
  /// falls back to the notes object and then the Triage Queue (which holds
  /// finished ExternalVideo and Courses videos only).
  ///
  /// The answer is remembered per video. A lookup that takes longer than
  /// [timeout] gives false, so the usual end-of-video choices are not held up;
  /// it keeps running and a later call gets its answer.
  Future<bool> isPostViewingVideo(
    int videoId, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (isOffline) {
      return false;
    }
    final Future<bool> lookup =
        _postViewing.putIfAbsent(videoId, () => _lookupPostViewing(videoId));
    try {
      return await lookup.timeout(timeout);
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Starts the post-viewing lookup when the player opens, so the answer is
  /// usually known by the end of the video.
  void prefetchPostViewing(int videoId) {
    if (isOffline) {
      return;
    }
    _postViewing.putIfAbsent(videoId, () => _lookupPostViewing(videoId));
  }

  Future<bool> _lookupPostViewing(int videoId) async {
    try {
      final VideoTypeInfo info = await _api.videoType(videoId);
      if (info.known) {
        // null is audio, which never gets the menu.
        return info.type != null && postViewingTypes.contains(info.type);
      }
      final VideoNotes notes = await _api.get(videoId);
      await _store.saveNotes(notes);
      if (notes.postViewing != null) {
        return notes.postViewing!;
      }
      final List<TriageItem> triage = await _api.triage();
      await _store.saveTriage(triage);
      return _find(triage, videoId) != null;
    } catch (_) {
      // Not remembered: the next call asks again.
      _postViewing.remove(videoId);
      return false;
    }
  }

  // ---- Topics ----

  /// Returns true when the server took the Topics, false when they wait offline.
  Future<bool> saveTopics(
    int videoId, {
    required List<String> topics,
    required bool noTopics,
    String title = '',
  }) async {
    if (!isOffline) {
      try {
        final VideoNotes notes =
            await _api.setTopics(videoId, topics: topics, noTopics: noTopics);
        await _store.saveNotes(notes);
        await _deleteDrafts(videoId, NoteDraftKind.topics);
        return true;
      } catch (error) {
        final NotesFailure failure = notesFailureFrom(error);
        if (!failure.offline) {
          throw failure;
        }
      }
    }
    await _deleteDrafts(videoId, NoteDraftKind.topics);
    await _store.addDraft(
      videoId: videoId,
      kind: NoteDraftKind.topics,
      status: NoteDraftStatus.ready,
      text: jsonEncode(<String, dynamic>{
        'topics': topics,
        'noTopics': noTopics,
      }),
      title: title,
    );
    // Shown right away from the cached Vocabulary.
    final List<NoteTopic> vocabulary = await _store.readVocabulary();
    final VideoNotes cached =
        await _store.readNotes(videoId) ?? VideoNotes(videoId: videoId);
    await _store.saveNotes(
      cached.copyWith(
        topics: topics.map((String name) {
          for (final NoteTopic known in vocabulary) {
            if (known.name.toLowerCase() == name.toLowerCase()) {
              return known;
            }
          }
          return NoteTopic(id: 0, name: name);
        }).toList(growable: false),
        noTopics: topics.isEmpty && noTopics,
      ),
    );
    return false;
  }

  Future<List<SuggestedTopic>> suggestTopics(int videoId) =>
      _online(() => _api.suggestTopics(videoId));

  Future<List<SuggestedTopic>> matchTopics(int videoId, String phrase) =>
      _online(() => _api.matchTopics(videoId, phrase));

  // ---- Review and Extended Description ----

  /// Saves a confirmed Review. Returns false when it was kept as a Draft.
  Future<bool> confirmReview(
    int videoId,
    String text, {
    int? draftId,
    String title = '',
  }) {
    return _confirm(
      videoId: videoId,
      kind: NoteDraftKind.review,
      text: text,
      draftId: draftId,
      title: title,
      send: () async => _store.saveNotes(await _api.saveReview(videoId, text)),
    );
  }

  Future<void> regenerateDescription(int videoId) => _online(
        () async => _store.saveNotes(await _api.regenerateDescription(videoId)),
      );

  Future<void> editDescription(int videoId, String text) => _online(
        () async =>
            _store.saveNotes(await _api.editDescription(videoId, text)),
      );

  // ---- Action ----

  /// Formulates an Action. It is not sent anywhere until [sendAction].
  /// Offline, the phrase is kept as a Draft and null is returned.
  Future<FormulatedAction?> formulateAction(
    int videoId,
    String phrase, {
    int? draftId,
    String title = '',
  }) async {
    if (!isOffline) {
      try {
        return await _api.formulateAction(videoId, phrase);
      } catch (error) {
        final NotesFailure failure = notesFailureFrom(error);
        if (!failure.offline) {
          throw failure;
        }
      }
    }
    await _keepDraft(videoId, NoteDraftKind.action, phrase, draftId, title);
    return null;
  }

  /// Sends a confirmed Action to Telegram. Returns false when kept as a Draft.
  Future<bool> sendAction(
    int videoId,
    String action, {
    double? position,
    int? draftId,
    String title = '',
  }) {
    return _confirm(
      videoId: videoId,
      kind: NoteDraftKind.action,
      text: action,
      draftId: draftId,
      title: title,
      send: () =>
          _api.sendAction(videoId, action: action, position: position),
      // Once the request is out it may have reached Telegram; keeping it as
      // a Draft would send it twice on the next confirmation.
      draftOnFailure: false,
      failureNote: 'Действие могло уже уйти в Telegram — проверьте, '
          'прежде чем отправлять снова.',
    );
  }

  // ---- Video Query ----

  /// Sends a confirmed Video Query. Returns false when kept as a Draft.
  Future<bool> ask(
    int videoId,
    String query, {
    int? draftId,
    String title = '',
  }) {
    return _confirm(
      videoId: videoId,
      kind: NoteDraftKind.query,
      text: query,
      draftId: draftId,
      title: title,
      send: () async {
        await _api.ask(videoId, query);
      },
    );
  }

  // ---- Drafts ----

  Future<List<NoteDraft>> drafts(int videoId) => _store.draftsForVideo(videoId);

  Future<void> saveDraftText(
    int videoId,
    NoteDraftKind kind,
    String text, {
    int? draftId,
    String title = '',
  }) =>
      _keepDraft(videoId, kind, text, draftId, title);

  Future<void> deleteDraft(int draftId) async {
    final NoteDraft? draft = await _store.draftById(draftId);
    if (draft?.clipPath != null) {
      await _deleteFile(draft!.clipPath!);
    }
    await _store.deleteDraft(draftId);
  }

  /// Recognizes a fresh clip. Online, the text comes back for the person to
  /// edit and the clip is deleted. Otherwise the clip stays as a Draft.
  Future<DictationResult> dictate(
    int videoId,
    NoteDraftKind kind,
    String clipPath, {
    String title = '',
  }) async {
    if (!isOffline) {
      try {
        final String text = await _api.recognize(clipPath);
        await _deleteFile(clipPath);
        return DictationResult(text: text);
      } catch (error) {
        final NotesFailure failure = notesFailureFrom(error);
        final int draftId = await _store.addDraft(
          videoId: videoId,
          kind: kind,
          status: failure.offline
              ? NoteDraftStatus.pendingRecognition
              : NoteDraftStatus.recognitionFailed,
          clipPath: clipPath,
          title: title,
        );
        if (!failure.offline) {
          await _store.updateDraft(
            draftId,
            status: NoteDraftStatus.recognitionFailed,
            error: failure.message,
          );
        }
        return DictationResult(failure: failure, keptAsDraft: true);
      }
    }
    await _store.addDraft(
      videoId: videoId,
      kind: kind,
      status: NoteDraftStatus.pendingRecognition,
      clipPath: clipPath,
      title: title,
    );
    return const DictationResult(keptAsDraft: true);
  }

  /// Recognizes a clip right away (a Mark caption). The clip is removed only
  /// once recognized; on failure it stays for the caller to retry or delete
  /// with [deleteClip].
  Future<String> recognizeClip(String clipPath) async {
    if (isOffline) {
      throw const NotesFailure(
        'Нет связи с сервером. Запись сохранена, распознать её можно '
        'после подключения.',
        offline: true,
      );
    }
    try {
      final String text = await _api.recognize(clipPath);
      await _deleteFile(clipPath);
      return text;
    } catch (error) {
      throw notesFailureFrom(error);
    }
  }

  /// Removes a clip that is no longer wanted.
  Future<void> deleteClip(String clipPath) => _deleteFile(clipPath);

  /// Retries recognition of one Draft clip («повторить»).
  /// Topics the server refused are applied again the same way.
  Future<void> retryDraft(int draftId) async {
    final NoteDraft? draft = await _store.draftById(draftId);
    if (draft == null) {
      return;
    }
    if (draft.kind == NoteDraftKind.topics) {
      if (!isOffline) {
        await _applyTopicsDraft(draft);
      }
      return;
    }
    if (!draft.hasClip) {
      return;
    }
    if (isOffline) {
      await _store.updateDraft(
        draftId,
        status: NoteDraftStatus.pendingRecognition,
      );
      return;
    }
    await _recognizeDraft(draft);
  }

  /// Runs on reconnect: recognizes waiting clips and applies offline Topics.
  /// Recognized text stays a Draft until the person confirms it.
  Future<void> syncDrafts({int? videoId}) async {
    if (_isSyncing || isOffline) {
      return;
    }
    _isSyncing = true;
    try {
      // Signed out: nothing to sync, and no credentials to sync it with.
      if ((await _store.currentAccount()).isEmpty) {
        return;
      }
      final List<NoteDraft> drafts = videoId == null
          ? await _store.allDrafts()
          : await _store.draftsForVideo(videoId);
      for (final NoteDraft draft in drafts) {
        if (draft.status == NoteDraftStatus.pendingRecognition &&
            draft.hasClip) {
          if (!await _recognizeDraft(draft)) {
            return;
          }
        } else if (draft.kind == NoteDraftKind.topics &&
            draft.error.isEmpty) {
          // Topics the server refused wait for «Повторить»: sending them
          // again on every sync would fail the same way.
          if (!await _applyTopicsDraft(draft)) {
            return;
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Returns false when the server is unreachable, so syncing stops.
  Future<bool> _recognizeDraft(NoteDraft stale) async {
    final NoteDraft? draft = await _store.draftById(stale.id);
    if (draft == null || !draft.hasClip) {
      return true;
    }
    try {
      final String text = await _api.recognize(draft.clipPath!);
      final String merged =
          draft.text.trim().isEmpty ? text : '${draft.text.trim()} $text';
      await _store.updateDraft(
        draft.id,
        status: NoteDraftStatus.ready,
        text: merged,
      );
      await _deleteFile(draft.clipPath!);
      await _store.clearClip(draft.id);
      return true;
    } catch (error) {
      final NotesFailure failure = notesFailureFrom(error);
      if (failure.offline) {
        await _store.updateDraft(
          draft.id,
          status: NoteDraftStatus.pendingRecognition,
        );
        return false;
      }
      await _store.updateDraft(
        draft.id,
        status: NoteDraftStatus.recognitionFailed,
        error: failure.message,
      );
      return true;
    }
  }

  Future<bool> _applyTopicsDraft(NoteDraft stale) async {
    // Re-read: the account may have changed or the Draft gone since listing.
    final NoteDraft? draft = await _store.draftById(stale.id);
    if (draft == null) {
      return true;
    }
    Map<String, dynamic>? decoded;
    try {
      decoded = notesJsonMap(jsonDecode(draft.text));
    } on FormatException {
      decoded = null;
    }
    if (decoded == null) {
      await _store.deleteDraft(draft.id);
      return true;
    }
    final Map<String, dynamic> payload = decoded;
    final Object? rawTopics = payload['topics'];
    final List<String> topics = rawTopics is List
        ? rawTopics.map((dynamic t) => t.toString()).toList(growable: false)
        : const <String>[];
    try {
      final VideoNotes notes = await _api.setTopics(
        draft.videoId,
        topics: topics,
        noTopics: payload['noTopics'] == true,
      );
      await _store.saveNotes(notes);
      await _store.deleteDraft(draft.id);
      return true;
    } catch (error) {
      final NotesFailure failure = notesFailureFrom(error);
      if (failure.offline) {
        return false;
      }
      await _store.updateDraft(
        draft.id,
        status: NoteDraftStatus.ready,
        error: failure.message,
      );
      return true;
    }
  }

  // ---- Sign-out ----

  /// Forgets every account's Drafts, clips and cached notes.
  Future<void> clearLocalData() async {
    for (final String path in await _store.allClipPaths()) {
      await _deleteFile(path);
    }
    await _store.clearAll();
    _postViewing.clear();
  }

  // ---- Helpers ----

  /// Sends confirmed text; offline it is kept as a Draft. A failed send
  /// becomes a Draft only when the server was unreachable and
  /// [draftOnFailure] allows it. Otherwise the failure is thrown, with
  /// [failureNote] added when no answer came back.
  Future<bool> _confirm({
    required int videoId,
    required NoteDraftKind kind,
    required String text,
    required Future<void> Function() send,
    int? draftId,
    String title = '',
    bool draftOnFailure = true,
    String? failureNote,
  }) async {
    if (!isOffline) {
      try {
        await send();
      } catch (error) {
        final NotesFailure failure = notesFailureFrom(error);
        if (failure.offline && draftOnFailure) {
          await _keepDraft(videoId, kind, text, draftId, title);
          return false;
        }
        final String? note = failureNote;
        // A server answer means it was not carried out; only a missing answer
        // leaves that open.
        if (note == null || (!failure.offline && !failure.timedOut)) {
          throw failure;
        }
        throw NotesFailure(
          '${failure.message} $note',
          offline: failure.offline,
          timedOut: failure.timedOut,
        );
      }
      if (draftId != null) {
        await deleteDraft(draftId);
      }
      return true;
    }
    await _keepDraft(videoId, kind, text, draftId, title);
    return false;
  }

  Future<void> _keepDraft(
    int videoId,
    NoteDraftKind kind,
    String text,
    int? draftId,
    String title,
  ) async {
    if (draftId != null && await _store.draftById(draftId) != null) {
      await _store.updateDraft(
        draftId,
        status: NoteDraftStatus.ready,
        text: text,
      );
      return;
    }
    await _store.addDraft(
      videoId: videoId,
      kind: kind,
      status: NoteDraftStatus.ready,
      text: text,
      title: title,
    );
  }

  Future<void> _deleteDrafts(int videoId, NoteDraftKind kind) async {
    for (final NoteDraft draft in await _store.draftsForVideo(videoId)) {
      if (draft.kind == kind) {
        await _store.deleteDraft(draft.id);
      }
    }
  }

  Future<T> _online<T>(Future<T> Function() action) async {
    if (isOffline) {
      throw const NotesFailure(
        'Доступно после подключения к серверу.',
        offline: true,
      );
    }
    try {
      return await action();
    } catch (error) {
      throw notesFailureFrom(error);
    }
  }

  Future<void> _deleteFile(String path) async {
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
