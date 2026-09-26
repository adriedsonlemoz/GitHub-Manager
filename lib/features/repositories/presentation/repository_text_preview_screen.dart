import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';

part 'repository_markdown_preview.dart';

class RepositoryTextPreviewScreen extends ConsumerStatefulWidget {
  const RepositoryTextPreviewScreen.file({
    required this.repositoryFullName,
    required this.branch,
    required this.item,
    super.key,
  }) : readme = false;

  const RepositoryTextPreviewScreen.readme({
    required this.repositoryFullName,
    required this.branch,
    super.key,
  })  : item = null,
        readme = true;

  final String repositoryFullName;
  final String branch;
  final RepositoryContentItem? item;
  final bool readme;

  @override
  ConsumerState<RepositoryTextPreviewScreen> createState() =>
      _RepositoryTextPreviewScreenState();
}

class _RepositoryTextPreviewScreenState
    extends ConsumerState<RepositoryTextPreviewScreen> {
  late Future<RepositoryTextFile?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<RepositoryTextFile?> _load({bool forceRefresh = false}) {
    final service = ref.read(repositoryGitServiceProvider);
    if (widget.readme) {
      return service.readReadme(
        repositoryFullName: widget.repositoryFullName,
        branch: widget.branch,
        forceRefresh: forceRefresh,
      );
    }
    return service.readTextFile(
      repositoryFullName: widget.repositoryFullName,
      branch: widget.branch,
      path: widget.item!.path,
    );
  }

  Future<void> _refresh() async {
    final future = _load(forceRefresh: true);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 0),
      appBar: AppBar(
        title: Text(
          widget.readme ? 'README' : widget.item!.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<RepositoryTextFile?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PreviewLoading();
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is AppException
                ? error.message
                : 'Não foi possível abrir este arquivo.';
            return _PreviewMessage(
              icon: Icons.description_outlined,
              message: message,
            );
          }
          final file = snapshot.data;
          if (file == null) {
            return const _PreviewMessage(
              icon: Icons.menu_book_outlined,
              message: 'Este repositório ainda não possui um README.',
            );
          }

          final lower = file.name.toLowerCase();
          final isMarkdown = widget.readme ||
              lower.endsWith('.md') ||
              lower.endsWith('.markdown') ||
              lower.endsWith('.mdown');
          final maxChars = isMarkdown ? 180000 : 220000;
          final truncated = file.content.length > maxChars;
          final content = truncated
              ? file.content.substring(0, maxChars)
              : file.content;

          if (isMarkdown) {
            return _MarkdownPreview(
              content: content,
              path: file.path,
              branch: widget.branch,
              truncated: truncated,
            );
          }
          return _PlainTextPreview(
            content: content,
            path: file.path,
            branch: widget.branch,
            truncated: truncated,
          );
        },
      ),
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 14),
            Text('Abrindo conteúdo…'),
          ],
        ),
      );
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 38),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.path, required this.branch});

  final String path;
  final String branch;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(branch, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _TruncatedNotice extends StatelessWidget {
  const _TruncatedNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .tertiaryContainer
              .withValues(alpha: .55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Arquivo muito grande: exibindo apenas o início para manter o aplicativo responsivo.',
        ),
      );
}

class _PlainTextPreview extends StatelessWidget {
  const _PlainTextPreview({
    required this.content,
    required this.path,
    required this.branch,
    required this.truncated,
  });

  final String content;
  final String path;
  final String branch;
  final bool truncated;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 88),
        children: [
          _PreviewHeader(path: path, branch: branch),
          const SizedBox(height: 10),
          if (truncated) ...[
            const _TruncatedNotice(),
            const SizedBox(height: 10),
          ],
          SelectableText(
            content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      );
}

