import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/features/repositories/domain/github_repository.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';

class RepositoryCard extends ConsumerWidget {
  const RepositoryCard({
    required this.repository,
    this.onTap,
    this.onMenu,
    this.onOpenExternal,
    this.onCopyLink,
    this.onFork,
    this.readOnly = false,
    super.key,
  });

  final GitHubRepository repository;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onCopyLink;
  final VoidCallback? onFork;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final info = readOnly ? null : ref.watch(repositoryProjectInfoProvider(repository));
    final projectName = info?.maybeWhen(
          data: (value) => value.projectName,
          orElse: () => repository.name,
        ) ??
        repository.name;
    final version = info?.maybeWhen(
      data: (value) => value.version,
      orElse: () => null,
    );
    final description = repository.description?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -.25,
                              color: scheme.onSurface,
                            ),
                        children: [
                          TextSpan(text: projectName),
                          if (version?.isNotEmpty == true)
                            TextSpan(
                              text: '  v$version',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (repository.isArchived)
                    const Padding(
                      padding: EdgeInsets.only(left: 7),
                      child: Icon(Icons.archive_outlined, size: 16),
                    ),
                  if (readOnly && onFork != null)
                    IconButton(
                      onPressed: onFork,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Criar fork',
                      icon: const Icon(Icons.call_split_rounded, size: 20),
                    ),
                  IconButton(
                    onPressed: onMenu,
                    visualDensity: VisualDensity.compact,
                    tooltip: readOnly
                        ? 'Remover dos acompanhados'
                        : 'Gerenciar repositório',
                    icon: const Icon(Icons.more_vert_rounded, size: 21),
                  ),
                ],
              ),
              if (description?.isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(
                  description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
