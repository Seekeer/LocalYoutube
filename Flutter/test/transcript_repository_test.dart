import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/transcript/data/transcript_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform originalPaths;
  late Dio dio;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('localtube-transcript-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {'text': 'Сохранённый текст', 'words': <dynamic>[]},
      ));
    }));
  });

  tearDown(() async {
    dio.close(force: true);
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });

  test('concurrent panel and download cache loads leave one readable result',
      () async {
    final panel = TranscriptRepository(dio, 'server-a');
    final downloads = TranscriptRepository(dio, 'server-a');
    final results = await Future.wait(List.generate(
        8, (index) => (index.isEven ? panel : downloads).load(42)));

    expect(results.map((result) => result.text),
        everyElement('Сохранённый текст'));
    expect((await panel.cached(42))?.text, 'Сохранённый текст');
    expect(await TranscriptRepository(dio, 'server-b').cached(42), isNull);
    final entries = await Directory('${directory.path}/transcripts/server-a')
        .list()
        .toList();
    expect(entries.map((entry) => entry.path.split('/').last), ['42.json']);
  });
}
