import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commits')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            FutureBuilder<List<RepositoryBranch>>(
              future: _branchesFuture,
              builder: (context, snapshot) {
                final branches = snapshot.data ?? const <RepositoryBranch>[];
                final names = branches.map((item) => item.name).toSet();
                if (!names.contains(_branch)) {
                  names.add(_branch);
                }
                return DropdownButtonFormField<String>(
                  initialValue: _branch,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: names.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _changeBranch(value);
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<RepositoryCommit>>(
              future: _commitsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(_message(snapshot.error!))));
                }
                final commits = snapshot.data ?? const <RepositoryCommit>[];
                if (commits.isEmpty) {
                  return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Nenhum commit encontrado nesta branch.')));
                }
                return Column(
                  children: commits
                      .map(
                        (commit) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.commit_rounded),
                            title: Text(commit.message.split('\n').first, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${commit.author} • ${_formatDate(commit.date)}\n${commit.shortSha}'),
                            isThreeLine: true,
                          ),
                        ),
                      )
                      .toList(),
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
