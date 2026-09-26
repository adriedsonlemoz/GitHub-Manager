import 'dart:collection';

import 'package:github_manager/features/builds/domain/release_asset.dart';

/// Grupo visual de arquivos que pertencem à mesma versão publicada.
///
/// Alguns projetos mantêm várias versões dentro de uma única GitHub Release
/// (por exemplo, uma tag fixa de desenvolvimento). Por isso o agrupamento não
/// pode depender apenas do releaseId/tag: quando o nome do asset contém uma
/// versão, ela também participa da chave.
class ReleaseAssetGroup {
  const ReleaseAssetGroup({
    required this.releaseId,
    required this.tagName,
    required this.releaseName,
    required this.version,
    required this.publishedAt,
    required this.assets,
  });

  final int releaseId;
  final String tagName;
  final String releaseName;
  final String? version;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  bool get hasMultipleAssets => assets.length > 1;
  bool get hasApk => assets.any((asset) => asset.isApk);
  ReleaseAsset get preferredAsset => assets.first;
}

List<ReleaseAssetGroup> groupReleaseAssets(Iterable<ReleaseAsset> source) {
  final buckets = LinkedHashMap<String, List<ReleaseAsset>>();

  for (final asset in source) {
    final version = releaseAssetVersion(asset);
    final releaseKey = asset.releaseId > 0
        ? 'release:${asset.releaseId}'
        : 'tag:${asset.tagName.toLowerCase()}';
    final key = version == null
        ? releaseKey
        : '$releaseKey|version:${version.toLowerCase()}';
    (buckets[key] ??= <ReleaseAsset>[]).add(asset);
  }

  final groups = <ReleaseAssetGroup>[];
  for (final assets in buckets.values) {
    assets.sort(_compareVariantPreference);
    final first = assets.first;
    final version = releaseAssetVersion(first) ??
        assets.map(releaseAssetVersion).whereType<String>().firstOrNull;
    final published = assets
        .map((asset) => asset.publishedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, date) {
      if (latest == null || date.isAfter(latest)) return date;
      return latest;
    });
    groups.add(
      ReleaseAssetGroup(
        releaseId: first.releaseId,
        tagName: first.tagName,
        releaseName: first.releaseName,
        version: version,
        publishedAt: published,
        assets: List<ReleaseAsset>.unmodifiable(assets),
      ),
    );
  }

  groups.sort(_compareGroupsNewestFirst);
  return List<ReleaseAssetGroup>.unmodifiable(groups);
}

String? releaseAssetVersion(ReleaseAsset asset) {
  // Preferimos o nome do arquivo porque uma Release pode usar uma tag fixa
  // (ex.: "explorador-xp-dev") e acumular assets de muitas versões.
  return _extractVersion(asset.name) ?? _extractVersion(asset.tagName);
}

String releaseAssetVariantLabel(ReleaseAsset asset) {
  final lower = asset.name.toLowerCase();
  if (lower.contains('universal') ||
      lower.contains('fat-apk') ||
      lower.contains('-all.')) {
    return 'Universal';
  }
  if (lower.contains('arm64-v8a') ||
      lower.contains('arm64') ||
      lower.contains('aarch64')) {
    return 'ARM64';
  }
  if (lower.contains('armeabi-v7a') ||
      lower.contains('armv7') ||
      lower.contains('v7a')) {
    return 'ARMv7';
  }
  if (lower.contains('x86_64')) return 'x86_64';
  if (RegExp(r'(^|[-_.])x86($|[-_.])').hasMatch(lower)) return 'x86';
  if (lower.contains('performance')) return 'Performance';
  if (lower.contains('profile')) return 'Profile';
  if (lower.contains('debug')) return 'Debug';
  if (asset.isApk) return 'APK';
  return 'Arquivo';
}

bool releaseAssetIsRecommended(ReleaseAsset asset) =>
    releaseAssetVariantLabel(asset) == 'Universal';

String? _extractVersion(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  // Captura o núcleo x.y.z e os qualificadores de pré-release usados nos
  // projetos do usuário. Sufixos de build/ABI (performance, arm64, universal)
  // ficam fora da versão para que variantes sejam agrupadas corretamente.
  final match = RegExp(
    r'(\d+\.\d+\.\d+(?:-(?:alpha|beta|preview|pre|rc|dev)(?:[._-]?\d+)?)?)',
    caseSensitive: false,
  ).firstMatch(value);
  if (match != null) return match.group(1);

  // Fallback para projetos que usam somente major.minor.
  return RegExp(r'(\d+\.\d+)').firstMatch(value)?.group(1);
}

int _compareVariantPreference(ReleaseAsset left, ReleaseAsset right) {
  final rank = _variantRank(left).compareTo(_variantRank(right));
  if (rank != 0) return rank;
  return left.name.toLowerCase().compareTo(right.name.toLowerCase());
}

int _variantRank(ReleaseAsset asset) {
  return switch (releaseAssetVariantLabel(asset)) {
    'Universal' => 0,
    'ARM64' => 1,
    'ARMv7' => 2,
    'Performance' => 3,
    'APK' => 4,
    'x86_64' => 5,
    'x86' => 6,
    'Profile' => 7,
    'Debug' => 8,
    _ => 9,
  };
}

int _compareGroupsNewestFirst(ReleaseAssetGroup left, ReleaseAssetGroup right) {
  final leftVersion = _ComparableVersion.tryParse(left.version);
  final rightVersion = _ComparableVersion.tryParse(right.version);
  if (leftVersion != null && rightVersion != null) {
    final byVersion = rightVersion.compareTo(leftVersion);
    if (byVersion != 0) return byVersion;
  } else if (leftVersion != null) {
    return -1;
  } else if (rightVersion != null) {
    return 1;
  }

  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final byDate = (right.publishedAt ?? epoch).compareTo(left.publishedAt ?? epoch);
  if (byDate != 0) return byDate;
  return right.tagName.toLowerCase().compareTo(left.tagName.toLowerCase());
}

class _ComparableVersion implements Comparable<_ComparableVersion> {
  const _ComparableVersion(this.core, this.preRelease);

  final List<int> core;
  final List<String> preRelease;

  static _ComparableVersion? tryParse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final match = RegExp(
      r'^(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z._-]+))?$',
    ).firstMatch(value);
    if (match == null) return null;
    final preRelease = (match.group(4) ?? '')
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return _ComparableVersion(
      <int>[
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.tryParse(match.group(3) ?? '') ?? 0,
      ],
      preRelease,
    );
  }

  @override
  int compareTo(_ComparableVersion other) {
    for (var index = 0; index < core.length; index++) {
      if (core[index] != other.core[index]) {
        return core[index].compareTo(other.core[index]);
      }
    }

    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    final max = preRelease.length > other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var index = 0; index < max; index++) {
      if (index >= preRelease.length) return -1;
      if (index >= other.preRelease.length) return 1;
      final left = preRelease[index];
      final right = other.preRelease[index];
      if (left == right) continue;
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      if (leftNumber != null && rightNumber != null) {
        return leftNumber.compareTo(rightNumber);
      }
      if (leftNumber != null) return -1;
      if (rightNumber != null) return 1;
      return left.toLowerCase().compareTo(right.toLowerCase());
    }
    return 0;
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
