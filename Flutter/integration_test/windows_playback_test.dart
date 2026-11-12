import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localtube_flutter/core/playback/initialize_video_playback.dart';
import 'package:video_player/video_player.dart';

import 'windows_video_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows plays downloaded and authenticated streaming video',
      (tester) async {
    initializeVideoPlayback();
    final bytes = base64Decode(windowsVideoFixture);
    final directory = await Directory.systemTemp.createTemp('playback-');
    final file = File('${directory.path}/downloaded.mp4');
    await file.writeAsBytes(bytes);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    int authorizedRequests = 0;
    final subscription = server.listen((request) async {
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          'Bearer playback-test') {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      authorizedRequests++;
      request.response.headers
        ..contentType = ContentType('video', 'mp4')
        ..set(HttpHeaders.acceptRangesHeader, 'bytes');
      final range = request.headers.value(HttpHeaders.rangeHeader);
      int start = 0;
      int end = bytes.length - 1;
      if (range != null) {
        final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
        if (match == null) {
          request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          await request.response.close();
          return;
        }
        start = int.parse(match.group(1)!);
        end = int.tryParse(match.group(2)!) ?? end;
        if (start > end || end >= bytes.length) {
          request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(HttpHeaders.contentRangeHeader,
            'bytes $start-$end/${bytes.length}');
      }
      request.response.contentLength = end - start + 1;
      request.response.add(bytes.sublist(start, end + 1));
      await request.response.close();
    });

    try {
      for (final controller in [
        VideoPlayerController.file(file),
        VideoPlayerController.networkUrl(
          Uri.parse('http://127.0.0.1:${server.port}/video.mp4'),
          httpHeaders: {'Authorization': 'Bearer playback-test'},
        ),
      ]) {
        try {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(body: VideoPlayer(controller)),
          ));
          Object? initializationError;
          bool initialized = false;
          final initialization = controller.initialize().then((_) {
            initialized = true;
          }, onError: (Object error) {
            initializationError = error;
          });
          final deadline = DateTime.now().add(const Duration(seconds: 30));
          // Media Kit attaches its native video output after a Flutter frame.
          // Keep rendering while initialization waits for that output.
          while (!initialized &&
              initializationError == null &&
              DateTime.now().isBefore(deadline)) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(initializationError, isNull);
          expect(initialized, isTrue, reason: 'Video initialization timed out');
          await initialization;
          expect(controller.value.isInitialized, isTrue);
          expect(controller.value.size, const Size(160, 90));
          expect(controller.value.duration, greaterThan(Duration.zero));
          await tester.runAsync(() async {
            await controller.play();
            final deadline = DateTime.now().add(const Duration(seconds: 15));
            while (
                controller.value.position < const Duration(milliseconds: 300) &&
                    DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }
          });
          expect(controller.value.hasError, isFalse,
              reason: controller.value.errorDescription);
          expect(controller.value.position,
              greaterThanOrEqualTo(const Duration(milliseconds: 300)));
          await tester.runAsync(() async {
            await controller.pause();
            await controller.seekTo(const Duration(seconds: 1));
          });
          expect(controller.value.position, const Duration(seconds: 1));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(controller.dispose);
        }
      }
      expect(authorizedRequests, greaterThan(0));
    } finally {
      await server.close(force: true);
      await subscription.cancel();
      await directory.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);
}
