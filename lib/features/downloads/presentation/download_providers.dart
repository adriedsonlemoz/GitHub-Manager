import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/downloads/data/download_manager_service.dart';

final downloadManagerProvider = Provider<DownloadManagerService>((ref) {
  final manager = DownloadManagerService(ref.watch(githubApiClientProvider));
  ref.onDispose(manager.dispose);
  return manager;
});
