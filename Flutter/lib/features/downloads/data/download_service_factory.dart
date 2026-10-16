import 'dart:io';

import '../../../core/auth/token_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/logging/log_service.dart';
import '../../../core/network/api_route.dart';
import '../domain/download_service.dart';
import 'background_downloader_download_service.dart';
import 'local_downloads_repository.dart';

DownloadService createDownloadService({
  required LocalDownloadsRepository localDownloadsRepository,
  required AppConfig appConfig,
  required TokenRepository tokenRepository,
  required LogService logService,
  ApiRoute? apiRoute,
}) {
  if (Platform.isAndroid) {
    return AndroidDownloadService(
      localDownloadsRepository: localDownloadsRepository,
      appConfig: appConfig,
      tokenRepository: tokenRepository,
      logService: logService,
      apiRoute: apiRoute,
    );
  }
  if (Platform.isWindows) {
    return WindowsDownloadService(
      localDownloadsRepository: localDownloadsRepository,
      appConfig: appConfig,
      tokenRepository: tokenRepository,
      logService: logService,
      apiRoute: apiRoute,
    );
  }

  return GenericDownloadService(
    localDownloadsRepository: localDownloadsRepository,
    appConfig: appConfig,
    tokenRepository: tokenRepository,
    logService: logService,
    apiRoute: apiRoute,
  );
}
