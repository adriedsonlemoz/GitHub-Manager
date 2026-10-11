import 'dart:convert';

/// Tipo e destino interno de uma notificação. Nunca aceita URLs externas.
class NotificationDestination {
  const NotificationDestination._(this.route);

  final String route;

  static String forBuild({
    required String repository,
    required int runId,
    String? branch,
  }) => jsonEncode({
        'type': 'build',
        'repository': repository,
        'runId': runId,
        if (branch != null && branch.trim().isNotEmpty) 'branch': branch,
      });

  static String forDownload(String id) =>
      jsonEncode({'type': 'download', 'id': id});

  static String forUpload(String id) =>
      jsonEncode({'type': 'upload', 'id': id});

  static NotificationDestination? fromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type'];
        if (type == 'build') {
          final repo = decoded['repository'];
          final id = decoded['runId'];
          final branch = decoded['branch'];
          if (repo is! String || !_validRepository(repo) ||
              id is! int || id <= 0) return null;
          final segments = repo.split('/');
          final base = Uri(pathSegments: [
            '', 'repositories', segments[0], segments[1], 'builds',
          ]);
          final query = <String, String>{'runId': '$id'};
          if (branch is String && branch.trim().isNotEmpty &&
              branch.length <= 200) {
            query['branch'] = branch;
          }
          return NotificationDestination._(
            base.replace(queryParameters: query).toString(),
          );
        }
        if (type == 'download' || type == 'upload') {
          final id = decoded['id'];
          if (id is! String || id.isEmpty || id.length > 180) return null;
          return NotificationDestination._(
            Uri(path: type == 'download' ? '/downloads' : '/uploads',
              queryParameters: {type == 'download' ? 'downloadId' : 'uploadId': id})
                .toString(),
          );
        }
      }
    } catch (_) {
      // Payloads legados não eram JSON.
    }
    // Compatibilidade: downloads antigos eram identificados por 'download:<id>'.
    if (payload.startsWith('download:')) {
      final id = payload.substring('download:'.length);
      if (id.isEmpty || id.length > 180) return null;
      return NotificationDestination._(
        Uri(path: '/downloads', queryParameters: {'downloadId': id}).toString(),
      );
    }
    // Builds anteriores guardavam somente o nome completo do repositório.
    if (_validRepository(payload)) {
      final segments = payload.split('/');
      return NotificationDestination._(
        Uri(pathSegments: ['', 'repositories', ...segments, 'builds']).toString(),
      );
    }
    return null;
  }

  static NotificationDestination? fromNativeRoute(String? route) {
    if (route == null || route.isEmpty || route.length > 512) return null;
    final uri = Uri.tryParse(route);
    if (uri == null || uri.hasAuthority || uri.hasScheme || uri.hasFragment ||
        uri.pathSegments.length != 1) return null;
    if (uri.path != '/downloads' && uri.path != '/uploads') return null;
    final key = uri.path == '/downloads' ? 'downloadId' : 'uploadId';
    final id = uri.queryParameters[key];
    if (id == null || id.isEmpty || id.length > 180) return null;
    return NotificationDestination._(
      Uri(path: uri.path, queryParameters: {key: id}).toString(),
    );
  }

  static bool _validRepository(String value) =>
      value.length <= 160 &&
      RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(value);
}
