import 'dart:convert';

class RepositorySecret {
  const RepositorySecret({
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RepositorySecret.fromJson(Map<String, dynamic> json) => RepositorySecret(
        name: json['name'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );
}

enum SecretMutationKind { create, update }

class SecretImportItem {
  const SecretImportItem({
    required this.name,
    required this.value,
    required this.kind,
  });

  final String name;
  final String value;
  final SecretMutationKind kind;

  int get utf8Bytes => utf8.encode(value).length;
}

class SecretImportPlan {
  const SecretImportPlan({
    required this.items,
    required this.existingCount,
    required this.finalCount,
  });

  final List<SecretImportItem> items;
  final int existingCount;
  final int finalCount;

  int get total => items.length;
  int get createCount =>
      items.where((item) => item.kind == SecretMutationKind.create).length;
  int get updateCount => total - createCount;
}

class SecretWriteResult {
  const SecretWriteResult({
    required this.name,
    required this.kind,
    required this.success,
    required this.message,
    this.technicalCode,
    this.httpStatus,
    this.endpoint,
    this.apiMessage,
  });

  final String name;
  final SecretMutationKind kind;
  final bool success;
  final String message;
  final String? technicalCode;
  final int? httpStatus;
  final String? endpoint;
  final String? apiMessage;

  String get actionLabel => kind == SecretMutationKind.create ? 'criado' : 'atualizado';
}

class SecretBatchResult {
  const SecretBatchResult({required this.items});

  final List<SecretWriteResult> items;

  int get total => items.length;
  int get saved => items.where((item) => item.success).length;
  int get failed => total - saved;
  bool get allSucceeded => failed == 0;

  String diagnosticText({required String repositoryFullName, DateTime? generatedAt}) {
    final timestamp = (generatedAt ?? DateTime.now()).toIso8601String();
    final buffer = StringBuffer()
      ..writeln('GitHub Manager — diagnóstico de Secrets')
      ..writeln('Data/hora: $timestamp')
      ..writeln('Repositório: $repositoryFullName')
      ..writeln('Resultado: ${allSucceeded ? 'Concluído' : saved == 0 ? 'Falhou' : 'Parcial'}')
      ..writeln('Resumo: $saved salvos • $failed falharam • $total analisados')
      ..writeln('Valores: nunca incluídos neste diagnóstico')
      ..writeln()
      ..writeln('Itens:');

    for (final item in items) {
      buffer.write(item.success ? '- ✓ ' : '- ✕ ');
      buffer.write('${item.name} — ${item.message}');
      if (!item.success) {
        if (item.httpStatus != null) buffer.write(' • HTTP ${item.httpStatus}');
        if (item.technicalCode?.isNotEmpty == true) {
          buffer.write(' • ${item.technicalCode}');
        }
        if (item.endpoint?.isNotEmpty == true) {
          buffer.write(' • endpoint: ${item.endpoint}');
        }
        if (item.apiMessage?.isNotEmpty == true) {
          buffer.write(' • GitHub: ${item.apiMessage}');
        }
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
}
