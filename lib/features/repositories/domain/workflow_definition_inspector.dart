class WorkflowDefinitionInfo {
  const WorkflowDefinitionInfo({
    required this.supportsDispatch,
    required this.likelyBuildsApk,
    required this.declaredName,
  });

  final bool supportsDispatch;
  final bool likelyBuildsApk;
  final String declaredName;
}

class WorkflowDefinitionInspector {
  const WorkflowDefinitionInspector._();

  static WorkflowDefinitionInfo inspect(String content) {
    final lines = _meaningfulLines(content);
    final declaredName = _topLevelScalar(lines, 'name') ?? '';
    final supportsDispatch = _hasWorkflowDispatch(lines);
    final jobsText = _sectionText(lines, 'jobs').toLowerCase();

    final likelyBuildsApk = jobsText.contains('.apk') ||
        jobsText.contains('flutter build apk') ||
        RegExp(r'\bgradlew(?:\.bat)?\b[^\n]*(?:assemble|install)[a-z0-9_-]*')
            .hasMatch(jobsText) ||
        RegExp(r'\bassemble(?:debug|release|[a-z0-9_-]*apk)\b')
            .hasMatch(jobsText) ||
        (jobsText.contains('upload-artifact') && jobsText.contains('apk'));

    return WorkflowDefinitionInfo(
      supportsDispatch: supportsDispatch,
      likelyBuildsApk: likelyBuildsApk,
      declaredName: declaredName,
    );
  }

  static bool _hasWorkflowDispatch(List<_YamlLine> lines) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.indent != 0 || _key(line.text) != 'on') continue;

      final inline = _value(line.text).toLowerCase();
      if (RegExp(r'\bworkflow_dispatch\b').hasMatch(inline)) {
        return true;
      }

      for (var j = i + 1; j < lines.length; j++) {
        final child = lines[j];
        if (child.indent <= line.indent) break;
        if (_key(child.text) == 'workflow_dispatch') return true;
      }
    }
    return false;
  }

  static String _sectionText(List<_YamlLine> lines, String key) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.indent != 0 || _key(line.text) != key) continue;
      final buffer = StringBuffer();
      final inline = _value(line.text);
      if (inline.isNotEmpty) buffer.writeln(inline);
      for (var j = i + 1; j < lines.length; j++) {
        final child = lines[j];
        if (child.indent <= line.indent) break;
        buffer.writeln(child.text);
      }
      return buffer.toString();
    }
    return '';
  }

  static String? _topLevelScalar(List<_YamlLine> lines, String key) {
    for (final line in lines) {
      if (line.indent == 0 && _key(line.text) == key) {
        final value = _value(line.text).trim();
        if (value.isEmpty) return null;
        return value.replaceAll(RegExp(r'''^["']|["']$'''), '').trim();
      }
    }
    return null;
  }

  static List<_YamlLine> _meaningfulLines(String content) {
    final result = <_YamlLine>[];
    for (final raw in content.replaceAll('\r\n', '\n').split('\n')) {
      final withoutComment = _stripComment(raw);
      if (withoutComment.trim().isEmpty) continue;
      final spaces = withoutComment.length - withoutComment.trimLeft().length;
      result.add(_YamlLine(spaces, withoutComment.trim()));
    }
    return result;
  }

  static String _stripComment(String line) {
    var single = false;
    var double = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == "'" && !double) single = !single;
      if (char == '"' && !single && (i == 0 || line[i - 1] != '\\')) {
        double = !double;
      }
      if (char == '#' && !single && !double) {
        return line.substring(0, i);
      }
    }
    return line;
  }

  static String _key(String text) {
    final index = text.indexOf(':');
    if (index < 0) return '';
    return text
        .substring(0, index)
        .trim()
        .replaceAll(RegExp(r'''^["']|["']$'''), '')
        .toLowerCase();
  }

  static String _value(String text) {
    final index = text.indexOf(':');
    return index < 0 ? '' : text.substring(index + 1).trim();
  }
}

class _YamlLine {
  const _YamlLine(this.indent, this.text);

  final int indent;
  final String text;
}
