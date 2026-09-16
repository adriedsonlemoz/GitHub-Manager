import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/builds/data/artifact_service.dart';
import 'package:github_manager/features/builds/data/build_cleanup_service.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';

final artifactServiceProvider = Provider<ArtifactService>(
  (ref) => ArtifactService(ref.watch(githubApiClientProvider)),
);

final repositoryArtifactsProvider = FutureProvider.autoDispose.family<List<ActionArtifact>, String>(
  (ref, repositoryFullName) =>
      ref.watch(artifactServiceProvider).listArtifacts(repositoryFullName),
);

final buildCleanupServiceProvider = Provider<BuildCleanupService>(
  (ref) => BuildCleanupService(
    ref.watch(githubApiClientProvider),
    ref.watch(artifactServiceProvider),
  ),
);

final repositoryReleaseAssetsProvider =
    FutureProvider.autoDispose.family<List<ReleaseAsset>, String>(
  (ref, repositoryFullName) =>
      ref.watch(artifactServiceProvider).listReleaseAssets(repositoryFullName),
);
