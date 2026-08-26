class ReleaseAsset {
  const ReleaseAsset({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.downloadUrl,
    required this.tagName,
    required this.publishedAt,
  });

  final int id;
  final String name;
  final int sizeBytes;
  final String downloadUrl;
  final String tagName;
  final DateTime? publishedAt;

  bool get isApk => name.toLowerCase().endsWith('.apk');

  factory ReleaseAsset.fromJson(
    Map<String, dynamic> json, {
    required String tagName,
    required DateTime? publishedAt,
  }) =>
      ReleaseAsset(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'arquivo',
        sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
        downloadUrl: json['browser_download_url'] as String? ?? '',
        tagName: tagName,
        publishedAt: publishedAt,
      );
}
