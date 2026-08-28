import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/features/issues/domain/repository_issue.dart';
import 'package:github_manager/features/issues/presentation/issue_providers.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';

class RepositoryIssuesScreen extends ConsumerStatefulWidget {
  const RepositoryIssuesScreen({required this.repositoryFullName, super.key});

  final String repositoryFullName;

  @override
  ConsumerState<RepositoryIssuesScreen> createState() =>
      _RepositoryIssuesScreenState();
}

class _RepositoryIssuesScreenState
    extends ConsumerState<RepositoryIssuesScreen> {
  late Future<List<RepositoryIssue>> _future;
  String _filter = 'open';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RepositoryIssue>> _load() => ref
      .read(repositoryIssueServiceProvider)
      .listIssues(widget.repositoryFullName, state: _filter);

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Future<void> _changeFilter(String value) async {
    setState(() {
      _filter = value;
      _future = _load();
    });
    await _future;
  }

  Future<void> _createIssue() async {
    final result = await _showIssueDialog();
    if (result == null || !mounted) {
      return;
    }
    try {
      await ref.read(repositoryIssueServiceProvider).createIssue(
            repositoryFullName: widget.repositoryFullName,
            title: result.$1,
            body: result.$2,
          );
      await _refresh();
      if (mounted) {
        showCenteredNotice(context, 'Issue criada no GitHub.');
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<void> _openIssue(RepositoryIssue issue) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${issue.number} ${issue.title}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                issue.body.isEmpty ? 'Sem descrição.' : issue.body,
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar issue'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  issue.isOpen
                      ? Icons.check_circle_outline_rounded
                      : Icons.refresh_rounded,
                ),
                title: Text(issue.isOpen ? 'Fechar issue' : 'Reabrir issue'),
                onTap: () => Navigator.pop(context, 'toggle'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'edit') {
      final edited = await _showIssueDialog(issue: issue);
      if (edited == null || !mounted) {
        return;
      }
      await _updateIssue(
        issue,
        title: edited.$1,
        body: edited.$2,
        state: issue.state,
      );
    } else if (action == 'toggle') {
      await _updateIssue(
        issue,
        title: issue.title,
        body: issue.body,
        state: issue.isOpen ? 'closed' : 'open',
      );
    }
  }

  Future<void> _updateIssue(
    RepositoryIssue issue, {
    required String title,
    required String body,
    required String state,
  }) async {
    try {
      await ref.read(repositoryIssueServiceProvider).updateIssue(
            repositoryFullName: widget.repositoryFullName,
            number: issue.number,
            title: title,
            body: body,
            state: state,
          );
      await _refresh();
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<(String, String)?> _showIssueDialog({RepositoryIssue? issue}) async {
    final title = TextEditingController(text: issue?.title ?? '');
    final body = TextEditingController(text: issue?.body ?? '');
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(issue == null ? 'Nova issue' : 'Editar issue'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context, (title.text.trim(), body.text.trim()));
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    title.dispose();
    body.dispose();
    return result;
  }

  void _showError(Object error) {
    final message = error is AppException
        ? error.message
        : 'Não foi possível concluir a operação.';
    showCenteredNotice(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(),
      appBar: AppBar(
        title: const Text('Issues / Bugs'),
        actions: [
          IconButton(
            onPressed: () => _refresh(),
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createIssue,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova issue'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'open', label: Text('Abertos')),
                ButtonSegment(value: 'closed', label: Text('Fechados')),
                ButtonSegment(value: 'all', label: Text('Todos')),
              ],
              selected: {_filter},
              onSelectionChanged: (value) => _changeFilter(value.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<RepositoryIssue>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        _MessageCard(message: _message(snapshot.error!)),
                      ],
                    );
                  }
                  final issues = snapshot.data ?? const <RepositoryIssue>[];
                  if (issues.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: const [
                        _MessageCard(
                          message: 'Nenhum bug encontrado neste filtro.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    itemCount: issues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      return Card(
                        child: ListTile(
                          onTap: () => _openIssue(issue),
                          leading: Icon(
                            issue.isOpen
                                ? Icons.radio_button_unchecked_rounded
                                : Icons.check_circle_outline_rounded,
                            color: issue.isOpen
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            issue.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '#${issue.number} • ${issue.author} • ${_formatDate(issue.updatedAt)}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _message(Object error) => error is AppException
      ? error.message
      : 'Não foi possível carregar os bugs.';

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return 'data indisponível';
    }
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(message),
        ),
      );
}
