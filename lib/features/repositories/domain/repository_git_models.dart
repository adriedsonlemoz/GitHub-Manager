class RepositoryContentItem {
  const RepositoryContentItem({
    required this.name,
    required this.path,
    required this.sha,
    required this.type,
    required this.size,
    this.downloadUrl,
    this.htmlUrl,
  });

  final String name;
  final String path;
  final String sha;
  final String type;
  final int size;
  final String? downloadUrl;
  final String? htmlUrl;

  bool get isDirectory => type == 'dir';
  bool get isFile => type == 'file';

  factory RepositoryContentItem.fromJson(Map<String, dynamic> json) =>
      RepositoryContentItem(
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        sha: json['sha'] as String? ?? '',
        type: json['type'] as String? ?? 'file',
        size: (json['size'] as num?)?.toInt() ?? 0,
        downloadUrl: json['download_url'] as String?,
        htmlUrl: json['html_url'] as String?,
      );
}

class RepositoryTextFile {
  const RepositoryTextFile({
    required this.name,
    required this.path,
    required this.sha,
    required this.content,
    required this.size,
  });

  final String name;
  final String path;
  final String sha;
  final String content;
  final int size;
}

class RepositoryBranch {
  const RepositoryBranch({
    required this.name,
    required this.sha,
    required this.isProtected,
  });

  final String name;
  final String sha;
  final bool isProtected;

  factory RepositoryBranch.fromJson(Map<String, dynamic> json) {
    final commit = json['commit'];
    return RepositoryBranch(
      name: json['name'] as String? ?? '',
      sha: commit is Map ? commit['sha'] as String? ?? '' : '',
      isProtected: json['protected'] as bool? ?? false,
    );
  }
}

class RepositoryCommit {
  const RepositoryCommit({
    required this.sha,
    required this.message,
    required this.author,
    required this.date,
    required this.htmlUrl,
  });

  final String sha;
  final String message;
  final String author;
  final DateTime? date;
  final String htmlUrl;

  String get shortSha => sha.length > 7 ? sha.substring(0, 7) : sha;

  factory RepositoryCommit.fromJson(Map<String, dynamic> json) {
    final commit = json['commit'];
    final commitMap = commit is Map<String, dynamic>
        ? commit
        : commit is Map
            ? Map<String, dynamic>.from(commit)
            : const <String, dynamic>{};
    final author = commitMap['author'];
    final authorMap = author is Map<String, dynamic>
        ? author
        : author is Map
            ? Map<String, dynamic>.from(author)
            : const <String, dynamic>{};
    return RepositoryCommit(
      sha: json['sha'] as String? ?? '',
      message: commitMap['message'] as String? ?? '',
      author: authorMap['name'] as String? ?? 'Autor desconhecido',
      date: DateTime.tryParse(authorMap['date'] as String? ?? ''),
      htmlUrl: json['html_url'] as String? ?? '',
    );
  }
}

class RepositoryWorkflow {
  const RepositoryWorkflow({
    required this.id,
    required this.name,
    required this.path,
    required this.state,
  });

  final int id;
  final String name;
  final String path;
  final String state;

  bool get isActive => state == 'active';

  factory RepositoryWorkflow.fromJson(Map<String, dynamic> json) =>
      RepositoryWorkflow(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Workflow',
        path: json['path'] as String? ?? '',
        state: json['state'] as String? ?? 'unknown',
      );
}

class RepositoryWorkflowRun {
  const RepositoryWorkflowRun({
    required this.id,
    required this.name,
    required this.title,
    required this.status,
    required this.conclusion,
    required this.branch,
    required this.runNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.htmlUrl,
  });

  final int id;
  final String name;
  final String title;
  final String status;
  final String? conclusion;
  final String branch;
  final int runNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String htmlUrl;

  bool get isRunning =>
      status == 'queued' || status == 'in_progress' || status == 'waiting';

  factory RepositoryWorkflowRun.fromJson(Map<String, dynamic> json) =>
      RepositoryWorkflowRun(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Workflow',
        title: json['display_title'] as String? ??
            json['name'] as String? ??
            'Execução',
        status: json['status'] as String? ?? 'unknown',
        conclusion: json['conclusion'] as String?,
        branch: json['head_branch'] as String? ?? '-',
        runNumber: (json['run_number'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
        htmlUrl: json['html_url'] as String? ?? '',
      );
}

class RepositoryWorkflowJob {
  const RepositoryWorkflowJob({
    required this.id,
    required this.name,
    required this.status,
    required this.conclusion,
    required this.steps,
  });

  final int id;
  final String name;
  final String status;
  final String? conclusion;
  final List<RepositoryWorkflowStep> steps;

  factory RepositoryWorkflowJob.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    return RepositoryWorkflowJob(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Job',
      status: json['status'] as String? ?? 'unknown',
      conclusion: json['conclusion'] as String?,
      steps: rawSteps is List
          ? rawSteps
              .whereType<Map>()
              .map(
                (step) => RepositoryWorkflowStep.fromJson(
                  Map<String, dynamic>.from(step),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class RepositoryWorkflowStep {
  const RepositoryWorkflowStep({
    required this.name,
    required this.status,
    required this.conclusion,
    required this.number,
  });

  final String name;
  final String status;
  final String? conclusion;
  final int number;

  factory RepositoryWorkflowStep.fromJson(Map<String, dynamic> json) =>
      RepositoryWorkflowStep(
        name: json['name'] as String? ?? 'Etapa',
        status: json['status'] as String? ?? 'unknown',
        conclusion: json['conclusion'] as String?,
        number: (json['number'] as num?)?.toInt() ?? 0,
      );
}
