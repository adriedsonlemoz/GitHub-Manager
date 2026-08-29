import 'package:flutter/material.dart';

class CodeHighlightingController extends TextEditingController {
  CodeHighlightingController({this.fileName = '', super.text});

  String fileName;
  Brightness _brightness = Brightness.light;

  void setFileName(String value) {
    if (fileName == value) {
      return;
    }
    fileName = value;
    notifyListeners();
  }

  void setBrightness(Brightness value) {
    if (_brightness == value) {
      return;
    }
    _brightness = value;
  }

  String get languageLabel {
    final extension = _extension;
    return switch (extension) {
      'html' || 'htm' => 'HTML',
      'css' => 'CSS',
      'js' || 'mjs' || 'cjs' => 'JavaScript',
      'json' => 'JSON',
      'xml' => 'XML',
      'yaml' || 'yml' => 'YAML',
      'dart' => 'Dart',
      'kt' || 'kts' => 'Kotlin',
      _ => extension.isEmpty ? 'Texto' : extension.toUpperCase(),
    };
  }

  String get _extension {
    final clean = fileName.split('/').last.toLowerCase();
    final index = clean.lastIndexOf('.');
    return index < 0 ? '' : clean.substring(index + 1);
  }

  bool get _hashComments => const {'yaml', 'yml'}.contains(_extension);
  bool get _slashComments =>
      const {'css', 'js', 'mjs', 'cjs', 'dart', 'kt', 'kts'}.contains(_extension);
  bool get _xmlComments => const {'html', 'htm', 'xml'}.contains(_extension);

