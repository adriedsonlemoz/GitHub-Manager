part of 'repository_text_preview_screen.dart';

class _MarkdownPreview extends StatefulWidget {
  const _MarkdownPreview({
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
  State<_MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<_MarkdownPreview> {
  late List<_MarkdownBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _blocks = _parseMarkdown(widget.content);
  }

  @override
  void didUpdateWidget(covariant _MarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _blocks = _parseMarkdown(widget.content);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerItems = widget.truncated ? 3 : 2;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 88),
      cacheExtent: 700,
      itemCount: headerItems + _blocks.length,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _PreviewHeader(path: widget.path, branch: widget.branch);
        }
        if (index == 1) return const SizedBox(height: 10);
        if (widget.truncated && index == 2) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _TruncatedNotice(),
          );
        }
        final blockIndex = index - headerItems;
        return _MarkdownBlockWidget(block: _blocks[blockIndex]);
      },
    );
  }
}

enum _MarkdownBlockType {
  spacer,
  divider,
  heading,
  quote,
  bullet,
  ordered,
  code,
  paragraph,
}

class _MarkdownBlock {
  const _MarkdownBlock(
    this.type,
    this.text, {
    this.level = 0,
    this.marker,
  });

  final _MarkdownBlockType type;
  final String text;
  final int level;
  final String? marker;
}

final RegExp _markdownDivider = RegExp(r'^[-*_]{3,}$');
final RegExp _markdownHeading = RegExp(r'^(#{1,6})\s+(.+)$');
final RegExp _markdownQuotePrefix = RegExp(r'^>\s?');
final RegExp _markdownBullet = RegExp(r'^[-*+]\s+(.+)$');
final RegExp _markdownOrdered = RegExp(r'^(\d+)[.)]\s+(.+)$');
final RegExp _markdownImage = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
final RegExp _markdownLink = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');

List<_MarkdownBlock> _parseMarkdown(String content) {
  final lines = content.replaceAll('\r\n', '\n').split('\n');
  final blocks = <_MarkdownBlock>[];
  var index = 0;
  var inCode = false;
  final code = <String>[];

  void flushCode() {
    if (code.isEmpty) return;
    blocks.add(_MarkdownBlock(_MarkdownBlockType.code, code.join('\n')));
    code.clear();
  }

  while (index < lines.length) {
    final raw = lines[index];
    final trimmed = raw.trim();

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
      if (blocks.isEmpty || blocks.last.type != _MarkdownBlockType.spacer) {
        blocks.add(const _MarkdownBlock(_MarkdownBlockType.spacer, ''));
      }
      index++;
      continue;
    }
    if (_markdownDivider.hasMatch(trimmed)) {
      blocks.add(const _MarkdownBlock(_MarkdownBlockType.divider, ''));
      index++;
      continue;
    }

    final heading = _markdownHeading.firstMatch(trimmed);
    if (heading != null) {
      blocks.add(
        _MarkdownBlock(
          _MarkdownBlockType.heading,
          _cleanMarkdownInline(heading.group(2)!),
          level: heading.group(1)!.length,
        ),
      );
      index++;
      continue;
    }

    if (trimmed.startsWith('>')) {
      blocks.add(
        _MarkdownBlock(
          _MarkdownBlockType.quote,
          _cleanMarkdownInline(trimmed.replaceFirst(_markdownQuotePrefix, '')),
        ),
      );
      index++;
      continue;
    }

    final bullet = _markdownBullet.firstMatch(trimmed);
    if (bullet != null) {
      blocks.add(
        _MarkdownBlock(
          _MarkdownBlockType.bullet,
          _cleanMarkdownInline(bullet.group(1)!),
          marker: '•',
        ),
      );
      index++;
      continue;
    }

    final ordered = _markdownOrdered.firstMatch(trimmed);
    if (ordered != null) {
      blocks.add(
        _MarkdownBlock(
          _MarkdownBlockType.ordered,
          _cleanMarkdownInline(ordered.group(2)!),
          marker: '${ordered.group(1)}.',
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
          _markdownBullet.hasMatch(next) ||
          _markdownOrdered.hasMatch(next) ||
          _markdownDivider.hasMatch(next)) {
        break;
      }
      paragraph.add(next);
      index++;
    }
    blocks.add(
      _MarkdownBlock(
        _MarkdownBlockType.paragraph,
        _cleanMarkdownInline(paragraph.join(' ')),
      ),
    );
  }
  if (inCode) flushCode();
  return List<_MarkdownBlock>.unmodifiable(blocks);
}

String _cleanMarkdownInline(String value) {
  var result = value;
  result = result.replaceAllMapped(
    _markdownImage,
    (match) =>
        'Imagem: ${match.group(1)?.trim().isNotEmpty == true ? match.group(1) : match.group(2)}',
  );
  result = result.replaceAllMapped(
    _markdownLink,
    (match) => '${match.group(1)} (${match.group(2)})',
  );
  return result
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('~~', '')
      .replaceAll('`', '');
}

class _MarkdownBlockWidget extends StatelessWidget {
  const _MarkdownBlockWidget({required this.block});

  final _MarkdownBlock block;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case _MarkdownBlockType.spacer:
        return const SizedBox(height: 6);
      case _MarkdownBlockType.divider:
        return const Divider(height: 18);
      case _MarkdownBlockType.heading:
        final size = switch (block.level) {
          1 => 25.0,
          2 => 21.0,
          3 => 18.0,
          _ => 16.0,
        };
        return Padding(
          padding: EdgeInsets.only(
            top: block.level <= 2 ? 12 : 8,
            bottom: 4,
          ),
          child: SelectableText(
            block.text,
            style: TextStyle(
              fontSize: size,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      case _MarkdownBlockType.quote:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            block.text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        );
      case _MarkdownBlockType.bullet:
      case _MarkdownBlockType.ordered:
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 0, 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 27,
                child: Text(
                  block.marker ?? '•',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: SelectableText(
                  block.text,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ],
          ),
        );
      case _MarkdownBlockType.code:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            block.text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          ),
        );
      case _MarkdownBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: SelectableText(
            block.text,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        );
    }
  }
}
