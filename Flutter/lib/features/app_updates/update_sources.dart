import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/bootstrap/bootstrap_providers.dart';
import '../../core/config/app_config.dart';
import '../../core/config/windows_edition.dart';
import 'update_models.dart';

typedef InstalledAppSource = Future<InstalledApp?> Function();
typedef UpdateSource = Future<Map<String, dynamic>?> Function(String channel);

/// The update server answered but does not know this installation's channel:
/// it runs an API older than the channel.
class UpdateChannelNotServed implements Exception {
  const UpdateChannelNotServed();
}

/// This build has no usable address of its update server.
class UpdateServerNotConfigured implements Exception {
  const UpdateServerNotConfigured(this.reason);
  final String reason;
}

// CI passes the canonical version into Windows distribution builds. Local
// builds have no version and therefore no update channel.
const int windowsVersionCode =
    int.fromEnvironment('LOCALTUBE_WINDOWS_VERSION_CODE');
const String windowsVersionName =
    String.fromEnvironment('LOCALTUBE_WINDOWS_VERSION_NAME');

final installedAppProvider = Provider<InstalledAppSource>((ref) => () async {
      if (Platform.isWindows) {
        return windowsVersionCode > 0 && windowsVersionName.isNotEmpty
            ? const InstalledApp(
                windowsUpdateChannel == 'windows-preview'
                    ? windowsPreviewApplicationId
                    : windowsApplicationId,
                windowsVersionCode,
                windowsVersionName)
            : null;
      }
      if (!Platform.isAndroid) return null;
      const channel = MethodChannel('org.localtube.app/app_updates');
      final info =
          await channel.invokeMapMethod<String, dynamic>('installedApp');
      if (info == null) throw const FormatException('Missing package identity');
      return InstalledApp(info['applicationId'] as String,
          info['versionCode'] as int, info['versionName'] as String);
    });

/// Address of an update endpoint for [channel].
///
/// Android updates use the configured LAN listener directly; the Android
/// installer still checks the APK signature. Windows bundles carry no code
/// signature, so their metadata and packages come only from the HTTPS API,
/// whose TLS certificate authenticates the published SHA-256.
Uri updateServerUri(AppConfig config, String channel, String path) {
  if (channel.startsWith('windows-')) {
    final base = Uri.tryParse(config.apiBaseUrl.trim());
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      throw const UpdateServerNotConfigured(
          'HTTPS update server is not configured');
    }
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return Uri(
        scheme: 'https',
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: '$prefix$path');
  }
  if (config.localApiHost.trim().isEmpty || config.localApiPort <= 0) {
    throw const UpdateServerNotConfigured(
        'LAN update server is not configured');
  }
  return Uri(
      scheme: 'http',
      host: config.localApiHost,
      port: config.localApiPort,
      path: path);
}

// Updates never use media routing, authentication refresh, or change the
// application's access mode.
final updateSourceProvider = Provider<UpdateSource>((ref) => (channel) async {
      final uri = updateServerUri(ref.read(appConfigProvider), channel,
          '/app-updates/$channel/latest');
      // The HTTPS route may leave the LAN, so it gets more time.
      final timeout = Duration(seconds: uri.scheme == 'https' ? 15 : 5);
      final client = Dio(
          BaseOptions(connectTimeout: timeout, receiveTimeout: timeout));
      try {
        final response = await client.getUri<dynamic>(uri,
            options: Options(
                headers: {'Cache-Control': 'no-cache'},
                validateStatus: (status) =>
                    status == 200 || status == 400 || status == 404));
        return parseLatestUpdateResponse(response.statusCode, response.data);
      } finally {
        client.close();
      }
    });

/// Interprets the answer of `GET /app-updates/{channel}/latest`: metadata on
/// 200, no publication on 404, an unknown channel on the API's 400.
Map<String, dynamic>? parseLatestUpdateResponse(int? status, Object? body) {
  if (status == 404) return null;
  if (status == 400) {
    if (body is String && body.contains('Unknown update channel')) {
      throw const UpdateChannelNotServed();
    }
    throw StateError('Update server rejected the request');
  }
  // A proxy or web front end may answer 200 with a page instead of JSON.
  if (body is! Map) throw const FormatException('Update metadata is not JSON');
  return Map<String, dynamic>.from(body);
}
