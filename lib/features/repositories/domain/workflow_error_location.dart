/// Localização extraída de annotations ou de erros de compiladores conhecidos.
/// Uma linha genérica de log nunca é considerada localização confirmada.
class WorkflowErrorLocation {
  const WorkflowErrorLocation({
    required this.path,
    this.line,
    required this.source,
  });

  final String path;
  final int? line;
  final String source;

  bool get confirmed => source == 'GitHub annotation';

  /// Caminhos externos ao repositório ou absolutos nunca viram links no GitHub.
  bool get canOpenRepositoryFile =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.startsWith('\\') &&
      !RegExp(r'^[A-Za-z]:').hasMatch(path) &&
      !path.split('/').contains('..') &&
      !path.contains('://');

  static WorkflowErrorLocation? fromAnnotation(Map<dynamic, dynamic> raw) {
    final value = raw['path']?.toString().trim().replaceAll('\\', '/');
    if (value == null || value.isEmpty) return null;
    final number = raw['start_line'];
    final line = number is num ? number.toInt() : int.tryParse('$number');
    return WorkflowErrorLocation(
      path: value,
      line: line != null && line > 0 ? line : null,
      source: 'GitHub annotation',
    );
  }

  static WorkflowErrorLocation? fromLogLine(String text) {
    final line = text.trim();
    final patterns = <RegExp>[
      // Dart, Java, Gradle e compiladores que usam arquivo:linha:coluna.
      RegExp(r'((?:[A-Za-z]:)?[^\s:]+\.(?:dart|kt|kts|java|xml|gradle|py|rs|js|ts|tsx|jsx|yaml|yml|json)):(\d+)(?::\d+)?'),
      // Erros Kotlin no formato: e: /pasta/Arquivo.kt: (42, 9)
      RegExp(r'((?:[A-Za-z]:)?[^\s:]+\.(?:kt|kts|java)):\s*\((\d+),\s*\d+\)'),
      // Python traceback: File "src/main.py", line 38.
      RegExp(r'''File ["']([^"']+\.py)["'], line (\d+)'''),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      var path = match.group(1)!.replaceAll('\\', '/');
      if (path.startsWith('file:///')) path = path.substring(8);
      if (path.startsWith('./')) path = path.substring(2);
      final number = int.tryParse(match.group(2)!);
      if (path.isNotEmpty && number != null && number > 0) {
        return WorkflowErrorLocation(path: path, line: number, source: 'Linha do log');
      }
    }
    return null;
  }

  /// URL do arquivo no commit da execução, jamais na branch atual.
  String? githubUrl(String repository, String commit) {
    if (!canOpenRepositoryFile ||
        !RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(repository) ||
        !RegExp(r'^[a-fA-F0-9]{7,40}$').hasMatch(commit)) {
      return null;
    }
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    return 'https://github.com/$repository/blob/$commit/$encoded'
        '${line == null ? '' : '#L$line'}';
  }
}
