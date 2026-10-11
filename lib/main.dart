import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/app/github_manager_app.dart';
import 'package:github_manager/app/theme/app_theme_controller.dart';
import 'package:github_manager/core/background/build_monitor_service.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/core/platform/system_ui_settings.dart';
import 'package:github_manager/core/telemetry/app_telemetry_service.dart';
import 'package:github_manager/features/update/application/startup_update_coordinator.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      _installGlobalErrorCapture();
      WidgetsBinding.instance.addObserver(_nativeEngineLifecycleObserver);

      // O primeiro frame nunca deve depender de plugins/armazenamento. A splash
      // nativa do Android só é removida quando o Flutter desenha esse frame.
      runApp(const ProviderScope(child: GitHubManagerApp()));

      unawaited(
        SystemUiSettings.instance.reapply()
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

final _nativeEngineLifecycleObserver = _NativeEngineLifecycleObserver();

class _NativeEngineLifecycleObserver extends WidgetsBindingObserver {
  bool _keyboardWasVisible = false;
  Timer? _keyboardRestoreTimer;

  @override
  void didChangeMetrics() {
    final keyboardVisible = WidgetsBinding.instance.platformDispatcher.views
        .any((view) => view.viewInsets.bottom > 0);
    if (keyboardVisible) {
      _keyboardRestoreTimer?.cancel();
    } else if (_keyboardWasVisible && SystemUiSettings.instance.value) {
      // Android pode mostrar as barras enquanto o teclado está aberto e exige
      // pelo menos 1 s após fechá-lo antes de aceitar modo imersivo de novo.
      _keyboardRestoreTimer?.cancel();
      _keyboardRestoreTimer = Timer(const Duration(milliseconds: 1250), () {
        if (!SystemUiSettings.instance.value) return;
        unawaited(
          SystemUiSettings.instance.reapply().catchError(
            (Object error, StackTrace stackTrace) =>
                _recordNonFatal('keyboard.system_ui', error, stackTrace),
          ),
        );
      });
    }
    _keyboardWasVisible = keyboardVisible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppTelemetryService.instance.importPendingNativeEngineLifecycle());
      unawaited(
        SystemUiSettings.instance.reapply().catchError(
          (Object error, StackTrace stackTrace) =>
              _recordNonFatal('lifecycle.system_ui', error, stackTrace),
        ),
      );
    }
  }
}

Future<void> _initializeAfterFirstFrame() async {
  // Resolve primeiro o tema. As novidades automáticas só podem abrir depois
  // dessa possível reconstrução visual e fora do MaterialApp.builder.
  try {
    await AppThemeController.instance.initialize().timeout(
          const Duration(seconds: 3),
        );
  } catch (error, stackTrace) {
    _recordNonFatal('startup.theme', error, stackTrace);
  }

  // Recupera o modo visual salvo, sem tornar a primeira renderização dependente
  // de banco de dados. O modo imersivo permanece padrão na primeira instalação.
  try {
    await SystemUiSettings.instance.initialize().timeout(
          const Duration(seconds: 3),
        );
  } catch (error, stackTrace) {
    _recordNonFatal('startup.system_ui_settings', error, stackTrace);
  }

  StartupUpdateCoordinator.instance.start();

  try {
    await AppTelemetryService.instance.importPendingNativeEngineLifecycle().timeout(
          const Duration(seconds: 3),
        );
  } catch (error, stackTrace) {
    _recordNonFatal('startup.native_engine_lifecycle_import', error, stackTrace);
  }

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
    await BuildMonitorService.initialize().timeout(const Duration(seconds: 8));
    await BuildMonitorService.ensureDefaultEnabled().timeout(
          const Duration(seconds: 15),
        );
  } catch (error, stackTrace) {
    _recordNonFatal('startup.build_monitor', error, stackTrace);
  }
}
