import 'dart:async';
import 'dart:developer' as developer;

import 'package:github_manager/core/telemetry/app_telemetry_service.dart';

abstract final class AppLogger {
  static final _sensitivePatterns = <RegExp>[
    RegExp(r'(authorization\s*:\s*bearer\s+)[^\s,}]+', caseSensitive: false),
    RegExp(r'((token|api[_-]?key|password|secret)\s*[=:]\s*)[^\s,}]+', caseSensitive: false),
    RegExp(r'github_pat_[A-Za-z0-9_]+'),
    RegExp(r'gh[pousr]_[A-Za-z0-9]+'),
  ];

  static void info(String message) =>
      developer.log(_sanitize(message), name: 'GitHubManager');

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String source = 'app.logger',
  }) {
    final sanitizedMessage = _sanitize(message);
    developer.log(
      sanitizedMessage,
      name: 'GitHubManager',
      error: error == null ? null : _sanitize(error.toString()),
      stackTrace: stackTrace,
      level: 1000,
    );
    unawaited(
      AppTelemetryService.instance.recordError(
        source: source,
        error: error == null ? sanitizedMessage : '$sanitizedMessage — $error',
        stackTrace: stackTrace,
      ),
    );
  }

  static String _sanitize(String value) {
    var output = value;
    for (final pattern in _sensitivePatterns) {
      output = output.replaceAllMapped(
        pattern,
        (match) => '${match.groupCount >= 1 ? match.group(1) ?? '' : ''}[REDACTED]',
      );
    }
    return output;
  }
}
