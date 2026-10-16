import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/bootstrap/bootstrap_providers.dart';
import 'update_models.dart';

typedef InstalledAppSource = Future<InstalledApp?> Function();
typedef UpdateSource = Future<Map<String, dynamic>?> Function(String channel);

final installedAppProvider = Provider<InstalledAppSource>((ref) => () async {
      if (!Platform.isAndroid) return null;
      const channel = MethodChannel('org.localtube.app/app_updates');
      final info =
          await channel.invokeMapMethod<String, dynamic>('installedApp');
      if (info == null) throw const FormatException('Missing package identity');
      return InstalledApp(info['applicationId'] as String,
          info['versionCode'] as int, info['versionName'] as String);
    });

// Updates use the configured LAN listener directly. They never use media routing,
// authentication refresh, or change the application's access mode.
final updateSourceProvider = Provider<UpdateSource>((ref) => (channel) async {
      final config = ref.read(appConfigProvider);
      if (config.localApiHost.trim().isEmpty || config.localApiPort <= 0) {
        throw StateError('LAN update server is not configured');
      }
      final uri = Uri(
          scheme: 'http',
          host: config.localApiHost,
          port: config.localApiPort,
          path: '/app-updates/$channel/latest');
      final client = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5)));
      try {
        final response = await client.getUri<dynamic>(uri,
            options: Options(
                headers: {'Cache-Control': 'no-cache'},
                validateStatus: (status) => status == 200 || status == 404));
        if (response.statusCode == 404) return null;
        return Map<String, dynamic>.from(response.data as Map);
      } finally {
        client.close();
      }
    });
