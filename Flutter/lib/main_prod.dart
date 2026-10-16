import 'core/config/app_config.dart';
import 'main.dart' as app;

Future<void> main() {
  return app.runLocalTubeApp(
    environmentOverride: AppEnvironment.prod,
  );
}
