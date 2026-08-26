import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/features/builds/data/artifact_service.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';

final artifactServiceProvider = Provider<ArtifactService>(
  (ref) => ArtifactService(ref.watch(githubApiClientProvider)),
);

final repositoryArtifactsProvider = FutureProvider.family<List<ActionArtifact>, String>(
  (ref, repositoryFullName) =>
      ref.watch(artifactServiceProvider).listArtifacts(repositoryFullName),
);
