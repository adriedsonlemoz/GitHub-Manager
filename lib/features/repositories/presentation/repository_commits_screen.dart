import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';

class RepositoryCommitsScreen extends ConsumerStatefulWidget {
  const RepositoryCommitsScreen({
    required this.repositoryFullName,
    required this.initialBranch,
    super.key,
  });

  final String repositoryFullName;
  final String initialBranch;

  @override
  ConsumerState<RepositoryCommitsScreen> createState() => _RepositoryCommitsScreenState();
}

class _RepositoryCommitsScreenState extends ConsumerState<RepositoryCommitsScreen> {
  late String _branch;
  late Future<List<RepositoryBranch>> _branchesFuture;
  late Future<List<RepositoryCommit>> _commitsFuture;

  @override
  void initState() {
    super.initState();
    _branch = widget.initialBranch;
    _branchesFuture = ref.read(repositoryGitServiceProvider).listBranches(widget.repositoryFullName);
    _commitsFuture = _loadCommits();
  }

  Future<List<RepositoryCommit>> _loadCommits() => ref.read(repositoryGitServiceProvider).listCommits(
        repositoryFullName: widget.repositoryFullName,
        branch: _branch,
      );

  Future<void> _refresh() async {
    final future = _loadCommits();
    setState(() => _commitsFuture = future);
    await future;
  }

  void _changeBranch(String branch) {
    setState(() {
      _branch = branch;
      _commitsFuture = _loadCommits();
    });
  }

  Future<void> _copySha(String sha) async {
    await Clipboard.setData(ClipboardData(text: sha));
    if (mounted) showCenteredNotice(context, 'SHA copiado.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(),
      appBar: AppBar(
        title: const Text('Commits'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            FutureBuilder<List<RepositoryBranch>>(
              future: _branchesFuture,
              builder: (context, snapshot) {
                final branches = snapshot.data ?? const <RepositoryBranch>[];
                final names = branches.map((item) => item.name).toSet();
                if (!names.contains(_branch)) names.add(_branch);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .38),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _branch,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: names
                          .map(
                            (name) => DropdownMenuItem(
                              value: name,
                              child: Row(
                                children: [
                                  const Icon(Icons.account_tree_outlined, size: 17),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(name)),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) _changeBranch(value);
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<RepositoryCommit>>(
              future: _commitsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(_message(snapshot.error!)),
                    ),
                  );
                }
                final commits = snapshot.data ?? const <RepositoryCommit>[];
                if (commits.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Nenhum commit encontrado nesta branch.'),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 7),
                      child: Text(
                        '${commits.length} commits carregados • $_branch',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    ...commits.map((commit) => Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _CommitCard(
                            commit: commit,
                            onCopySha: () => _copySha(commit.shortSha),
                          ),
                        )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _message(Object error) => error is AppException ? error.message : 'Não foi possível carregar os commits.';

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Data indisponível';
    }
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}


class _CommitCard extends StatelessWidget {
  const _CommitCard({required this.commit, required this.onCopySha});

  final RepositoryCommit commit;
  final VoidCallback onCopySha;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .36)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.commit_rounded, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commit.message.split('\n').first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${commit.author} • ${_commitDate(commit.date)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    commit.shortSha,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar SHA',
            visualDensity: VisualDensity.compact,
            onPressed: onCopySha,
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  static String _commitDate(DateTime? date) {
    if (date == null) return 'Data indisponível';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
