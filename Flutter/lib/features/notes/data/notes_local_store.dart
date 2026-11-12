import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos/session_meta_dao.dart';
import '../../auth/data/offline_availability_probe.dart';
import '../domain/notes_models.dart';

/// Local part of video notes: Drafts and the last known notes and Vocabulary.
///
/// Everything here is private to the signed-in account: rows carry the
/// account they were made under, and only that account reads them. With
/// nobody signed in nothing is read or written.
class NotesLocalStore {
  /// [account] names the signed-in account; by default it is the user name
  /// the session was saved under.
  NotesLocalStore(this._database, {Future<String?> Function()? account})
      : _account = account;

  final AppDatabase _database;
  final Future<String?> Function()? _account;

  /// The signed-in account as rows store it, or '' when nobody is signed in.
  Future<String> currentAccount() async {
    String? value;
    try {
      final Future<String?> Function()? account = _account;
      value = account != null
          ? await account()
          : await SessionMetaDao(_database)
              .readValue(AuthLocalSessionKeys.userNameKey);
    } catch (_) {
      value = null;
    }
    return (value ?? '').trim().toLowerCase();
  }

  static const String _vocabularyKey = 'vocabulary';
  static String _videoKey(int videoId) => 'video:$videoId';

  // ---- Drafts ----

  Future<int> addDraft({
    required int videoId,
    required NoteDraftKind kind,
    required NoteDraftStatus status,
    String text = '',
    String? clipPath,
    String title = '',
  }) async {
    final String account = await currentAccount();
    if (account.isEmpty) {
      throw const NotesFailure('Войдите в аккаунт, чтобы сохранить черновик.');
    }
    final String now = DateTime.now().toUtc().toIso8601String();
    await _database.execute(
      '''
      INSERT INTO note_drafts(account, video_id, kind, status, text, clip_path, error, title, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, '', ?, ?, ?)
      ''',
      variables: <Object?>[
        account,
        videoId,
        kind.name,
        status.name,
        text,
        clipPath ?? '',
        title,
        now,
        now,
      ],
    );
    final List<Map<String, Object?>> rows = await _database.query(
      'SELECT MAX(id) AS id FROM note_drafts WHERE account = ? AND video_id = ?',
      variables: <Object?>[account, videoId],
    );
    final Object? id = rows.isEmpty ? null : rows.first['id'];
    return id is int ? id : int.tryParse('$id') ?? 0;
  }

