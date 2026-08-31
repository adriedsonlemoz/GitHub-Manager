class RepositoryNameRules {
  RepositoryNameRules._();

  static const int maxLength = 100;
  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9._-]+$');

  static String normalize(String value) => value.trim();

  static String? validate(String value) {
    final name = normalize(value);
    if (name.isEmpty) return 'Informe o novo nome do repositório.';
    if (name.length > maxLength) {
      return 'O nome pode ter no máximo $maxLength caracteres.';
    }
    if (name == '.' || name == '..') {
      return 'Escolha um nome diferente de . ou ..';
    }
    if (name.contains('/')) {
      return 'Informe apenas o nome, sem owner/ ou barras.';
    }
    if (RegExp(r'\s').hasMatch(name)) {
      return 'O nome do repositório não pode conter espaços.';
    }
    if (!_allowed.hasMatch(name)) {
      return 'Use apenas letras, números, ponto, hífen ou sublinhado.';
    }
    return null;
  }

  static bool isChanged(String currentName, String candidate) =>
      normalize(candidate) != currentName;
}
