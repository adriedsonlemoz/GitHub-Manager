abstract class AppException implements Exception {
  const AppException(
    this.message, {
    this.technicalCode,
    this.httpStatus,
    this.endpoint,
    this.apiMessage,
  });

  final String message;
  final String? technicalCode;
  final int? httpStatus;
  final String? endpoint;
  final String? apiMessage;

  @override
  String toString() => '$runtimeType($message)';
}

final class AuthenticationRequiredException extends AppException {
  // ignore: use_super_parameters
  const AuthenticationRequiredException({
    int? httpStatus,
    String? endpoint,
    String? apiMessage,
  }) : super(
          'Conecte sua conta GitHub para continuar.',
          technicalCode: 'AUTH_REQUIRED',
          httpStatus: httpStatus,
          endpoint: endpoint,
          apiMessage: apiMessage,
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
  // ignore: use_super_parameters
  const GitHubRateLimitException({
    int? httpStatus,
    String? endpoint,
    String? apiMessage,
  }) : super(
          'O limite temporário da API do GitHub foi atingido. Tente novamente mais tarde.',
          technicalCode: 'GITHUB_RATE_LIMIT',
          httpStatus: httpStatus,
          endpoint: endpoint,
          apiMessage: apiMessage,
        );
}

final class GitHubPermissionException extends AppException {
  // ignore: use_super_parameters
  const GitHubPermissionException({
    int? httpStatus,
    String? endpoint,
    String? apiMessage,
  }) : super(
          'Seu token não tem permissão para realizar esta operação.',
          technicalCode: 'GITHUB_PERMISSION',
          httpStatus: httpStatus,
          endpoint: endpoint,
          apiMessage: apiMessage,
        );
}

final class GitHubNotFoundException extends AppException {
  // ignore: use_super_parameters
  const GitHubNotFoundException({
    int? httpStatus,
    String? endpoint,
    String? apiMessage,
  }) : super(
          'O recurso solicitado não foi encontrado ou não está acessível.',
          technicalCode: 'GITHUB_NOT_FOUND',
          httpStatus: httpStatus,
          endpoint: endpoint,
          apiMessage: apiMessage,
        );
}

final class GitHubConflictException extends AppException {
  // ignore: use_super_parameters
  const GitHubConflictException({
    int? httpStatus,
    String? endpoint,
    String? apiMessage,
  }) : super(
          'O GitHub encontrou um conflito. Atualize os dados e tente novamente.',
          technicalCode: 'GITHUB_CONFLICT',
          httpStatus: httpStatus,
          endpoint: endpoint,
          apiMessage: apiMessage,
        );
}

final class GitHubValidationException extends AppException {
  // ignore: use_super_parameters
  const GitHubValidationException({
    int? httpStatus,
    String? endpoint,
    String? apiMessage,
  }) : super(
          'O GitHub rejeitou os dados enviados. Confira nome, branch e permissões do token.',
          technicalCode: 'GITHUB_VALIDATION',
          httpStatus: httpStatus,
          endpoint: endpoint,
          apiMessage: apiMessage,
        );
}

final class GitHubSecretOperationException extends AppException {
  const GitHubSecretOperationException(
    super.message, {
    super.technicalCode,
    super.httpStatus,
    super.endpoint,
    super.apiMessage,
  });
}

final class DownloadFailureException extends AppException {
  // ignore: use_super_parameters
  const DownloadFailureException(
    String message, {
    required String code,
    required String endpoint,
    required this.stage,
    int? httpStatus,
    String? apiMessage,
  }) : super(
          message,
          technicalCode: code,
          endpoint: endpoint,
          httpStatus: httpStatus,
          apiMessage: apiMessage,
        );

  final String stage;
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
