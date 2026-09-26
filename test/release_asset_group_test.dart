import 'package:flutter_test/flutter_test.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';
import 'package:github_manager/features/builds/domain/release_asset_group.dart';

void main() {
  ReleaseAsset asset({
    required int id,
    required String name,
    required String tag,
    required int releaseId,
    DateTime? publishedAt,
  }) =>
      ReleaseAsset(
        id: id,
        name: name,
        sizeBytes: 6 * 1024 * 1024,
        downloadUrl: 'https://example.invalid/$name',
        tagName: tag,
        publishedAt: publishedAt,
        releaseId: releaseId,
        releaseName: tag,
        targetCommitish: 'main',
      );

  test('ordena versões dentro de uma Release fixa pela versão do asset', () {
    final published = DateTime.utc(2026, 9, 12, 23, 6);
    final groups = groupReleaseAssets([
      asset(
        id: 31,
        name: 'Explorador-XP-0.1.0-alpha.31-performance.apk',
        tag: 'explorador-xp-dev',
        releaseId: 100,
        publishedAt: published,
      ),
      asset(
        id: 74,
        name: 'Explorador-XP-0.1.0-alpha.74-performance.apk',
        tag: 'explorador-xp-dev',
        releaseId: 100,
        publishedAt: published,
      ),
      asset(
        id: 66,
        name: 'Explorador-XP-0.1.0-alpha.66-performance.apk',
        tag: 'explorador-xp-dev',
        releaseId: 100,
        publishedAt: published,
      ),
    ]);

    expect(groups.map((group) => group.version), [
      '0.1.0-alpha.74',
      '0.1.0-alpha.66',
      '0.1.0-alpha.31',
    ]);
  });

  test('agrupa variantes da mesma versão e prioriza Universal', () {
    final groups = groupReleaseAssets([
      asset(
        id: 1,
        name: 'App-1.4.2-arm64-v8a.apk',
        tag: 'v1.4.2',
        releaseId: 200,
      ),
      asset(
        id: 2,
        name: 'App-1.4.2-armeabi-v7a.apk',
        tag: 'v1.4.2',
        releaseId: 200,
      ),
      asset(
        id: 3,
        name: 'App-1.4.2-universal.apk',
        tag: 'v1.4.2',
        releaseId: 200,
      ),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.version, '1.4.2');
    expect(groups.single.assets, hasLength(3));
    expect(releaseAssetVariantLabel(groups.single.assets[0]), 'Universal');
    expect(releaseAssetVariantLabel(groups.single.assets[1]), 'ARM64');
    expect(releaseAssetVariantLabel(groups.single.assets[2]), 'ARMv7');
    expect(releaseAssetIsRecommended(groups.single.preferredAsset), isTrue);
  });

  test('versão estável fica acima de pré-release equivalente', () {
    final groups = groupReleaseAssets([
      asset(
        id: 1,
        name: 'App-2.0.0-alpha.10.apk',
        tag: 'dev',
        releaseId: 300,
      ),
      asset(
        id: 2,
        name: 'App-2.0.0.apk',
        tag: 'dev',
        releaseId: 300,
      ),
    ]);

    expect(groups.first.version, '2.0.0');
    expect(groups.last.version, '2.0.0-alpha.10');
  });
}
