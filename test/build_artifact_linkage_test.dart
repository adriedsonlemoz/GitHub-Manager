import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';

void main() {
  test('artifact keeps workflow run id and head sha for build cleanup', () {
    final artifact = ActionArtifact.fromJson({
      'id': 10,
      'name': 'android-apk',
      'size_in_bytes': 20,
      'expired': false,
      'workflow_run': {
        'id': 77,
        'head_sha': 'abc123',
      },
    });

    expect(artifact.workflowRunId, 77);
    expect(artifact.workflowRunHeadSha, 'abc123');
  });

  test('release asset keeps release linkage metadata', () {
    final asset = ReleaseAsset.fromJson(
      {
        'id': 30,
        'name': 'app-release.apk',
        'size': 40,
        'browser_download_url': 'https://example.invalid/app.apk',
      },
      tagName: 'v2.0.70',
      publishedAt: null,
      releaseId: 50,
      releaseName: 'Version 2.0.70',
      targetCommitish: 'abc123',
    );

    expect(asset.releaseId, 50);
    expect(asset.targetCommitish, 'abc123');
    expect(asset.isApk, isTrue);
  });
}
