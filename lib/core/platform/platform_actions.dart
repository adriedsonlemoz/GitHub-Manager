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
  }) async {
    final location = await _channel.invokeMethod<String>(
      'publishToDownloads',
      {
        'sourcePath': sourcePath,
        'fileName': fileName,
        'mimeType': mimeType,
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
}
