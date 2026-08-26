sealed class AppException implements Exception {
  const AppException(this.message, {this.technicalCode});
  final String message;
  final String? technicalCode;
  @override
  String toString() => '$runtimeType($message)';
}

final class AuthenticationRequiredException extends AppException {
  const AuthenticationRequiredException()
      : super(
          'Conecte sua conta GitHub para continuar.',
          technicalCode: 'AUTH_REQUIRED',
        );
}

final class NetworkRequiredException extends AppException {
  const NetworkRequiredException()
      : super(
          'Conexão com a internet necessária para esta operação.',
          technicalCode: 'NETWORK_REQUIRED',
        );
}

final class GitHubRateLimitException extends AppException {
  const GitHubRateLimitException()
      : super(
          'O limite temporário da API do GitHub foi atingido. Tente novamente mais tarde.',
          technicalCode: 'GITHUB_RATE_LIMIT',
        );
}

final class GitHubPermissionException extends AppException {
  const GitHubPermissionException()
      : super(
          'Seu token não tem permissão para realizar esta operação.',
          technicalCode: 'GITHUB_PERMISSION',
        );
}

final class GitHubNotFoundException extends AppException {
  const GitHubNotFoundException()
      : super(
          'O recurso solicitado não foi encontrado ou não está acessível.',
          technicalCode: 'GITHUB_NOT_FOUND',
        );
}

final class GitHubConflictException extends AppException {
  const GitHubConflictException()
      : super(
          'O GitHub encontrou um conflito. Atualize os dados e tente novamente.',
          technicalCode: 'GITHUB_CONFLICT',
        );
}

final class GitHubValidationException extends AppException {
  const GitHubValidationException()
      : super(
          'O GitHub rejeitou os dados enviados. Confira nome, branch e permissões do token.',
          technicalCode: 'GITHUB_VALIDATION',
        );
}

final class InvalidZipException extends AppException {
  // A mensagem e o código têm nomes públicos diferentes de AppException.
  // ignore: use_super_parameters
  const InvalidZipException(String message, {String code = 'INVALID_ZIP'})
      : super(message, technicalCode: code);
}


final class RepositoryFileException extends AppException {
  // ignore: use_super_parameters
  const RepositoryFileException(String message, {String code = 'REPOSITORY_FILE'})
      : super(message, technicalCode: code);
}

final class UnexpectedAppException extends AppException {
  const UnexpectedAppException([String? details])
      : super(
          'Não foi possível concluir a operação.',
          technicalCode: details ?? 'UNEXPECTED',
        );
}
