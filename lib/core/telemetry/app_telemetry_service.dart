import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:github_manager/core/persistence/local_database.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:path_provider/path_provider.dart';

class AppTelemetryEvent {
  const AppTelemetryEvent({
    required this.id,
    required this.source,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.stackTrace,
    this.context = const {},
  });

  final int id;
  final String source;
  final String severity;
  final String message;
  final String? stackTrace;
  final DateTime createdAt;
  final Map<String, Object?> context;

  bool get fatal => severity == 'fatal';

  factory AppTelemetryEvent.fromRow(Map<String, Object?> row) {
    final rawContext = row['context_json']?.toString();
    Map<String, Object?> context = const {};
    if (rawContext != null && rawContext.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawContext);
        if (decoded is Map) {
          context = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } catch (_) {
        context = const {};
      }
    }

    return AppTelemetryEvent(
      id: (row['id'] as num?)?.toInt() ?? 0,
      source: row['source']?.toString() ?? 'desconhecido',
      severity: row['severity']?.toString() ?? 'error',
      message: row['message']?.toString() ?? 'Erro sem mensagem',
      stackTrace: row['stack_trace']?.toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num?)?.toInt() ?? 0,
      ),
      context: context,
    );
  }
}

/// Captura local de falhas do GitHub Manager.
///
/// Nada é enviado automaticamente para servidores externos. Os registros ficam
/// no SQLite privado do app e só saem do aparelho se a pessoa copiar/exportar o
/// relatório manualmente pela tela de Configurações.
class AppTelemetryService {
  AppTelemetryService._();

  static final AppTelemetryService instance = AppTelemetryService._();

  static const _enabledKey = 'telemetry.local_error_capture.enabled';
  static const _maxMessageLength = 4000;
  static const _maxStackLength = 16000;

  final LocalDatabase _database = LocalDatabase.shared;
  bool? _enabledCache;

  static final _sensitivePatterns = <RegExp>[
    RegExp(r'(authorization\s*:\s*bearer\s+)[^\s,}]+', caseSensitive: false),
    RegExp(
      r'((token|api[_-]?key|password|secret)\s*[=:]\s*)[^\s,}]+',
      caseSensitive: false,
    ),
    RegExp(r'github_pat_[A-Za-z0-9_]+'),
    RegExp(r'gh[pousr]_[A-Za-z0-9]+'),
  ];

  Future<bool> isEnabled() async {
    final cached = _enabledCache;
    if (cached != null) return cached;
    try {
      final raw = await _database.readJson(_enabledKey);
      final enabled = raw is bool ? raw : true;
      _enabledCache = enabled;
      return enabled;
    } catch (_) {
      // Se a preferência não puder ser lida, prioriza capturar a falha local.
      return true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    await _database.putJson(_enabledKey, enabled);
    _enabledCache = enabled;
  }

  Future<void> recordError({
    required String source,
    required Object error,
    StackTrace? stackTrace,
    bool fatal = false,
    Map<String, Object?> context = const {},
  }) async {
    try {
      if (!await isEnabled()) return;
      await _database.insertErrorTelemetry(
        source: _sanitize(source, 160),
        severity: fatal ? 'fatal' : 'error',
        message: _sanitize(error.toString(), _maxMessageLength),
        stackTrace: stackTrace == null
            ? null
            : _sanitize(stackTrace.toString(), _maxStackLength),
        context: _sanitizeContext(context),
      );
    } catch (telemetryError, telemetryStack) {
      // A própria telemetria jamais pode derrubar o aplicativo.
      debugPrint('Falha ao registrar telemetria: $telemetryError');
      debugPrintStack(stackTrace: telemetryStack);
    }
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) => recordError(
        source: 'flutter.framework',
        error: details.exception,
        stackTrace: details.stack,
        fatal: false,
        context: {
          if (details.library != null) 'library': details.library,
          if (details.context != null) 'context': details.context.toString(),
          'silent': details.silent,
        },
      );

  Future<void> importPendingNativeCrash() async {
    try {
      final raw = await PlatformActions.consumeNativeCrashReport();
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      final message = map['message']?.toString().trim();
      final type = map['type']?.toString().trim();
      final stack = map['stackTrace']?.toString();
      final context = <String, Object?>{
        'thread': map['thread']?.toString(),
        'androidSdk': map['androidSdk'],
        'device': map['device']?.toString(),
        'appVersion': map['appVersion']?.toString(),
        'versionCode': map['versionCode'],
      }..removeWhere((_, value) => value == null || value == '');

      final summary = [
        if (type?.isNotEmpty == true) type,
        if (message?.isNotEmpty == true) message,
      ].whereType<String>().join(': ');
      await recordError(
        source: 'android.native',
        error: summary.isEmpty ? 'Crash nativo sem mensagem' : summary,
        stackTrace: stack == null ? null : StackTrace.fromString(stack),
        fatal: true,
        context: context,
      );
    } catch (error, stackTrace) {
      debugPrint('Falha ao importar crash nativo: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<AppTelemetryEvent>> readEvents({int limit = 100}) async {
    final rows = await _database.readErrorTelemetry(limit: limit);
    return rows.map(AppTelemetryEvent.fromRow).toList(growable: false);
  }

  Future<void> clear() => _database.clearErrorTelemetry();

  Future<String> buildReport({int limit = 100}) async {
    final events = await readEvents(limit: limit);
    final buffer = StringBuffer()
      ..writeln('GitHub Manager — relatório local de erros')
      ..writeln('Gerado em: ${DateTime.now().toIso8601String()}')
      ..writeln('Registros: ${events.length}')
      ..writeln('Observação: tokens, senhas e chaves conhecidas são ocultados automaticamente.')
      ..writeln();

    for (final event in events) {
      buffer
        ..writeln('------------------------------------------------------------')
        ..writeln('${event.createdAt.toIso8601String()} | ${event.severity.toUpperCase()} | ${event.source}')
        ..writeln(event.message);
      if (event.context.isNotEmpty) {
        buffer.writeln('Contexto: ${jsonEncode(event.context)}');
      }
      final stack = event.stackTrace?.trim();
      if (stack?.isNotEmpty == true) {
        buffer
          ..writeln('Stack trace:')
          ..writeln(stack);
      }
    }
    return buffer.toString();
  }

  Future<String> exportReportToDownloads({int limit = 100}) async {
    final report = await buildReport(limit: limit);
    final tempDir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final fileName = 'GitHub-Manager-telemetria-$stamp.txt';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(report, flush: true);
    return PlatformActions.publishToDownloads(
      sourcePath: file.path,
      fileName: fileName,
      mimeType: 'text/plain',
      relativeFolder: 'GitHub Manager',
    );
  }

  String _sanitize(String value, int maxLength) {
    var output = value;
    for (final pattern in _sensitivePatterns) {
      output = output.replaceAllMapped(pattern, (match) {
        final prefix = match.groupCount >= 1 ? match.group(1) : null;
        return '${prefix ?? ''}[REDACTED]';
      });
    }
    if (output.length > maxLength) {
      output = '${output.substring(0, maxLength)}\n…[truncado]';
    }
    return output;
  }

  Map<String, Object?> _sanitizeContext(Map<String, Object?> context) {
    final output = <String, Object?>{};
    for (final entry in context.entries) {
      final key = _sanitize(entry.key, 80);
      final value = entry.value;
      if (value == null || value is num || value is bool) {
        output[key] = value;
      } else {
        output[key] = _sanitize(value.toString(), 1000);
      }
    }
    return output;
  }
}
