import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/app/github_manager_app.dart';
import 'package:github_manager/app/theme/app_theme_controller.dart';
import 'package:github_manager/core/background/build_monitor_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await AppThemeController.instance.initialize();
  await BuildMonitorService.initialize();
  runApp(const ProviderScope(child: GitHubManagerApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    BuildMonitorService.ensureDefaultEnabled();
  });
}
