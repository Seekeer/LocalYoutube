import 'dart:io';

import 'package:dio/dio.dart';

import '../domain/notes_models.dart';

/// HTTP client of `api/notes`. Errors come back as plain-text Russian messages.
class NotesApi {
  NotesApi(this._dio);

  final Dio _dio;

  static Options get _idempotent =>
      Options(extra: <String, dynamic>{'idempotent': true});

  /// AI calls wait for a language model; the app-wide 30 s is not enough.
  static const Duration aiTimeout = Duration(minutes: 3);

  /// Recognition may wait behind another clip on the speech worker.
  static const Duration speechTimeout = Duration(minutes: 5);

  static Options get _ai => Options(receiveTimeout: aiTimeout);

  Future<List<NoteTopic>> vocabulary() async {
    final Response<dynamic> response =
        await _dio.get<dynamic>('/notes/vocabulary', options: _idempotent);
    return notesJsonList(response.data)
        .map(NoteTopic.fromJson)
        .toList(growable: false);
  }

  Future<VideoNotes> get(int videoId) async {
    final Response<dynamic> response =
        await _dio.get<dynamic>('/notes/videos/$videoId', options: _idempotent);
    return VideoNotes.fromJson(notesJsonMap(response.data));
  }

  Future<VideoNotes> setTopics(
    int videoId, {
    required List<String> topics,
    required bool noTopics,
  }) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/notes/videos/$videoId/topics',
      data: <String, dynamic>{'topics': topics, 'noTopics': noTopics},
      options: _idempotent,
    );
    return VideoNotes.fromJson(notesJsonMap(response.data));
  }

  Future<List<SuggestedTopic>> suggestTopics(int videoId) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/notes/videos/$videoId/topics/suggest',
      options: _ai,
    );
    return notesJsonList(response.data)
        .map(SuggestedTopic.fromJson)
        .toList(growable: false);
  }

  Future<List<SuggestedTopic>> matchTopics(int videoId, String phrase) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/notes/videos/$videoId/topics/match',
      data: <String, dynamic>{'phrase': phrase},
      options: _ai,
    );
    return notesJsonList(response.data)
        .map(SuggestedTopic.fromJson)
        .toList(growable: false);
  }

  Future<VideoNotes> saveReview(int videoId, String text) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/notes/videos/$videoId/review',
      data: <String, dynamic>{'text': text},
      options: _idempotent,
    );
    return VideoNotes.fromJson(notesJsonMap(response.data));
  }

  Future<VideoNotes> regenerateDescription(int videoId) async {
    final Response<dynamic> response = await _dio
        .post<dynamic>('/notes/videos/$videoId/description/regenerate');
    return VideoNotes.fromJson(notesJsonMap(response.data));
  }

  Future<VideoNotes> editDescription(int videoId, String text) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      '/notes/videos/$videoId/description',
      data: <String, dynamic>{'text': text},
      options: _idempotent,
    );
    return VideoNotes.fromJson(notesJsonMap(response.data));
  }

  Future<FormulatedAction> formulateAction(int videoId, String phrase) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/notes/videos/$videoId/action/formulate',
      data: <String, dynamic>{'phrase': phrase},
      options: _ai,
    );
    return FormulatedAction.fromJson(notesJsonMap(response.data));
  }

  Future<void> sendAction(
    int videoId, {
    required String action,
    double? position,
  }) async {
    await _dio.post<dynamic>(
      '/notes/videos/$videoId/action/send',
      data: <String, dynamic>{'action': action, 'position': position},
    );
  }

  Future<NoteAnswer> ask(int videoId, String query) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/notes/videos/$videoId/answers',
      data: <String, dynamic>{'query': query},
      options: _ai,
    );
    return NoteAnswer.fromJson(notesJsonMap(response.data));
  }

  Future<List<TriageItem>> triage() async {
    final Response<dynamic> response =
        await _dio.get<dynamic>('/notes/triage', options: _idempotent);
    return notesJsonList(notesJsonMap(response.data)['items'])
        .map(TriageItem.fromJson)
        .toList(growable: false);
  }

  /// VideoType of a video as a number (Courses = 8, ExternalVideo = 10).
  /// [VideoTypeInfo.known] is false when the server does not report the field.
  Future<VideoTypeInfo> videoType(int videoId) async {
    final Response<dynamic> response =
        await _dio.get<dynamic>('/files/$videoId', options: _idempotent);
    final Map<String, dynamic> json = notesJsonMap(response.data);
    if (!json.containsKey('videoType')) {
      return const VideoTypeInfo(known: false);
    }
    final Object? type = json['videoType'];
    return VideoTypeInfo(
      known: true,
      type: type is num ? type.toInt() : int.tryParse(type?.toString() ?? ''),
    );
  }

  /// Uploads a voice clip and returns the recognized text.
  Future<String> recognize(String filePath) async {
    final String name = filePath.split(RegExp(r'[\\/]')).last;
    final FormData form = FormData.fromMap(<String, dynamic>{
      'audio': await MultipartFile.fromFile(filePath, filename: name),
    });
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/notes/speech',
      data: form,
      options: Options(
        receiveTimeout: speechTimeout,
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    final Object? text = notesJsonMap(response.data)['text'];
    return text == null ? '' : text.toString();
  }
}

/// Turns a Dio failure into something the notes section can show.
NotesFailure notesFailureFrom(Object error) {
  if (error is NotesFailure) {
    return error;
  }
  if (error is DioException) {
    final Response<dynamic>? response = error.response;
    if (response != null) {
      final Object? body = response.data;
      final String message = body is String && body.trim().isNotEmpty
          ? body.trim()
          : 'Ошибка сервера (${response.statusCode ?? '?'}).';
      return NotesFailure(message);
    }
    // Only a request that never reached the server counts as offline. A
    // timeout means the server may still be working on it.
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return _offline;
      case DioExceptionType.receiveTimeout:
        return const NotesFailure(
          'Сервер не ответил вовремя. Попробуйте ещё раз.',
          timedOut: true,
        );
      case DioExceptionType.sendTimeout:
        return const NotesFailure(
          'Не удалось вовремя отправить запрос. Попробуйте ещё раз.',
          timedOut: true,
        );
      case DioExceptionType.cancel:
        return const NotesFailure('Запрос отменён.');
      case DioExceptionType.badCertificate:
        return const NotesFailure('Ошибка защищённого соединения с сервером.');
      case DioExceptionType.badResponse:
        return const NotesFailure('Ошибка сервера.');
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return _offline;
        }
        return NotesFailure(
          'Ошибка связи с сервером: ${error.message ?? error.error ?? ''}',
        );
    }
  }
  return NotesFailure(error.toString());
}

const NotesFailure _offline =
    NotesFailure('Нет связи с сервером.', offline: true);

class VideoTypeInfo {
  const VideoTypeInfo({required this.known, this.type});

  /// Whether the server reported `videoType` at all.
  final bool known;

  /// null for audio.
  final int? type;
}
