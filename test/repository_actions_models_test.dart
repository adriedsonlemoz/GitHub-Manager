import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';

void main() {
  group('GitHub Actions models', () {
    const workflow = RepositoryWorkflow(
      id: 342786192,
      name: 'Android APK',
      path: '.github/workflows/android-apk.yml',
      state: 'active',
    );

    test('run belongs to workflow by workflow_id', () {
      final run = RepositoryWorkflowRun.fromJson({
        'id': 32979732892,
        'workflow_id': 342786192,
        'path': '.github/workflows/android-apk.yml',
        'name': 'Android APK',
        'display_title': 'Build atual',
        'status': 'completed',
        'conclusion': 'success',
        'head_branch': 'main',
        'head_sha': '4e4b13dab1c7eb9d6e8972c6dc8a648eae495572',
        'run_number': 15,
        'run_attempt': 1,
      });

      expect(run.belongsTo(workflow), isTrue);
      expect(run.workflowId, 342786192);
      expect(run.shortSha, '4e4b13d');
    });

    test('run falls back to normalized workflow path', () {
      final run = RepositoryWorkflowRun.fromJson({
        'id': 1,
        'workflow_id': 0,
        'path': '.GITHUB/WORKFLOWS/android-apk.yml',
        'name': 'Android APK',
        'status': 'queued',
        'head_branch': 'main',
      });

      expect(run.belongsTo(workflow), isTrue);
      expect(run.isRunning, isTrue);
    });
  });
}
