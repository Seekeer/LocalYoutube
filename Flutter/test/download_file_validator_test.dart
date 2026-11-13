import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/downloads/data/download_file_validator.dart';

void main() {
  late Directory directory;
  const DownloadFileValidator validator = DownloadFileValidator();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('download_validation_');
  });
  tearDown(() => directory.delete(recursive: true));

  Future<File> fixture(List<int> bytes, {String extension = 'mp4'}) async {
    final File file = File('${directory.path}/video.$extension');
    return file.writeAsBytes(bytes);
  }

  test('accepts media before metadata and unknown legal boxes', () async {
    final File file = await fixture(<int>[
      ...box('ftyp', <int>[0, 0, 0, 0]),
      ...box('free', <int>[1, 2]),
      ...box('mdat', <int>[1, 2, 3, 4]),
      ...box('moov', <int>[1]),
    ]);
    await validator.validate(file.path);
  });

  test('rejects corrupt appended bytes like the captured resumed MP4',
      () async {
    final File file = await fixture(<int>[
      ...box('moov', <int>[1]),
      ...box('mdat', <int>[1, 2, 3, 4]),
      // Real bytes at the declared end of video 66331's mdat box.
      0x70, 0xb9, 0xc5, 0xd2, 0x3a, 0x32, 0x05, 0xb2,
    ]);
    await expectLater(
      validator.validate(file.path),
      throwsA(isA<InvalidDownloadException>()),
    );
  });

  test('rejects truncated media payload', () async {
    final File file = await fixture(<int>[
      ...box('moov', <int>[1]),
      ...box('mdat', <int>[1, 2, 3, 4]).take(10),
    ]);
    await expectLater(
      validator.validate(file.path),
      throwsA(isA<InvalidDownloadException>()),
    );
  });

  test('rejects short headers, missing metadata and invalid box sizes',
      () async {
    for (final List<int> bytes in <List<int>>[
      <int>[1, 2, 3],
      box('mdat', <int>[1]),
      <int>[0, 0, 0, 4, ...'moov'.codeUnits],
      <int>[0, 0, 0, 1, ...'moov'.codeUnits, 0],
      <int>[0, 0, 0, 1, ...'moov'.codeUnits, ...List<int>.filled(8, 255)],
    ]) {
      final File file = await fixture(bytes);
      await expectLater(
        validator.validate(file.path),
        throwsA(isA<InvalidDownloadException>()),
      );
    }
  });

  test('accepts extended sizes and a final box extending to EOF', () async {
    final File file = await fixture(<int>[
      0,
      0,
      0,
      1,
      ...'moov'.codeUnits,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      17,
      1,
      0,
      0,
      0,
      0,
      ...'mdat'.codeUnits,
      1,
      2,
      3,
    ]);
    await validator.validate(file.path);
  });

  test('rejects missing and empty files even for unsupported containers',
      () async {
    await expectLater(
      validator.validate('${directory.path}/missing.mkv'),
      throwsA(isA<InvalidDownloadException>()),
    );
    final File empty = await fixture(<int>[], extension: 'mkv');
    await expectLater(
      validator.validate(empty.path),
      throwsA(isA<InvalidDownloadException>()),
    );
  });

  test('rejects an MP4 containing only empty media and metadata boxes',
      () async {
    final File file = await fixture(<int>[
      ...box('moov', <int>[]),
      ...box('mdat', <int>[]),
    ]);
    await expectLater(
      validator.validate(file.path),
      throwsA(isA<InvalidDownloadException>()),
    );
  });

  test('does not apply MP4 parsing to other containers', () async {
    final File file = await fixture(<int>[1, 2, 3], extension: 'mkv');
    await validator.validate(file.path);
  });

  test('recognizes server containers saved with the default mp4 extension',
      () async {
    // Headers captured from the five server files rejected by released clients.
    for (final String hex in <String>[
      '1a45dfa3a34286810142f7810142f2810442f381084282886d6174726f736b61',
      '1a45dfa3934282886d6174726f736b6142878101428581011853806701000001',
      '52494646d621497f415649204c4953547e4300006864726c6176696838000000',
      '000001ba4400040484010189c3f8000001bb001280c4e104e17fb9e0e8b8c020',
    ]) {
      final File file = await fixture(<int>[
        for (int i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
      await validator.validate(file.path);
    }
  });

  test('does not exempt an arbitrary RIFF file from MP4 validation', () async {
    final File file = await fixture(<int>[
      ...'RIFF'.codeUnits,
      4,
      0,
      0,
      0,
      ...'WAVE'.codeUnits,
    ]);
    await expectLater(
      validator.validate(file.path),
      throwsA(isA<InvalidDownloadException>()),
    );
  });
}

List<int> box(String type, List<int> payload) {
  final ByteData header = ByteData(8)..setUint32(0, 8 + payload.length);
  final Uint8List bytes = header.buffer.asUint8List();
  bytes.setRange(4, 8, type.codeUnits);
  return <int>[...bytes, ...payload];
}
