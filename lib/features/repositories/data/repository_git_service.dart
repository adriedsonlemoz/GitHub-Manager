import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/core/utils/commit_message.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/domain/workflow_definition_inspector.dart';

part 'repository_git_files.dart';
part 'repository_git_workflows.dart';
part 'repository_git_actions.dart';

abstract class _RepositoryGitBase {
  _RepositoryGitBase(this._client);

  final GitHubApiClient _client;
  final Map<String, String?> _runVersionCache = <String, String?>{};
}

class RepositoryGitService extends _RepositoryGitBase
    with
        _RepositoryGitFileOperations,
        _RepositoryGitWorkflowOperations,
        _RepositoryGitActionsOperations {
  RepositoryGitService(GitHubApiClient client) : super(client);

  static const maxEditableTextBytes = 1024 * 1024;
  static const maxUploadBytes = 95 * 1024 * 1024;
}

class _WorkflowFileCandidate {
  const _WorkflowFileCandidate({
    required this.fileName,
    required this.path,
  });

  final String fileName;
  final String path;
}

class _WorkflowRunsPage {
  const _WorkflowRunsPage({
    required this.runs,
    required this.httpStatus,
    required this.totalCount,
  });

  final List<RepositoryWorkflowRun> runs;
  final int? httpStatus;
  final int? totalCount;
}
