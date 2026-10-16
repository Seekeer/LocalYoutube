import 'dart:io';
import 'dart:typed_data';

class InvalidDownloadException implements Exception {
  const InvalidDownloadException(this.reason);

  final String reason;

  String get message =>
      'The downloaded video is damaged or incomplete. Download it again.';

  @override
  String toString() => message;
}

/// Checks container boundaries without reading or decoding the media payload.
/// This detects truncated MP4 files and broken joins after resumed downloads;
/// it is not a checksum or a guarantee that every frame can be decoded.
class DownloadFileValidator {
  const DownloadFileValidator();

  Future<void> validate(String path) async {
    final File file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      throw const InvalidDownloadException('File is missing or empty.');
    }
    final String extension = path.toLowerCase().split('.').last;
    if (!const <String>{'mp4', 'm4v', 'mov'}.contains(extension)) {
      return;
    }

    final RandomAccessFile input = await file.open();
    try {
      final int length = await input.length();
      final Set<String> boxes = <String>{};
      int position = 0;
      while (position < length) {
        if (length - position < 8) {
          throw const InvalidDownloadException('Incomplete MP4 box header.');
        }
        await input.setPosition(position);
        final Uint8List header = await input.read(8);
        if (header.length != 8) {
          throw const InvalidDownloadException('Incomplete MP4 box header.');
        }
        int size = ByteData.sublistView(header).getUint32(0);
        final String type = String.fromCharCodes(header.sublist(4));
        int headerSize = 8;
        if (size == 1) {
          final Uint8List extended = await input.read(8);
          if (extended.length != 8) {
            throw const InvalidDownloadException('Incomplete MP4 box size.');
          }
          // Avoid signed integer overflow for corrupt 64-bit sizes.
          final ByteData data = ByteData.sublistView(extended);
          final int high = data.getUint32(0);
          final int low = data.getUint32(4);
          if (high > length ~/ 0x100000000) {
            throw const InvalidDownloadException('MP4 box exceeds file size.');
          }
          size = high * 0x100000000 + low;
          headerSize = 16;
        } else if (size == 0) {
          size = length - position;
        }
        if (size < headerSize || size > length - position) {
          throw InvalidDownloadException(
            'Invalid MP4 box at byte $position: size=$size, fileSize=$length.',
          );
        }
        if (size > headerSize) {
          boxes.add(type);
        }
        position += size;
      }
      if (!boxes.contains('moov') || !boxes.contains('mdat')) {
        throw const InvalidDownloadException(
            'MP4 media or metadata is missing.');
      }
    } finally {
      await input.close();
    }
  }
}
