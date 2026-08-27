import 'package:flutter/services.dart';

abstract final class PlatformActions {
  static const _channel = MethodChannel('br.com.githubmanager.app/platform');

  static Future<void> openUri(String uri, {String? mimeType}) async {
    final arguments = <String, dynamic>{'uri': uri};
    if (mimeType != null) {
      arguments['mimeType'] = mimeType;
    }
    await _channel.invokeMethod<void>('openUri', arguments);
  }

  static Future<void> openFile(String location, {String? mimeType}) async {
    final arguments = <String, dynamic>{'path': location};
    if (mimeType != null) {
      arguments['mimeType'] = mimeType;
    }
    await _channel.invokeMethod<void>('openFile', arguments);
  }

  static Future<String?> installApk(String location) =>
      _channel.invokeMethod<String>('installApk', {'path': location});

  static Future<void> shareFile(String location, {String? mimeType}) async {
    final arguments = <String, dynamic>{'path': location};
    if (mimeType != null) {
      arguments['mimeType'] = mimeType;
    }
    await _channel.invokeMethod<void>('shareFile', arguments);
  }

  static Future<String> publishToDownloads({
    required String sourcePath,
    required String fileName,
    required String mimeType,
    String? relativeFolder,
  }) async {
    final location = await _channel.invokeMethod<String>(
      'publishToDownloads',
      {
        'sourcePath': sourcePath,
        'fileName': fileName,
        'mimeType': mimeType,
        'relativeFolder': relativeFolder,
      },
    );
    if (location == null || location.isEmpty) {
      throw PlatformException(
        code: 'DOWNLOAD_PUBLISH_FAILED',
        message: 'O Android não retornou o arquivo publicado.',
      );
    }
    return location;
  }

  static Future<bool> requestLegacyDownloadsPermission() async =>
      await _channel.invokeMethod<bool>('requestLegacyDownloadsPermission') ??
      false;

  static Future<void> deletePublishedDownload(String location) =>
      _channel.invokeMethod<void>('deletePublishedDownload', {
        'location': location,
      });

  static Future<void> showUploadForegroundService({
    required bool startService,
    required String uploadId,
    required String projectName,
    required String repositoryFullName,
    required String phase,
    required int current,
    required int total,
    required bool indeterminate,
    required int activeCount,
  }) =>
      _channel.invokeMethod<void>('showUploadForegroundService', {
        'startService': startService,
        'uploadId': uploadId,
        'projectName': projectName,
        'repositoryFullName': repositoryFullName,
        'phase': phase,
        'current': current,
        'total': total,
        'indeterminate': indeterminate,
        'activeCount': activeCount,
      });

  static Future<void> stopUploadForegroundService() =>
      _channel.invokeMethod<void>('stopUploadForegroundService');

  static Future<void> showDownloadForegroundService({
    required bool startService,
    required String downloadId,
    required String fileName,
    required String repositoryFullName,
    required int current,
    required int total,
    required bool indeterminate,
    required int activeCount,
  }) =>
      _channel.invokeMethod<void>('showDownloadForegroundService', {
        'startService': startService,
        'downloadId': downloadId,
        'fileName': fileName,
        'repositoryFullName': repositoryFullName,
        'current': current,
        'total': total,
        'indeterminate': indeterminate,
        'activeCount': activeCount,
      });

  static Future<void> stopDownloadForegroundService() =>
      _channel.invokeMethod<void>('stopDownloadForegroundService');
}