  Set<String> get _keywords => switch (_extension) {
        'dart' => _dartKeywords,
        'kt' || 'kts' => _kotlinKeywords,
        'js' || 'mjs' || 'cjs' => _javascriptKeywords,
        'css' => _cssKeywords,
        'json' => _jsonKeywords,
        'yaml' || 'yml' => _yamlKeywords,
        'html' || 'htm' || 'xml' => _xmlKeywords,
        _ => const <String>{},
      };

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    return TextSpan(style: base, children: _scan(text, base));
  }

  List<InlineSpan> _scan(String source, TextStyle base) {
    final keywords = _keywords;
    // Texto puro (.md, .txt etc.) não precisa ser quebrado caractere por
    // caractere. Esse era o motivo de alguns Markdown travarem a interface.
    // Arquivos grandes de código também desativam realce para manter o editor
    // responsivo no celular.
    if (source.length > 60000 ||
        (keywords.isEmpty && !_hashComments && !_slashComments && !_xmlComments)) {
      return <InlineSpan>[TextSpan(text: source, style: base)];
    }
    final result = <InlineSpan>[];
    var index = 0;
    while (index < source.length) {
      if (_xmlComments && source.startsWith('<!--', index)) {
        final end = source.indexOf('-->', index + 4);
        final stop = end < 0 ? source.length : end + 3;
        result.add(_span(source.substring(index, stop), base, _commentColor));
        index = stop;
        continue;
      }
      if (_slashComments && source.startsWith('//', index)) {
        final end = source.indexOf('\n', index);
        final stop = end < 0 ? source.length : end;
        result.add(_span(source.substring(index, stop), base, _commentColor));
        index = stop;
        continue;
      }
      if (_slashComments && source.startsWith('/*', index)) {
        final end = source.indexOf('*/', index + 2);
        final stop = end < 0 ? source.length : end + 2;
        result.add(_span(source.substring(index, stop), base, _commentColor));
        index = stop;
        continue;
      }
      if (_hashComments && source[index] == '#') {
        final end = source.indexOf('\n', index);
        final stop = end < 0 ? source.length : end;
        result.add(_span(source.substring(index, stop), base, _commentColor));
        index = stop;
        continue;
      }

      final char = source[index];
      if (char == '"' || char == "'" || (char == '`' && _extension.contains('js'))) {
        var stop = index + 1;
        var escaped = false;
        while (stop < source.length) {
          final current = source[stop];
          if (!escaped && current == char) {
            stop++;
            break;
          }
          if (current == '\\' && !escaped) {
            escaped = true;
          } else {
            escaped = false;
          }
          stop++;
        }
        result.add(_span(source.substring(index, stop), base, _stringColor));
        index = stop;
        continue;
      }

      if (_isDigit(char)) {
        var stop = index + 1;
        while (stop < source.length &&
            (_isDigit(source[stop]) || '.xabcdefABCDEF'.contains(source[stop]))) {
          stop++;
        }
        result.add(_span(source.substring(index, stop), base, _numberColor));
        index = stop;
        continue;
      }

      if (_isWordStart(char)) {
        var stop = index + 1;
        while (stop < source.length && _isWordPart(source[stop])) {
          stop++;
        }
        final word = source.substring(index, stop);
        final lower = word.toLowerCase();
        result.add(
          keywords.contains(word) || keywords.contains(lower)
              ? _span(word, base, _keywordColor, fontWeight: FontWeight.w600)
              : TextSpan(text: word, style: base),
        );
        index = stop;
        continue;
      }

      if (_xmlComments && (char == '<' || char == '>' || char == '/' || char == '=')) {
        result.add(_span(char, base, _keywordColor));
      } else if ('{}[]():;,'.contains(char)) {
        result.add(_span(char, base, _punctuationColor));
      } else {
        result.add(TextSpan(text: char, style: base));
      }
      index++;
    }
    return result;
  }

  TextSpan _span(
    String text,
    TextStyle base,
    Color color, {
    FontWeight? fontWeight,
  }) =>
      TextSpan(
        text: text,
        style: base.copyWith(color: color, fontWeight: fontWeight),
      );

  bool _isDigit(String value) {
    final code = value.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _isWordStart(String value) {
    final code = value.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        value == '_' ||
        value == r'$';
  }

  bool _isWordPart(String value) => _isWordStart(value) || _isDigit(value) || value == '-';

  Color get _keywordColor => _brightness == Brightness.dark
      ? const Color(0xFF9CC7FF)
      : const Color(0xFF0759A6);
  Color get _stringColor => _brightness == Brightness.dark
      ? const Color(0xFFC3E88D)
      : const Color(0xFF287A27);
  Color get _commentColor => _brightness == Brightness.dark
      ? const Color(0xFF92A1A8)
      : const Color(0xFF69777D);
  Color get _numberColor => _brightness == Brightness.dark
      ? const Color(0xFFFFCB6B)
      : const Color(0xFF9B4A00);
  Color get _punctuationColor => _brightness == Brightness.dark
      ? const Color(0xFFC792EA)
      : const Color(0xFF6D35A8);

  static const _dartKeywords = <String>{
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
    'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
    'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
    'factory', 'false', 'final', 'finally', 'for', 'function', 'get', 'hide',
    'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
    'mixin', 'new', 'null', 'of', 'on', 'operator', 'part', 'required', 'rethrow',
    'return', 'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync',
    'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'when', 'while',
    'with', 'yield',
  };
  static const _kotlinKeywords = <String>{
    'as', 'break', 'class', 'continue', 'do', 'else', 'false', 'for', 'fun',
    'if', 'in', 'interface', 'is', 'null', 'object', 'package', 'return', 'super',
    'this', 'throw', 'true', 'try', 'typealias', 'typeof', 'val', 'var', 'when',
    'while', 'by', 'catch', 'constructor', 'delegate', 'dynamic', 'field', 'file',
    'finally', 'get', 'import', 'init', 'param', 'property', 'receiver', 'set',
    'setparam', 'where', 'actual', 'abstract', 'annotation', 'companion', 'const',
    'crossinline', 'data', 'enum', 'expect', 'external', 'final', 'infix', 'inline',
    'inner', 'internal', 'lateinit', 'noinline', 'open', 'operator', 'out',
    'override', 'private', 'protected', 'public', 'reified', 'sealed', 'suspend',
    'tailrec', 'vararg',
  };
  static const _javascriptKeywords = <String>{
    'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
    'default', 'delete', 'do', 'else', 'export', 'extends', 'false', 'finally',
    'for', 'function', 'if', 'import', 'in', 'instanceof', 'let', 'new', 'null',
    'return', 'static', 'super', 'switch', 'this', 'throw', 'true', 'try',
    'typeof', 'var', 'void', 'while', 'with', 'yield', 'async',
  };
  static const _jsonKeywords = <String>{'true', 'false', 'null'};
  static const _yamlKeywords = <String>{'true', 'false', 'null', 'yes', 'no', 'on', 'off'};
  static const _cssKeywords = <String>{
    'important', 'inherit', 'initial', 'unset', 'auto', 'none', 'block', 'flex',
    'grid', 'relative', 'absolute', 'fixed', 'sticky',
  };
  static const _xmlKeywords = <String>{
    'xml', 'html', 'head', 'body', 'div', 'span', 'script', 'style', 'manifest',
    'application', 'activity', 'uses-permission',
  };
}
