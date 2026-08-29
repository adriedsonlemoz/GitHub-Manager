import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:github_manager/features/repositories/domain/repository_git_models.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';

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

  Future<RepositoryTextFile?> _load() {
    final service = ref.read(repositoryGitServiceProvider);
    if (widget.readme) {
      return service.readReadme(
        repositoryFullName: widget.repositoryFullName,
        branch: widget.branch,
      );
    }
    return service.readTextFile(
      repositoryFullName: widget.repositoryFullName,
      branch: widget.branch,
      path: widget.item!.path,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
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
            return const Center(child: CircularProgressIndicator());
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 88),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      file.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.branch,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (truncated) ...[
                Container(
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
                ),
                const SizedBox(height: 10),
              ],
              if (isMarkdown)
                _MarkdownDocument(content: content)
              else
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
        },
      ),
    );
  }
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

class _MarkdownDocument extends StatelessWidget {
  const _MarkdownDocument({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    var index = 0;
    var inCode = false;
    final code = <String>[];

    void flushCode() {
      if (code.isEmpty) return;
      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            code.join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          ),
        ),
      );
      code.clear();
    }

    while (index < lines.length) {
      final raw = lines[index];
      final line = raw.trimRight();
      final trimmed = line.trim();

      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        if (inCode) flushCode();
        inCode = !inCode;
        index++;
        continue;
      }
      if (inCode) {
        code.add(raw);
        index++;
        continue;
      }
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        index++;
        continue;
      }
      if (RegExp(r'^[-*_]{3,}$').hasMatch(trimmed)) {
        widgets.add(const Divider(height: 18));
        index++;
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final size = switch (level) {
          1 => 25.0,
          2 => 21.0,
          3 => 18.0,
          _ => 16.0,
        };
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: level <= 2 ? 12 : 8, bottom: 4),
            child: SelectableText(
              _cleanInline(heading.group(2)!),
              style: TextStyle(
                fontSize: size,
                height: 1.25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
        index++;
        continue;
      }

      if (trimmed.startsWith('>')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _cleanInline(trimmed.replaceFirst(RegExp(r'^>\s?'), '')),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        );
        index++;
        continue;
      }

      final bullet = RegExp(r'^[-*+]\s+(.+)$').firstMatch(trimmed);
      final ordered = RegExp(r'^(\d+)[.)]\s+(.+)$').firstMatch(trimmed);
      if (bullet != null || ordered != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 0, 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 27,
                  child: Text(
                    bullet != null ? '•' : '${ordered!.group(1)}.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    _cleanInline(
                      bullet?.group(1) ?? ordered!.group(2)!,
                    ),
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
        index++;
        continue;
      }

      final paragraph = <String>[trimmed];
      index++;
      while (index < lines.length) {
        final next = lines[index].trim();
        if (next.isEmpty ||
            next.startsWith('#') ||
            next.startsWith('>') ||
            next.startsWith('```') ||
            next.startsWith('~~~') ||
            RegExp(r'^[-*+]\s+').hasMatch(next) ||
            RegExp(r'^\d+[.)]\s+').hasMatch(next)) {
          break;
        }
        paragraph.add(next);
        index++;
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: SelectableText(
            _cleanInline(paragraph.join(' ')),
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
      );
    }
    if (inCode) flushCode();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  static String _cleanInline(String value) {
    var result = value;
    result = result.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
      (match) => 'Imagem: ${match.group(1)?.trim().isNotEmpty == true ? match.group(1) : match.group(2)}',
    );
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (match) => '${match.group(1)} (${match.group(2)})',
    );
    result = result
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('~~', '')
        .replaceAll('`', '');
    return result;
  }
}
