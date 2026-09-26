import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/app/github_manager_app.dart';
import 'package:github_manager/app/theme/app_theme_controller.dart';
import 'package:github_manager/core/background/build_monitor_service.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/core/telemetry/app_telemetry_service.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      _installGlobalErrorCapture();

      // O primeiro frame nunca deve depender de plugins/armazenamento. A splash
      // nativa do Android só é removida quando o Flutter desenha esse frame.
      runApp(const ProviderScope(child: GitHubManagerApp()));

      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
            .catchError((Object error, StackTrace stackTrace) {
          _recordNonFatal('startup.system_ui', error, stackTrace);
        }),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeAfterFirstFrame());
      });
    },
    (error, stackTrace) {
      _recordNonFatal('dart.zone', error, stackTrace, fatal: true);
    },
  );
}

void _installGlobalErrorCapture() {
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(AppTelemetryService.instance.recordFlutterError(details));
    if (previousFlutterHandler != null) {
      previousFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _recordNonFatal('dart.platform_dispatcher', error, stackTrace, fatal: true);
    if (previousPlatformHandler != null) {
      return previousPlatformHandler(error, stackTrace);
    }
    // O erro foi registrado. Evita encerrar o isolate por exceções assíncronas
    // que não precisam derrubar toda a interface.
    return true;
  };
}

void _recordNonFatal(
  String source,
  Object error,
  StackTrace stackTrace, {
  bool fatal = false,
}) {
  unawaited(
    AppTelemetryService.instance.recordError(
      source: source,
      error: error,
      stackTrace: stackTrace,
      fatal: fatal,
    ),
  );
}

Future<void> _initializeAfterFirstFrame() async {
  try {
    await AppTelemetryService.instance.importPendingNativeCrash().timeout(
          const Duration(seconds: 3),
        );
  } catch (error, stackTrace) {
    _recordNonFatal('startup.native_crash_import', error, stackTrace);
  }

  try {
    await LocalDatabase.shared.clearLegacyRemoteGitHubData();
  } catch (error, stackTrace) {
    _recordNonFatal('startup.local_database_cleanup', error, stackTrace);
  }

  try {
    await AppThemeController.instance.initialize().timeout(
          const Duration(seconds: 3),
        );
  } catch (error, stackTrace) {
    _recordNonFatal('startup.theme', error, stackTrace);
  }

  try {
    await BuildMonitorService.initialize().timeout(const Duration(seconds: 8));
    await BuildMonitorService.ensureDefaultEnabled().timeout(
          const Duration(seconds: 15),
        );
  } catch (error, stackTrace) {
    _recordNonFatal('startup.build_monitor', error, stackTrace);
  }
}
