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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final info = readOnly ? null : ref.watch(repositoryProjectInfoProvider(repository));
    final projectName = info?.maybeWhen(
          data: (value) => value.projectName,
          orElse: () => repository.name,
        ) ??
        repository.name;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? const [Color(0xFF3337CC), Color(0xFF252A8E)]
                        : [scheme.primary, scheme.primaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF555CFF)
                        : scheme.primary.withValues(alpha: .30),
                  ),
                ),
                child: Icon(
                  repository.isPrivate
                      ? Icons.lock_outline_rounded
                      : Icons.code_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -.25,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: scheme.tertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (repository.isArchived)
                      const Padding(
                        padding: EdgeInsets.only(left: 7),
                        child: Icon(Icons.archive_outlined, size: 16),
                      ),
                  ],
                ),
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
              const Icon(Icons.chevron_right_rounded, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}
