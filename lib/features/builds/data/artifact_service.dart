import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:github_manager/core/network/github_api_client.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/domain/release_asset.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ReleasePublishResult {
  const ReleasePublishResult({
    required this.tagName,
    required this.releaseName,
    required this.assetName,
    required this.htmlUrl,
  });

  final String tagName;
  final String releaseName;
  final String assetName;
  final String htmlUrl;
}

class ArtifactService {
  ArtifactService(this._client);

  final GitHubApiClient _client;

  Future<List<ActionArtifact>> listArtifacts(String repositoryFullName) async {
    final artifacts = <ActionArtifact>[];
    for (var page = 1; page <= 5; page++) {
      final response = await _client.get<Map<String, dynamic>>(
        '/repos/$repositoryFullName/actions/artifacts',
        queryParameters: {'per_page': 100, 'page': page},
      );
      final raw = response.data?['artifacts'];
      if (raw is! List) break;
      final pageItems = raw
          .whereType<Map>()
          .map((json) => ActionArtifact.fromJson(Map<String, dynamic>.from(json)))
          .toList(growable: false);
      artifacts.addAll(pageItems);
      if (raw.length < 100) break;
    }
    artifacts.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return artifacts;
  }

  Future<void> deleteArtifact({
    required String repositoryFullName,
    required int artifactId,
  }) =>
      _client.delete<void>(
        '/repos/$repositoryFullName/actions/artifacts/$artifactId',
      );

  Future<int> deleteArtifacts({
    required String repositoryFullName,
    required Iterable<int> artifactIds,
  }) async {
    var deleted = 0;
    for (final artifactId in artifactIds.toSet()) {
      await deleteArtifact(
        repositoryFullName: repositoryFullName,
        artifactId: artifactId,
      );
      deleted++;
    }
    return deleted;
  }

