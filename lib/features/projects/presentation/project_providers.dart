import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/projects/data/git_project_upload_service.dart';
import 'package:github_manager/features/projects/data/local_project_service.dart';

final localProjectServiceProvider = Provider<LocalProjectService>(
  (ref) => LocalProjectService(),
);

final gitProjectUploadServiceProvider = Provider<GitProjectUploadService>(
  (ref) => GitProjectUploadService(ref.watch(githubApiClientProvider)),
);
