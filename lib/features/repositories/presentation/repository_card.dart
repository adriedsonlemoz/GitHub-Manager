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
    final version = info?.maybeWhen(
      data: (value) => value.version,
      orElse: () => null,
    );
    final technologies = info?.maybeWhen(
          data: (value) => value.technologies,
          orElse: () => [if (repository.language != null) repository.language!],
        ) ??
        [if (repository.language != null) repository.language!];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: dark
                            ? const [Color(0xFF3337CC), Color(0xFF252A8E)]
                            : [scheme.primary, scheme.primaryContainer],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: dark ? const Color(0xFF555CFF) : scheme.primary.withValues(alpha: .3),
                      ),
                    ),
                    child: Icon(
                      repository.isPrivate ? Icons.lock_outline_rounded : Icons.code_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                projectName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      letterSpacing: -.35,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: scheme.tertiary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.tertiary.withValues(alpha: .3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            if (repository.isArchived)
                              const Padding(
                                padding: EdgeInsets.only(left: 7),
                                child: Icon(Icons.archive_outlined, size: 17),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          repository.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onMenu,
                    visualDensity: VisualDensity.compact,
                    tooltip: readOnly ? 'Remover dos acompanhados' : 'Gerenciar repositório',
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                ],
              ),
              if (repository.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 13),
                Text(
                  repository.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (version?.isNotEmpty == true)
                    _InfoPill(icon: Icons.sell_outlined, text: 'v$version'),
                  _InfoPill(icon: Icons.account_tree_outlined, text: repository.defaultBranch),
                  ...technologies.take(4).map(
                        (technology) => _InfoPill(
                          icon: _technologyIcon(technology),
                          text: technology,
                        ),
                      ),
                  _InfoPill(
                    icon: repository.isPrivate ? Icons.lock_outline_rounded : Icons.public_rounded,
                    text: repository.isPrivate ? 'Privado' : 'Público',
                  ),
                  _InfoPill(icon: Icons.schedule_rounded, text: _formatDate(repository.updatedAt)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _PrimaryActionButton(
                      onPressed: onOpenExternal,
                      icon: Icons.open_in_new_rounded,
                      label: 'GitHub',
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _SecondaryActionButton(
                      onPressed: onCopyLink,
                      icon: Icons.copy_all_rounded,
                      label: 'Copiar link',
                    ),
                  ),
                  if (readOnly && onFork != null) ...[
                    const SizedBox(width: 9),
                    _SecondaryIconButton(
                      onPressed: onFork,
                      icon: Icons.call_split_rounded,
                      tooltip: 'Criar fork',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _technologyIcon(String technology) {
    final value = technology.toLowerCase();
    if (value.contains('flutter')) return Icons.flutter_dash_rounded;
    if (value.contains('android')) return Icons.android_rounded;
    if (value.contains('dart')) return Icons.code_rounded;
    if (value.contains('python')) return Icons.settings_suggest_outlined;
    if (value.contains('java')) return Icons.coffee_outlined;
    if (value.contains('javascript') || value.contains('typescript') || value.contains('node')) {
      return Icons.javascript_rounded;
    }
    return Icons.memory_rounded;
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)} ${two(date.hour)}:${two(date.minute)}';
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.onPressed, required this.icon, required this.label});
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF5A4FF3), Color(0xFF3936D7)]),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4B46E5).withValues(alpha: .22),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
          ),
          icon: Icon(icon, size: 19),
          label: Text(label),
        ),
      );
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.onPressed, required this.icon, required this.label});
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
        icon: Icon(icon, size: 19),
        label: Text(label),
      );
}

class _SecondaryIconButton extends StatelessWidget {
  const _SecondaryIconButton({required this.onPressed, required this.icon, required this.tooltip});
  final VoidCallback? onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon),
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF101B2C) : scheme.surfaceContainerHighest.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .85)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
