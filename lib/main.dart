import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/app/github_manager_app.dart';
import 'package:github_manager/app/theme/app_theme_controller.dart';
import 'package:github_manager/core/background/build_monitor_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // O primeiro frame nunca deve depender de plugins/armazenamento. A splash
  // nativa do Android só é removida quando o Flutter desenha esse frame.
  runApp(const ProviderScope(child: GitHubManagerApp()));

  unawaited(
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
        .catchError((_) {}),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeAfterFirstFrame());
  });
}

Future<void> _initializeAfterFirstFrame() async {
  try {
    await AppThemeController.instance.initialize().timeout(
      const Duration(seconds: 3),
    );
  } catch (_) {
    // Tema salvo é conveniência; nunca pode impedir a abertura do app.
  }

  try {
    await BuildMonitorService.initialize().timeout(const Duration(seconds: 8));
    await BuildMonitorService.ensureDefaultEnabled().timeout(
      const Duration(seconds: 15),
    );
  } catch (_) {
    // WorkManager/notificações são auxiliares e não podem bloquear o startup.
  }
}
