enum AppEnvironment {
  dev,
  stage,
  prod,
}

enum AppLogLevel {
  debug,
  info,
  warning,
  error,
}

extension AppEnvironmentX on AppEnvironment {
  static AppEnvironment parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'dev':
        return AppEnvironment.dev;
      case 'stage':
      case 'staging':
        return AppEnvironment.stage;
      case 'prod':
      case 'production':
      default:
        return AppEnvironment.prod;
    }
  }

  String get key {
    switch (this) {
      case AppEnvironment.dev:
        return 'dev';
      case AppEnvironment.stage:
        return 'stage';
      case AppEnvironment.prod:
        return 'prod';
    }
  }

  String get defaultApiBaseUrl {
    switch (this) {
      case AppEnvironment.dev:
        return 'http://10.0.2.2:51254';
      case AppEnvironment.stage:
        return 'https://api.example.invalid:9999';
      case AppEnvironment.prod:
        return 'https://api.example.invalid:9999';
    }
  }

  AppLogLevel get defaultLogLevel {
    switch (this) {
      case AppEnvironment.dev:
        return AppLogLevel.debug;
      case AppEnvironment.stage:
        return AppLogLevel.info;
      case AppEnvironment.prod:
        return AppLogLevel.warning;
    }
  }
}

extension AppLogLevelX on AppLogLevel {
  static AppLogLevel parse(String raw, {required AppLogLevel fallback}) {
    switch (raw.trim().toLowerCase()) {
      case 'debug':
        return AppLogLevel.debug;
      case 'info':
        return AppLogLevel.info;
      case 'warning':
      case 'warn':
        return AppLogLevel.warning;
      case 'error':
        return AppLogLevel.error;
      default:
        return fallback;
    }
  }

  String get key {
    switch (this) {
      case AppLogLevel.debug:
        return 'debug';
      case AppLogLevel.info:
        return 'info';
      case AppLogLevel.warning:
        return 'warning';
      case AppLogLevel.error:
        return 'error';
    }
  }
}

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.connectTimeoutMs,
    required this.receiveTimeoutMs,
    required this.sendTimeoutMs,
    this.crashReportUrl = '',
    this.environment = AppEnvironment.prod,
    this.logLevel = AppLogLevel.info,
    this.enableNetworkLogs = false,
    this.enableCrashReporting = true,
    this.enableLocalApiRoute = false,
    this.localApiHost = '',
    this.localApiPort = 0,
    this.localApiProbeTimeoutMs = 700,
    this.localApiCacheTtlMs = 30000,
  });

  final String apiBaseUrl;
  final int connectTimeoutMs;
  final int receiveTimeoutMs;
  final int sendTimeoutMs;
  final String crashReportUrl;
  final AppEnvironment environment;
  final AppLogLevel logLevel;
  final bool enableNetworkLogs;
  final bool enableCrashReporting;
  final bool enableLocalApiRoute;
  final String localApiHost;
  final int localApiPort;
  final int localApiProbeTimeoutMs;
  final int localApiCacheTtlMs;

  String get signalrUrl => '$apiBaseUrl/player';

  static AppConfig fromEnvironment({
    AppEnvironment? environmentOverride,
  }) {
    final AppEnvironment environment = environmentOverride ??
        AppEnvironmentX.parse(
          const String.fromEnvironment(
            'LOCALTUBE_ENV',
            defaultValue: 'prod',
          ),
        );
    final String apiBaseUrl = const String.fromEnvironment(
      'LOCALTUBE_API_BASE_URL',
      defaultValue: '',
    );
    final AppLogLevel logLevel = AppLogLevelX.parse(
      const String.fromEnvironment(
        'LOCALTUBE_LOG_LEVEL',
        defaultValue: '',
      ),
      fallback: environment.defaultLogLevel,
    );

    return AppConfig(
      apiBaseUrl: apiBaseUrl.trim().isEmpty
          ? environment.defaultApiBaseUrl
          : apiBaseUrl,
      connectTimeoutMs: const int.fromEnvironment(
        'LOCALTUBE_CONNECT_TIMEOUT_MS',
        defaultValue: 15000,
      ),
      receiveTimeoutMs: const int.fromEnvironment(
        'LOCALTUBE_RECEIVE_TIMEOUT_MS',
        defaultValue: 30000,
      ),
      sendTimeoutMs: const int.fromEnvironment(
        'LOCALTUBE_SEND_TIMEOUT_MS',
        defaultValue: 15000,
      ),
      crashReportUrl: const String.fromEnvironment(
        'LOCALTUBE_CRASH_REPORT_URL',
        defaultValue: '',
      ),
      environment: environment,
      logLevel: logLevel,
      // Enable in stage/prod only when launched with:
      // --dart-define=LOCALTUBE_FEATURE_NETWORK_LOGS=true
      enableNetworkLogs: _parseBool(
        const String.fromEnvironment(
          'LOCALTUBE_FEATURE_NETWORK_LOGS',
          defaultValue: '',
        ),
        fallback: environment == AppEnvironment.dev,
      ),
      enableCrashReporting: _parseBool(
        const String.fromEnvironment(
          'LOCALTUBE_FEATURE_CRASH_REPORTING',
          defaultValue: '',
        ),
        fallback: environment != AppEnvironment.dev,
      ),
      enableLocalApiRoute: _parseBool(
        const String.fromEnvironment(
          'LOCALTUBE_FEATURE_LOCAL_API_ROUTE',
          defaultValue: '',
        ),
        fallback: false,
      ),
      localApiHost: const String.fromEnvironment(
        'LOCALTUBE_LOCAL_API_HOST',
        defaultValue: '',
      ),
      localApiPort: const int.fromEnvironment(
        'LOCALTUBE_LOCAL_API_PORT',
        defaultValue: 0,
      ),
      localApiProbeTimeoutMs: const int.fromEnvironment(
        'LOCALTUBE_LOCAL_API_PROBE_TIMEOUT_MS',
        defaultValue: 700,
      ),
      localApiCacheTtlMs: const int.fromEnvironment(
        'LOCALTUBE_LOCAL_API_CACHE_TTL_MS',
        defaultValue: 30000,
      ),
    );
  }

  static bool _parseBool(String raw, {required bool fallback}) {
    final String normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return fallback;
    }
    switch (normalized) {
      case '1':
      case 'true':
      case 'yes':
      case 'on':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'off':
        return false;
      default:
        return fallback;
    }
  }
}
