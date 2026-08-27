import 'dart:developer' as developer;

abstract final class AppLogger {
  static final _sensitivePatterns = <RegExp>[
    RegExp(r'(authorization\s*:\s*bearer\s+)[^\s,}]+', caseSensitive: false),
    RegExp(r'((token|api[_-]?key|password|secret)\s*[=:]\s*)[^\s,}]+', caseSensitive: false),
  ];

  static void info(String message) => developer.log(_sanitize(message), name: 'GitHubManager');

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      _sanitize(message),
      name: 'GitHubManager',
      error: error == null ? null : _sanitize(error.toString()),
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  static String _sanitize(String value) {
    var output = value;
    for (final pattern in _sensitivePatterns) {
      output = output.replaceAllMapped(
        pattern,
        (match) => '${match.group(1) ?? ''}[REDACTED]',
      );
    }
    return output;
  }
}