  Future<List<ReleaseAsset>> listReleaseAssets(String repositoryFullName) async {
    final response = await _client.get<List<dynamic>>(
      '/repos/$repositoryFullName/releases',
      queryParameters: {'per_page': 30, 'page': 1},
    );
    final result = <ReleaseAsset>[];
    for (final rawRelease in response.data ?? const <dynamic>[]) {
      if (rawRelease is! Map) continue;
      final release = Map<String, dynamic>.from(rawRelease);
      final tag = release['tag_name'] as String? ?? '';
      final published = DateTime.tryParse(release['published_at'] as String? ?? '');
      final assets = release['assets'];
      if (assets is! List) continue;
      for (final rawAsset in assets) {
        if (rawAsset is Map) {
          final asset = ReleaseAsset.fromJson(
            Map<String, dynamic>.from(rawAsset),
            tagName: tag,
            publishedAt: published,
          );
          if (asset.id > 0) result.add(asset);
        }
      }
    }
    result.sort(
      (a, b) => (b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return result;
  }

  Future<ReleasePublishResult> publishArtifactAsRelease({
    required String repositoryFullName,
    required String targetCommitish,
    required ActionArtifact artifact,
    required String tagName,
    required String releaseName,
    required String notes,
    required bool makeLatest,
    required bool prerelease,
    void Function(String stage)? onProgress,
  }) async {
    if (artifact.expired) {
      throw const FormatException(
        'Este artifact expirou e não pode mais ser publicado em uma Release.',
      );
    }

    final tempRoot = await getTemporaryDirectory();
    final work = await Directory(
      p.join(
        tempRoot.path,
        'release-${artifact.id}-${DateTime.now().microsecondsSinceEpoch}',
      ),
    ).create(recursive: true);
    final artifactZip = File(p.join(work.path, 'artifact.zip'));
    File? apkFile;
    int? releaseId;

    try {
      onProgress?.call('Baixando o artifact do GitHub');
      await _client.downloadRedirectedFile(
        '/repos/$repositoryFullName/actions/artifacts/${artifact.id}/zip',
        artifactZip.path,
      );

      onProgress?.call('Localizando o APK dentro do artifact');
      final input = InputFileStream(artifactZip.path);
      try {
        final archive = ZipDecoder().decodeStream(input, verify: false);
        final apkEntries = archive
            .where(
              (entry) =>
                  entry.isFile && entry.name.toLowerCase().endsWith('.apk'),
            )
            .toList(growable: false);

        if (apkEntries.isNotEmpty) {
          final selected = apkEntries.firstWhere(
            (entry) {
              final lower = entry.name.toLowerCase();
              return lower.contains('universal') ||
                  (!lower.contains('arm64') &&
                      !lower.contains('armeabi') &&
                      !lower.contains('x86'));
            },
            orElse: () =>
                apkEntries.reduce((a, b) => a.size >= b.size ? a : b),
          );

          final bytes = selected.readBytes();
          if (bytes == null) {
            throw const FormatException(
              'Não foi possível extrair o APK do artifact.',
            );
          }
          final safeAssetName = _safeAssetName(selected.name.split('/').last);
          apkFile = File(p.join(work.path, safeAssetName));
          await apkFile.writeAsBytes(bytes, flush: true);
        } else {
          final names = archive
              .where((entry) => entry.isFile)
              .map((entry) => entry.name.replaceAll('\\', '/').toLowerCase())
              .toSet();
          final directApk = names.contains('androidmanifest.xml') &&
              (names.contains('classes.dex') ||
                  names.contains('resources.arsc'));
          if (!directApk) {
            throw const FormatException(
              'O artifact selecionado não contém um APK.',
            );
          }

          // upload-artifact v7 com archive:false já entregou o APK real.
          // Reutiliza o arquivo baixado em vez de descompactar/recompactar.
          final directName = artifact.name.toLowerCase().endsWith('.apk')
              ? artifact.name
              : 'app-release.apk';
          final safeAssetName = _safeAssetName(directName);
          apkFile = File(p.join(work.path, safeAssetName));
          await artifactZip.copy(apkFile.path);
        }
        archive.clearSync();
      } finally {
        input.closeSync();
      }

      onProgress?.call('Criando a Release no GitHub');
      final releaseResponse = await _client.post<Map<String, dynamic>>(
        '/repos/$repositoryFullName/releases',
        data: {
          'tag_name': tagName.trim(),
          'target_commitish': targetCommitish.trim(),
          'name': releaseName.trim(),
          'body': notes.trim(),
          'draft': false,
          'prerelease': prerelease,
          'make_latest': makeLatest ? 'true' : 'false',
        },
      );
      final release = releaseResponse.data ?? const <String, dynamic>{};
      releaseId = (release['id'] as num?)?.toInt();
      if (releaseId == null || releaseId <= 0) {
        throw const FormatException(
          'O GitHub criou uma resposta de Release inválida.',
        );
      }

      onProgress?.call('Enviando o APK para a Release');
      final fileLength = await apkFile.length();
      final assetName = p.basename(apkFile.path);
      await _client.uploadBinary<Map<String, dynamic>>(
        url:
            'https://uploads.github.com/repos/$repositoryFullName/releases/$releaseId/assets',
        stream: apkFile.openRead(),
        contentLength: fileLength,
        contentType: 'application/vnd.android.package-archive',
        queryParameters: {'name': assetName},
      );

      return ReleasePublishResult(
        tagName: tagName.trim(),
        releaseName: releaseName.trim(),
        assetName: assetName,
        htmlUrl: release['html_url'] as String? ?? '',
      );
    } catch (_) {
      if (releaseId != null) {
        try {
          await _client.delete<void>(
            '/repos/$repositoryFullName/releases/$releaseId',
          );
        } catch (_) {
          // A falha original é mais importante; rollback é apenas proteção.
        }
      }
      rethrow;
    } finally {
      if (await work.exists()) {
        await work.delete(recursive: true);
      }
    }
  }

  Future<int> deleteOlderApkArtifacts(String repositoryFullName) async {
    final artifacts = await listArtifacts(repositoryFullName);
    final apks = artifacts
        .where((item) => item.likelyContainsApk && !item.expired)
        .toList();
    if (apks.length <= 1) return 0;
    var deleted = 0;
    for (final artifact in apks.skip(1)) {
      await deleteArtifact(
        repositoryFullName: repositoryFullName,
        artifactId: artifact.id,
      );
      deleted++;
    }
    return deleted;
  }

  static String _safeAssetName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), '-')
        .trim();
    return cleaned.isEmpty ? 'app-release.apk' : cleaned;
  }
}
