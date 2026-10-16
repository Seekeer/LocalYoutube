import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/logging/log_service.dart';
import '../domain/catalog_models.dart';
import 'local_video_metadata_repository.dart';

class LocalThumbnailService {
  LocalThumbnailService({
    required Dio dio,
    required LocalVideoMetadataRepository localVideoMetadataRepository,
    required LogService logService,
    String storageNamespace = '',
  })  : _dio = dio,
        _localVideoMetadataRepository = localVideoMetadataRepository,
        _logService = logService,
        _storageNamespace = storageNamespace;

  final String _storageNamespace;
  final Dio _dio;
  final LocalVideoMetadataRepository _localVideoMetadataRepository;
  final LogService _logService;

  Future<void> syncForItems(List<CatalogItem> items) async {
    for (final CatalogItem item in items) {
      await _syncSingle(item);
    }
  }

  Future<void> _syncSingle(CatalogItem item) async {
    if (item.id <= 0) {
      return;
    }

    try {
      final Directory root = await getApplicationDocumentsDirectory();
      final Directory thumbnailsDir = Directory(
        '${root.path}${Platform.pathSeparator}thumbnails/$_storageNamespace',
      );
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }

      final File target = File(
        '${thumbnailsDir.path}${Platform.pathSeparator}${item.id}.img',
      );
      final Response<List<int>> response = await _dio.get<List<int>>(
        '/files/getImage?fileId=${item.id}&isMobile=true',
        options: Options(responseType: ResponseType.bytes),
      );
      final List<int> bytes = response.data ?? const <int>[];
      if (bytes.isEmpty) {
        return;
      }

      await target.writeAsBytes(bytes, flush: true);
      await _localVideoMetadataRepository.updateThumbnail(
        videoId: item.id,
        thumbnailLocalPath: target.path,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (error, stackTrace) {
      _logService.error(
        'thumbnail sync failed for video=${item.id}',
        error,
        stackTrace,
      );
    }
  }
}
