import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/projects/domain/project_safety_check.dart';
import 'package:github_manager/features/projects/domain/zip_project.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/domain/repository_project_info.dart';

void main() {
  const repository = GitHubRepository(
    id: 1,
    name: 'Social-Lite',
    fullName: 'owner/Social-Lite',
    isPrivate: false,
    isArchived: false,
    defaultBranch: 'main',
    updatedAt: null,
    htmlUrl: 'https://github.com/owner/Social-Lite',
  );

  ZipProjectPreview preview({
    String name = 'Social-Lite-0.1.1.zip',
    String? projectName,
    String? packageName,
    String? applicationId,
    String? version = '0.1.1',
    int? versionCode,
  }) =>
      ZipProjectPreview(
        path: '/tmp/$name',
        name: name,
        archiveBytes: 1,
        uncompressedBytes: 1,
        fileCount: 1,
        folderCount: 1,
        projectType: 'Android',
        importantFiles: const [],
        commonRoot: null,
        projectName: projectName,
        packageName: packageName,
        applicationId: applicationId,
        version: version,
        versionCode: versionCode,
      );

  RepositoryProjectInfo info({
    String projectName = 'Social-Lite',
    String? version = '0.1.0',
    String? packageName,
    String? applicationId,
    int? versionCode,
  }) =>
      RepositoryProjectInfo(
        projectName: projectName,
        version: version,
        technologies: const ['Android'],
        packageName: packageName,
        applicationId: applicationId,
        versionCode: versionCode,
      );

  test('versioned ZIP filename matches same repository without blocking', () {
    final result = ProjectSafetyCheck.compare(
      project: preview(),
      repository: repository,
      repositoryInfo: info(),
    );

    expect(result.blocked, isFalse);
    expect(result.warning, isFalse);
    expect(result.identitySource, contains('ZIP'));
    expect(result.versionComparison, ProjectVersionComparison.newer);
  });


  test('versioned project metadata still matches repository name', () {
    final result = ProjectSafetyCheck.compare(
      project: preview(projectName: 'social-lite-0.1.1'),
      repository: repository,
      repositoryInfo: info(projectName: 'Social-Lite'),
    );

    expect(result.blocked, isFalse);
    expect(result.warning, isFalse);
    expect(result.versionComparison, ProjectVersionComparison.newer);
  });

  test('versioned package clue from metadata does not create false mismatch', () {
    final result = ProjectSafetyCheck.compare(
      project: preview(packageName: 'social-lite-0.1.1'),
      repository: repository,
      repositoryInfo: info(packageName: 'social-lite-0.1.0'),
    );

    expect(result.blocked, isFalse);
    expect(result.warning, isFalse);
  });

  test('GitHub Manager export suffix is ignored as a weak filename clue', () {
    final result = ProjectSafetyCheck.compare(
      project: preview(
        name: 'Social-Lite-v0.1.1-20260826-212533-main.zip',
      ),
      repository: repository,
      repositoryInfo: info(),
    );

    expect(result.blocked, isFalse);
    expect(result.warning, isFalse);
  });

  test('different applicationId remains blocked', () {
    final result = ProjectSafetyCheck.compare(
      project: preview(applicationId: 'com.example.sociallite'),
      repository: repository,
      repositoryInfo: info(applicationId: 'com.example.other'),
    );

    expect(result.blocked, isTrue);
    expect(result.identitySource, 'applicationId');
  });

  test('unknown version becomes warning instead of newer version', () {
    final result = ProjectSafetyCheck.compare(
      project: preview(version: null),
      repository: repository,
      repositoryInfo: info(version: '0.1.0'),
    );

    expect(result.blocked, isFalse);
    expect(result.warning, isTrue);
    expect(result.versionComparison, ProjectVersionComparison.unknown);
  });

  test('older version remains blocked', () {
    final result = ProjectSafetyCheck.compare(
      project: preview(version: '0.0.9'),
      repository: repository,
      repositoryInfo: info(version: '0.1.0'),
    );

    expect(result.blocked, isTrue);
    expect(result.versionComparison, ProjectVersionComparison.older);
  });

  test('different weak filename never blocks by itself', () {
    final result = ProjectSafetyCheck.compare(
      project: preview(name: 'arquivo-exportado-0.1.1.zip'),
      repository: repository,
      repositoryInfo: info(),
    );

    expect(result.blocked, isFalse);
    expect(result.warning, isTrue);
  });
}
