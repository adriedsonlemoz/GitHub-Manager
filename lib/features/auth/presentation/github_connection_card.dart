import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/features/auth/presentation/auth_providers.dart';
import 'package:github_manager/features/home/presentation/home_providers.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';

class GitHubConnectionCard extends ConsumerStatefulWidget {
  const GitHubConnectionCard({super.key});

  @override
  ConsumerState<GitHubConnectionCard> createState() => _GitHubConnectionCardState();
}

class _GitHubConnectionCardState extends ConsumerState<GitHubConnectionCard> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refreshGitHubState() {
    ref.invalidate(githubConnectionProvider);
    ref.invalidate(githubProfileProvider);
    ref.invalidate(repositoriesProvider);
  }

  Future<void> _connect() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(githubAuthRepositoryProvider).connectWithToken(_controller.text);
      _controller.clear();
      _refreshGitHubState();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is AppException ? error.message : 'Não foi possível conectar ao GitHub.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _disconnect() async {
    await ref.read(githubAuthRepositoryProvider).disconnect();
    _refreshGitHubState();
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(githubConnectionProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: connection.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Não foi possível verificar a conexão GitHub.'),
          data: (connected) {
            if (connected) {
              return Row(
                children: [
                  const Icon(Icons.verified_rounded),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('GitHub conectado neste dispositivo.')),
                  TextButton(onPressed: _disconnect, child: const Text('Desconectar')),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conectar GitHub', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'O token é validado no GitHub e salvo somente no armazenamento seguro do Android.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Token GitHub',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!_submitting) {
                _connect();
              }
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _submitting ? null : _connect,
                  icon: _submitting
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.link_rounded),
                  label: const Text('Conectar'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
