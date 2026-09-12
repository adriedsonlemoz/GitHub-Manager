import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/projects/presentation/project_providers.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:github_manager/features/uploads/data/upload_manager_service.dart';
import 'package:github_manager/features/uploads/data/upload_recovery_settings.dart';

final uploadManagerProvider = Provider<UploadManagerService>((ref) {
  final manager = UploadManagerService(
    uploadService: ref.watch(gitProjectUploadServiceProvider),
    gitService: ref.watch(repositoryGitServiceProvider),
    automaticRecoveryEnabled: () =>
        UploadRecoverySettings.isAutomaticRecoveryEnabled(
      database: ref.read(localDatabaseProvider),
    ),
  );
  ref.onDispose(manager.dispose);
  return manager;
});
