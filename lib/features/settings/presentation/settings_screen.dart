import 'package:flutter/material.dart';
import 'package:github_manager/core/widgets/app_main_navigation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:github_manager/app/theme/app_theme_controller.dart';
import 'package:github_manager/core/background/build_monitor_service.dart';
import 'package:github_manager/core/errors/app_exception.dart';
import 'package:github_manager/core/providers/core_providers.dart';
import 'package:github_manager/core/widgets/adaptive_dialog.dart';
import 'package:github_manager/core/widgets/centered_notice.dart';
import 'package:github_manager/core/widgets/installed_version_banner.dart';
import 'package:github_manager/features/auth/presentation/auth_providers.dart';
import 'package:github_manager/features/home/domain/github_profile.dart';
import 'package:github_manager/features/home/presentation/github_profile_edit_dialog.dart';
import 'package:github_manager/features/home/presentation/home_providers.dart';
import 'package:github_manager/features/repositories/presentation/repository_providers.dart';
import 'package:go_router/go_router.dart';

part 'settings_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late ThemeMode _themeMode;
  Map<String, String>? _apiSettings;
  bool? _buildNotificationsEnabled;

  @override
  void initState() {
    super.initState();
    _themeMode = AppThemeController.instance.value;
    _loadApiSettings();
    _loadNotificationSettings();
  }

  Future<void> _loadApiSettings() async {
    final values = await ref.read(secureStorageProvider).readApiSettings();
    if (mounted) {
      setState(() => _apiSettings = values);
    }
  }


  Future<void> _loadNotificationSettings() async {
    final enabled = await BuildMonitorService.isEnabled();
    if (mounted) {
      setState(() => _buildNotificationsEnabled = enabled);
    }
  }

  Future<void> _setBuildNotifications(bool enabled) async {
    final resolved = await BuildMonitorService.setEnabled(enabled);
    if (!mounted) return;
    setState(() => _buildNotificationsEnabled = resolved);
    showCenteredNotice(context, resolved
              ? 'Avisos de build ativados.'
              : enabled
                  ? 'Permissão de notificações não concedida.'
                  : 'Avisos de build desativados.');
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await AppThemeController.instance.setMode(mode);
  }

  Future<void> _pasteInto(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    controller
      ..text = text.trim()
      ..selection = TextSelection.collapsed(offset: controller.text.length);
  }

  Future<void> _replaceGitHubToken() async {
    final controller = TextEditingController();
    var obscure = true;
    final token = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('GitHub API'),
          content: AdaptiveDialogBody(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cole um Personal Access Token fine-grained (github_pat_...) ou clássico (ghp_...). Ele será validado em /user antes de substituir o token atual.'),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Personal Access Token',
                      hintText: 'github_pat_... ou ghp_...',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _pasteInto(controller),
                            tooltip: 'Colar',
                            icon: const Icon(Icons.content_paste_rounded),
                          ),
                          IconButton(
                            onPressed: () => setDialogState(() => obscure = !obscure),
                            tooltip: obscure ? 'Exibir' : 'Ocultar',
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
                  TextButton.icon(
                    onPressed: () => context.push('/setup'),
                    icon: const Icon(Icons.help_outline_rounded),
                    label: const Text('Abrir guia de configuração'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Testar e salvar')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (token == null || token.isEmpty || !mounted) {
      return;
    }
    try {
      await ref.read(githubAuthRepositoryProvider).connectWithToken(token);
      ref.invalidate(githubConnectionProvider);
      ref.invalidate(githubProfileProvider);
      ref.invalidate(repositoriesProvider);
      if (mounted) {
        showCenteredNotice(context, 'Token validado e salvo.');
      }
    } catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  Future<void> _showGitHubTokenBackup() async {
    final token = await ref.read(secureStorageProvider).readGitHubToken();
    if (!mounted) {
      return;
    }
    if (token == null || token.isEmpty) {
      showCenteredNotice(context, 'Nenhum token GitHub salvo neste aparelho.');
      return;
    }
    var visible = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Backup do token GitHub'),
          content: AdaptiveDialogBody(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Este token dá acesso aos recursos autorizados no GitHub. Guarde-o em local seguro e não compartilhe publicamente.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      visible ? token : '•' * 24,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setDialogState(() => visible = !visible),
                        icon: Icon(
                          visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        label: Text(visible ? 'Ocultar' : 'Exibir'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: token));
                          if (context.mounted) {
                            showCenteredNotice(context, 'Token copiado.');
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disconnectGitHub() async {
    await ref.read(githubAuthRepositoryProvider).disconnect();
    ref.invalidate(githubConnectionProvider);
    ref.invalidate(githubProfileProvider);
    ref.invalidate(repositoriesProvider);
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _editProfile(GitHubProfile profile) async {
    final draft = await showGitHubProfileEditDialog(context, profile);
    if (draft == null || !mounted) return;
    try {
      await ref.read(githubProfileRepositoryProvider).updateProfile(
            name: draft.name,
            email: draft.email,
            blog: draft.blog,
            twitterUsername: draft.twitterUsername,
            company: draft.company,
            location: draft.location,
            bio: draft.bio,
            hireable: draft.hireable,
          );
      ref.invalidate(githubProfileProvider);
      if (mounted) {
        showCenteredNotice(
          context,
          'Perfil atualizado no GitHub.',
          kind: CenteredNoticeKind.success,
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _editApi() async {
    final current = _apiSettings ?? await ref.read(secureStorageProvider).readApiSettings();
    if (!mounted) {
      return;
    }
    final name = TextEditingController(text: current['name'] ?? 'Groq');
    final baseUrl = TextEditingController(text: current['baseUrl'] ?? 'https://api.groq.com/openai/v1');
    final apiKey = TextEditingController(text: current['apiKey'] ?? '');
    final model = TextEditingController(text: current['model'] ?? '');
    var provider = current['provider'] ?? 'groq';
    var obscure = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configurar API'),
          content: AdaptiveDialogBody(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Para que serve? Esta integração foi preparada para recursos opcionais de IA, '
                      'como resumir logs e explicar erros de build em linguagem simples. '
                      'Na versão atual nenhuma função principal depende do Groq, então você pode deixar sem chave.',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'groq', label: Text('Groq')),
                      ButtonSegment(value: 'custom', label: Text('Personalizada')),
                    ],
                    selected: {provider},
                    onSelectionChanged: (value) {
                      setDialogState(() {
                        provider = value.first;
                        if (provider == 'groq') {
                          name.text = 'Groq';
                          if (baseUrl.text.trim().isEmpty) {
                            baseUrl.text = 'https://api.groq.com/openai/v1';
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome da integração')),
                  const SizedBox(height: 10),
                  TextField(controller: baseUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Base URL')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: apiKey,
                    obscureText: obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _pasteInto(apiKey),
                            tooltip: 'Colar',
                            icon: const Icon(Icons.content_paste_rounded),
                          ),
                          IconButton(
                            onPressed: () => setDialogState(() => obscure = !obscure),
                            tooltip: obscure ? 'Exibir' : 'Ocultar',
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
                  TextField(controller: model, decoration: const InputDecoration(labelText: 'Modelo padrão (opcional)')),
                  const SizedBox(height: 10),
                  const Text('A chave fica apenas no armazenamento seguro do Android; não é enviada ao repositório.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      await ref.read(secureStorageProvider).writeApiSettings(
            provider: provider,
            name: name.text,
            baseUrl: baseUrl.text,
            apiKey: apiKey.text,
            model: model.text,
          );
      await _loadApiSettings();
      if (mounted) {
        showCenteredNotice(context, 'Configuração da API salva.');
      }
    }

    name.dispose();
    baseUrl.dispose();
    apiKey.dispose();
    model.dispose();
  }

  Future<void> _copySupportText(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      showCenteredNotice(
        context,
        message,
        kind: CenteredNoticeKind.success,
      );
    }
  }

  void _showError(Object error) {
    final message = error is AppException ? error.message : 'Não foi possível concluir a operação.';
    showCenteredNotice(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(githubProfileProvider);
    final api = _apiSettings;
    return Scaffold(
      bottomNavigationBar: const AppMainNavigation(selectedIndex: 4),
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
        children: [
          const _SectionTitle('Aparência'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Sistema')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Escuro')),
                ],
                selected: {_themeMode},
                onSelectionChanged: (value) => _setTheme(value.first),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Notificações'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Avisar quando builds terminarem'),
              subtitle: const Text(
                'Enquanto o aplicativo está ativo, verifica builds recentes em intervalos curtos. '
                'Em segundo plano, o Android controla a frequência mínima das verificações.',
              ),
              value: _buildNotificationsEnabled ?? true,
              onChanged: _buildNotificationsEnabled == null
                  ? null
                  : _setBuildNotifications,
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Integrações'),
          profile.when(
            loading: () => const _IntegrationLoadingCard(title: 'GitHub'),
            error: (_, _) => _IntegrationCard(
              icon: Icons.code_rounded,
              title: 'GitHub',
              subtitle: 'Token não configurado ou inválido',
              status: 'Configurar',
              onTap: _replaceGitHubToken,
            ),
            data: (data) => _IntegrationCard(
              icon: Icons.code_rounded,
              title: 'GitHub',
              subtitle: '${data.name?.isNotEmpty == true ? data.name : data.login} • @${data.login}',
              status: 'Conectado',
              onTap: () => _showGitHubIntegration(data),
            ),
          ),
          const SizedBox(height: 8),
          _IntegrationCard(
            icon: Icons.auto_awesome_rounded,
            title: api?['name']?.isNotEmpty == true ? api!['name']! : 'Groq / API personalizada',
            subtitle: api == null
                ? 'Carregando configuração…'
                : 'IA opcional para futuros resumos e explicações de logs. '
                    'Hoje não é necessária para usar o GitHub Manager.',
            status: api?['apiKey']?.isNotEmpty == true ? 'Configurada' : 'Opcional',
            onTap: _editApi,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Text(
              'A integração Groq está preparada para recursos de IA, como resumir logs e explicar erros de build. '
              'Nesta versão ela ainda não é usada automaticamente; você pode deixar sem chave.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Transferências'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Central de Envios'),
                  subtitle: const Text('Acompanhar envios, builds e tentativas interrompidas.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/uploads'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: const Text('Central de Downloads'),
                  subtitle: const Text('Acompanhar APKs, ZIPs, artifacts e logs.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/downloads'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Ajuda e segurança'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Assistente de configuração'),
                  subtitle: const Text('Rever token, permissões e teste de conexão.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/setup'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Versão instalada'),
          const _InstalledVersionCard(),
          const SizedBox(height: 18),
          const _SectionTitle('Sobre e novidades'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('GitHub Manager'),
                  subtitle: Text(
                    'Gerenciador GitHub local-first para Android\n'
                    'Desenvolvedor: @AdriedsonLemos',
                  ),
                ),
                const Divider(height: 1),
                ExpansionTile(
                  leading: const Icon(Icons.new_releases_outlined),
                  title: const Text('Últimas 3 mudanças'),
                  subtitle: const Text('Toque para expandir'),
                  initiallyExpanded: false,
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: const [
                    _ChangeNote(
                      version: '2.0.53',
                      text: 'Corrige a splash screen do Android 12+: fundo branco e área segura maior para o ícone não ser cortado.',
                    ),
                    _ChangeNote(
                      version: '2.0.52',
                      text: 'Corrige a compilação Kotlin dos serviços de upload/download usando um ícone de notificação dedicado compatível com Android.',
                    ),
                    _ChangeNote(
                      version: '2.0.51',
                      text: 'Novo ícone Android/adaptive icon e correção do pubspec.lock que bloqueava CI e geração do APK com exit code 65.',
                    ),
                  ],
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Apoiar via Pix'),
                  subtitle: const Text('adriedson@outlook.com • toque para copiar'),
                  trailing: const Icon(Icons.copy_rounded),
                  onTap: () => _copySupportText(
                    'adriedson@outlook.com',
                    'Chave Pix copiada.',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('Fale conosco / Feedback'),
                  subtitle: const Text('adriedson@outlook.com • toque para copiar'),
                  trailing: const Icon(Icons.copy_rounded),
                  onTap: () => _copySupportText(
                    'adriedson@outlook.com',
                    'E-mail de contato copiado.',
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Text(
                    'GitHub Manager é um projeto independente. Não possui parceria, afiliação, endosso ou patrocínio do GitHub.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGitHubIntegration(GitHubProfile profile) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub'),
        content: AdaptiveDialogBody(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    foregroundImage: profile.avatarUrl.isEmpty ? null : NetworkImage(profile.avatarUrl),
                    child: profile.avatarUrl.isEmpty ? const Icon(Icons.person_outline_rounded) : null,
                  ),
                  title: Text(profile.name?.isNotEmpty == true ? profile.name! : profile.login),
                  subtitle: Text('@${profile.login}'),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'As permissões podem variar por repositório. Abra um repositório e toque em “Diagnóstico do token” para verificar Contents, Actions, Secrets, administração e exclusão sem alterar dados.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pop(context);
                    _editProfile(profile);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar perfil permitido pela API'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _replaceGitHubToken();
                  },
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Substituir token'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showGitHubTokenBackup();
                  },
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Exibir / copiar token para backup'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _disconnectGitHub();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Desconectar GitHub'),
                ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ),
    );
  }
}
