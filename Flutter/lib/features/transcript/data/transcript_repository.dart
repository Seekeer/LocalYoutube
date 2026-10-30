import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/bootstrap/bootstrap_providers.dart';
import '../domain/transcript.dart';

final transcriptRepositoryProvider =
    Provider<TranscriptRepository>((ref) => TranscriptRepository(
          ref.watch(dioProvider),
          ref.watch(appConfigProvider).serverStorageNamespace,
        ));
final transcriptProvider =
    StateProvider.family<Transcript?, int>((ref, id) => null);
final captionsEnabledProvider =
    StateProvider.family<bool, int>((ref, id) => false);

class TranscriptRepository {
  TranscriptRepository(this._dio, this._namespace);
  final Dio _dio;
  final String _namespace;

  Future<File> _file(int id, [String extension = 'json']) async {
    final Directory support = await getApplicationSupportDirectory();
    final String namespace =
        _namespace.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final Directory dir = Directory('${support.path}/transcripts/$namespace');
    await dir.create(recursive: true);
    return File('${dir.path}/$id.$extension');
  }

  Future<Transcript?> cached(int id) async {
    try {
      final File file = await _file(id);
      if (!await file.exists()) return null;
      return Transcript.fromJson(Map<String, dynamic>.from(
          jsonDecode(await file.readAsString()) as Map));
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<Map<String, dynamic>> status(int id) async {
    final response = await _dio.get<dynamic>('/videos/$id/transcript/status',
        options: Options(extra: {'idempotent': true}));
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> request(int id) async {
    await _dio.post<dynamic>('/videos/$id/transcript');
  }

  Future<Transcript> load(int id) async {
    final response = await _dio.get<dynamic>('/videos/$id/transcript',
        options: Options(extra: {'idempotent': true}));
    final payload = Map<String, dynamic>.from(response.data as Map);
    final Transcript transcript = Transcript.fromJson(payload);
    final File file = await _file(id);
    final Directory staging = await file.parent.createTemp('.transcript-');
    try {
      final File temporary = File('${staging.path}/transcript.json');
      await temporary.writeAsString(jsonEncode(payload));
      await temporary.rename(file.path);
    } finally {
      await staging.delete(recursive: true);
    }
    return transcript;
  }

  Future<String> srt(int id) async {
    final File file = await _file(id, 'srt');
    try {
      final response = await _dio.get<String>(
          '/videos/$id/transcript/subtitles.srt',
          options: Options(responseType: ResponseType.plain));
      await file.writeAsString(response.data!);
      return response.data!;
    } catch (_) {
      if (await file.exists()) return file.readAsString();
      rethrow;
    }
  }
}
