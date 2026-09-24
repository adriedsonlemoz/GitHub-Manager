import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

void main() {
  RepositoryWorkflowRun run(String status) => RepositoryWorkflowRun(
        id: 1,
        workflowId: 1,
        workflowPath: '.github/workflows/build.yml',
        name: 'Build',
        title: 'Build',
        status: status,
        conclusion: null,
        branch: 'main',
        headSha: 'abcdef0',
        commitMessage: 'Build',
        event: 'push',
        runNumber: 1,
        runAttempt: 1,
        createdAt: null,
        startedAt: null,
        updatedAt: null,
        htmlUrl: '',
      );

  test('requested e pending são tratados como execução ativa', () {
    expect(run('requested').isRunning, isTrue);
    expect(run('pending').isRunning, isTrue);
    expect(run('queued').isRunning, isTrue);
    expect(run('in_progress').isRunning, isTrue);
    expect(run('completed').isRunning, isFalse);
  });
}
