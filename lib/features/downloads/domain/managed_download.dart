enum ManagedDownloadType { apk, projectZip, logs, file }

enum ManagedDownloadStatus { queued, downloading, completed, failed, cancelled }

class ManagedDownload {
  ManagedDownload({
    required this.id,
    required this.title,
    required this.fileName,
    required this.type,
    required this.status,
    required this.createdAt,
    this.repositoryFullName,
    this.localPath,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  final String id;
  String title;
  String fileName;
  final ManagedDownloadType type;
  ManagedDownloadStatus status;
  final DateTime createdAt;
  final String? repositoryFullName;
  String? localPath;
  int receivedBytes;
  int totalBytes;
  String? errorMessage;

  bool get isActive =>
      status == ManagedDownloadStatus.queued ||
      status == ManagedDownloadStatus.downloading;

  bool get isApk =>
      type == ManagedDownloadType.apk || fileName.toLowerCase().endsWith('.apk');

  bool get usesContentUri => localPath?.startsWith('content://') == true;

  double? get progress => totalBytes > 0 ? receivedBytes / totalBytes : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'fileName': fileName,
        'type': type.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'repositoryFullName': repositoryFullName,
        'localPath': localPath,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'errorMessage': errorMessage,
      };

  factory ManagedDownload.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString();
    final statusName = json['status']?.toString();
    return ManagedDownload(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Download',
      fileName: json['fileName']?.toString() ?? 'download',
      type: ManagedDownloadType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => ManagedDownloadType.file,
      ),
      status: ManagedDownloadStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => ManagedDownloadStatus.completed,
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      repositoryFullName: json['repositoryFullName']?.toString(),
      localPath: json['localPath']?.toString(),
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      errorMessage: json['errorMessage']?.toString(),
    );
  }
}
