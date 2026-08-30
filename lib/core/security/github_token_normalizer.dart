String normalizeGitHubToken(String rawToken) {
  var token = rawToken.trim();
  if (token.isEmpty) {
    return '';
  }

  // Remove caracteres invisíveis comuns de copiar/colar.
  token = token.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

  // Aceita colagens como `ghp_...`, "github_pat_..." ou 'ghp_...'.
  if (token.length >= 2) {
    final first = token[0];
    final last = token[token.length - 1];
    final paired = (first == '`' && last == '`') ||
        (first == '"' && last == '"') ||
        (first == "'" && last == "'");
    if (paired) {
      token = token.substring(1, token.length - 1).trim();
    }
  }

  // Também aceita um valor colado a partir de um cabeçalho HTTP.
  token = token.replaceFirst(
    RegExp(
      r'^(?:authorization\s*:\s*)?(?:bearer|token)\s+',
      caseSensitive: false,
    ),
    '',
  );

  // PATs do GitHub não contêm whitespace; quebras acidentais do clipboard
  // podem ser removidas sem alterar um token válido.
  token = token.replaceAll(RegExp(r'\s+'), '');
  return token;
}
