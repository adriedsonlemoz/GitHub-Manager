import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/home/domain/github_profile.dart';
import 'package:github_manager/features/home/presentation/github_profile_edit_dialog.dart';
import 'package:github_manager/features/home/presentation/home_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    GitHubProfile data,
  ) async {
    final draft = await showGitHubProfileEditDialog(context, data);
    if (draft == null || !context.mounted) return;
    try {
      await ref.read(githubProfileRepositoryProvider).updateProfile(
            name: draft.name,
            email: draft.email,
            blog: draft.blog,
            twitterUsername: draft.twitterUsername,
            company: draft.company,
            location: draft.location,
            bio: draft.bio,
            hireable: draft.hireable,
          );
      ref.invalidate(githubProfileProvider);
      if (context.mounted) {
        showCenteredNotice(
          context,
          'Perfil atualizado no GitHub.',
          kind: CenteredNoticeKind.success,
        );
      }
    } catch (_) {
      if (context.mounted) {
        showCenteredNotice(context, 'Não foi possível atualizar o perfil.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(githubProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 2),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.tonalIcon(
            onPressed: () => ref.invalidate(githubProfileProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ),
        data: (data) {
          final scheme = Theme.of(context).colorScheme;
          final displayName =
              (data.name?.trim().isNotEmpty ?? false) ? data.name! : data.login;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(githubProfileProvider);
              await ref.read(githubProfileProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
              children: [
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: .55),
                        ),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            foregroundImage: data.avatarUrl.isEmpty
                                ? null
                                : NetworkImage(data.avatarUrl),
                            child: data.avatarUrl.isEmpty
                                ? const Icon(Icons.person_rounded, size: 42)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${data.login}',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          if (data.bio?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            Text(
                              data.bio!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _Metric(
                                  value: '${data.repositoryCount}',
                                  label: 'Repositórios',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Metric(
                                  value: '${data.publicRepos}',
                                  label: 'Públicos',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Metric(
                                  value: '${data.privateRepos}',
                                  label: 'Privados',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        tooltip: 'Editar perfil',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _edit(context, ref, data),
                        icon: const Icon(Icons.edit_outlined, size: 19),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailsCard(data: data),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.data});

  final GitHubProfile data;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (data.company?.trim().isNotEmpty == true)
        _DetailRow(Icons.business_outlined, 'Empresa', data.company!),
      if (data.location?.trim().isNotEmpty == true)
        _DetailRow(Icons.location_on_outlined, 'Localização', data.location!),
      if (data.email?.trim().isNotEmpty == true)
        _DetailRow(Icons.mail_outline_rounded, 'E-mail', data.email!),
      if (data.blog?.trim().isNotEmpty == true)
        _DetailRow(Icons.link_rounded, 'Site', data.blog!),
      if (data.twitterUsername?.trim().isNotEmpty == true)
        _DetailRow(
          Icons.alternate_email_rounded,
          'X / Twitter',
          '@${data.twitterUsername}',
        ),
      _DetailRow(
        Icons.work_outline_rounded,
        'Disponível para contratação',
        data.hireable ? 'Sim' : 'Não',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: rows),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
