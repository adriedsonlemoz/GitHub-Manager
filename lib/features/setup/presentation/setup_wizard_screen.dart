import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/features/auth/presentation/auth_providers.dart';
import 'package:github_manager/features/home/presentation/home_providers.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:go_router/go_router.dart';

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final _token = TextEditingController();
  var _step = 0;
  bool _working = false;
  bool _obscure = true;

  static const _tokenUrl = 'https://github.com/settings/tokens/new';

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_working || _token.text.trim().isEmpty) {
      return;
    }
    setState(() => _working = true);
    try {
      await ref.read(githubAuthRepositoryProvider).connectWithToken(_token.text);
      ref.invalidate(githubConnectionProvider);
      ref.invalidate(githubProfileProvider);
      ref.invalidate(repositoriesProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conexão com o GitHub validada.')),
      );
      if (widget.embedded) {
        setState(() => _step = 3);
      } else {
        context.go('/');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is AppException
          ? error.message
          : 'Não foi possível validar o token. Confira o token e as permissões.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.developer_mode_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configurar GitHub Manager',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          'Conecte o GitHub uma vez para liberar projetos, builds e arquivos.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Progress(step: _step),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: switch (_step) {
                  0 => _Intro(key: const ValueKey(0), onNext: () => setState(() => _step = 1)),
                  1 => _Permissions(
                      key: const ValueKey(1),
                      onOpen: () => PlatformActions.openUri(_tokenUrl),
                      onCopy: () async {
                        await Clipboard.setData(const ClipboardData(text: _tokenUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copiado.')),
                          );
                        }
                      },
                      onBack: () => setState(() => _step = 0),
                      onNext: () => setState(() => _step = 2),
                    ),
                  2 => _TokenStep(
                      key: const ValueKey(2),
                      token: _token,
                      obscure: _obscure,
                      working: _working,
                      onToggle: () => setState(() => _obscure = !_obscure),
                      onBack: () => setState(() => _step = 1),
                      onConnect: _connect,
                    ),
                  _ => _Done(
                      key: const ValueKey(3),
                      onFinish: () {
                        ref.invalidate(githubConnectionProvider);
                        if (widget.embedded) {
                          setState(() {});
                        } else {
                          context.go('/');
                        }
                      },
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(appBar: AppBar(title: const Text('Assistente de configuração')), body: body);
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(4, (index) {
          final active = index <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == 3 ? 0 : 6),
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      );
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onNext, super.key});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _WizardCard(
        title: 'Por que o token é necessário?',
        icon: Icons.key_rounded,
        children: [
          const Text(
            'O GitHub Manager não usa servidor intermediário. Ele conversa diretamente com a API oficial do GitHub usando um token salvo somente no armazenamento seguro do aparelho.',
          ),
          const SizedBox(height: 14),
          const _Bullet('O login e a senha do GitHub nunca são pedidos pelo aplicativo.'),
          const _Bullet('Você escolhe quais repositórios o token pode acessar.'),
          const _Bullet('É possível trocar ou remover o token a qualquer momento nas Configurações.'),
          const SizedBox(height: 18),
          FilledButton(onPressed: onNext, child: const Text('Continuar')),
        ],
      );
}

class _Permissions extends StatelessWidget {
  const _Permissions({
    required this.onOpen,
    required this.onCopy,
    required this.onBack,
    required this.onNext,
    super.key,
  });

  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _WizardCard(
        title: 'Crie um Personal Access Token',
        icon: Icons.admin_panel_settings_outlined,
        children: [
          const Text('No GitHub, restrinja o token aos repositórios que deseja administrar e use estas permissões:'),
          const SizedBox(height: 12),
          const _Bullet('repo — acesso aos repositórios, arquivos, commits, Actions, Issues e Secrets.'),
          const _Bullet('workflow — necessário para criar ou alterar arquivos de workflow.'),
          const _Bullet('delete_repo — somente se quiser excluir repositórios pelo aplicativo.'),
          const _Bullet('user — somente se quiser editar dados do perfil pela engrenagem.'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(onPressed: onOpen, icon: const Icon(Icons.open_in_new_rounded), label: const Text('Abrir GitHub')),
              OutlinedButton.icon(onPressed: onCopy, icon: const Icon(Icons.copy_rounded), label: const Text('Copiar link')),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              TextButton(onPressed: onBack, child: const Text('Voltar')),
              const Spacer(),
              FilledButton(onPressed: onNext, child: const Text('Já criei o token')),
            ],
          ),
        ],
      );
}

class _TokenStep extends StatelessWidget {
  const _TokenStep({
    required this.token,
    required this.obscure,
    required this.working,
    required this.onToggle,
    required this.onBack,
    required this.onConnect,
    super.key,
  });

  final TextEditingController token;
  final bool obscure;
  final bool working;
  final VoidCallback onToggle;
  final VoidCallback onBack;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => _WizardCard(
        title: 'Cole e teste o token',
        icon: Icons.link_rounded,
        children: [
          TextField(
            controller: token,
            obscureText: obscure,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Personal Access Token',
              hintText: 'ghp_...',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      final text = data?.text;
                      if (text == null || text.isEmpty) {
                        return;
                      }
                      token
                        ..text = text.trim()
                        ..selection = TextSelection.collapsed(offset: token.text.length);
                    },
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: const Text('Colar'),
                  ),
                  IconButton(
                    onPressed: onToggle,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Ao tocar em Testar e conectar, o GitHub Manager consulta /user. Se a API responder corretamente, o token é salvo no aparelho.'),
          const SizedBox(height: 18),
          Row(
            children: [
              TextButton(onPressed: working ? null : onBack, child: const Text('Voltar')),
              const Spacer(),
              FilledButton.icon(
                onPressed: working ? null : onConnect,
                icon: working
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.verified_user_outlined),
                label: Text(working ? 'Testando...' : 'Testar e conectar'),
              ),
            ],
          ),
        ],
      );
}

class _Done extends StatelessWidget {
  const _Done({required this.onFinish, super.key});
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => _WizardCard(
        title: 'GitHub conectado',
        icon: Icons.check_circle_rounded,
        children: [
          const Text('Configuração concluída. A tela inicial agora pode carregar seus repositórios diretamente do GitHub.'),
          const SizedBox(height: 18),
          FilledButton(onPressed: onFinish, child: const Text('Abrir meus projetos')),
        ],
      );
}

class _WizardCard extends StatelessWidget {
  const _WizardCard({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_rounded, size: 16)),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
