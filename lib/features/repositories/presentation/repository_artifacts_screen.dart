import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/features/builds/domain/action_artifact.dart';
import 'package:github_manager/features/builds/presentation/build_providers.dart';
import 'package:github_manager/features/downloads/presentation/download_center_button.dart';
import 'package:github_manager/features/downloads/presentation/download_providers.dart';

class RepositoryArtifactsScreen extends ConsumerStatefulWidget {
  const RepositoryArtifactsScreen({required this.repositoryFullName, super.key});

  final String repositoryFullName;

  @override
  ConsumerState<RepositoryArtifactsScreen> createState() =>
      _RepositoryArtifactsScreenState();
}

class _RepositoryArtifactsScreenState
    extends ConsumerState<RepositoryArtifactsScreen> {
  late Future<List<ActionArtifact>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ActionArtifact>> _load() => ref
      .read(artifactServiceProvider)
      .listArtifacts(widget.repositoryFullName);

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  void _download(ActionArtifact artifact) {
    ref.read(downloadManagerProvider).startArtifactApk(
          repositoryFullName: widget.repositoryFullName,
          artifact: artifact,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download iniciado. Acompanhe pelo botão de Downloads.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('APKs e Artifacts'),
        actions: const [DownloadCenterButton(), SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ActionArtifact>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(_message(snapshot.error!)),
                    ),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? const <ActionArtifact>[];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: const [
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Nenhum artifact disponível neste repositório.'),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final artifact = items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              artifact.likelyContainsApk
                                  ? Icons.android_rounded
                                  : Icons.inventory_2_outlined,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                artifact.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatBytes(artifact.sizeBytes)} • ${_formatDate(artifact.createdAt)}',
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: artifact.likelyContainsApk
                                ? () => _download(artifact)
                                : null,
                            icon: const Icon(Icons.download_rounded),
                            label: Text(
                              artifact.likelyContainsApk
                                  ? 'Baixar APK'
                                  : 'Sem APK detectado',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _message(Object error) => error is AppException
      ? error.message
      : 'Não foi possível carregar os artifacts.';

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Data indisponível';
    }
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