  Future<List<NoteDraft>> draftsForVideo(int videoId) async {
    final String account = await currentAccount();
    if (account.isEmpty) {
      return const <NoteDraft>[];
    }
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT id, video_id, kind, status, text, clip_path, error, title, created_at
      FROM note_drafts
      WHERE account = ? AND video_id = ?
      ORDER BY id
      ''',
      variables: <Object?>[account, videoId],
    );
    return _drafts(rows);
  }

  Future<List<NoteDraft>> allDrafts() async {
    final String account = await currentAccount();
    if (account.isEmpty) {
      return const <NoteDraft>[];
    }
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT id, video_id, kind, status, text, clip_path, error, title, created_at
      FROM note_drafts
      WHERE account = ?
      ORDER BY id
      ''',
      variables: <Object?>[account],
    );
    return _drafts(rows);
  }

  /// Only a Draft of the signed-in account is found.
  Future<NoteDraft?> draftById(int id) async {
    final String account = await currentAccount();
    if (account.isEmpty) {
      return null;
    }
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT id, video_id, kind, status, text, clip_path, error, title, created_at
      FROM note_drafts
      WHERE id = ? AND account = ?
      LIMIT 1
      ''',
      variables: <Object?>[id, account],
    );
    final List<NoteDraft> drafts = _drafts(rows);
    return drafts.isEmpty ? null : drafts.first;
  }

  Future<void> updateDraft(
    int id, {
    required NoteDraftStatus status,
    String? text,
    String? clipPath,
    String error = '',
  }) async {
    final NoteDraft? current = await draftById(id);
    if (current == null) {
      return;
    }
    await _database.execute(
      '''
      UPDATE note_drafts
      SET status = ?, text = ?, clip_path = ?, error = ?, updated_at = ?
      WHERE id = ? AND account = ?
      ''',
      variables: <Object?>[
        status.name,
        text ?? current.text,
        clipPath ?? current.clipPath ?? '',
        error,
        DateTime.now().toUtc().toIso8601String(),
        id,
        await currentAccount(),
      ],
    );
  }

  /// Clears the clip path once its file is gone.
  Future<void> clearClip(int id) async {
    final String account = await currentAccount();
    await _database.execute(
      "UPDATE note_drafts SET clip_path = '' WHERE id = ? AND account = ?",
      variables: <Object?>[id, account],
    );
  }

  Future<void> deleteDraft(int id) async {
    final String account = await currentAccount();
    await _database.execute(
      'DELETE FROM note_drafts WHERE id = ? AND account = ?',
      variables: <Object?>[id, account],
    );
  }

  /// Clip files of every account's Drafts, for [clearAll].
  Future<List<String>> allClipPaths() async {
    final List<Map<String, Object?>> rows = await _database.query(
      "SELECT clip_path FROM note_drafts WHERE clip_path <> ''",
    );
    return rows
        .map((Map<String, Object?> row) => row['clip_path']?.toString() ?? '')
        .where((String path) => path.isNotEmpty)
        .toList(growable: false);
  }

  /// Forgets every account's Drafts and cached notes (sign-out). The caller
  /// removes the clip files listed by [allClipPaths] first.
  Future<void> clearAll() async {
    await _database.execute('DELETE FROM note_drafts');
    await _database.execute('DELETE FROM notes_cache');
  }

  List<NoteDraft> _drafts(List<Map<String, Object?>> rows) {
    final List<NoteDraft> drafts = <NoteDraft>[];
    for (final Map<String, Object?> row in rows) {
      final NoteDraft? draft = NoteDraft.fromRow(row);
      if (draft != null) {
        drafts.add(draft);
      }
    }
    return drafts;
  }

  // ---- Cache ----

  Future<void> saveNotes(VideoNotes notes) =>
      _write(_videoKey(notes.videoId), jsonEncode(notes.toJson()));

  Future<VideoNotes?> readNotes(int videoId) async {
    final String? payload = await _read(_videoKey(videoId));
    if (payload == null) {
      return null;
    }
    try {
      return VideoNotes.fromJson(notesJsonMap(jsonDecode(payload)));
    } on FormatException {
      return null;
    }
  }

  Future<void> saveVocabulary(List<NoteTopic> topics) => _write(
        _vocabularyKey,
        jsonEncode(topics.map((NoteTopic t) => t.toJson()).toList()),
      );

  Future<List<NoteTopic>> readVocabulary() async {
    final String? payload = await _read(_vocabularyKey);
    if (payload == null) {
      return const <NoteTopic>[];
    }
    try {
      return notesJsonList(jsonDecode(payload))
          .map(NoteTopic.fromJson)
          .toList(growable: false);
    } on FormatException {
      return const <NoteTopic>[];
    }
  }

  Future<void> saveTriage(List<TriageItem> items) => _write(
        _triageKey,
        jsonEncode(
          items
              .map(
                (TriageItem item) => <String, dynamic>{
                  'videoId': item.videoId,
                  'title': item.title,
                  'seriesName': item.seriesName,
                  'watchedDate': item.watchedDate?.toIso8601String(),
                  'reason': item.reason,
                },
              )
              .toList(),
        ),
      );

  Future<List<TriageItem>> readTriage() async {
    final String? payload = await _read(_triageKey);
    if (payload == null) {
      return const <TriageItem>[];
    }
    try {
      return notesJsonList(jsonDecode(payload))
          .map(TriageItem.fromJson)
          .toList(growable: false);
    } on FormatException {
      return const <TriageItem>[];
    }
  }

  static const String _triageKey = 'triage';

  /// Cache keys start with the account, so one account never reads another's
  /// private notes.
  Future<void> _write(String key, String payload) async {
    final String account = await currentAccount();
    if (account.isEmpty) {
      return;
    }
    await _database.execute(
      '''
      INSERT OR REPLACE INTO notes_cache(cache_key, payload_json, updated_at)
      VALUES (?, ?, ?)
      ''',
      variables: <Object?>[
        '$account|$key',
        payload,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  Future<String?> _read(String key) async {
    final String account = await currentAccount();
    if (account.isEmpty) {
      return null;
    }
    final List<Map<String, Object?>> rows = await _database.query(
      'SELECT payload_json FROM notes_cache WHERE cache_key = ? LIMIT 1',
      variables: <Object?>['$account|$key'],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['payload_json']?.toString();
  }
}
