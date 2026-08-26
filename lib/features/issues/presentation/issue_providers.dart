import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/issues/data/repository_issue_service.dart';

final repositoryIssueServiceProvider = Provider<RepositoryIssueService>(
  (ref) => RepositoryIssueService(ref.watch(githubApiClientProvider)),
);
