import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/platform/platform_actions.dart';
import 'package:github_manager/core/security/github_token_normalizer.dart';
import 'package:github_manager/features/auth/presentation/auth_providers.dart';
import 'package:github_manager/features/home/presentation/home_providers.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';

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

  static const _fineGrainedTokenUrl = 'https://github.com/settings/personal-access-tokens/new';
  static const _classicTokenUrl = 'https://github.com/settings/tokens/new';

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
      showCenteredNotice(context, 'Conexão com o GitHub validada.');
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
      showCenteredNotice(context, message);
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
                      onOpenFineGrained: () =>
                          PlatformActions.openUri(_fineGrainedTokenUrl),
                      onOpenClassic: () => PlatformActions.openUri(_classicTokenUrl),
                      onCopyFineGrained: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _fineGrainedTokenUrl),
                        );
                        if (context.mounted) {
                          showCenteredNotice(context, 'Link do token fine-grained copiado.');
                        }
                      },
                      onCopyClassic: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _classicTokenUrl),
                        );
                        if (context.mounted) {
                          showCenteredNotice(context, 'Link do token clássico copiado.');
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
    required this.onOpenFineGrained,
    required this.onOpenClassic,
    required this.onCopyFineGrained,
    required this.onCopyClassic,
    required this.onBack,
    required this.onNext,
    super.key,
  });

  final VoidCallback onOpenFineGrained;
  final VoidCallback onOpenClassic;
  final VoidCallback onCopyFineGrained;
  final VoidCallback onCopyClassic;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _WizardCard(
        title: 'Crie um Personal Access Token',
        icon: Icons.admin_panel_settings_outlined,
        children: [
          const Text(
            'O GitHub Manager aceita tanto token fine-grained (github_pat_...) quanto token clássico (ghp_...). Prefira fine-grained quando possível e libere somente os repositórios e permissões que pretende usar.',
          ),
          const SizedBox(height: 14),
          Text(
            'Fine-grained',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const _Bullet('Contents: Read and write — ler e sincronizar arquivos do projeto.'),
          const _Bullet('Workflows: Read and write — necessário quando o ZIP altera .github/workflows.'),
          const _Bullet('Actions: Read and write — listar, executar, cancelar e reexecutar builds.'),
          const _Bullet('Secrets: Read and write — listar, criar, substituir e excluir Secrets.'),
          const _Bullet('Administration: Read and write — somente para recursos administrativos e exclusão de repositório.'),
          const _Bullet('Issues: Read and write — somente se quiser gerenciar Bugs/Issues pelo app.'),
          const _Bullet('Metadata: leitura é concedida pelo GitHub e ajuda a identificar os repositórios permitidos.'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onOpenFineGrained,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Criar fine-grained'),
              ),
              OutlinedButton.icon(
                onPressed: onCopyFineGrained,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copiar link'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Token clássico',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const _Bullet('repo — acesso aos repositórios privados e aos Secrets do repositório.'),
          const _Bullet('workflow — necessário para criar ou alterar arquivos de workflow.'),
          const _Bullet('delete_repo — somente se quiser excluir repositórios pelo aplicativo.'),
          const _Bullet('user — somente se quiser editar dados do perfil.'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenClassic,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Criar clássico'),
              ),
              OutlinedButton.icon(
                onPressed: onCopyClassic,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copiar link'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Depois de conectar, cada repositório possui “Diagnóstico do token”. Ele faz apenas consultas de leitura e mostra quais permissões estão confirmadas, ausentes ou precisam ser conferidas no PAT fine-grained.',
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
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!working) {
                onConnect();
              }
            },
            decoration: InputDecoration(
              labelText: 'Personal Access Token',
              hintText: 'github_pat_... ou ghp_...',
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
                      final normalized = normalizeGitHubToken(text);
                      token
                        ..text = normalized
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
          const Text('Ao tocar em Testar e conectar, o GitHub Manager consulta /user. Tokens fine-grained e clássicos são aceitos; se a API responder corretamente, o token é salvo no armazenamento seguro do aparelho.'),
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
