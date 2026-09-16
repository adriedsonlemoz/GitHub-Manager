import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/projects/data/git_project_upload_service.dart';

void main() {
  test('GitHub Actions workflows are protected from implicit ZIP deletion', () {
    expect(
      GitProjectUploadService.isProtectedRepositoryInfrastructurePath(
        '.github/workflows/android-apk.yml',
      ),
      isTrue,
    );
    expect(
      GitProjectUploadService.isProtectedRepositoryInfrastructurePath(
        r'\.github\workflows\release.yaml',
      ),
      isTrue,
    );
    expect(
      GitProjectUploadService.isProtectedRepositoryInfrastructurePath(
        'lib/main.dart',
      ),
      isFalse,
    );
    expect(
      GitProjectUploadService.isProtectedRepositoryInfrastructurePath(
        '.github/ISSUE_TEMPLATE/bug.md',
      ),
      isFalse,
    );
  });

  test('protected workflows never become stale just because ZIP omitted them', () {
    final zipPaths = <String>{'lib/main.dart'};

    expect(
      GitProjectUploadService.shouldRemoveRepositoryPath(
        path: '.github/workflows/android-apk.yml',
        zipPaths: zipPaths,
      ),
      isFalse,
    );
    expect(
      GitProjectUploadService.shouldRemoveRepositoryPath(
        path: 'lib/old_screen.dart',
        zipPaths: zipPaths,
      ),
      isTrue,
    );
    expect(
      GitProjectUploadService.shouldRemoveRepositoryPath(
        path: 'lib/main.dart',
        zipPaths: zipPaths,
      ),
      isFalse,
    );
  });
}
